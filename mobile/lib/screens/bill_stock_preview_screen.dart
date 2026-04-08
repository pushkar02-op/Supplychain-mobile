import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/norm_suggestion.dart';
import '../providers/warehouse_context_provider.dart';
import '../repositories/norm_rule_repository.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_snack_bar.dart';

/// Preview screen for bill-to-stock generation.
///
/// Shows normalization suggestions grouped by confidence level:
/// - Auto (green): confirmed rules, no action needed
/// - Confirm (blue): clean first-time suggestions
/// - Review (orange): range weights with editable estimates
/// - Manual (red): ambiguous items needing user input
/// - Skip (grey): items the user chose to skip
class BillStockPreviewScreen extends ConsumerStatefulWidget {
  final int billId;
  const BillStockPreviewScreen({super.key, required this.billId});

  @override
  ConsumerState<BillStockPreviewScreen> createState() =>
      _BillStockPreviewScreenState();
}

class _BillStockPreviewScreenState
    extends ConsumerState<BillStockPreviewScreen> {
  final _repo = NormRuleRepository();

  bool _isLoading = true;
  bool _isGenerating = false;
  String? _error;
  List<NormSuggestionItem> _items = [];

  // User overrides: billItemId → edited rule_value
  final Map<int, double> _editedValues = {};
  // Items the user explicitly accepted (confirm/review categories)
  final Set<int> _acceptedIds = {};
  // Items the user chose to skip
  final Set<int> _skippedIds = {};
  // Controllers for manual input fields
  final Map<int, TextEditingController> _manualControllers = {};

  int get _warehouseId {
    final id = ref.read(warehouseContextProvider);
    if (id == null) throw StateError('Warehouse not selected');
    return id;
  }

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    for (final c in _manualControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final resp = await _repo.fetchNormSuggestions(
        warehouseId: _warehouseId,
        billId: widget.billId,
      );
      if (!mounted) return;
      setState(() {
        _items = resp.items;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  // ── Category grouping ─────────────────────────────────────────────────

  List<NormSuggestionItem> _byCategory(NormCategory cat) {
    return _items.where((item) {
      if (_skippedIds.contains(item.billItemId)) {
        return cat == NormCategory.skip;
      }
      return item.category == cat;
    }).toList();
  }

  int get _readyCount {
    int count = 0;
    for (final item in _items) {
      if (_skippedIds.contains(item.billItemId)) continue;
      final cat = item.category;
      if (cat == NormCategory.auto) {
        count++;
      } else if (cat == NormCategory.confirm &&
          _acceptedIds.contains(item.billItemId)) {
        count++;
      } else if (cat == NormCategory.review &&
          _acceptedIds.contains(item.billItemId)) {
        count++;
      } else if (cat == NormCategory.manual &&
          _editedValues.containsKey(item.billItemId)) {
        count++;
      }
    }
    return count;
  }

  // ── Actions ───────────────────────────────────────────────────────────

  Future<void> _generateStock() async {
    setState(() => _isGenerating = true);

    try {
      // Step 1: Confirm all new/updated rules
      final rulesToConfirm = <Map<String, dynamic>>[];
      for (final item in _items) {
        if (_skippedIds.contains(item.billItemId)) continue;
        final cat = item.category;

        if (cat == NormCategory.confirm &&
            _acceptedIds.contains(item.billItemId)) {
          rulesToConfirm.add({
            'bill_item_id': item.billItemId,
            'rule_type': item.ruleType,
            'rule_value': _editedValues[item.billItemId] ?? item.ruleValue,
            'accepted': true,
          });
        } else if (cat == NormCategory.review &&
            _acceptedIds.contains(item.billItemId)) {
          rulesToConfirm.add({
            'bill_item_id': item.billItemId,
            'rule_type': item.ruleType,
            'rule_value': _editedValues[item.billItemId] ?? item.ruleValue,
            'accepted': true,
          });
        } else if (cat == NormCategory.manual &&
            _editedValues.containsKey(item.billItemId)) {
          // For manual items, determine rule type from stock uom
          final stockUom = item.targetItem?.stockUom ?? 'ea';
          final ruleType =
              stockUom == 'kg' ? 'FIXED_WEIGHT_TO_KG' : 'FIXED_COUNT_TO_EA';
          rulesToConfirm.add({
            'bill_item_id': item.billItemId,
            'rule_type': ruleType,
            'rule_value': _editedValues[item.billItemId],
            'accepted': true,
          });
        }
      }

      if (rulesToConfirm.isNotEmpty) {
        await _repo.confirmRules(
          warehouseId: _warehouseId,
          billId: widget.billId,
          rules: rulesToConfirm,
        );
      }

      // Step 2: Generate stock entries
      final result = await _repo.generateStock(
        warehouseId: _warehouseId,
        billId: widget.billId,
      );

      if (!mounted) return;
      setState(() => _isGenerating = false);

      // Show result dialog
      await _showResultDialog(result);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGenerating = false);
      AgroSnackBar.error(context, e.toString());
    }
  }

  Future<void> _showResultDialog(GenerateStockResponse result) async {
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.check_circle, color: AgroColors.success.text, size: 24),
            const SizedBox(width: AgroSpacing.sm),
            const Text('Stock Generated'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${result.createdCount} stock entries created',
              style: AgroTypography.body.copyWith(fontWeight: FontWeight.w600),
            ),
            if (result.skippedCount > 0) ...[
              const SizedBox(height: AgroSpacing.sm),
              Text(
                '${result.skippedCount} items skipped',
                style: AgroTypography.caption,
              ),
              ...result.skipped.map((s) => Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '  - ${s.itemName}: ${s.reason}',
                      style: AgroTypography.caption,
                    ),
                  )),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              context.pop(); // Go back to bill detail
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final autoItems = _byCategory(NormCategory.auto);
    final confirmItems = _byCategory(NormCategory.confirm);
    final reviewItems = _byCategory(NormCategory.review);
    final manualItems = _byCategory(NormCategory.manual);
    final skippedItems = _byCategory(NormCategory.skip);
    final ready = _readyCount;

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('Stock Preview'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(AgroSpacing.lg),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, style: AgroTypography.body),
                        const SizedBox(height: AgroSpacing.md),
                        ElevatedButton(
                          onPressed: _loadSuggestions,
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text('No mapped items found',
                          style: AgroTypography.body))
                  : Column(
                      children: [
                        Expanded(
                          child: CustomScrollView(
                            slivers: [
                              // Summary bar
                              SliverToBoxAdapter(
                                child: _buildSummaryBar(
                                  autoItems.length,
                                  confirmItems.length,
                                  reviewItems.length,
                                  manualItems.length,
                                  skippedItems.length,
                                ),
                              ),

                              // Auto section (collapsed by default)
                              if (autoItems.isNotEmpty)
                                ..._buildSection(
                                  title: 'READY',
                                  icon: Icons.check_circle,
                                  color: AgroColors.success.text,
                                  bgColor: AgroColors.success.background,
                                  items: autoItems,
                                  builder: _buildAutoCard,
                                  collapsible: true,
                                ),

                              // Confirm section
                              if (confirmItems.isNotEmpty)
                                ..._buildSection(
                                  title: 'CONFIRM',
                                  icon: Icons.thumb_up_outlined,
                                  color: AgroColors.info.text,
                                  bgColor: AgroColors.info.background,
                                  items: confirmItems,
                                  builder: _buildConfirmCard,
                                ),

                              // Review section
                              if (reviewItems.isNotEmpty)
                                ..._buildSection(
                                  title: 'REVIEW',
                                  icon: Icons.edit_outlined,
                                  color: AgroColors.warning.text,
                                  bgColor: AgroColors.warning.background,
                                  items: reviewItems,
                                  builder: _buildReviewCard,
                                ),

                              // Manual section
                              if (manualItems.isNotEmpty)
                                ..._buildSection(
                                  title: 'MANUAL INPUT',
                                  icon: Icons.keyboard_outlined,
                                  color: AgroColors.critical.text,
                                  bgColor: AgroColors.critical.background,
                                  items: manualItems,
                                  builder: _buildManualCard,
                                ),

                              // Skipped section
                              if (skippedItems.isNotEmpty)
                                ..._buildSection(
                                  title: 'SKIPPED',
                                  icon: Icons.block_outlined,
                                  color: AgroColors.textSecondary,
                                  bgColor: AgroColors.surface,
                                  items: skippedItems,
                                  builder: _buildSkippedCard,
                                ),

                              const SliverToBoxAdapter(
                                child: SizedBox(height: AgroSpacing.xl),
                              ),
                            ],
                          ),
                        ),

                        // Bottom generate bar
                        _buildBottomBar(ready),
                      ],
                    ),
    );
  }

  Widget _buildSummaryBar(
      int auto, int confirm, int review, int manual, int skipped) {
    return Container(
      margin: const EdgeInsets.all(AgroSpacing.md),
      padding: const EdgeInsets.all(AgroSpacing.md),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        borderRadius: AgroShapes.containerRadius,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryDot(
              count: auto, label: 'Auto', color: AgroColors.success.text),
          _SummaryDot(
              count: confirm, label: 'Confirm', color: AgroColors.info.text),
          _SummaryDot(
              count: review, label: 'Review', color: AgroColors.warning.text),
          _SummaryDot(
              count: manual, label: 'Manual', color: AgroColors.critical.text),
          if (skipped > 0)
            _SummaryDot(
                count: skipped,
                label: 'Skip',
                color: AgroColors.textSecondary),
        ],
      ),
    );
  }

  List<Widget> _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required List<NormSuggestionItem> items,
    required Widget Function(NormSuggestionItem) builder,
    bool collapsible = false,
  }) {
    return [
      SliverToBoxAdapter(
        child: _SectionHeader(
          icon: icon,
          color: color,
          label: '$title  (${items.length})',
        ),
      ),
      SliverList(
        delegate: SliverChildBuilderDelegate(
          (_, i) => builder(items[i]),
          childCount: items.length,
        ),
      ),
    ];
  }

  // ── Card Builders ─────────────────────────────────────────────────────

  Widget _buildAutoCard(NormSuggestionItem item) {
    return _NormCard(
      item: item,
      borderColor: AgroColors.success.border,
      trailing: Icon(Icons.check_circle,
          color: AgroColors.success.text, size: 20),
      conversionText: _conversionText(item),
      onSkip: () => setState(() => _skippedIds.add(item.billItemId)),
    );
  }

  Widget _buildConfirmCard(NormSuggestionItem item) {
    final accepted = _acceptedIds.contains(item.billItemId);
    return _NormCard(
      item: item,
      borderColor: AgroColors.info.border,
      conversionText: _conversionText(item),
      trailing: accepted
          ? Icon(Icons.check_circle,
              color: AgroColors.success.text, size: 20)
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AgroColors.info.text,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: AgroSpacing.sm, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () =>
                  setState(() => _acceptedIds.add(item.billItemId)),
              child: const Text('Accept'),
            ),
      onSkip: () => setState(() => _skippedIds.add(item.billItemId)),
    );
  }

  Widget _buildReviewCard(NormSuggestionItem item) {
    final accepted = _acceptedIds.contains(item.billItemId);
    final editedVal = _editedValues[item.billItemId];
    final currentVal = editedVal ?? item.ruleValue ?? 0;

    return _NormCard(
      item: item,
      borderColor: AgroColors.warning.border,
      conversionText: _conversionText(item, overrideValue: currentVal),
      subtitle: 'Estimated value — tap to adjust',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            child: TextField(
              controller: TextEditingController(
                  text: currentVal.toStringAsFixed(3)),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: OutlineInputBorder(),
              ),
              style: AgroTypography.caption,
              onChanged: (v) {
                final parsed = double.tryParse(v);
                if (parsed != null && parsed > 0) {
                  _editedValues[item.billItemId] = parsed;
                }
              },
            ),
          ),
          const SizedBox(width: 4),
          Text(item.stockUom ?? 'kg', style: AgroTypography.caption),
          const SizedBox(width: AgroSpacing.sm),
          if (!accepted)
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AgroColors.warning.text,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: AgroSpacing.sm, vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () =>
                  setState(() => _acceptedIds.add(item.billItemId)),
              child: const Text('OK'),
            )
          else
            Icon(Icons.check_circle,
                color: AgroColors.success.text, size: 20),
        ],
      ),
      onSkip: () => setState(() => _skippedIds.add(item.billItemId)),
    );
  }

  Widget _buildManualCard(NormSuggestionItem item) {
    final stockUom = item.targetItem?.stockUom ?? 'ea';
    _manualControllers.putIfAbsent(
        item.billItemId, () => TextEditingController());
    final ctrl = _manualControllers[item.billItemId]!;
    final hasValue = _editedValues.containsKey(item.billItemId);

    return _NormCard(
      item: item,
      borderColor: AgroColors.critical.border,
      conversionText: hasValue
          ? _conversionText(item,
              overrideValue: _editedValues[item.billItemId]!)
          : null,
      subtitle: 'Enter $stockUom per 1 billed ${item.billedUom}',
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 64,
            child: TextField(
              controller: ctrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                isDense: true,
                hintText: '0.0',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                border: const OutlineInputBorder(),
                fillColor: hasValue ? AgroColors.success.background : null,
                filled: hasValue,
              ),
              style: AgroTypography.caption,
              onChanged: (v) {
                final parsed = double.tryParse(v);
                setState(() {
                  if (parsed != null && parsed > 0) {
                    _editedValues[item.billItemId] = parsed;
                  } else {
                    _editedValues.remove(item.billItemId);
                  }
                });
              },
            ),
          ),
          const SizedBox(width: 4),
          Text(stockUom, style: AgroTypography.caption),
        ],
      ),
      onSkip: () => setState(() => _skippedIds.add(item.billItemId)),
    );
  }

  Widget _buildSkippedCard(NormSuggestionItem item) {
    return _NormCard(
      item: item,
      borderColor: AgroColors.divider,
      conversionText: null,
      trailing: TextButton(
        onPressed: () => setState(() {
          _skippedIds.remove(item.billItemId);
        }),
        child: const Text('Undo'),
      ),
    );
  }

  String? _conversionText(NormSuggestionItem item, {double? overrideValue}) {
    final val = overrideValue ?? item.ruleValue;
    if (val == null) return null;
    final stockQty = item.billedQty * val;
    final uom = item.stockUom ?? 'kg';
    return '${item.billedQty} ${item.billedUom} × $val → '
        '${stockQty.toStringAsFixed(2)} $uom';
  }

  Widget _buildBottomBar(int readyCount) {
    final canGenerate = readyCount > 0 && !_isGenerating;
    return Container(
      padding: const EdgeInsets.all(AgroSpacing.md),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            offset: const Offset(0, -2),
            blurRadius: 4,
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: canGenerate ? _generateStock : null,
            icon: _isGenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.inventory_2_outlined),
            label: Text(
              readyCount > 0
                  ? 'Generate $readyCount Stock Entries'
                  : 'No items ready',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AgroColors.success.text,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              disabledBackgroundColor: AgroColors.divider,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Helper Widgets ──────────────────────────────────────────────────────────

class _SummaryDot extends StatelessWidget {
  final int count;
  final String label;
  final Color color;
  const _SummaryDot(
      {required this.count, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              '$count',
              style: AgroTypography.captionEmphasis.copyWith(color: color),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(label,
            style: AgroTypography.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  const _SectionHeader(
      {required this.icon, required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          AgroSpacing.md, AgroSpacing.sm, AgroSpacing.md, AgroSpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: AgroSpacing.xs),
          Text(
            label,
            style: AgroTypography.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _NormCard extends StatelessWidget {
  final NormSuggestionItem item;
  final Color borderColor;
  final Widget? trailing;
  final String? conversionText;
  final String? subtitle;
  final VoidCallback? onSkip;

  const _NormCard({
    required this.item,
    required this.borderColor,
    this.trailing,
    this.conversionText,
    this.subtitle,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
          AgroSpacing.md, 0, AgroSpacing.md, AgroSpacing.sm),
      decoration: BoxDecoration(
        color: AgroColors.surface,
        borderRadius: AgroShapes.containerRadius,
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AgroSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.itemName,
                        style: AgroTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${item.billedQty} ${item.billedUom}'
                        '${item.targetItem != null ? '  →  ${item.targetItem!.name}' : ''}',
                        style: AgroTypography.caption,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[
                  const SizedBox(width: AgroSpacing.sm),
                  trailing!,
                ],
              ],
            ),
            if (conversionText != null) ...[
              const SizedBox(height: AgroSpacing.xs),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: AgroSpacing.sm, vertical: 4),
                decoration: BoxDecoration(
                  color: AgroColors.background,
                  borderRadius: AgroShapes.bannerRadius,
                ),
                child: Text(conversionText!,
                    style: AgroTypography.caption
                        .copyWith(fontWeight: FontWeight.w500)),
              ),
            ],
            if (subtitle != null) ...[
              const SizedBox(height: 4),
              Text(subtitle!,
                  style: AgroTypography.caption
                      .copyWith(fontStyle: FontStyle.italic)),
            ],
            if (onSkip != null) ...[
              const SizedBox(height: 4),
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onSkip,
                  child: Text(
                    'Skip',
                    style: AgroTypography.caption.copyWith(
                      color: AgroColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
