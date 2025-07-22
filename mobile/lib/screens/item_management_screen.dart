import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../services/item_service.dart';

class ItemManagementScreen extends StatefulWidget {
  final Map<String, dynamic>? data;
  const ItemManagementScreen({super.key, this.data});

  @override
  State<ItemManagementScreen> createState() => _ItemManagementScreenState();
}

class _ItemManagementScreenState extends State<ItemManagementScreen> {
  final _formKey = GlobalKey<FormState>();

  String name = '';
  int? defaultUomId;
  List<int> selectedAliasIds = [];
  List<Map<String, dynamic>> uoms = [];
  List<Map<String, dynamic>> conversions = [];
  List<Map<String, dynamic>> aliasOptions = [];
  List<Map<String, dynamic>> fetchedAliases = []; // <-- Add this line

  bool isLoading = true;
  String error = '';
  bool isSaving = false;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final fetchedUoms = await ItemService.fetchUOMs();
      fetchedAliases =
          await ItemService.fetchUnmappedAliases(); // <-- Assign here

      final currentItem = widget.data;
      // Prefill for edit mode
      name = currentItem?['name'] ?? '';
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
        aliasOptions = [
          ...fetchedAliases,
          ...existingAliases.where(
            (ea) => !fetchedAliases.any((fa) => fa['id'] == ea['id']),
          ),
        ];
        isLoading = false;
      });

      // Generate conversions only for new item
      if (widget.data == null) _generateConversions();
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

  Future<void> _saveItem() async {
    if (!_formKey.currentState!.validate()) return;
    if (defaultUomId == null) return;

    setState(() => isSaving = true);
    try {
      final payload = {
        if (widget.data?['id'] != null) 'id': widget.data!['id'],
        'name': name,
        'default_uom_id': defaultUomId,
        'aliases':
            aliasOptions
                .where((a) => selectedAliasIds.contains(a['id']))
                .map(
                  (a) => {
                    'alias_code': a['alias_code'],
                    'alias_name': a['alias_name'],
                  },
                )
                .toList(),
        'conversions': conversions,
      };

      await ItemService.createOrUpdateItem(payload);

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Item saved successfully')));
      context.pop(true);
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
                Text(error, style: const TextStyle(color: Colors.red)),
              TextFormField(
                initialValue: name,
                decoration: const InputDecoration(labelText: 'Item Name'),
                validator:
                    (v) => v == null || v.trim().isEmpty ? 'Required' : null,
                onChanged: (v) => name = v.trim(),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                decoration: const InputDecoration(labelText: 'Default UOM'),
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
                  _generateConversions(); // Always regenerate conversions on UOM change
                },
                validator: (v) => v == null ? 'Select UOM' : null,
              ),
              const Divider(height: 32),
              const Text(
                'Select Aliases (mapped and unmapped)',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Wrap(
                spacing: 6,
                children:
                    aliasOptions.map((alias) {
                      final isSelected = selectedAliasIds.contains(alias['id']);
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
                          decoration: const InputDecoration(labelText: 'Alias'),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel'),
                          ),
                          ElevatedButton(
                            onPressed:
                                () => Navigator.pop(context, tempSelected),
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
              const Divider(height: 32),
              const Text(
                'Conversions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              ...conversions.asMap().entries.map((entry) {
                final i = entry.key;
                final c = entry.value;
                return Row(
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
                        initialValue: c['conversion_factor'].toString(),
                        decoration: InputDecoration(
                          labelText: c['target_unit'],
                        ),
                        keyboardType: const TextInputType.numberWithOptions(
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
                );
              }),
              const SizedBox(height: 16),
              const Text(
                'Conversion Description',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
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
                      Row(
                        children: [
                          Text(
                            'Reverse: ',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.grey,
                            ),
                          ),
                          SizedBox(
                            width: 60,
                            child: TextFormField(
                              initialValue:
                                  reverseFactor != null
                                      ? reverseFactor.toStringAsFixed(3)
                                      : '',
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
              }).toList(),
              const SizedBox(height: 24),
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
