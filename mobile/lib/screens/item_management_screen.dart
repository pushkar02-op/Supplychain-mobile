import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../providers/item_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_section.dart';
import '../ui/widgets/agro_snack_bar.dart';

class ItemManagementScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? data;
  const ItemManagementScreen({super.key, this.data});

  @override
  ConsumerState<ItemManagementScreen> createState() =>
      _ItemManagementScreenState();
}

class _ItemManagementScreenState extends ConsumerState<ItemManagementScreen> {
  final _formKey = GlobalKey<FormState>();

  String name = '';
  int? defaultUomId;
  String? creationIntent; // "REGULAR" | "ONE_OFF"

  List<int> selectedAliasIds = [];
  List<Map<String, dynamic>> uoms = [];
  List<Map<String, dynamic>> conversions = [];
  List<Map<String, dynamic>> aliasOptions = [];
  List<Map<String, dynamic>> fetchedAliases = [];
  List<Map<String, dynamic>> similarItems = [];

  bool isLoading = true;
  String error = '';
  bool isSaving = false;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      final fetchedUoms = await ref.read(itemAliasProvider.notifier).fetchUOMs();
      final unmappedBillItems =
          await ref.read(itemAliasProvider.notifier).fetchUnmappedMartBillItems();

      // Transform unmapped items to look like aliases for the UI
      final unmappedAsAliases =
          unmappedBillItems.map((item) {
            return {
              'id': item['invoice_item_id'],
              'alias_name': item['item_name'],
              'alias_code': item['item_code'],
            };
          }).toList();

      final currentItem = widget.data;
      // Prefill for edit mode
      name = currentItem?['name'] ?? '';
      creationIntent = currentItem?['creation_intent'];

      // Use code for UOM if available, else id
      String? defaultUomCode = currentItem?['default_uom_code'];
      defaultUomId =
          defaultUomCode != null
              ? fetchedUoms.firstWhere(
                (u) => u['code'] == defaultUomCode,
                orElse: () => fetchedUoms.first,
              )['id']
              : null;

      // Prefill selected aliases for edit
      final existingAliases = List<Map<String, dynamic>>.from(
        currentItem?['aliases'] ?? [],
      );
      selectedAliasIds = existingAliases.map((a) => a['id'] as int).toList();

      // Prefill conversions for edit
      conversions = List<Map<String, dynamic>>.from(
        currentItem?['conversions'] ?? [],
      );

      setState(() {
        uoms = fetchedUoms;
        fetchedAliases = unmappedAsAliases; // For the "Add" dialog
        aliasOptions = [
          ...unmappedAsAliases,
          ...existingAliases.where(
            // Already linked aliases
            (ea) => !fetchedAliases.any((fa) => fa['id'] == ea['id']),
          ),
        ];
        isLoading = false;
      });

