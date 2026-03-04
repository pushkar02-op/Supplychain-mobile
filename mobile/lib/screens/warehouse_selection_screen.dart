import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/warehouse_provider.dart';

class WarehouseSelectionScreen extends ConsumerWidget {
  const WarehouseSelectionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final warehousesAsync = ref.watch(warehouseListProvider);
    final activeWarehouseId = ref.watch(activeWarehouseProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Warehouse'),
        automaticallyImplyLeading: false,
      ),
      body: warehousesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load warehouses: $error'),
              ),
            ),
        data: (warehouses) {
          if (warehouses.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text('No accessible warehouses found.'),
              ),
            );
          }

          return ListView.separated(
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
                onTap: () async {
                  await selectActiveWarehouse(ref, warehouse.id);
                  if (!context.mounted) return;
                  context.go('/main');
                },
              );
            },
          );
        },
      ),
    );
  }
}
