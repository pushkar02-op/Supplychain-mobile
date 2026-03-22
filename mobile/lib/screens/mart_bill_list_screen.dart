import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../models/mart_bill.dart';
import '../providers/active_mart_provider.dart';
import '../providers/mart_bill_provider.dart';
import '../ui/semantics/agro_severity.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_empty_state.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_snack_bar.dart';
import '../ui/widgets/agro_status_badge.dart';
import '../widgets/skeleton_loader.dart';

class MartBillListScreen extends ConsumerStatefulWidget {
  const MartBillListScreen({super.key});

  @override
  ConsumerState<MartBillListScreen> createState() => _MartBillListScreenState();
}

class _MartBillListScreenState extends ConsumerState<MartBillListScreen> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      ref.read(martBillProvider.notifier).loadMore();
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;
    final pdfPaths = result.files
        .where((f) => f.path != null && f.path!.toLowerCase().endsWith('.pdf'))
        .map((f) => f.path!)
        .toList();
    ref.read(martBillProvider.notifier).setPickedPaths(pdfPaths);
  }

  Future<void> _uploadFiles() async {
    try {
      await ref.read(martBillProvider.notifier).uploadBills();
    } catch (e) {
      if (!mounted) return;
      AgroSnackBar.error(context, e.toString());
    }
  }

  Future<void> _pickDateRange(MartBillState state) async {
    final today = DateTime.now();
    final initial = state.dateFrom != null && state.dateTo != null
        ? DateTimeRange(start: state.dateFrom!, end: state.dateTo!)
        : DateTimeRange(
            start: DateTime(today.year, today.month, 1), end: today);
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange: initial,
      firstDate: DateTime(today.year - 2),
      lastDate: today,
    );
    if (picked != null) {
      await ref
          .read(martBillProvider.notifier)
          .setDateRange(picked.start, picked.end);
    }
  }

  Future<void> _confirmDelete(int billId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Bill'),
        content: const Text('Are you sure you want to delete this bill?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
                foregroundColor: AgroColors.critical.text),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).deleteBill(billId);
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _confirmVerify(int billId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Verify Bill'),
        content: const Text('Mark this bill as verified and lock it?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).verifyBill(billId);
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  Future<void> _confirmUnverify(int billId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Unlock Bill'),
        content: const Text('This will allow editing again.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Unlock'),
          ),
        ],
      ),
    );
    if (ok == true) {
      try {
        await ref.read(martBillProvider.notifier).unverifyBill(billId);
      } catch (e) {
        if (!mounted) return;
        AgroSnackBar.error(context, e.toString());
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(martBillProvider);
    final marts = ref.watch(
      martListProvider.select(
        (async) =>
            async.valueOrNull?.map((m) => m['name'] as String).toList() ??
            const <String>[],
      ),
    );
    final selectedMart = ref.watch(activeMartProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Mart Bills'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 0,
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _pickFiles,
        backgroundColor: AgroColors.primary,
        tooltip: 'Upload Bill',
        child: const Icon(Icons.upload_file, color: Colors.white),
      ),
      body: asyncState.when(
        loading: () => const StaticSkeletonList(itemCount: 6),
        error: (e, _) => AgroErrorState.loadFailed(
          customTitle: 'Failed to load mart bills',
          message: e.toString(),
          onRetry: () => ref.read(martBillProvider.notifier).refresh(),
        ),
        data: (state) {
          final dateFmt = DateFormat('MMM d');
          final dateLabel = state.dateFrom != null && state.dateTo != null
              ? '${dateFmt.format(state.dateFrom!)} – ${dateFmt.format(state.dateTo!)}'
              : 'All dates';
          final summary = state.summary;

          // Build flat list with section-header sentinels
          final List<Object> items = [];
          String? lastStatus;
          for (final bill in state.bills) {
            if (bill.status != lastStatus) {
              items.add(bill.status);
              lastStatus = bill.status;
            }
            items.add(bill);
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ── Filter Section ──
              Container(
                color: AgroColors.surface,
                padding: const EdgeInsets.fromLTRB(
                  AgroSpacing.lg,
                  AgroSpacing.md,
                  AgroSpacing.lg,
                  AgroSpacing.sm,
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField2<String>(
                            isExpanded: true,
                            value: selectedMart,
                            decoration: InputDecoration(
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: AgroSpacing.md,
                                vertical: AgroSpacing.sm,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: AgroShapes.pillRadius,
                                borderSide: const BorderSide(
                                    color: AgroColors.divider),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: AgroShapes.pillRadius,
                                borderSide: const BorderSide(
                                    color: AgroColors.divider),
                              ),
                              filled: true,
                              fillColor: AgroColors.surfaceVariant,
                            ),
                            dropdownStyleData:
                                const DropdownStyleData(maxHeight: 200),
                            hint: const Text(
                              'All Marts',
                              style: AgroTypography.body,
                            ),
                            items: [
                              const DropdownMenuItem<String>(
                                value: null,
                                child: Text('All Marts'),
                              ),
                              ...marts.map(
                                (m) => DropdownMenuItem(
                                    value: m, child: Text(m)),
                              ),
                            ],
                            onChanged: (v) =>
                                ref.read(activeMartProvider.notifier).state =
                                    v,
                          ),
                        ),
                        const SizedBox(width: AgroSpacing.sm),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickDateRange(state),
                            icon: const Icon(Icons.date_range, size: 16),
                            label: Text(dateLabel),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AgroColors.textPrimary,
                              side: const BorderSide(
                                  color: AgroColors.divider),
                              backgroundColor: AgroColors.surfaceVariant,
                              shape: RoundedRectangleBorder(
                                borderRadius: AgroShapes.pillRadius,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: AgroSpacing.md,
                                vertical: AgroSpacing.sm + 2,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AgroSpacing.sm),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _StatusChip(
                            label: 'All',
                            count: summary.totalBills,
                            active: state.statusFilter == null,
                            onTap: () => ref
                                .read(martBillProvider.notifier)
                                .setStatusFilter(null),
                          ),
                          const SizedBox(width: AgroSpacing.sm),
                          _StatusChip(
                            label: 'Needs review',
                            count: summary.needsReview,
                            active: state.statusFilter == 'NEEDS_REVIEW',
                            activeColor: AgroColors.warning.text,
                            onTap: () => ref
                                .read(martBillProvider.notifier)
                                .setStatusFilter('NEEDS_REVIEW'),
                          ),
                          const SizedBox(width: AgroSpacing.sm),
                          _StatusChip(
                            label: 'Processing',
                            count: summary.processing,
                            active: state.statusFilter == 'PROCESSING',
                            activeColor: AgroColors.info.text,
                            onTap: () => ref
                                .read(martBillProvider.notifier)
                                .setStatusFilter('PROCESSING'),
                          ),
                          const SizedBox(width: AgroSpacing.sm),
                          _StatusChip(
                            label: 'Verified',
                            count: summary.verified,
                            active: state.statusFilter == 'VERIFIED',
                            activeColor: AgroColors.success.text,
                            onTap: () => ref
                                .read(martBillProvider.notifier)
                                .setStatusFilter('VERIFIED'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: AgroColors.divider),
              // ── Metrics Bar ──
              Container(
                color: AgroColors.surfaceVariant,
                padding: const EdgeInsets.symmetric(
                  horizontal: AgroSpacing.lg,
                  vertical: AgroSpacing.sm,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AgroSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: AgroColors.surface,
                          borderRadius: AgroShapes.containerRadius,
                          border: Border.all(color: AgroColors.divider),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Total bills',
                                style: AgroTypography.caption),
                            const SizedBox(height: 2),
                            Text(
                              '${summary.totalBills}',
                              style: AgroTypography.cardTitle
                                  .copyWith(fontSize: 22),
                            ),
                            Text(
                              '${summary.verified} verified',
                              style: AgroTypography.caption,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AgroSpacing.sm),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(AgroSpacing.sm + 2),
                        decoration: BoxDecoration(
                          color: summary.totalUnresolvedItems > 0
                              ? AgroColors.warning.background
                              : AgroColors.surface,
                          borderRadius: AgroShapes.containerRadius,
                          border: Border.all(
                            color: summary.totalUnresolvedItems > 0
                                ? AgroColors.warning.border
                                : AgroColors.divider,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Unresolved items',
                              style: AgroTypography.caption.copyWith(
                                color: summary.totalUnresolvedItems > 0
                                    ? AgroColors.warning.text
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${summary.totalUnresolvedItems}',
                              style: AgroTypography.cardTitle.copyWith(
                                fontSize: 22,
                                color: summary.totalUnresolvedItems > 0
                                    ? AgroColors.warning.text
                                    : null,
                              ),
                            ),
                            Text(
                              'across ${summary.needsReview} bills',
                              style: AgroTypography.caption.copyWith(
                                color: summary.totalUnresolvedItems > 0
                                    ? AgroColors.warning.text
                                    : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Upload Pending Banner ──
              if (state.pickedPaths.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(
                      AgroSpacing.lg, AgroSpacing.sm, AgroSpacing.lg, 0),
                  padding: const EdgeInsets.all(AgroSpacing.sm + 2),
                  decoration: BoxDecoration(
                    color: AgroColors.info.background,
                    borderRadius: AgroShapes.bannerRadius,
                    border: Border.all(color: AgroColors.info.border),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline,
                          size: 16, color: AgroColors.info.text),
                      const SizedBox(width: AgroSpacing.sm),
                      Expanded(
                        child: Text(
                          '${state.pickedPaths.length} file(s) selected',
                          style: AgroTypography.disclaimer
                              .copyWith(color: AgroColors.info.text),
                        ),
                      ),
                      TextButton(
                        onPressed: () => ref
                            .read(martBillProvider.notifier)
                            .setPickedPaths(const []),
                        child: const Text('Cancel'),
                      ),
                      const SizedBox(width: AgroSpacing.xs),
                      if (state.isUploading)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        TextButton(
                          onPressed: _uploadFiles,
                          child: const Text('Upload'),
                        ),
                    ],
                  ),
                ),
              // ── Upload Results ──
              if (state.uploadResults.isNotEmpty)
                Container(
                  margin: const EdgeInsets.fromLTRB(
                      AgroSpacing.lg, AgroSpacing.sm, AgroSpacing.lg, 0),
                  decoration: BoxDecoration(
                    color: AgroColors.surface,
                    borderRadius: AgroShapes.containerRadius,
                    border: Border.all(color: AgroColors.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(
                            AgroSpacing.md,
                            AgroSpacing.md,
                            AgroSpacing.md,
                            AgroSpacing.sm),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Upload results',
                                style: AgroTypography.cardTitle),
                            IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () => ref
                                  .read(martBillProvider.notifier)
                                  .clearUploadResults(),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),
                      ...state.uploadResults.map((result) {
                        final success = result['success'] == true;
                        final filename =
                            result['filename'] as String? ?? 'Unknown file';
                        final error = result['error'] as String?;
                        final unmapped = result['unmapped_items'] as List?;

                        if (success) {
                          final itemCount = unmapped?.length ?? 0;
                          return _UploadResultTile(
                            filename: filename,
                            success: true,
                            message: itemCount > 0
                                ? '$itemCount item(s) need mapping'
                                : 'All items mapped',
                          );
                        }

                        final errorStr = error ?? '';
                        final isMartNotFound =
                            errorStr.contains('Mart not found');
                        final isDuplicate =
                            errorStr.contains('Duplicate');

                        return _UploadResultTile(
                          filename: filename,
                          success: false,
                          message: errorStr,
                          actionLabel:
                              isMartNotFound ? 'Create mart' : null,
                          onAction: isMartNotFound
                              ? () => _showCreateMartDialog(
                                  context, ref, errorStr, filename)
                              : isDuplicate
                                  ? () => ref
                                      .read(martBillProvider.notifier)
                                      .clearUploadResults()
                                  : null,
                        );
                      }),
                      Padding(
                        padding: const EdgeInsets.all(AgroSpacing.md),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => ref
                                  .read(martBillProvider.notifier)
                                  .clearUploadResults(),
                              child: const Text('Dismiss'),
                            ),
                            const SizedBox(width: AgroSpacing.sm),
                            ElevatedButton.icon(
                              onPressed: _pickFiles,
                              icon: const Icon(Icons.add, size: 16),
                              label: const Text('Upload more'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AgroColors.primary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              // ── Bill List ──
              Expanded(
                child: state.bills.isEmpty
                    ? ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: 400,
                            child: AgroEmptyState(
                              icon: Icons.receipt_long_outlined,
                              title: 'No mart bills found',
                              actionLabel: 'Upload a bill',
                              onAction: _pickFiles,
                            ),
                          ),
                        ],
                      )
                    : RefreshIndicator(
                        onRefresh: () =>
                            ref.read(martBillProvider.notifier).refresh(),
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(
                            AgroSpacing.lg,
                            AgroSpacing.md,
                            AgroSpacing.lg,
                            AgroSpacing.xxl,
                          ),
                          itemCount:
                              items.length + (state.hasMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == items.length) {
                              return Padding(
                                padding:
                                    const EdgeInsets.all(AgroSpacing.lg),
                                child: Center(
                                  child: state.isLoadingMore
                                      ? const CircularProgressIndicator(
                                          strokeWidth: 2)
                                      : const SizedBox.shrink(),
                                ),
                              );
                            }
                            final item = items[i];
                            if (item is String) {
                              return _buildSectionHeader(item);
                            }
                            final bill = item as MartBill;
                            return _BillCard(
                              bill: bill,
                              onTap: () => context
                                  .push('/mart-bill-detail/${bill.id}'),
                              onVerify: bill.unresolvedCount > 0
                                  ? () => AgroSnackBar.error(
                                        context,
                                        '${bill.unresolvedCount} item(s) unresolved. Resolve before verifying.',
                                      )
                                  : () => _confirmVerify(bill.id),
                              onUnverify: () => _confirmUnverify(bill.id),
                              onDelete: () => _confirmDelete(bill.id),
                            );
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCreateMartDialog(
    BuildContext context,
    WidgetRef ref,
    String errorMessage,
    String filename,
  ) async {
    String martName = 'Unknown';
    final match = RegExp(r'Mart not found: "(.+?)"').firstMatch(errorMessage);
    if (match != null) martName = match.group(1)!;

    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Mart'),
        content: Text(
          'Mart "$martName" does not exist.\n\nGo to Mart Management to create it, then re-upload "$filename".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Go to Mart Management'),
          ),
        ],
      ),
    );

    if (ok == true && context.mounted) {
      context.push('/admin/marts');
      AgroSnackBar.success(
        context,
        'Create "$martName" in mart management, then re-upload.',
      );
    }
  }

  Widget _buildSectionHeader(String status) {
    Color dotColor;
    String label;
    switch (status) {
      case 'NEEDS_REVIEW':
        dotColor = AgroColors.warning.text;
        label = 'NEEDS ATTENTION';
        break;
      case 'PROCESSING':
        dotColor = AgroColors.info.text;
        label = 'PROCESSING';
        break;
      case 'VERIFIED':
        dotColor = AgroColors.success.text;
        label = 'VERIFIED';
        break;
      default:
        dotColor = AgroColors.textSecondary;
        label = status.toUpperCase();
    }
    return Padding(
      padding: const EdgeInsets.only(
          top: AgroSpacing.sm, bottom: AgroSpacing.xs),
      child: Row(
        children: [
          Container(
            width: 6,
            height: 6,
            decoration:
                BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: AgroSpacing.xs),
          Text(
            label,
            style: AgroTypography.caption.copyWith(
              color: dotColor,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Status Filter Chip ──────────────────────────────────────────────────────

class _StatusChip extends StatelessWidget {
  final String label;
  final int count;
  final bool active;
  final Color? activeColor;
  final VoidCallback onTap;

  const _StatusChip({
    required this.label,
    required this.count,
    required this.active,
    this.activeColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? (activeColor ?? AgroColors.primary)
        : AgroColors.surfaceVariant;
    final fg = active ? Colors.white : AgroColors.textSecondary;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: AgroSpacing.sm + 2, vertical: 6),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: AgroShapes.pillRadius,
          border: Border.all(color: active ? bg : AgroColors.divider),
        ),
        child: Text(
          '$label · $count',
          style: AgroTypography.caption.copyWith(
            color: fg,
            fontWeight: active ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

// ── Bill Card ───────────────────────────────────────────────────────────────

class _BillCard extends StatelessWidget {
  final MartBill bill;
  final VoidCallback onTap;
  final VoidCallback onVerify;
  final VoidCallback onUnverify;
  final VoidCallback onDelete;

  const _BillCard({
    required this.bill,
    required this.onTap,
    required this.onVerify,
    required this.onUnverify,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final severity = AgroSeverity.fromBillStatus(bill.status);
    final isVerified = bill.status == 'VERIFIED';
    final isNeedsReview = bill.status == 'NEEDS_REVIEW';
    final readyToVerify = isNeedsReview && bill.unresolvedCount == 0;

    return Container(
      margin: const EdgeInsets.only(bottom: AgroSpacing.sm),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        borderRadius: AgroShapes.containerRadius,
        border: Border(
            left: BorderSide(width: 5, color: severity.textColor)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: AgroShapes.containerRadius,
        child: Padding(
          padding: const EdgeInsets.all(AgroSpacing.md + 2),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            bill.martName ?? 'Unknown Mart',
                            style: AgroTypography.cardTitle
                                .copyWith(fontSize: 15),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Text(
                          '₹${bill.totalAmount.toStringAsFixed(2)}',
                          style: AgroTypography.captionEmphasis,
                        ),
                      ],
                    ),
                    if (bill.invoiceDate != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        DateFormat('MMM d, yyyy')
                            .format(DateTime.parse(bill.invoiceDate!)),
                        style: AgroTypography.caption,
                      ),
                    ],
                    const SizedBox(height: AgroSpacing.sm),
                    Wrap(
                      spacing: AgroSpacing.sm,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        AgroStatusBadge.fromBillStatus(bill.status),
                        if (bill.unresolvedCount > 0)
                          Text(
                            '· ${bill.unresolvedCount} unresolved',
                            style: AgroTypography.caption.copyWith(
                              color: AgroColors.warning.text,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        if (readyToVerify)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AgroSpacing.sm, vertical: 2),
                            decoration: BoxDecoration(
                              color: AgroColors.success.background,
                              borderRadius: AgroShapes.badgeRadius,
                            ),
                            child: Text(
                              'Ready to verify',
                              style: AgroTypography.caption.copyWith(
                                color: AgroColors.success.text,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'view') onTap();
                  if (v == 'verify') onVerify();
                  if (v == 'unverify') onUnverify();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(
                      value: 'view', child: Text('View Details')),
                  if (isNeedsReview && bill.unresolvedCount == 0)
                    const PopupMenuItem(
                        value: 'verify', child: Text('Verify')),
                  if (isVerified)
                    const PopupMenuItem(
                        value: 'unverify', child: Text('Unlock')),
                  if (!isVerified)
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline,
                              size: 18,
                              color: AgroColors.critical.text),
                          const SizedBox(width: AgroSpacing.sm),
                          Text('Delete',
                              style: TextStyle(
                                  color: AgroColors.critical.text)),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Upload Result Tile ───────────────────────────────────────────────────────

class _UploadResultTile extends StatelessWidget {
  final String filename;
  final bool success;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _UploadResultTile({
    required this.filename,
    required this.success,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor =
        success ? AgroColors.success.background : AgroColors.critical.background;
    final borderColor =
        success ? AgroColors.success.border : AgroColors.critical.border;
    final textColor =
        success ? AgroColors.success.text : AgroColors.critical.text;
    final icon = success ? Icons.check_circle_outline : Icons.error_outline;

    return Container(
      margin: const EdgeInsets.fromLTRB(
          AgroSpacing.md, 0, AgroSpacing.md, AgroSpacing.sm),
      padding: const EdgeInsets.all(AgroSpacing.sm + 2),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: AgroShapes.bannerRadius,
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 16, color: textColor),
              const SizedBox(width: AgroSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      filename,
                      style: AgroTypography.body.copyWith(
                        fontWeight: FontWeight.w600,
                        color: textColor,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message,
                      style: AgroTypography.caption.copyWith(color: textColor),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!success && actionLabel != null) ...[
            const SizedBox(height: AgroSpacing.sm),
            Row(
              children: [
                const SizedBox(width: 24),
                OutlinedButton(
                  onPressed: onAction,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: textColor,
                    side: BorderSide(color: borderColor),
                    padding: const EdgeInsets.symmetric(
                        horizontal: AgroSpacing.sm + 2, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!, style: const TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
