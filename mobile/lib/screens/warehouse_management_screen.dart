import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/session/session_controller.dart';
import '../repositories/warehouse_repository.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/widgets/agro_snack_bar.dart';

class WarehouseManagementScreen extends ConsumerStatefulWidget {
  const WarehouseManagementScreen({super.key});

  @override
  ConsumerState<WarehouseManagementScreen> createState() =>
      _WarehouseManagementScreenState();
}

class _WarehouseManagementScreenState
    extends ConsumerState<WarehouseManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _warehouses = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(warehouseRepositoryProvider);
      final warehouses = await repo.fetchWarehouses();
      if (!mounted) return;
      setState(() {
        _warehouses = warehouses;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _showEditor({Map<String, dynamic>? warehouse}) async {
    final nameController = TextEditingController(
      text: warehouse?['name']?.toString() ?? '',
    );
    final codeController = TextEditingController(
      text: warehouse?['code']?.toString() ?? '',
    );
    bool isActive = warehouse?['is_active'] as bool? ?? true;
    final isEdit = warehouse != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Warehouse' : 'Create Warehouse'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: 'Warehouse name'),
              ),
              const SizedBox(height: AgroSpacing.sm),
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: AgroSpacing.sm),
              SwitchListTile(
                value: isActive,
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                onChanged: (value) => setDialogState(() => isActive = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final session = ref.read(sessionProvider);
                final warehouseId = warehouse?['id'] as int?;
                final isDeactivatingCurrentWarehouse =
                    warehouseId != null &&
                    session.warehouseId == warehouseId &&
                    (warehouse?['is_active'] as bool? ?? true) &&
                    !isActive;
                if (isDeactivatingCurrentWarehouse) {
                  await showDialog<void>(
                    context: dialogContext,
                    builder: (context) => AlertDialog(
                      title: const Text('Warehouse switch required'),
                      content: const Text(
                        'Switch to another warehouse before deactivating this one.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('OK'),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                final payload = {
                  'name': nameController.text.trim(),
                  'code': codeController.text.trim(),
                  'is_active': isActive,
                  'financial_lock_date': warehouse?['financial_lock_date'],
                };
                try {
                  final repo = ref.read(warehouseRepositoryProvider);
                  if (isEdit) {
                    await repo.updateWarehouse(
                      warehouse['id'] as int,
                      payload,
                      currentSessionWarehouseId: session.warehouseId,
                    );
                  } else {
                    await repo.createWarehouse(payload);
                  }
                  await ref.read(sessionProvider.notifier).refreshWarehouses();
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _load();
                  if (!mounted) return;
                  AgroSnackBar.success(
                    context,
                    isEdit ? 'Warehouse updated' : 'Warehouse created',
                  );
                } catch (e) {
                  if (!mounted) return;
                  AgroSnackBar.error(context, e.toString());
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _setLock(Map<String, dynamic> warehouse) async {
    final initial = warehouse['financial_lock_date']?.toString();
    final selected = initial == null ? null : DateTime.tryParse(initial);
    final picked = await showDatePicker(
      context: context,
      initialDate: selected ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    final formatted = DateFormat('yyyy-MM-dd').format(picked);
    try {
      final repo = ref.read(warehouseRepositoryProvider);
      await repo.setFinancialLock(warehouse['id'] as int, formatted);
      await _load();
      if (!mounted) return;
      AgroSnackBar.success(context, 'Financial lock updated');
    } catch (e) {
      if (!mounted) return;
      AgroSnackBar.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Warehouse Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AgroSpacing.screenPadding),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                : _warehouses.isEmpty
                    ? const Center(child: Text('No warehouses configured'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AgroSpacing.screenPadding),
                        itemCount: _warehouses.length,
                        itemBuilder: (context, index) {
                          final warehouse = _warehouses[index];
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                (warehouse['is_active'] as bool? ?? true)
                                    ? Icons.warehouse_outlined
                                    : Icons.warehouse,
                              ),
                              title: Text(warehouse['name']?.toString() ?? ''),
                              subtitle: Text(
                                'Code: ${warehouse['code'] ?? ''}\nLock: ${warehouse['financial_lock_date'] ?? 'Not set'}',
                              ),
                              isThreeLine: true,
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showEditor(warehouse: warehouse);
                                  if (value == 'lock') _setLock(warehouse);
                                },
                                itemBuilder: (context) => const [
                                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                                  PopupMenuItem(
                                    value: 'lock',
                                    child: Text('Set financial lock'),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
