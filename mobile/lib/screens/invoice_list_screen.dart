import 'dart:io';
import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import '../services/invoice_service.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({Key? key}) : super(key: key);
  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  DateTime? _filterDate;
  String? _filterMart;
  String _search = '';
  List<Map<String, dynamic>> _invoices = [];
  List<String> _marts = [];
  bool _loading = true, _uploading = false;
  String? _error;
  List<String> _pickedPaths = [];
  List<Map<String, dynamic>> _uploadResults = [];
  bool _showUploadSection = false;

  @override
  void initState() {
    super.initState();
    _loadMarts();
    _fetchInvoices();
  }

  Future<void> _loadMarts() async {
    try {
      final list = await InvoiceService.fetchMartNames();
      setState(() => _marts = list);
    } catch (_) {}
  }

  Future<void> _fetchInvoices() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await InvoiceService.fetchInvoices(
        date: _filterDate,
        martName: _filterMart,
        search: _search.isNotEmpty ? _search : null,
      );
      setState(() => _invoices = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );

    if (result != null && result.files.isNotEmpty) {
      final pdfFiles =
          result.files
              .where(
                (file) =>
                    file.path != null &&
                    file.path!.toLowerCase().endsWith('.pdf'),
              )
              .toList();

      setState(() {
        _pickedPaths = pdfFiles.map((file) => file.path!).toList();
        _showUploadSection = true;
        _uploadResults.clear(); // clear previous results if new files selected
      });
    }
  }

  Future<void> _uploadFiles() async {
    if (_pickedPaths.isEmpty) return;

    setState(() {
      _uploading = true;
      _uploadResults.clear();
      _error = null;
    });

    try {
      final responses = await InvoiceService.uploadInvoices(_pickedPaths);

      for (final resp in responses) {
        if (resp['unmapped_items'] != null &&
            resp['unmapped_items'].isNotEmpty) {
          final invoiceId = resp['invoice_id'];
          final unmappedItems = List<Map<String, dynamic>>.from(
            resp['unmapped_items'],
          );
          if (mounted) {
            await context.push(
              '/map-items',
              extra: {'invoice_id': invoiceId, 'unmapped_items': unmappedItems},
            );
          }
        }
      }

      setState(() {
        _uploadResults = responses;
        _pickedPaths.clear();
        _showUploadSection = false; // hide upload form
      });

      await _fetchInvoices(); // refresh table
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _uploading = false;
      });
    }
  }

  Future<void> _selectDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _filterDate ?? today,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null) {
      setState(() => _filterDate = picked);
      _fetchInvoices();
    }
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Invoice'),
            content: const Text('Are you sure?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Yes'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await InvoiceService.deleteInvoice(id);
      _fetchInvoices();
    }
  }

  Future<void> _showEditItemDialog(Map<String, dynamic> item) async {
    final qtyController = TextEditingController(
      text: item['quantity'].toString(),
    );
    final priceController = TextEditingController(
      text: item['price'].toString(),
    );
    final totalController = TextEditingController();

    void calculateTotal() {
      final qty = double.tryParse(qtyController.text) ?? 0;
      final price = double.tryParse(priceController.text) ?? 0;
      final total = qty * price;
      totalController.text = total.toStringAsFixed(2);
    }

    // Set initial total
    calculateTotal();

    // Add listeners to update total when qty or price changes
    qtyController.addListener(calculateTotal);
    priceController.addListener(calculateTotal);

    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Invoice Item'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: qtyController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Quantity'),
              ),
              TextField(
                controller: priceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Price'),
              ),
              TextField(
                controller: totalController,
                readOnly: true,
                decoration: const InputDecoration(labelText: 'Total'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final updatedQty = double.tryParse(qtyController.text);
                final updatedPrice = double.tryParse(priceController.text);
                final updatedTotal = double.tryParse(totalController.text);

                if (updatedQty == null ||
                    updatedPrice == null ||
                    updatedTotal == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Invalid input')),
                  );
                  return;
                }

                await InvoiceService.updateInvoiceItem(item['id'], {
                  'quantity': updatedQty,
                  'price': updatedPrice,
                  'total': updatedTotal,
                });
                Navigator.pop(context);
                await _fetchInvoices();
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Invoices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.upload_file),
            onPressed: _pickFiles,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ───────────────────────────────────────────────
            // 1) UPLOAD FORM CARD
            // ───────────────────────────────────────────────
            if (_showUploadSection)
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // header with close button
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Selected Files',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Cancel Upload',
                            onPressed: () {
                              setState(() {
                                _pickedPaths.clear();
                                _showUploadSection = false;
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // file list
                      ..._pickedPaths.map(
                        (p) => Text(
                          '• ${p.split('/').last}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),

                      const SizedBox(height: 12),
                      // Upload button
                      Align(
                        alignment: Alignment.centerRight,
                        child: ElevatedButton.icon(
                          icon:
                              _uploading
                                  ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                  : const Icon(Icons.cloud_upload),
                          label: const Text('Upload'),
                          onPressed: _uploading ? null : _uploadFiles,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // ───────────────────────────────────────────────
            // 2) UPLOAD RESULTS CARD
            // ───────────────────────────────────────────────
            if (_uploadResults.isNotEmpty)
              Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // header + close
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Upload Results',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Dismiss Results',
                            onPressed: () {
                              setState(() {
                                _uploadResults.clear();
                              });
                            },
                          ),
                        ],
                      ),

                      const SizedBox(height: 8),
                      // each result
                      for (final result in _uploadResults)
                        ListTile(
                          dense: true,
                          leading: Icon(
                            result['success'] == true
                                ? Icons.check_circle
                                : Icons.error,
                            color:
                                result['success'] == true
                                    ? Colors.green
                                    : Colors.red,
                          ),
                          title: Text(result['filename'] ?? 'Unnamed file'),
                          subtitle:
                              result['success'] == true
                                  ? null
                                  : Text(
                                    result['error'] ?? 'Unknown error',
                                    style: const TextStyle(
                                      color: Colors.redAccent,
                                    ),
                                  ),
                        ),

                      const SizedBox(height: 12),
                      // add more
                      Center(
                        child: ElevatedButton.icon(
                          icon: const Icon(Icons.add),
                          label: const Text('Add More Files'),
                          onPressed: () {
                            setState(() {
                              _uploadResults.clear();
                              _pickedPaths.clear();
                              _showUploadSection = true;
                            });
                            _pickFiles();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

            // Filters
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _selectDate,
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    _filterDate == null
                        ? 'All Dates'
                        : DateFormat('yyyy-MM-dd').format(_filterDate!),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _filterMart,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(),
                    ),
                    dropdownStyleData: DropdownStyleData(
                      maxHeight: 200,
                      width: 200, // You can adjust this as needed
                    ),
                    hint: const Text('All Marts'),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('All Marts'),
                      ),
                      ..._marts.map(
                        (m) => DropdownMenuItem(value: m, child: Text(m)),
                      ),
                    ],
                    onChanged: (v) {
                      setState(() {
                        _filterMart = v;
                        _fetchInvoices();
                      });
                    },
                  ),
                ),

                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Search…'),
                    onChanged: (v) {
                      _search = v;
                      _fetchInvoices();
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Error
            if (_error != null)
              Center(
                child: Text(_error!, style: const TextStyle(color: Colors.red)),
              ),

            // Invoice List
            Expanded(
              child:
                  _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _invoices.isEmpty
                      ? const Center(child: Text('No invoices found'))
                      : ListView.builder(
                        itemCount: _invoices.length,
                        itemBuilder: (ctx, i) {
                          final inv = _invoices[i];
                          return ExpansionTile(
                            title: Text(
                              inv['mart_name'],
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            subtitle: Text(
                              '${DateFormat('MMM dd, yyyy').format(DateTime.parse(inv['invoice_date']))}   ₹ ${inv['total_amount'].toStringAsFixed(2)}',
                            ),
                            trailing: Wrap(
                              spacing: 4,
                              children: [
                                Tooltip(
                                  message:
                                      inv['is_verified']
                                          ? 'Mark as Unverified'
                                          : 'Mark as Verified',
                                  child: IconButton(
                                    icon: Icon(
                                      inv['is_verified']
                                          ? Icons.check_circle
                                          : Icons.hourglass_bottom,
                                    ),
                                    onPressed: () async {
                                      await InvoiceService.updateInvoice(
                                        inv['id'],
                                        !(inv['is_verified'] as bool),
                                        inv['remarks'] as String? ?? '',
                                      );
                                      _fetchInvoices();
                                    },
                                  ),
                                ),
                                Tooltip(
                                  message: 'Delete Invoice',
                                  child: IconButton(
                                    icon: const Icon(Icons.delete),
                                    onPressed: () => _confirmDelete(inv['id']),
                                  ),
                                ),
                              ],
                            ),

                            children: [
                              ListTile(
                                title: Text(
                                  inv['file_path'].toString().split('/').last,
                                ),
                                trailing: TextButton(
                                  onPressed: () {
                                    context.push(
                                      '/pdf-viewer',
                                      extra: int.parse(inv['id'].toString()),
                                    );
                                  },
                                  child: const Text('View'),
                                ),
                              ),
                              FutureBuilder<List<Map<String, dynamic>>>(
                                future: InvoiceService.fetchInvoiceItems(
                                  inv['id'],
                                ),
                                builder: (ctx, snap) {
                                  if (!snap.hasData) {
                                    return const LinearProgressIndicator();
                                  }
                                  final items = snap.data!;
                                  return SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: DataTable(
                                      columns: const [
                                        DataColumn(label: Text('Name')),
                                        DataColumn(label: Text('Qty')),
                                        DataColumn(label: Text('UOM')),
                                        DataColumn(label: Text('Price')),
                                        DataColumn(label: Text('Total')),
                                        DataColumn(label: Text('Actions')),
                                      ],
                                      rows:
                                          items.map((it) {
                                            return DataRow(
                                              onLongPress: () async {
                                                final selected =
                                                    await showMenu<String>(
                                                      context: context,
                                                      position:
                                                          RelativeRect.fill,
                                                      items: [
                                                        const PopupMenuItem(
                                                          value: 'edit',
                                                          child: Text('Edit'),
                                                        ),
                                                        const PopupMenuItem(
                                                          value: 'delete',
                                                          child: Text('Delete'),
                                                        ),
                                                      ],
                                                    );

                                                if (selected == 'edit') {
                                                  await _showEditItemDialog(it);
                                                  setState(() {}); // refresh UI
                                                } else if (selected ==
                                                    'delete') {
                                                  final confirmed = await showDialog<
                                                    bool
                                                  >(
                                                    context: context,
                                                    builder:
                                                        (_) => AlertDialog(
                                                          title: const Text(
                                                            'Delete Item',
                                                          ),
                                                          content: const Text(
                                                            'Are you sure you want to delete this item?',
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed:
                                                                  () =>
                                                                      Navigator.pop(
                                                                        context,
                                                                        false,
                                                                      ),
                                                              child: const Text(
                                                                'No',
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed:
                                                                  () =>
                                                                      Navigator.pop(
                                                                        context,
                                                                        true,
                                                                      ),
                                                              child: const Text(
                                                                'Yes',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                  );
                                                  if (confirmed == true) {
                                                    await InvoiceService.deleteInvoiceItem(
                                                      it['id'],
                                                    );
                                                    setState(() {});
                                                  }
                                                }
                                              },
                                              cells: [
                                                DataCell(
                                                  Text(it['item_name'] ?? ''),
                                                ),
                                                DataCell(
                                                  Text(
                                                    it['quantity'].toString(),
                                                  ),
                                                ),
                                                DataCell(Text(it['uom'] ?? '')),
                                                DataCell(
                                                  Text(
                                                    (it['price'] as num)
                                                        .toStringAsFixed(2),
                                                  ),
                                                ),
                                                DataCell(
                                                  Text(
                                                    (it['total'] as num)
                                                        .toStringAsFixed(2),
                                                  ),
                                                ),
                                                DataCell(
                                                  PopupMenuButton<String>(
                                                    icon: const Icon(
                                                      Icons.more_vert,
                                                      size: 18,
                                                    ),
                                                    onSelected: (value) async {
                                                      if (value == 'edit') {
                                                        await _showEditItemDialog(
                                                          it,
                                                        );
                                                      } else if (value ==
                                                          'delete') {
                                                        final confirmed = await showDialog<
                                                          bool
                                                        >(
                                                          context: context,
                                                          builder:
                                                              (
                                                                _,
                                                              ) => AlertDialog(
                                                                title: const Text(
                                                                  'Delete Item',
                                                                ),
                                                                content: const Text(
                                                                  'Are you sure you want to delete this item?',
                                                                ),
                                                                actions: [
                                                                  TextButton(
                                                                    onPressed:
                                                                        () => Navigator.pop(
                                                                          context,
                                                                          false,
                                                                        ),
                                                                    child:
                                                                        const Text(
                                                                          'No',
                                                                        ),
                                                                  ),
                                                                  TextButton(
                                                                    onPressed:
                                                                        () => Navigator.pop(
                                                                          context,
                                                                          true,
                                                                        ),
                                                                    child:
                                                                        const Text(
                                                                          'Yes',
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                        );
                                                        if (confirmed == true) {
                                                          await InvoiceService.deleteInvoiceItem(
                                                            it['id'],
                                                          );
                                                          await _fetchInvoices();
                                                        }
                                                      }
                                                    },
                                                    itemBuilder:
                                                        (context) => [
                                                          const PopupMenuItem(
                                                            value: 'edit',
                                                            child: Text('Edit'),
                                                          ),
                                                          const PopupMenuItem(
                                                            value: 'delete',
                                                            child: Text(
                                                              'Delete',
                                                            ),
                                                          ),
                                                        ],
                                                  ),
                                                ),
                                              ],
                                            );
                                          }).toList(),
                                    ),
                                  );
                                },
                              ),
                              // Remarks & Save
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                child: Column(
                                  children: [
                                    SwitchListTile(
                                      title: const Text('Verified'),
                                      value: inv['is_verified'] as bool,
                                      onChanged: (v) async {
                                        await InvoiceService.updateInvoice(
                                          inv['id'],
                                          v,
                                          inv['remarks'] as String? ?? '',
                                        );
                                        _fetchInvoices();
                                      },
                                    ),
                                    TextField(
                                      controller: TextEditingController(
                                        text: inv['remarks'] as String? ?? '',
                                      ),
                                      decoration: const InputDecoration(
                                        labelText: 'Remarks',
                                      ),
                                      onSubmitted: (txt) async {
                                        await InvoiceService.updateInvoice(
                                          inv['id'],
                                          inv['is_verified'] as bool,
                                          txt,
                                        );
                                        _fetchInvoices();
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }
}
