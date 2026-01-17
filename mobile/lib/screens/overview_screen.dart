import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/admin_ledger_provider.dart';
import '../providers/auth_provider.dart';
import '../services/dispatch_service.dart';
import '../services/order_service.dart';
import '../services/stock_service.dart';

/// Overview screen - read-only dashboard showing today's system snapshot.
/// This is Tab 1 in the bottom navigation.
class OverviewScreen extends ConsumerStatefulWidget {
  const OverviewScreen({super.key});

  @override
  ConsumerState<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends ConsumerState<OverviewScreen> {
  bool _loading = true;
  String? _error;

  int _ordersToday = 0;
  int _dispatchesToday = 0;
  int _stockEntriesToday = 0;

  @override
  void initState() {
    super.initState();
    _loadTodayData();
  }

  Future<void> _loadTodayData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final results = await Future.wait([
        OrderService.fetchOrders(DateTime.now()),
        DispatchService.fetchDispatches(dispatchDate: todayStr),
        StockService.fetchStockEntries(date: todayStr),
      ]);

      if (!mounted) return;
      setState(() {
        _ordersToday = results[0].length;
        _dispatchesToday = results[1].length;
        _stockEntriesToday = results[2].length;
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

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final isAdmin = authState.value?.isAdmin ?? false;
    final todayFormatted = DateFormat('EEEE, MMMM d').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Overview'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadTodayData,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body:
          _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? _buildError()
              : RefreshIndicator(
                onRefresh: _loadTodayData,
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    // Date Header
                    Text(
                      todayFormatted,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[700],
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Today's Operations
                    _buildSectionHeader('Today\'s Operations'),
                    const SizedBox(height: 8),
                    _buildOperationsGrid(),
                    const SizedBox(height: 24),

                    // Quick Actions
                    _buildSectionHeader('Quick Actions'),
                    const SizedBox(height: 8),
                    _buildQuickActions(),

                    // Admin Summary (conditional)
                    if (isAdmin) ...[
                      const SizedBox(height: 24),
                      _buildSectionHeader('System Health'),
                      const SizedBox(height: 8),
                      _buildAdminSummary(),
                    ],
                  ],
                ),
              ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
          const SizedBox(height: 12),
          Text(
            'Could not load overview',
            style: TextStyle(color: Colors.grey[600]),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _loadTodayData,
            icon: const Icon(Icons.refresh),
            label: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.bold,
        color: Colors.grey,
      ),
    );
  }

  Widget _buildOperationsGrid() {
    return Row(
      children: [
        Expanded(
          child: _buildMetricCard(
            'Orders',
            _ordersToday.toString(),
            Icons.receipt_long,
            Colors.blue,
            () => context.push('/orders'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Dispatches',
            _dispatchesToday.toString(),
            Icons.local_shipping,
            Colors.orange,
            () => context.push('/dispatch-entries'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildMetricCard(
            'Stock In',
            _stockEntriesToday.toString(),
            Icons.inventory_2,
            Colors.green,
            () => context.push('/stock-list'),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    String label,
    String value,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(height: 8),
              Text(
                value,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _buildActionChip(
          'New Stock',
          Icons.add_box_outlined,
          () => context.push('/stock-entry'),
        ),
        _buildActionChip(
          'New Order',
          Icons.add_shopping_cart,
          () => context.push('/order-entry'),
        ),
        _buildActionChip(
          'View Inventory',
          Icons.analytics_outlined,
          () => context.push('/inventory'),
        ),
        _buildActionChip(
          'Mart Bills',
          Icons.receipt_outlined,
          () => context.push('/mart-bills'),
        ),
      ],
    );
  }

  Widget _buildActionChip(String label, IconData icon, VoidCallback onTap) {
    return ActionChip(
      avatar: Icon(icon, size: 18, color: Colors.green),
      label: Text(label),
      onPressed: onTap,
      backgroundColor: Colors.white,
      side: BorderSide(color: Colors.grey.shade300),
    );
  }

  Widget _buildAdminSummary() {
    final healthAsync = ref.watch(ledgerHealthProvider);

    return healthAsync.when(
      loading:
          () => const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
          ),
      error:
          (e, _) => Card(
            color: Colors.red.shade50,
            child: ListTile(
              leading: Icon(Icons.error_outline, color: Colors.red.shade700),
              title: const Text('Could not load health'),
              trailing: IconButton(
                icon: const Icon(Icons.refresh),
                onPressed:
                    () => ref.read(ledgerHealthProvider.notifier).refresh(),
              ),
            ),
          ),
      data: (data) {
        final status = data['status'] as String? ?? 'unknown';
        final isHealthy = status == 'healthy';
        final driftedBatches = data['drifted_batches'] ?? 0;
        final negativeStock = data['negative_stock_batches'] ?? 0;

        return Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: isHealthy ? Colors.green.shade200 : Colors.red.shade200,
            ),
          ),
          child: InkWell(
            onTap: () => context.push('/admin/ledger/health'),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isHealthy
                        ? Icons.check_circle
                        : Icons.warning_amber_rounded,
                    color: isHealthy ? Colors.green : Colors.red,
                    size: 32,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isHealthy ? 'System Healthy' : 'Attention Needed',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color:
                                isHealthy ? Colors.green[700] : Colors.red[700],
                          ),
                        ),
                        if (!isHealthy)
                          Text(
                            'Drift: $driftedBatches | Negative: $negativeStock',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
