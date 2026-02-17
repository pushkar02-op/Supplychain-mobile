import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/rejection_repository.dart';

final rejectionRepositoryProvider = Provider((ref) => RejectionRepository());

final rejectionListProvider =
    AsyncNotifierProvider<RejectionListNotifier, Map<String, dynamic>>(
      RejectionListNotifier.new,
    );

class RejectionListNotifier extends AsyncNotifier<Map<String, dynamic>> {
  late final RejectionRepository _repo;

  @override
  Future<Map<String, dynamic>> build() async {
    _repo = ref.read(rejectionRepositoryProvider);
    return _repo.fetchRejections();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.fetchRejections());
  }

  Future<Map<String, dynamic>> fetchRejections({
    String? date,
    List<int>? itemIds,
    int skip = 0,
    int limit = 50,
  }) async {
    return _repo.fetchRejections(
      date: date,
      itemIds: itemIds,
      skip: skip,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> fetchItemsWithBatches() async {
    return _repo.fetchItemsWithBatches();
  }

  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    return _repo.fetchBatches(itemId: itemId);
  }

  Future<void> createRejection({
    required int itemId,
    required int batchId,
    required double quantity,
    required String unit,
    required String reason,
    required String rejectionDate,
    String? rejectedBy,
  }) async {
    await _repo.createRejection(
      itemId: itemId,
      batchId: batchId,
      quantity: quantity,
      unit: unit,
      reason: reason,
      rejectionDate: rejectionDate,
      rejectedBy: rejectedBy,
    );
    ref.invalidateSelf();
  }

  Future<void> reverseRejection(int id) async {
    await _repo.reverseRejection(id);
    ref.invalidateSelf();
  }
}
