import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../config/app_theme.dart';
import '../../providers/school_management_provider.dart';
import '../../models/school.dart';
import 'add_school_screen.dart';

class SchoolListScreen extends ConsumerWidget {
  const SchoolListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final schoolAsync = ref.watch(schoolListProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          schoolAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, stack) => _buildErrorState(err, ref, dark),
            data: (schools) => RefreshIndicator(
              onRefresh: () => ref.read(schoolListProvider.notifier).fetchSchools(),
              displacement: 20,
              color: AppTheme.primary,
              child: schools.isEmpty
                  ? _buildEmptyState(context, dark)
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
                      itemCount: schools.length,
                      itemBuilder: (context, index) => Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: _SchoolCard(school: schools[index], dark: dark),
                      ),
                    ),
            ),
          ),
          _buildFab(context),
        ],
      ),
    );
  }

  Widget _buildFab(BuildContext context) {
    return Positioned(
      bottom: 30,
      right: 24,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppTheme.primary.withValues(alpha: 0.4),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddSchoolScreen()),
          ),
          elevation: 0,
          backgroundColor: AppTheme.primary,
          icon: const Icon(Icons.add_rounded, color: Colors.white, size: 28),
          label: const Text(
            'LAUNCH ECOSYSTEM',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.1,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(Object err, WidgetRef ref, bool dark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.sync_problem_rounded, size: 48, color: AppTheme.danger),
          ),
          const SizedBox(height: 20),
          const Text('Connection Interrupted',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
          const SizedBox(height: 8),
          Text(err.toString().contains('404') ? 'Endpoint Not Found' : 'Check backend status',
              style: const TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.read(schoolListProvider.notifier).fetchSchools(),
            style: ElevatedButton.styleFrom(
              backgroundColor: dark ? Colors.white10 : Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Retry Synchronize'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool dark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Opacity(
            opacity: 0.5,
            child: Icon(Icons.auto_awesome_motion_rounded,
                size: 100, color: dark ? Colors.white24 : Colors.grey[300]),
          ),
          const SizedBox(height: 24),
          const Text('The Galaxy is Empty',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('Deploy your first school ecosystem to start monitoring.',
              style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _SchoolCard extends ConsumerWidget {
  final School school;
  final bool dark;
  const _SchoolCard({required this.school, required this.dark});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF131813) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: dark ? Colors.black26 : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: dark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.grey.shade100,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddSchoolScreen(school: school)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  _PremiumLogo(logoUrl: school.logoUrl, schoolName: school.name),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          school.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w900, fontSize: 17, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_pin,
                                size: 14,
                                color: AppTheme.primary.withValues(alpha: 0.7)),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                school.address,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStatusRow(),
                      ],
                    ),
                  ),
                  _buildActionMenu(context, ref),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusRow() {
    final status = (school.subscriptionStatus ?? 'Inactive').toUpperCase();
    return Row(
      children: [
        _miniBadge(status, _getStatusColor(status)),
        const SizedBox(width: 8),
        _miniBadge('${school.studentsCount ?? 0} STUDENTS', Colors.blueGrey),
      ],
    );
  }

  Widget _miniBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 9, fontWeight: FontWeight.w900, letterSpacing: 0.5),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status.contains('TRIAL')) return Colors.orange;
    if (status.contains('ACTIVE')) return AppTheme.primary;
    return AppTheme.danger;
  }

  Widget _buildActionMenu(BuildContext context, WidgetRef ref) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        PopupMenuButton<String>(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.more_horiz_rounded, color: Colors.grey),
          onSelected: (v) => _handleAction(v, context, ref),
          itemBuilder: (_) => [
            _menuItem('edit', Icons.auto_fix_high_rounded, 'Modify'),
            _menuItem('delete', Icons.delete_sweep_rounded, 'Purge', color: AppTheme.danger),
          ],
        ),
        const SizedBox(height: 20),
        Text('#${school.id}', style: const TextStyle(fontSize: 10, color: Colors.grey, fontWeight: FontWeight.bold)),
      ],
    );
  }

  PopupMenuItem<String> _menuItem(String val, IconData icon, String label, {Color? color}) {
    return PopupMenuItem(
      value: val,
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 12),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _handleAction(String value, BuildContext context, WidgetRef ref) {
    if (value == 'edit') {
      Navigator.push(context, MaterialPageRoute(builder: (_) => AddSchoolScreen(school: school)));
    } else {
      _confirmDelete(context, ref);
    }
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: const Text('Purge Ecosystem?', style: TextStyle(fontWeight: FontWeight.w900)),
        content: Text('Are you sure you want to permanently delete ${school.name}?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Dismiss')),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.danger,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(schoolListProvider.notifier).deleteSchool(school.id);
            },
            child: const Text('Confirm Purge'),
          ),
        ],
      ),
    );
  }
}

class _PremiumLogo extends StatelessWidget {
  final String? logoUrl;
  final String schoolName;

  const _PremiumLogo({this.logoUrl, required this.schoolName});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 75,
      height: 75,
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: logoUrl != null && logoUrl!.isNotEmpty
            ? Image.network(
                logoUrl!,
                fit: BoxFit.cover,

                // 🔥 Better error handling
                errorBuilder: (context, error, stackTrace) {
                  debugPrint("❌ Image failed: $logoUrl");
                  return _initialsFallback();
                },

                // 🔥 Smooth loading
                loadingBuilder: (context, child, progress) {
                  if (progress == null) return child;
                  return const Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                },
              )
            : _initialsFallback(),
      ),
    );
  }

  Widget _initialsFallback() {
    return Center(
      child: Text(
        schoolName.isNotEmpty ? schoolName[0].toUpperCase() : 'S',
        style: const TextStyle(
          fontSize: 28,
          fontWeight: FontWeight.w900,
          color: AppTheme.primary,
        ),
      ),
    );
  }
}