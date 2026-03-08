import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/mart_bill.dart';
import '../repositories/mart_bill_repository.dart';
import 'active_mart_provider.dart';
import 'warehouse_context_provider.dart';

final martBillRepositoryProvider = Provider((ref) => MartBillRepository());

final martBillProvider = AsyncNotifierProvider<MartBillNotifier, MartBillState>(
  MartBillNotifier.new,
);

class MartBillState {
  final List<Map<String, dynamic>> bills;
  final DateTime? selectedDate;
  final String search;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isUploading;
  final List<String> pickedPaths;
  final List<Map<String, dynamic>> uploadResults;

  const MartBillState({
    required this.bills,
    required this.selectedDate,
    required this.search,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
    required this.isUploading,
    required this.pickedPaths,
    required this.uploadResults,
  });

  MartBillState copyWith({
    List<Map<String, dynamic>>? bills,
    DateTime? selectedDate,
    bool clearSelectedDate = false,
    String? search,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isUploading,
    List<String>? pickedPaths,
    List<Map<String, dynamic>>? uploadResults,
  }) {
    return MartBillState(
      bills: bills ?? this.bills,
      selectedDate:
          clearSelectedDate ? null : (selectedDate ?? this.selectedDate),
      search: search ?? this.search,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isUploading: isUploading ?? this.isUploading,
      pickedPaths: pickedPaths ?? this.pickedPaths,
      uploadResults: uploadResults ?? this.uploadResults,
    );
  }
}

class MartBillNotifier extends AsyncNotifier<MartBillState> {
  @override
  Future<MartBillState> build() async {
    final warehouseId = ref.watch(warehouseContextProvider);
    if (warehouseId == null) {
      return const MartBillState(
        bills: [],
        selectedDate: null,
        search: '',
        skip: 0,
        limit: 20,
        hasMore: false,
        isLoadingMore: false,
        isUploading: false,
        pickedPaths: [],
        uploadResults: [],
      );
    }

    final repo = ref.read(martBillRepositoryProvider);
    // When active mart changes, refresh data automatically
    ref.listen<String?>(activeMartProvider, (_, __) => refresh());
    final initial = await repo.fetchMartBills(
      warehouseId: warehouseId,
      martName: ref.read(activeMartProvider),
      skip: 0,
      limit: 20,
    );
    return MartBillState(
      bills: List<Map<String, dynamic>>.from(initial['items'] ?? const []),
      selectedDate: null,
      search: '',
      skip: initial['skip'] as int? ?? 0,
      limit: initial['limit'] as int? ?? 20,
      hasMore: initial['has_more'] as bool? ?? false,
      isLoadingMore: false,
      isUploading: false,
      pickedPaths: const [],
      uploadResults: const [],
    );
  }

