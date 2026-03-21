import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/mart_bill_item.dart';
import '../providers/mart_bill_provider.dart';
import '../providers/warehouse_context_provider.dart';
import '../repositories/item_repository.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_snack_bar.dart';

/// Bottom sheet for mapping unresolved invoice items to a master item.
///
/// Supports single-item mapping (maps immediately) and selection-only mode
/// (returns the chosen master item ID without mapping).
class InlineItemMappingSheet extends ConsumerStatefulWidget {
  final MartBillItem? billItem;
  final int billId;

  /// If true, the sheet returns the selected item ID without mapping.
  final bool selectionOnly;

  const InlineItemMappingSheet({
    super.key,
    this.billItem,
    required this.billId,
    this.selectionOnly = false,
  });

  /// Show the mapping sheet for a single item (maps immediately on confirm).
  static Future<bool?> show(
    BuildContext context, {
    required MartBillItem billItem,
    required int billId,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => InlineItemMappingSheet(
        billItem: billItem,
        billId: billId,
      ),
    );
  }

  /// Show the sheet in selection-only mode. Returns `{id, name}` of the
  /// selected master item without performing any mapping.
  static Future<Map<String, dynamic>?> showForSelection(
    BuildContext context, {
    required int billId,
  }) {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => InlineItemMappingSheet(
        billId: billId,
        selectionOnly: true,
      ),
    );
  }

  @override
  ConsumerState<InlineItemMappingSheet> createState() =>
      _InlineItemMappingSheetState();
}

class _InlineItemMappingSheetState
    extends ConsumerState<InlineItemMappingSheet> {
  final _searchController = TextEditingController();
  final _repo = ItemRepository();
  Timer? _debounce;

  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _isMapping = false;
  int? _selectedItemId;
  String? _selectedItemName;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    final trimmed = query.trim();

    if (trimmed.length < 2) {
      _debounce?.cancel();
      setState(() {
        _searchResults = [];
        _selectedItemId = null;
        _selectedItemName = null;
        _isSearching = false;
      });
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      _performSearch(trimmed);
    });
  }

  Future<void> _performSearch(String query) async {
    final warehouseId = ref.read(warehouseContextProvider);
    if (warehouseId == null) return;

    setState(() => _isSearching = true);
    try {
      final results = await _repo.fetchItems(
        warehouseId: warehouseId,
        search: query,
      );
      if (mounted) {
        setState(() {
          _searchResults = results;
          _isSearching = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isSearching = false);
    }
  }

  Future<void> _mapItem() async {
    if (_selectedItemId == null) return;

    // Selection-only mode: return the chosen item without mapping
    if (widget.selectionOnly) {
      Navigator.pop(context, {'id': _selectedItemId, 'name': _selectedItemName});
      return;
    }

    final warehouseId = ref.read(warehouseContextProvider);
    if (warehouseId == null) return;

    setState(() => _isMapping = true);
    try {
      await _repo.mapAlias(
        warehouseId,
        widget.billItem!.id,
        _selectedItemId!,
      );

      if (!mounted) return;

      ref.invalidate(martBillProvider);
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isMapping = false);
      AgroSnackBar.error(context, e.toString());
    }
  }

  void _quickMap(int itemId) {
    setState(() {
      _selectedItemId = itemId;
    });
    _mapItem();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final headerText = widget.selectionOnly ? 'Select Item' : 'Map Item';
    final confirmLabel = widget.selectionOnly ? 'Select' : 'Map';

    return Padding(
      padding: EdgeInsets.only(
        left: AgroSpacing.lg,
        right: AgroSpacing.lg,
        top: AgroSpacing.lg,
        bottom: AgroSpacing.lg + bottomInset,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AgroColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: AgroSpacing.md),
          Text(headerText, style: AgroTypography.cardTitle),
          const SizedBox(height: AgroSpacing.sm),

          // Item info (single mapping mode only)
          if (!widget.selectionOnly && widget.billItem != null)
            Container(
              padding: const EdgeInsets.all(AgroSpacing.sm),
              decoration: BoxDecoration(
                color: AgroColors.warning.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.billItem!.itemName,
                    style: AgroTypography.body.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (widget.billItem!.itemCode != null)
                    Text(
                      'Code: ${widget.billItem!.itemCode}',
                      style: AgroTypography.caption,
                    ),
                  Text(
                    '${widget.billItem!.quantity} ${widget.billItem!.uom} @ \u20b9${widget.billItem!.price.toStringAsFixed(2)}',
                    style: AgroTypography.caption,
                  ),
                ],
              ),
            ),

          const SizedBox(height: AgroSpacing.md),

          // Search field
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search master items...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _isSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
            onChanged: _onSearchChanged,
          ),
          const SizedBox(height: AgroSpacing.sm),

          // Best match highlight
          if (_searchResults.isNotEmpty &&
              ((_searchResults.first['confidence'] as num?) ?? 0) >= 70)
            Container(
              padding: const EdgeInsets.all(AgroSpacing.sm),
              margin: const EdgeInsets.only(bottom: AgroSpacing.sm),
              decoration: BoxDecoration(
                color: AgroColors.success.background,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Best Match',
                          style: AgroTypography.caption.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_searchResults.first['name']} (${_searchResults.first['confidence']}%)',
                          style: AgroTypography.body,
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _isMapping
                        ? null
                        : () => _quickMap(_searchResults.first['id'] as int),
                    child: Text(widget.selectionOnly ? 'Quick Select' : 'Quick Map'),
                  ),
                ],
              ),
            ),

          // Search results
          if (_searchResults.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 200),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                itemBuilder: (ctx, i) {
                  final item = _searchResults[i];
                  final itemId = item['id'] as int;
                  final isSelected = _selectedItemId == itemId;
                  final confidence = (item['confidence'] as num?)?.toInt();
                  return ListTile(
                    dense: true,
                    selected: isSelected,
                    selectedTileColor: AgroColors.info.background,
                    title: Text(item['name'] ?? ''),
                    subtitle: Text(
                      '${item['default_uom_code'] ?? ''}${confidence != null ? '  \u2022  $confidence% match' : ''}',
                      style: AgroTypography.caption,
                    ),
                    trailing: isSelected
                        ? Icon(Icons.check_circle, color: AgroColors.success.text)
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedItemId = itemId;
                        _selectedItemName = item['name'];
                      });
                    },
                  );
                },
              ),
            ),

          if (_searchResults.isEmpty &&
              _searchController.text.trim().length >= 2 &&
              !_isSearching)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AgroSpacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'No matching items found',
                      style: AgroTypography.caption,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AgroSpacing.sm),
                    TextButton.icon(
                      onPressed: () => context.push('/item-edit'),
                      icon: const Icon(Icons.add),
                      label: const Text('Create New Item'),
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: AgroSpacing.md),

          // Selected item display + action button
          if (_selectedItemName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AgroSpacing.sm),
              child: Text(
                'Selected: $_selectedItemName',
                style: AgroTypography.body.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),

          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: _isMapping ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AgroSpacing.sm),
              ElevatedButton(
                onPressed: (_selectedItemId != null && !_isMapping)
                    ? _mapItem
                    : null,
                child: _isMapping
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AgroColors.surface,
                        ),
                      )
                    : Text(confirmLabel),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