      // Generate conversions only for new item
      if (widget.data == null || widget.data?['id'] == null)
        _generateConversions();
    } catch (e) {
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  void _generateConversions() {
    if (defaultUomId == null) return;
    final defaultUom = uoms.firstWhere((u) => u['id'] == defaultUomId);
    final defaultCode = defaultUom['code'];
    final otherUOMs = uoms
        .where((u) => u['id'] != defaultUomId)
        .toList(growable: false);

    conversions =
        otherUOMs.map((uom) {
          final existing = conversions.firstWhere(
            (c) => c['target_unit'] == uom['code'],
            orElse: () => {},
          );
          return {
            'source_unit': defaultCode,
            'target_unit': uom['code'],
            'conversion_factor': existing['conversion_factor'] ?? 1.0,
          };
        }).toList();
    setState(() {});
  }

  void _onNameChanged(String v) {
    name = v.trim();
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      _checkDuplicates();
    });
  }

  Future<void> _checkDuplicates() async {
    if (name.isEmpty) {
      setState(() => similarItems = []);
      return;
    }
    // Get UOM code
    String? uomCode;
    if (defaultUomId != null) {
      final u = uoms.firstWhere(
        (u) => u['id'] == defaultUomId,
        orElse: () => {},
      );
      uomCode = u['code'];
    }

    final results = await ref
        .read(itemAliasProvider.notifier)
        .checkSimilarity(name, uomCode);
    if (!mounted) return;
    setState(() {
      // Filter out self if editing
      if (widget.data != null) {
        similarItems =
            results.where((r) => r['id'] != widget.data!['id']).toList();
      } else {
        similarItems = results;
      }
    });
  }

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (defaultUomId == null) return;

    setState(() => isSaving = true);
    try {
      final payload = {
        if (widget.data?['id'] != null) 'id': widget.data!['id'],
        'name': name,
        'default_uom_id': defaultUomId,
        'creation_intent': creationIntent,
        'aliases':
            aliasOptions
                .where((a) => selectedAliasIds.contains(a['id']))
                .map(
                  (a) => {
                    'id': a['id'],
                    'alias_code': a['alias_code'],
                    'alias_name': a['alias_name'],
                  },
                )
                .toList(),
        'conversions': conversions,
      };

      final newItem = await ref
          .read(itemAliasProvider.notifier)
          .createOrUpdateItem(payload);

      if (!mounted) return;
      AgroSnackBar.success(context, 'Item saved successfully');
      context.pop(newItem);
    } catch (e) {
      setState(() {
        error = e.toString();
        isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // Phase 1 Guardrail: Intent Selection for NEW items
    if ((widget.data == null || widget.data?['id'] == null) &&
        creationIntent == null) {
      return _IntentSelectionScreen(
        onIntentSelected: (value) => setState(() => creationIntent = value),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.data != null ? 'Edit Item' : 'New Item'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              if (error.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: AgroSpacing.md),
                  child: Text(error, style: const TextStyle(color: Colors.red)),
                ),

              // ═══════════════════════════════════════════════════════════════
              // SECTION 1: IDENTITY — What is this?
              // ═══════════════════════════════════════════════════════════════
              AgroSection(
                title: 'Identity',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      initialValue: name,
                      decoration: const InputDecoration(labelText: 'Item Name'),
                      validator:
                          (v) =>
                              v == null || v.trim().isEmpty ? 'Required' : null,
                      onChanged: _onNameChanged,
                    ),

                    // Duplicate Awareness (Advisory)
                    if (similarItems.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.only(top: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          border: Border.all(color: Colors.orange.shade200),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.orange.shade800,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Potential similar items found",
                                  style: TextStyle(
                                    color: Colors.orange.shade900,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            ...similarItems
                                .map(
                                  (item) => Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 4,
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item['name'],
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              Text(
                                                "${item['default_unit']} • ${item['alias_count']} aliases",
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (item['has_stock'] == true)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade100,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "In Stock",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.green.shade800,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.grey.shade200,
                                              borderRadius:
                                                  BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              "Never Used",
                                              style: TextStyle(
                                                fontSize: 10,
                                                color: Colors.grey.shade600,
                                              ),
                                            ),
                                          ),
                                        TextButton(
                                          child: const Text("View"),
                                          onPressed: () {
                                            context.push(
                                              '/items/${item['id']}',
                                            );
                                          },
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ],
                        ),
                      ),

                    const SizedBox(height: AgroSpacing.md),

                    DropdownButtonFormField<int>(
                      decoration: const InputDecoration(
                        labelText: 'Default UOM',
                      ),
                      value: defaultUomId,
                      items:
                          uoms
                              .map(
                                (u) => DropdownMenuItem<int>(
                                  value: u['id'],
                                  child: Text(u['code']),
                                ),
                              )
                              .toList(),
                      onChanged: (v) {
                        setState(() => defaultUomId = v);
                        _generateConversions();
                        _checkDuplicates();
                      },
                      validator: (v) => v == null ? 'Select UOM' : null,
                    ),
                  ],
                ),
              ),

              SizedBox(height: AgroSpacing.sectionGap),

              // ═══════════════════════════════════════════════════════════════
              // SECTION 2: UNITS & CONVERSIONS — How is it measured?
              // ═══════════════════════════════════════════════════════════════
              AgroSection(
                title: 'Units & Conversions',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ...conversions.asMap().entries.map((entry) {
                      final i = entry.key;
                      final c = entry.value;
                      final currentTarget = c['target_unit'];

                      // 🔍 UX-3: Context Logic
                      final contextConversions =
                          conversions
                              .where(
                                (other) =>
                                    other['target_unit'] != currentTarget &&
                                    (other['conversion_factor'] ?? 1.0) != 1.0,
                              )
                              .toList();

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Text(
                                  '1 ${c['source_unit']} =',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue:
                                      c['conversion_factor'].toString(),
                                  decoration: InputDecoration(
                                    labelText: c['target_unit'],
                                  ),
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'^\d+\.?\d*'),
                                    ),
                                  ],
                                  validator:
                                      (v) =>
                                          double.tryParse(v ?? '') == null
                                              ? 'Invalid'
                                              : null,
                                  onChanged: (v) {
                                    conversions[i]['conversion_factor'] =
                                        double.tryParse(v) ?? 1.0;
                                  },
                                ),
                              ),
                            ],
                          ),
                          // 👁️ UX-3: Context Panel
                          if (contextConversions.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(
                                top: AgroSpacing.xs,
                                bottom: AgroSpacing.md,
                              ),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(AgroSpacing.sm),
                                decoration: BoxDecoration(
                                  color: AgroColors.neutral.background,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      "Existing conversions for this item:",
                                      style: AgroTypography.captionEmphasis,
                                    ),
                                    const SizedBox(height: 4),
                                    ...contextConversions.map((other) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 2,
                                        ),
                                        child: Text(
                                          "• 1 ${other['source_unit']} = ${other['conversion_factor']} ${other['target_unit']}",
                                          style: AgroTypography.tiny.copyWith(
                                            color: AgroColors.textSecondary,
                                          ),
                                        ),
                                      );
                                    }),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      );
                    }),
                    const SizedBox(height: AgroSpacing.sm),
                    // Conversion Description (read-only summary)
                    ...conversions.map((c) {
                      final factor = c['conversion_factor'];
                      final src = c['source_unit'];
                      final tgt = c['target_unit'];
                      final reverseFactor = factor != 0 ? (1 / factor) : null;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '1 $src of $name is $factor $tgt',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.grey,
                              ),
                            ),
                            if (reverseFactor != null)
                              Row(
                                children: [
                                  const Text(
                                    'Reverse: ',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  SizedBox(
                                    width: 60,
                                    child: TextFormField(
                                      key: ValueKey('rev_${tgt}_$src'),
                                      initialValue: reverseFactor
                                          .toStringAsFixed(3),
                                      decoration: InputDecoration(
                                        labelText: '$tgt to $src',
                                      ),
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      onChanged: (v) {
                                        final val = double.tryParse(v);
                                        if (val != null && val != 0) {
                                          setState(() {
                                            c['conversion_factor'] = 1 / val;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                  Text(
                                    ' $src',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      );
                    }),
                  ],
                ),
              ),

              SizedBox(height: AgroSpacing.sectionGap),

              // ═══════════════════════════════════════════════════════════════
              // SECTION 3: NAMING & ALIASES — How does it appear externally?
              // ═══════════════════════════════════════════════════════════════
              AgroSection(
                title: 'Naming & Aliases',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 6,
                      children:
                          aliasOptions.map((alias) {
                            final isSelected = selectedAliasIds.contains(
                              alias['id'],
                            );
                            return FilterChip(
                              label: Text(
                                '${alias['alias_name']} (${alias['alias_code']})',
                              ),
                              selected: isSelected,
                              onSelected: (val) {
                                setState(() {
                                  if (val) {
                                    selectedAliasIds.add(alias['id']);
                                  } else {
                                    selectedAliasIds.remove(alias['id']);
                                  }
                                });
                              },
                            );
                          }).toList(),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Add Unmapped Alias'),
                      onPressed: () async {
                        final selected = await showDialog<int>(
                          context: context,
                          builder: (context) {
                            int? tempSelected;
                            return AlertDialog(
                              title: const Text('Select Unmapped Alias'),
                              content: DropdownButtonFormField<int>(
                                value: tempSelected,
                                items:
                                    fetchedAliases
                                        .where(
                                          (a) =>
                                              !aliasOptions.any(
                                                (ao) => ao['id'] == a['id'],
                                              ),
                                        )
                                        .map(
                                          (a) => DropdownMenuItem<int>(
                                            value: a['id'],
                                            child: Text(
                                              '${a['alias_name']} (${a['alias_code']})',
                                            ),
                                          ),
                                        )
                                        .toList(),
                                onChanged: (v) => tempSelected = v,
                                decoration: const InputDecoration(
                                  labelText: 'Alias',
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context),
                                  child: const Text('Cancel'),
                                ),
                                ElevatedButton(
                                  onPressed:
                                      () =>
                                          Navigator.pop(context, tempSelected),
                                  child: const Text('Add'),
                                ),
                              ],
                            );
                          },
                        );
                        if (selected != null) {
                          final alias = fetchedAliases.firstWhere(
                            (a) => a['id'] == selected,
                          );
                          setState(() {
                            aliasOptions.add(alias);
                            selectedAliasIds.add(alias['id']);
                          });
                        }
                      },
                    ),
                  ],
                ),
              ),

              SizedBox(height: AgroSpacing.sectionGap),

              // ═══════════════════════════════════════════════════════════════
              // LIFECYCLE ACTIONS — Only for existing items (Edit mode)
              // ═══════════════════════════════════════════════════════════════
              if (widget.data != null && widget.data?['id'] != null) ...[
                _ItemLifecycleActions(
                  data: widget.data!,
                  isSaving: isSaving,
                  onSavingChanged: (v) => setState(() => isSaving = v),
                  onError: (e) => setState(() => error = e),
                ),
                SizedBox(height: AgroSpacing.md),
              ],

              // ═══════════════════════════════════════════════════════════════
              // SAVE BUTTON — Unchanged
              // ═══════════════════════════════════════════════════════════════
              ElevatedButton(
                onPressed: isSaving ? null : _saveItem,
                child:
                    isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Save Item'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Private Extracted Widgets ────────────────────────────────────────

class _IntentSelectionScreen extends StatelessWidget {
  final ValueChanged<String> onIntentSelected;

  const _IntentSelectionScreen({required this.onIntentSelected});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Create Item")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              "How will this item be used?",
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            const Text(
              "This helps organize your catalog.",
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            _IntentCard(
              title: "Regular Item",
              subtitle: "Used frequently in stock and dispatch.",
              icon: Icons.inventory_2,
              onTap: () => onIntentSelected("REGULAR"),
            ),
            const SizedBox(height: 16),
            _IntentCard(
              title: "One-off Item",
              subtitle: "Unlikely to appear again.",
              icon: Icons.filter_1,
              onTap: () => onIntentSelected("ONE_OFF"),
            ),
          ],
        ),
      ),
    );
  }
}