  Future<void> setDate(DateTime? date) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(martBillRepositoryProvider);
      final result = await repo.fetchMartBills(
        warehouseId: warehouseId,
        date: date,
        martName: ref.read(activeMartProvider),
        search: current.search.isEmpty ? null : current.search,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        selectedDate: date,
        clearSelectedDate: date == null,
        bills: List<Map<String, dynamic>>.from(result['items'] ?? const []),
        skip: result['skip'] as int? ?? 0,
        hasMore: result['has_more'] as bool? ?? false,
        isLoadingMore: false,
      );
    });
  }

  Future<void> setSearch(String search) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    final trimmed = search.trim();
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(martBillRepositoryProvider);
      final result = await repo.fetchMartBills(
        warehouseId: warehouseId,
        date: current.selectedDate,
        martName: ref.read(activeMartProvider),
        search: trimmed.isEmpty ? null : trimmed,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        search: trimmed,
        bills: List<Map<String, dynamic>>.from(result['items'] ?? const []),
        skip: result['skip'] as int? ?? 0,
        hasMore: result['has_more'] as bool? ?? false,
        isLoadingMore: false,
      );
    });
  }

  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) {
      ref.invalidateSelf();
      return;
    }

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(martBillRepositoryProvider);
      final result = await repo.fetchMartBills(
        warehouseId: warehouseId,
        date: current.selectedDate,
        martName: ref.read(activeMartProvider),
        search: current.search.isEmpty ? null : current.search,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        bills: List<Map<String, dynamic>>.from(result['items'] ?? const []),
        skip: result['skip'] as int? ?? 0,
        hasMore: result['has_more'] as bool? ?? false,
        isLoadingMore: false,
      );
    });
  }

  Future<void> loadMore() async {
    final current = state.valueOrNull;
    if (current == null || current.isLoadingMore || !current.hasMore) return;

    final warehouseId = requireWarehouse(ref);
    state = AsyncValue.data(current.copyWith(isLoadingMore: true));
    final nextSkip = current.skip + current.limit;
    final result = await AsyncValue.guard(() async {
      final repo = ref.read(martBillRepositoryProvider);
      final response = await repo.fetchMartBills(
        warehouseId: warehouseId,
        date: current.selectedDate,
        martName: ref.read(activeMartProvider),
        search: current.search.isEmpty ? null : current.search,
        skip: nextSkip,
        limit: current.limit,
      );
      final nextItems = List<Map<String, dynamic>>.from(
        response['items'] ?? const [],
      );
      return current.copyWith(
        bills: [...current.bills, ...nextItems],
        skip: response['skip'] as int? ?? nextSkip,
        hasMore: response['has_more'] as bool? ?? false,
        isLoadingMore: false,
      );
    });

    state = result;
  }

  void setPickedPaths(List<String> paths) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.copyWith(pickedPaths: paths, uploadResults: const []),
    );
  }

  void clearUploadResults() {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(current.copyWith(uploadResults: const []));
  }

  Future<void> uploadBills() async {
    final current = state.valueOrNull;
    if (current == null || current.pickedPaths.isEmpty) return;

    final warehouseId = requireWarehouse(ref);
    state = AsyncValue.data(
      current.copyWith(isUploading: true, uploadResults: const []),
    );
    final repo = ref.read(martBillRepositoryProvider);
    final responses = await repo.uploadMartBills(
      warehouseId,
      current.pickedPaths,
    );
    final next = state.valueOrNull ?? current;
    state = AsyncValue.data(
      next.copyWith(
        isUploading: false,
        pickedPaths: const [],
        uploadResults: responses,
      ),
    );
    await refresh();
  }

  Future<void> replacePdf(int billId, String path) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.replaceBillPdf(warehouseId, billId, path);
    await refresh();
  }

  Future<void> verifyBill(int billId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.verifyMartBill(warehouseId, billId);
    await refresh();
  }

  Future<void> unverifyBill(int billId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.unverifyMartBill(warehouseId, billId);
    await refresh();
  }

  Future<void> deleteBill(int billId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.deleteMartBill(warehouseId, billId);
    await refresh();
  }

  Future<void> updateBill(int billId, String remarks) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.updateMartBill(warehouseId, billId, remarks);
    await refresh();
  }

  Future<void> updateBillItem(int itemId, Map<String, dynamic> data) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.updateMartBillItem(warehouseId, itemId, data);
    await refresh();
  }

  Future<void> deleteBillItem(int itemId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.deleteMartBillItem(warehouseId, itemId);
    await refresh();
  }

  Future<void> processStock(int billId) async {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    await repo.processStock(warehouseId, billId);
    await refresh();
  }

  Future<List<Map<String, dynamic>>> fetchBillItems(int billId) {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    return repo.fetchMartBillItems(warehouseId, billId);
  }

  Future<List<Map<String, dynamic>>> fetchMartNames() {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    return repo.fetchMartNames(warehouseId);
  }

  Future<String> downloadPdf(int billId) {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    return repo.downloadMartBillPdf(warehouseId, billId);
  }

  Future<MartBill> getBillById(int id) {
    final warehouseId = requireWarehouse(ref);
    final repo = ref.read(martBillRepositoryProvider);
    return repo.getMartBillById(warehouseId, id);
  }
}
