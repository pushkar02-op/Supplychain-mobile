import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mart_bill.dart';
import '../repositories/mart_bill_repository.dart';

final martBillRepositoryProvider = Provider((ref) => MartBillRepository());

final martBillListProvider =
    AsyncNotifierProvider<MartBillListNotifier, Map<String, dynamic>>(
      MartBillListNotifier.new,
    );

class MartBillListNotifier extends AsyncNotifier<Map<String, dynamic>> {
  late final MartBillRepository _repo;

  @override
  Future<Map<String, dynamic>> build() async {
    _repo = ref.read(martBillRepositoryProvider);
    return _repo.fetchMartBills();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.fetchMartBills());
  }

  Future<Map<String, dynamic>> fetchMartBills({
    DateTime? date,
    String? martName,
    String? search,
    int skip = 0,
    int limit = 20,
  }) async {
    return _repo.fetchMartBills(
      date: date,
      martName: martName,
      search: search,
      skip: skip,
      limit: limit,
    );
  }

  Future<List<Map<String, dynamic>>> uploadMartBills(List<String> paths) async {
    final result = await _repo.uploadMartBills(paths);
    ref.invalidateSelf();
    return result;
  }

  Future<void> replaceBillPdf(int billId, String path) async {
    await _repo.replaceBillPdf(billId, path);
  }

  Future<List<Map<String, dynamic>>> fetchMartBillItems(int billId) async {
    return _repo.fetchMartBillItems(billId);
  }

  Future<void> updateMartBill(int billId, String remarks) async {
    await _repo.updateMartBill(billId, remarks);
    ref.invalidateSelf();
  }

  Future<void> verifyMartBill(int billId) async {
    await _repo.verifyMartBill(billId);
    ref.invalidateSelf();
  }

  Future<void> unverifyMartBill(int billId) async {
    await _repo.unverifyMartBill(billId);
    ref.invalidateSelf();
  }

  Future<void> updateMartBillItem(int itemId, Map<String, dynamic> data) async {
    await _repo.updateMartBillItem(itemId, data);
  }

  Future<void> deleteMartBill(int billId) async {
    await _repo.deleteMartBill(billId);
    ref.invalidateSelf();
  }

  Future<void> deleteMartBillItem(int itemId) async {
    await _repo.deleteMartBillItem(itemId);
  }

  Future<List<String>> fetchMartNames() async {
    return _repo.fetchMartNames();
  }

  Future<String> downloadMartBillPdf(int billId) async {
    return _repo.downloadMartBillPdf(billId);
  }

  Future<MartBill> getMartBillById(int id) async {
    return _repo.getMartBillById(id);
  }
}
