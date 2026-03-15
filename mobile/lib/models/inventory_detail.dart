import 'inventory_batch.dart';
import 'inventory_signal.dart';
import 'inventory_transaction.dart';

class InventoryDetail {
  final List<InventoryTransaction> transactions;
  final List<InventoryBatch> batches;
  final InventorySignal signals;

  const InventoryDetail({
    required this.transactions,
    required this.batches,
    required this.signals,
  });
}