class _IntentCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _IntentCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: Colors.blue.shade700, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle, style: const TextStyle(color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemLifecycleActions extends ConsumerWidget {
  final Map<String, dynamic> data;
  final bool isSaving;
  final ValueChanged<bool> onSavingChanged;
  final ValueChanged<String> onError;

  const _ItemLifecycleActions({
    required this.data,
    required this.isSaving,
    required this.onSavingChanged,
    required this.onError,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = data['status'] ?? 'ACTIVE';
    final isActive = status == 'ACTIVE';

    if (isActive) {
      return OutlinedButton.icon(
        onPressed: isSaving ? null : () => _confirmDeactivate(context, ref),
        icon: Icon(Icons.archive, color: AgroColors.critical.text),
        label: Text(
          'Deactivate Item',
          style: TextStyle(color: AgroColors.critical.text),
        ),
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: AgroColors.critical.text),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    } else {
      return ElevatedButton.icon(
        onPressed: isSaving ? null : () => _reactivateItem(context, ref),
        icon: const Icon(Icons.restore_from_trash),
        label: const Text('Reactivate Item'),
        style: ElevatedButton.styleFrom(
          backgroundColor: AgroColors.success.text,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
      );
    }
  }

  Future<void> _confirmDeactivate(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Deactivate Item?'),
            content: const Text(
              'This will mark the item as inactive. It will be hidden from '
              'default lists but history is preserved. You can reactivate it later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: TextButton.styleFrom(
                  foregroundColor: AgroColors.critical.text,
                ),
                child: const Text('Deactivate'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      onSavingChanged(true);
      final id = data['id'];
      final res = await ref.read(itemLifecycleProvider.notifier).deactivate(id);
      if (!context.mounted) return;
      onSavingChanged(false);

      if (res != null) {
        Navigator.pop(context, true);
      } else {
        onError('Failed to deactivate item');
      }
    }
  }

  Future<void> _reactivateItem(BuildContext context, WidgetRef ref) async {
    onSavingChanged(true);
    final id = data['id'];
    final res = await ref.read(itemLifecycleProvider.notifier).reactivate(id);
    if (!context.mounted) return;
    onSavingChanged(false);

    if (res != null) {
      AgroSnackBar.success(context, 'Item reactivated successfully');
      Navigator.pop(context, true);
    } else {
      onError('Failed to reactivate item');
    }
  }
}
