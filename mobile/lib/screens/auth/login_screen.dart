import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../core/extensions.dart';
 import '../../core/widgets.dart'; 
import '../../providers/auth_provider.dart';
import '../admin/admin_dashboard.dart';
import '../parent/parent_dashboard.dart';
import '../driver/driver_dashboard.dart';
import '../superadmin/superadmin_dashboard.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    ref.read(authProvider.notifier).clearError();

    await ref.read(authProvider.notifier).login(
          _emailCtrl.text.trim(),
          _passCtrl.text.trim(),
        );

    if (!mounted) return;

    final user = ref.read(authProvider).user; // Use the user from authProvider state
    if (user == null) return;

    // 2. UPDATED ROUTING LOGIC
    Widget dest;
    if (user.isDriver) {
      dest = const DriverDashboard();
    } else if (user.isParent) {
      dest = const ParentDashboard();
    } else if (user.isSuperAdmin) {
      dest = const SuperAdminDashboard(); // Land on SuperAdmin specific UI
    } else if (user.isSchoolAdmin) {
      dest = const AdminDashboard(); // Regular school admin UI
    } else {
      dest = Scaffold(
        body: Center(child: Text('Unknown role: ${user.role}')),
      );
    }

    if (!mounted) return;

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => dest,
        transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
        transitionDuration: const Duration(milliseconds: 400),
      ),
      (_) => false,
    );
  }

  InputDecoration _fieldDecor(
    BuildContext context, {
    required String label,
    required IconData icon,
    Widget? suffix,
  }) =>
      InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: context.muted),
        prefixIcon: Icon(icon, color: context.muted),
        suffixIcon: suffix,
        filled: true,
        fillColor: context.card,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: context.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppTheme.danger, width: 2),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: context.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(height: size.height * 0.08),

                    // ── Logo ──────────────────────────────────────────────
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppTheme.primary, AppTheme.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primary.withValues(alpha: 0.4),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.directions_bus_rounded,
                        size: 38,
                        color: Colors.white,
                      ),
                    ),

                    const SizedBox(height: 24),

                    Text('SchoolTrack',
                        style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: context.txt)),
                    const SizedBox(height: 6),
                    Text('Sign in to your account',
                        style:
                            TextStyle(fontSize: 15, color: context.muted)),

                    const SizedBox(height: 40),

                    // ── Email ─────────────────────────────────────────────
                    TextFormField(
                      controller: _emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      textInputAction: TextInputAction.next,
                      autocorrect: false,
                      style: TextStyle(color: context.txt),
                      decoration: _fieldDecor(context,
                          label: 'Email address',
                          icon: Icons.email_outlined),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!v.contains('@')) return 'Enter a valid email';
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // ── Password ──────────────────────────────────────────
                    TextFormField(
                      controller: _passCtrl,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _submit(),
                      style: TextStyle(color: context.txt),
                      decoration: _fieldDecor(
                        context,
                        label: 'Password',
                        icon: Icons.lock_outline,
                        suffix: IconButton(
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                            color: context.muted,
                          ),
                          onPressed: () =>
                              setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Password is required';
                        }
                        if (v.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 14),

                    // ── Error banner ──────────────────────────────────────
                    if (auth.errorMessage != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTheme.danger.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                              color:
                                  AppTheme.danger.withValues(alpha: 0.3)),
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              color: AppTheme.danger, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(auth.errorMessage!,
                                style: const TextStyle(
                                    color: AppTheme.danger, fontSize: 13)),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 14),
                    ],

                    // ── Sign in button ────────────────────────────────────
                    OrangeButton(
                      label: 'Sign in',
                      loading: auth.isLoading,
                      onTap: _submit,
                    ),

                    SizedBox(height: size.height * 0.05),

                    // ── Theme indicator ───────────────────────────────────
                    Center(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            context.dark
                                ? Icons.dark_mode_rounded
                                : Icons.light_mode_rounded,
                            color: context.hint,
                            size: 13,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            context.dark ? 'Dark mode' : 'Light mode',
                            style: TextStyle(
                                color: context.hint, fontSize: 11),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}