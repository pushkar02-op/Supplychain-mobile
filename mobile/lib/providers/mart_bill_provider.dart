import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session/session_guard.dart';
import '../models/mart_bill.dart';
import '../models/mart_bill_item.dart';
import '../models/mart_bill_page.dart';
import '../models/mart_bill_summary.dart';
import '../repositories/mart_bill_repository.dart';
import 'active_mart_provider.dart';
import 'warehouse_context_provider.dart';

final martBillRepositoryProvider = Provider((ref) => MartBillRepository());

final martBillProvider = AsyncNotifierProvider<MartBillNotifier, MartBillState>(
  MartBillNotifier.new,
);

class MartBillState {
  final List<MartBill> bills;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? statusFilter;
  final String search;
  final int skip;
  final int limit;
  final bool hasMore;
  final bool isLoadingMore;
  final bool isUploading;
  final MartBillSummary summary;
  final List<String> pickedPaths;
  final List<Map<String, dynamic>> uploadResults;

  // Backward compat: screen reads current.selectedDate
  DateTime? get selectedDate => dateFrom;

  const MartBillState({
    required this.bills,
    required this.dateFrom,
    required this.dateTo,
    required this.statusFilter,
    required this.search,
    required this.skip,
    required this.limit,
    required this.hasMore,
    required this.isLoadingMore,
    required this.isUploading,
    required this.summary,
    required this.pickedPaths,
    required this.uploadResults,
  });

  MartBillState copyWith({
    List<MartBill>? bills,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? statusFilter,
    bool clearDateFrom = false,
    bool clearDateTo = false,
    bool clearStatusFilter = false,
    String? search,
    int? skip,
    int? limit,
    bool? hasMore,
    bool? isLoadingMore,
    bool? isUploading,
    MartBillSummary? summary,
    List<String>? pickedPaths,
    List<Map<String, dynamic>>? uploadResults,
  }) {
    return MartBillState(
      bills: bills ?? this.bills,
      dateFrom: clearDateFrom ? null : (dateFrom ?? this.dateFrom),
      dateTo: clearDateTo ? null : (dateTo ?? this.dateTo),
      statusFilter:
          clearStatusFilter ? null : (statusFilter ?? this.statusFilter),
      search: search ?? this.search,
      skip: skip ?? this.skip,
      limit: limit ?? this.limit,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      isUploading: isUploading ?? this.isUploading,
      summary: summary ?? this.summary,
      pickedPaths: pickedPaths ?? this.pickedPaths,
      uploadResults: uploadResults ?? this.uploadResults,
    );
  }
}

class MartBillNotifier extends AsyncNotifier<MartBillState> {
  @override
  Future<MartBillState> build() async {
    final warehouseId = ref.watch(warehouseContextProvider);
    final now = DateTime.now();
    final defaultDateFrom = DateTime(now.year, now.month, 1);
    final defaultDateTo = now;

    if (warehouseId == null) {
      return MartBillState(
        bills: const [],
        dateFrom: defaultDateFrom,
        dateTo: defaultDateTo,
        statusFilter: null,
        search: '',
        skip: 0,
        limit: 20,
        hasMore: false,
        isLoadingMore: false,
        isUploading: false,
        summary: const MartBillSummary(),
        pickedPaths: const [],
        uploadResults: const [],
      );
    }

    final repo = ref.read(martBillRepositoryProvider);
    // When active mart changes, refresh data automatically
    ref.listen<String?>(activeMartProvider, (_, __) => refresh());
    final initial = await repo.fetchMartBills(
      warehouseId: warehouseId,
      dateFrom: defaultDateFrom,
      dateTo: defaultDateTo,
      martName: ref.read(activeMartProvider),
      skip: 0,
      limit: 20,
    );
    return MartBillState(
      bills: initial.items,
      dateFrom: defaultDateFrom,
      dateTo: defaultDateTo,
      statusFilter: null,
      search: '',
      skip: initial.skip,
      limit: initial.limit,
      hasMore: initial.hasMore,
      isLoadingMore: false,
      isUploading: false,
      summary: initial.summary,
      pickedPaths: const [],
      uploadResults: const [],
    );
  }

  // Backward compat — screen calls setDate(DateTime?)
  Future<void> setDate(DateTime? date) async {
    await setDateRange(date, date);
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(martBillRepositoryProvider);
      final result = await repo.fetchMartBills(
        warehouseId: warehouseId,
        dateFrom: from,
        dateTo: to,
        martName: ref.read(activeMartProvider),
        search: current.search.isEmpty ? null : current.search,
        status: current.statusFilter,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        dateFrom: from,
        dateTo: to,
        clearDateFrom: from == null,
        clearDateTo: to == null,
        bills: result.items,
        skip: result.skip,
        hasMore: result.hasMore,
        summary: result.summary,
        isLoadingMore: false,
      );
    });
  }

  Future<void> setStatusFilter(String? status) async {
    final current = state.valueOrNull;
    if (current == null) return;

    final warehouseId = requireWarehouse(ref);
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repo = ref.read(martBillRepositoryProvider);
      final result = await repo.fetchMartBills(
        warehouseId: warehouseId,
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
        martName: ref.read(activeMartProvider),
        search: current.search.isEmpty ? null : current.search,
        status: status,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        statusFilter: status,
        clearStatusFilter: status == null,
        bills: result.items,
        skip: result.skip,
        hasMore: result.hasMore,
        summary: result.summary,
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
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
        martName: ref.read(activeMartProvider),
        search: trimmed.isEmpty ? null : trimmed,
        status: current.statusFilter,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        search: trimmed,
        bills: result.items,
        skip: result.skip,
        hasMore: result.hasMore,
        summary: result.summary,
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
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
        martName: ref.read(activeMartProvider),
        search: current.search.isEmpty ? null : current.search,
        status: current.statusFilter,
        skip: 0,
        limit: current.limit,
      );
      return current.copyWith(
        bills: result.items,
        skip: result.skip,
        hasMore: result.hasMore,
        summary: result.summary,
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
      final MartBillPage response = await repo.fetchMartBills(
        warehouseId: warehouseId,
        dateFrom: current.dateFrom,
        dateTo: current.dateTo,
        martName: ref.read(activeMartProvider),
        search: current.search.isEmpty ? null : current.search,
        status: current.statusFilter,
        skip: nextSkip,
        limit: current.limit,
      );
      return current.copyWith(
        bills: [...current.bills, ...response.items],
        skip: response.skip,
        hasMore: response.hasMore,
        summary: response.summary,
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

    try {
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
    } catch (e) {
      // Reset isUploading AND pickedPaths so the UI is fully unstuck.
      final next = state.valueOrNull ?? current;
      state = AsyncValue.data(
        next.copyWith(isUploading: false, pickedPaths: const []),
      );
      rethrow;
    }
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

  Future<List<MartBillItem>> fetchBillItems(int billId) {
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
