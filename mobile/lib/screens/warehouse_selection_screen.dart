import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_controller.dart';
import '../core/session/session_state.dart';

class WarehouseSelectionScreen extends ConsumerWidget {
  const WarehouseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final warehouses = session.warehouses ?? const [];
    final activeWarehouseId = session.warehouseId;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Warehouse'),
        automaticallyImplyLeading: false,
      ),
      body:
          session.state == SessionState.loading
              ? const Center(child: CircularProgressIndicator())
              : warehouses.isEmpty
              ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No accessible warehouses found.'),
                ),
              )
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: warehouses.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final warehouse = warehouses[index];
                  return ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    title: Text(warehouse.name),
                    trailing:
                        activeWarehouseId == warehouse.id
                            ? const Icon(Icons.check, color: Colors.green)
                            : const Icon(Icons.chevron_right),
                    onTap:
                        () => ref
                            .read(sessionProvider.notifier)
                            .selectWarehouse(warehouse.id),
                  );
                },
              ),
    );
  }
}
