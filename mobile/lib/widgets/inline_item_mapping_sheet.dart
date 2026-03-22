import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../models/mart_bill_item.dart';
import '../providers/mart_bill_provider.dart';
import '../providers/warehouse_context_provider.dart';
import '../repositories/item_repository.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
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

  List<Map<String, dynamic>> _suggestions = [];
  bool _isSuggestionsLoading = false;
  List<Map<String, dynamic>> _allItems = [];
  bool _isAllItemsLoading = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadInitialData());
  }

  Future<void> _loadInitialData() async {
    final warehouseId = ref.read(warehouseContextProvider);
    if (warehouseId == null) return;

    setState(() => _isAllItemsLoading = true);
    try {
      final items = await _repo.fetchItems(warehouseId: warehouseId);
      if (mounted) {
        setState(() {
          _allItems = items;
          _isAllItemsLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isAllItemsLoading = false);
    }

    if (widget.billItem != null) {
      setState(() => _isSuggestionsLoading = true);
      try {
        final allSugs = await _repo.fetchBillItemSuggestions(
          warehouseId: warehouseId,
          billId: widget.billId,
        );
        final itemSugs = allSugs[widget.billItem!.id] ?? [];
        if (mounted) {
          setState(() {
            _suggestions = itemSugs;
            _isSuggestionsLoading = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSuggestionsLoading = false);
      }
    }
  }

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

  void _quickMap(int itemId, {String? name}) {
    setState(() {
      _selectedItemId = itemId;
      _selectedItemName = name;
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

          // ── Suggestions / All Items (when not searching) ──
          if (_searchController.text.trim().length < 2) ...[
            if (_suggestions.isNotEmpty || _isSuggestionsLoading)
              _buildSuggestionsSection(),
            _buildAllItemsSection(),
          ],

          // ── Search Results (when search active) ──
          if (_searchController.text.trim().length >= 2)
            _buildSearchResultsSection(),

          const SizedBox(height: AgroSpacing.md),

          // Selected item display
          if (_selectedItemName != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AgroSpacing.sm),
              child: Text(
                'Selected: $_selectedItemName',
                style: AgroTypography.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),

          // Action bar
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: () => context.push('/item-edit'),
                icon: const Icon(Icons.add, size: 16),
                label: const Text('New Item'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AgroSpacing.sm, vertical: 8),
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: _isMapping ? null : () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              const SizedBox(width: AgroSpacing.sm),
              ElevatedButton(
                onPressed:
                    (_selectedItemId != null && !_isMapping) ? _mapItem : null,
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

  Widget _buildSuggestionsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AgroSpacing.sm),
          child: Text(
            'Best matches',
            style: AgroTypography.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (_isSuggestionsLoading)
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ..._suggestions.map((s) {
          final id = (s['id'] as num?)?.toInt() ??
              (s['master_item_id'] as num?)?.toInt();
          if (id == null) return const SizedBox.shrink();
          final name = s['name'] as String? ?? '';
          final uom = s['default_uom_code'] as String? ?? '';
          final conf = (s['confidence'] as num?)?.toInt() ?? 0;
          final isTop = s == _suggestions.first;

          final Color badgeColor;
          if (conf >= 80) {
            badgeColor = AgroColors.success.text;
          } else if (conf >= 30) {
            badgeColor = AgroColors.warning.text;
          } else {
            badgeColor = AgroColors.textSecondary;
          }

          return Container(
            margin: const EdgeInsets.only(bottom: AgroSpacing.xs),
            padding: const EdgeInsets.symmetric(
                horizontal: AgroSpacing.sm, vertical: AgroSpacing.xs),
            decoration: BoxDecoration(
              color: isTop
                  ? AgroColors.success.background
                  : AgroColors.surface,
              borderRadius: AgroShapes.bannerRadius,
              border: Border.all(
                color:
                    isTop ? AgroColors.success.border : AgroColors.divider,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: AgroTypography.body
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$uom  •  $conf%',
                        style: AgroTypography.caption
                            .copyWith(color: badgeColor),
                      ),
                    ],
                  ),
                ),
                OutlinedButton(
                  onPressed:
                      _isMapping ? null : () => _quickMap(id, name: name),
                  style: OutlinedButton.styleFrom(
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AgroSpacing.sm, vertical: 4),
                  ),
                  child: const Text('Map'),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildAllItemsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AgroSpacing.sm),
          child: Text(
            'All items',
            style: AgroTypography.caption.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
        if (_isAllItemsLoading)
          const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        if (!_isAllItemsLoading && _allItems.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 220),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _allItems.length,
              itemBuilder: (ctx, i) {
                final item = _allItems[i];
                final id = item['id'] as int;
                final name = item['name'] as String? ?? '';
                final uom = item['default_uom_code'] as String? ?? '';
                final isSelected = _selectedItemId == id;
                return ListTile(
                  dense: true,
                  selected: isSelected,
                  selectedTileColor: AgroColors.info.background,
                  title: Text(name),
                  subtitle: Text(uom, style: AgroTypography.caption),
                  trailing: OutlinedButton(
                    onPressed:
                        _isMapping ? null : () => _quickMap(id, name: name),
                    style: OutlinedButton.styleFrom(
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                          horizontal: AgroSpacing.sm, vertical: 4),
                    ),
                    child: const Text('Map'),
                  ),
                  onTap: () => setState(() {
                    _selectedItemId = id;
                    _selectedItemName = name;
                  }),
                );
              },
            ),
          ),
      ],
    );
  }

  Widget _buildSearchResultsSection() {
    return Column(
      children: [
        if (_searchResults.isNotEmpty)
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 260),
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
                    '${item['default_uom_code'] ?? ''}${confidence != null ? '  •  $confidence% match' : ''}',
                    style: AgroTypography.caption,
                  ),
                  trailing: isSelected
                      ? Icon(Icons.check_circle, color: AgroColors.success.text)
                      : null,
                  onTap: () => setState(() {
                    _selectedItemId = itemId;
                    _selectedItemName = item['name'];
                  }),
                );
              },
            ),
          ),
        if (_searchResults.isEmpty && !_isSearching)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: AgroSpacing.md),
              child: Text(
                'No matching items found',
                style: AgroTypography.caption,
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
