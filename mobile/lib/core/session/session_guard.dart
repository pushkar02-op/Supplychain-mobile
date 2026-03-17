import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'session_controller.dart';

int requireWarehouse(Ref ref) {
  final session = ref.read(sessionProvider);
  if (!session.isReady || session.warehouseId == null) {
    throw StateError('Warehouse not selected');
  }
  return session.warehouseId!;
}
