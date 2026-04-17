import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../config/app_theme.dart';
import '../../../core/extensions.dart';
import '../../../core/widgets.dart';
import '../../../services/api_service.dart';

class BusesPage extends ConsumerStatefulWidget {
  const BusesPage({super.key});

  @override
  ConsumerState<BusesPage> createState() => _State();
}

class _State extends ConsumerState<BusesPage> {
  List<Map<String, dynamic>> _buses = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await ApiService.get('/buses');
      setState(() {
        _buses = List<Map<String, dynamic>>.from(
            data['data'] as List? ?? data as List? ?? []);
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load buses';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
        // Header
        Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
          Text('Buses',
              style: TextStyle(
                  color: context.txt,
                  fontSize: 20,
                  fontWeight: FontWeight.w800)),
          OrangeButton(
            label: 'Add Bus',
            icon: Icons.add,
            onTap: () => _showAddBusDialog(context),
          ),
        ]),
        const SizedBox(height: 16),

        if (_loading)
          Column(children: List.generate(
              4, (_) => const Padding(
                  padding: EdgeInsets.only(bottom: 10),
                  child: AppShimmer(height: 80))))
        else if (_error != null)
          ErrorState(message: _error!, onRetry: _load)
        else if (_buses.isEmpty)
          const EmptyState(
              icon: Icons.directions_bus_outlined,
              message: 'No buses yet.\nTap Add Bus to get started.')
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _buses.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: 10),
            itemBuilder: (_, i) => _BusItem(
              bus: _buses[i],
              onDelete: () => _deleteBus(_buses[i]['id']),
            ),
          ),
      ]),
    );
  }

  Future<void> _deleteBus(int id) async {
    try {
      await ApiService.delete('/buses/$id');
      _load();
    } catch (_) {}
  }

  void _showAddBusDialog(BuildContext context) {
    showDialog(
        context: context,
        builder: (_) => _AddBusDialog(onAdded: _load));
  }
}

class _BusItem extends StatelessWidget {
  final Map<String, dynamic> bus;
  final VoidCallback onDelete;
  const _BusItem({required this.bus, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final isActive = bus['status'] == 'active';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.border),
      ),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: isActive
                ? AppTheme.primary.withValues(alpha: 0.12)
                : context.border,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(Icons.directions_bus_rounded,
              color: isActive ? AppTheme.primary : context.hint,
              size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
          Text(bus['name'] ?? '',
              style: TextStyle(
                  color: context.txt,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(bus['plate'] ?? '',
              style: TextStyle(
                  color: context.muted, fontSize: 12)),
        ])),
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          StatusBadge(
            label: isActive ? 'Active' : 'Inactive',
            color: isActive ? AppTheme.success : context.hint,
          ),
          const SizedBox(height: 6),
          Text('School #${bus['school_id'] ?? ''}',
              style:
                  TextStyle(color: context.hint, fontSize: 10)),
        ]),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: onDelete,
          child: Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: AppTheme.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(Icons.delete_outline,
                color: AppTheme.danger, size: 16),
          ),
        ),
      ]),
    );
  }
}

class _AddBusDialog extends ConsumerStatefulWidget {
  final VoidCallback onAdded;
  const _AddBusDialog({required this.onAdded});

  @override
  ConsumerState<_AddBusDialog> createState() =>
      _AddBusDialogState();
}

class _AddBusDialogState extends ConsumerState<_AddBusDialog> {
  final _name = TextEditingController();
  final _plate = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.isEmpty || _plate.text.isEmpty) return;
    setState(() => _loading = true);
    try {
      await ApiService.post('/buses', body: {
        'name': _name.text.trim(),
        'plate': _plate.text.trim(),
        'status': 'active',
      });
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: context.card,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      title: Text('Add New Bus',
          style: TextStyle(
              color: context.txt, fontWeight: FontWeight.w700)),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: _name,
          style: TextStyle(color: context.txt),
          decoration: InputDecoration(
            labelText: 'Bus name',
            labelStyle: TextStyle(color: context.muted),
            filled: true,
            fillColor: context.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppTheme.primary, width: 2)),
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _plate,
          style: TextStyle(color: context.txt),
          decoration: InputDecoration(
            labelText: 'Plate number',
            labelStyle: TextStyle(color: context.muted),
            filled: true,
            fillColor: context.surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.border)),
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: context.border)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(
                    color: AppTheme.primary, width: 2)),
          ),
        ),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel',
              style: TextStyle(color: context.muted)),
        ),
        OrangeButton(
          label: 'Add Bus',
          loading: _loading,
          onTap: _submit,
        ),
      ],
    );
  }
}