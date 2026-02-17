import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/dispatch_repository.dart';

final dispatchRepositoryProvider = Provider((ref) => DispatchRepository());

final selectedDispatchDateProvider = StateProvider<String?>((ref) => null);

final selectedDispatchMartProvider = StateProvider<String?>((ref) => null);

final dispatchListProvider =
    AsyncNotifierProvider<DispatchListNotifier, List<dynamic>>(
      DispatchListNotifier.new,
    );

class DispatchListNotifier extends AsyncNotifier<List<dynamic>> {
  late final DispatchRepository _repo;

  @override
  Future<List<dynamic>> build() async {
    _repo = ref.read(dispatchRepositoryProvider);
    final date = ref.watch(selectedDispatchDateProvider);
    final mart = ref.watch(selectedDispatchMartProvider);
    return _repo.fetchDispatches(dispatchDate: date, martName: mart);
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final date = ref.read(selectedDispatchDateProvider);
      final mart = ref.read(selectedDispatchMartProvider);
      return _repo.fetchDispatches(dispatchDate: date, martName: mart);
    });
  }

  Future<dynamic> createDispatch(Map<String, dynamic> data) async {
    final result = await _repo.createDispatch(data);
    ref.invalidateSelf();
    return result;
  }

  Future<dynamic> reverseDispatch(
    int id,
    double? quantity,
    String? reason,
  ) async {
    final result = await _repo.reverseDispatch(id, quantity, reason);
    ref.invalidateSelf();
    return result;
  }

  Future<List<String>> fetchMartNames() async {
    return _repo.fetchMartNames();
  }

  Future<List<dynamic>> fetchBatches({required int itemId}) async {
    return _repo.fetchBatches(itemId: itemId);
  }
}
