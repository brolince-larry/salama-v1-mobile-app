import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_theme.dart';
import '../../providers/school_management_provider.dart';
import '../../providers/subscription_provider.dart';
import '../../models/school.dart';

class AddSchoolScreen extends ConsumerStatefulWidget {
  final School? school;
  const AddSchoolScreen({super.key, this.school});

  @override
  ConsumerState<AddSchoolScreen> createState() => _AddSchoolScreenState();
}

class _AddSchoolScreenState extends ConsumerState<AddSchoolScreen> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isObscure = true;

  // Hybrid Image Storage
  Uint8List? _logoBytes;
  Uint8List? _adminBytes;
  final ImagePicker _picker = ImagePicker();

  // Optimized Controllers
  late final TextEditingController _nameCtrl;
  late final TextEditingController _addressCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lngCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;

  // Admin Controllers (Only for new registrations)
  final _adminNameCtrl = TextEditingController();
  final _adminEmailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _passwordConfirmCtrl = TextEditingController();

  // Selected plan — null until API loads; defaults to first active plan
  int? _selectedPlanId;

  @override
  void initState() {
    super.initState();
    final s = widget.school;
    _nameCtrl = TextEditingController(text: s?.name ?? '');
    _addressCtrl = TextEditingController(text: s?.address ?? '');
    _latCtrl = TextEditingController(text: s?.lat?.toString() ?? '0.0');
    _lngCtrl = TextEditingController(text: s?.lng?.toString() ?? '0.0');
    _phoneCtrl = TextEditingController(text: s?.phone ?? '');
    _emailCtrl = TextEditingController(text: s?.email ?? '');

    // Only needed when registering a new school
    if (widget.school == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(plansProvider.notifier).fetchActivePlans();
      });
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _addressCtrl.dispose();
    _latCtrl.dispose();
    _lngCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _adminNameCtrl.dispose();
    _adminEmailCtrl.dispose();
    _passwordCtrl.dispose();
    _passwordConfirmCtrl.dispose();
    super.dispose();
  }

  void _showFeedback(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(message, style: const TextStyle(fontWeight: FontWeight.w500)),
        backgroundColor: isError ? AppTheme.danger : AppTheme.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _pickImage(bool isLogo) async {
    try {
      final XFile? image = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          if (isLogo) {
            _logoBytes = bytes;
          } else {
            _adminBytes = bytes;
          }
        });
      }
    } catch (e) {
      debugPrint('Image pick error: $e');
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final isEdit = widget.school != null;

    if (!isEdit) {
      if (_passwordCtrl.text != _passwordConfirmCtrl.text) {
        _showFeedback('Passwords do not match', isError: true);
        return;
      }
      if (_selectedPlanId == null) {
        _showFeedback('Please select a service plan', isError: true);
        return;
      }
    }

    setState(() => _isLoading = true);

    final Map<String, dynamic> data = {
      'name': _nameCtrl.text.trim(),
      'address': _addressCtrl.text.trim(),
      'lat': _latCtrl.text.trim(),
      'lng': _lngCtrl.text.trim(),
      'phone': _phoneCtrl.text.trim(),
      'email': _emailCtrl.text.trim(),
      'logo_bytes': _logoBytes,
    };

    if (!isEdit) {
      data.addAll({
        'admin_name': _adminNameCtrl.text.trim(),
        'admin_email': _adminEmailCtrl.text.trim(),
        'password': _passwordCtrl.text,
        'password_confirmation': _passwordConfirmCtrl.text,
        'plan_id': _selectedPlanId.toString(),
        'admin_bytes': _adminBytes,
      });
    }

    try {
      if (!isEdit) {
        await ref.read(schoolListProvider.notifier).createSchool(data);
        if (mounted) _showFeedback('School Ecosystem Launched!');
      } else {
        await ref
            .read(schoolListProvider.notifier)
            .updateSchool(widget.school!.id, data);
        if (mounted) _showFeedback('School Records Optimized!');
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) _showFeedback(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Build
  // ──────────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final isEdit = widget.school != null;

    return Scaffold(
      backgroundColor: dark ? const Color(0xFF0A0E0A) : Colors.grey[50],
      appBar: AppBar(
        title: Text(isEdit ? 'Optimize School' : 'New Registration'),
        elevation: 0,
        actions: [
          if (!_isLoading)
            IconButton(
              icon: const Icon(Icons.done_all_rounded, color: AppTheme.primary),
              onPressed: _save,
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    _sectionHeader(
                        '1. School Identity', Icons.business_center_rounded),
                    _buildImagePicker(
                      label: 'School Logo',
                      bytes: _logoBytes,
                      remoteUrl: widget.school?.logoUrl,
                      onTap: () => _pickImage(true),
                      dark: dark,
                    ),
                    const SizedBox(height: 20),
                    _buildSchoolFields(dark),
                    if (!isEdit) ...[
                      const SizedBox(height: 32),
                      _sectionHeader(
                          '2. Primary Administrator', Icons.shield_rounded),
                      _buildImagePicker(
                        label: 'Admin Profile',
                        bytes: _adminBytes,
                        remoteUrl: null,
                        onTap: () => _pickImage(false),
                        dark: dark,
                      ),
                      const SizedBox(height: 20),
                      _buildAdminFields(dark),
                      const SizedBox(height: 32),
                      _sectionHeader('3. Service Plan', Icons.bolt_rounded),
                      _buildPlanSelector(dark),
                    ],
                    const SizedBox(height: 40),
                    _buildSubmitButton(isEdit),
                  ],
                ),
              ),
            ),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Plan Selector — dynamic from API
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildPlanSelector(bool dark) {
    final plansState = ref.watch(plansProvider);

    // Loading state
    if (plansState.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    // Error state with retry
    if (plansState.error != null) {
      return _cardWrapper(dark, [
        const Icon(Icons.sync_problem_rounded,
            color: AppTheme.danger, size: 36),
        const SizedBox(height: 8),
        Text(
          'Could not load plans',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: () => ref.read(plansProvider.notifier).fetchActivePlans(),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Retry'),
        ),
      ]);
    }

    // Empty — shouldn't happen in production but handled gracefully
    if (plansState.plans.isEmpty) {
      return _cardWrapper(dark, [
        Text(
          'No active plans available.',
          style: TextStyle(color: Colors.grey[600], fontSize: 13),
        ),
      ]);
    }

    // Set default selection to first plan when plans load
    if (_selectedPlanId == null && plansState.plans.isNotEmpty) {
      // Use addPostFrameCallback to avoid setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() => _selectedPlanId = plansState.plans.first.id);
        }
      });
    }

    return Column(
      children: plansState.plans.map((plan) {
        final isSelected = _selectedPlanId == plan.id;
        return GestureDetector(
          onTap: () => setState(() => _selectedPlanId = plan.id),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.primary.withValues(alpha: 0.1)
                  : (dark ? const Color(0xFF131813) : Colors.white),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  isSelected
                      ? Icons.radio_button_checked
                      : Icons.radio_button_off,
                  color: isSelected ? AppTheme.primary : Colors.grey,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        plan.name,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        plan.durationLabel,
                        style: TextStyle(color: Colors.grey[600], fontSize: 13),
                      ),
                    ],
                  ),
                ),
                // Show discount badge when applicable
                if (plan.discountPercent > 0)
                  _DiscountBadge(label: plan.discountLabel),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  // Reusable Widgets
  // ──────────────────────────────────────────────────────────────────────────

  Widget _buildImagePicker({
    required String label,
    required Uint8List? bytes,
    required String? remoteUrl,
    required VoidCallback onTap,
    required bool dark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: onTap,
          child: Container(
            height: 110,
            width: 110,
            decoration: BoxDecoration(
              color: dark
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : (remoteUrl != null && remoteUrl.isNotEmpty)
                      ? Image.network(
                          remoteUrl,
                          fit: BoxFit.cover,
                          loadingBuilder: (ctx, child, progress) =>
                              progress == null
                                  ? child
                                  : const Center(
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2)),
                          errorBuilder: (ctx, e, s) => const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.grey),
                        )
                      : const Icon(Icons.add_a_photo_outlined,
                          color: AppTheme.primary, size: 28),
            ),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.primary, size: 22),
          const SizedBox(width: 10),
          Text(title,
              style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.5)),
        ],
      ),
    );
  }

  Widget _buildSchoolFields(bool dark) {
    return _cardWrapper(dark, [
      _textField(
          label: 'School Name',
          controller: _nameCtrl,
          icon: Icons.school_outlined),
      _textField(
          label: 'Location Address',
          controller: _addressCtrl,
          icon: Icons.map_outlined),
      Row(
        children: [
          Expanded(
            child: _textField(
                label: 'Lat',
                controller: _latCtrl,
                icon: Icons.south_east_rounded,
                type: TextInputType.number),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _textField(
                label: 'Lng',
                controller: _lngCtrl,
                icon: Icons.north_east_rounded,
                type: TextInputType.number),
          ),
        ],
      ),
      _textField(
          label: 'Contact Phone',
          controller: _phoneCtrl,
          icon: Icons.phone_android_rounded,
          type: TextInputType.phone),
      _textField(
          label: 'Official Email',
          controller: _emailCtrl,
          icon: Icons.alternate_email_rounded,
          type: TextInputType.emailAddress),
    ]);
  }

  Widget _buildAdminFields(bool dark) {
    return _cardWrapper(dark, [
      _textField(
          label: 'Full Name',
          controller: _adminNameCtrl,
          icon: Icons.face_rounded),
      _textField(
          label: 'Login Email',
          controller: _adminEmailCtrl,
          icon: Icons.email_outlined),
      _textField(
        label: 'Security Key',
        controller: _passwordCtrl,
        icon: Icons.vpn_key_outlined,
        isPassword: _isObscure,
        suffix: IconButton(
          icon: Icon(
              _isObscure
                  ? Icons.visibility_rounded
                  : Icons.visibility_off_rounded,
              size: 20),
          onPressed: () => setState(() => _isObscure = !_isObscure),
        ),
      ),
      _textField(
          label: 'Confirm Key',
          controller: _passwordConfirmCtrl,
          icon: Icons.lock_reset_rounded,
          isPassword: _isObscure),
    ]);
  }

  Widget _cardWrapper(bool dark, List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF131813) : Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(children: children),
    );
  }

  Widget _textField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    bool isPassword = false,
    TextInputType type = TextInputType.text,
    Widget? suffix,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        controller: controller,
        obscureText: isPassword,
        keyboardType: type,
        style: const TextStyle(fontSize: 15),
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 18),
          suffixIcon: suffix,
          filled: true,
          fillColor: Colors.black.withValues(alpha: 0.02),
          border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none),
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
        validator: (v) {
          // Skip password validation on edit screens
          if (widget.school != null && label.toLowerCase().contains('key')) {
            return null;
          }
          return (v == null || v.isEmpty) ? 'Field Required' : null;
        },
      ),
    );
  }

  Widget _buildSubmitButton(bool isEdit) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, 10)),
        ],
      ),
      child: FilledButton(
        onPressed: _isLoading ? null : _save,
        style: FilledButton.styleFrom(
          minimumSize: const Size(double.infinity, 60),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppTheme.primary,
        ),
        child: Text(
          isEdit ? 'SAVE OPTIMIZATIONS' : 'LAUNCH ECOSYSTEM',
          style:
              const TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.2),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Discount Badge — private widget
// ─────────────────────────────────────────────────────────────────────────────

class _DiscountBadge extends StatelessWidget {
  final String label;
  const _DiscountBadge({required this.label});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.green,
            fontSize: 11,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.3,
          ),
        ),
      );
}
