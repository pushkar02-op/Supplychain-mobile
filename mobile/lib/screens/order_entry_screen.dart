// lib/screens/order_entry_screen.dart

import 'package:dropdown_search/dropdown_search.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../providers/order_provider.dart';
import '../ui/widgets/agro_snack_bar.dart';

class OrderEntryScreen extends ConsumerStatefulWidget {
  const OrderEntryScreen({super.key});

  @override
  ConsumerState<OrderEntryScreen> createState() => _OrderEntryScreenState();
}

class _OrderEntryScreenState extends ConsumerState<OrderEntryScreen> {
  final _formKey = GlobalKey<FormState>();

  DateTime _orderDate = DateTime.now();
  Map<String, dynamic>? _selectedItem;
  String? _selectedMart;
  String _quantity = '';
  String _unit = '';
  bool _isLoading = false;
  String _error = '';

  List<Map<String, dynamic>> _items = <Map<String, dynamic>>[];
  List<String> _unitOptions = [];
  List<Map<String, dynamic>> _marts = [];
  int? _selectedMartId;

  Map<String, dynamic>? _editingOrder;

  String? _submitError;
  bool _isDuplicate = false;

  bool get _isEdit => _editingOrder != null;

  @override
  void initState() {
    super.initState();
    _loadMarts();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final extra = GoRouterState.of(context).extra;
    if (extra is Map<String, dynamic>) {
      _editingOrder = extra;
      _preFill();
    }
  }

  void _preFill() {
    if (_editingOrder == null) return;

    _orderDate = DateTime.parse(_editingOrder!['order_date']);
    _quantity = _editingOrder!['quantity_ordered'].toString();
    _unit = _editingOrder!['unit'] as String;
    _selectedMartId = _editingOrder!['mart_id'];
    _selectedMart = _editingOrder!['mart_name'];

    _selectedItem = {
      'id': _editingOrder!['item_id'],
      'item_name': _editingOrder!['item']['name'],
      'uom': _unit,
    };

    if (!_unitOptions.contains(_unit)) {
      _unitOptions = List.from(_unitOptions)..add(_unit);
    }

    if (_selectedMart != null) {
      _loadItemsForMart(_selectedMart!, keepSelection: true);
    }
  }

  Future<void> _loadItemsForMart(
    String martName, {
    bool keepSelection = false,
  }) async {
    setState(() {
      _items = [];
      if (!keepSelection) {
        _selectedItem = null;
        _unitOptions = [];
        _unit = '';
      }
      _error = '';
    });
    try {
      final items = await ref
          .read(orderListProvider.notifier)
          .fetchDistinctItemsForMart(martName);
      if (!mounted) return;
      setState(() {
        _items = items;
      });
    } catch (e, st) {
      debugPrint('Error loading items: $e\n$st');
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _loadMarts() async {
    try {
      final marts = await ref.read(orderListProvider.notifier).fetchMartList();
      if (!mounted) return;
      setState(() {
        _marts = marts;
      });
    } catch (e) {
      debugPrint('Failed to load marts: $e');
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _orderDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (picked != null && mounted) setState(() => _orderDate = picked);
  }

  Future<void> _submit() async {
    setState(() {
      _submitError = null;
      _isDuplicate = false;
    });

    if (!_formKey.currentState!.validate() ||
        _selectedItem == null ||
        _selectedMartId == null ||
        _selectedMart == null) {
      return;
    }
    _formKey.currentState!.save();
    setState(() => _isLoading = true);

    final payload = {
      'item_id': _selectedItem!['item_id'],
      'mart_name': _selectedMart!,
      'order_date': DateFormat('yyyy-MM-dd').format(_orderDate),
      'quantity_ordered': double.parse(_quantity),
      'unit': _unit,
    };

    try {
      if (_isEdit) {
        await ref
            .read(orderListProvider.notifier)
            .updateOrder(_editingOrder!['id'], payload);
      } else {
        await ref
            .read(orderListProvider.notifier)
            .createOrder(
              itemId: payload['item_id'],
              martName: payload['mart_name'],
              orderDate: payload['order_date'],
              quantityOrdered: payload['quantity_ordered'],
              unit: payload['unit'],
            );
      }

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (context.mounted) {
        AgroSnackBar.success(
          context,
          _isEdit ? 'Order adjusted' : 'Order created',
        );
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Order create error: $e');
      setState(() => _isLoading = false);

      final msg = e.toString();
      final isDup = msg.toLowerCase().contains('duplicate order');

      setState(() {
        _submitError =
            isDup
                ? "An order for this item, mart, and date already exists."
                : msg;
        _isDuplicate = isDup;
      });
    }
  }

  Widget _sectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Colors.grey[600],
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isToday = DateUtils.isSameDay(_orderDate, DateTime.now());
    final dateStr = DateFormat('EEEE, MMM d').format(_orderDate);

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          _isEdit ? 'Adjust Order' : 'Create Order',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Container(color: Colors.grey[200], height: 1),
        ),
      ),
      body:
          _error.isNotEmpty
              ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load data: $_error',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _loadMarts,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              )
              : (_marts.isEmpty)
              ? const Center(child: CircularProgressIndicator())
              : Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    // --- Schedule Section ---
                    _sectionHeader('Schedule'),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today,
                                size: 20,
                                color: Colors.green[700],
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  _isEdit
                                      ? 'Scheduled for $dateStr'
                                      : isToday
                                      ? 'Scheduled for Today — $dateStr'
                                      : 'Scheduled for $dateStr',
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (!_isEdit)
                                TextButton(
                                  onPressed: _pickDate,
                                  child: const Text('Change'),
                                ),
                            ],
                          ),
                          if (_isEdit)
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 32),
                              child: Text(
                                '(cannot be changed)',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            )
                          else
                            Padding(
                              padding: const EdgeInsets.only(top: 8, left: 32),
                              child: Text(
                                'Orders are scheduled per day.',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey[500],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Destination Section ---
                    _sectionHeader('Destination'),
                    DropdownButtonFormField<int>(
                      // ignore: deprecated_member_use
                      value: _selectedMartId,
                      decoration: InputDecoration(
                        labelText: 'Mart',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      items:
                          _marts
                              .map(
                                (m) => DropdownMenuItem<int>(
                                  value: m['id'],
                                  child: Text(m['name']),
                                ),
                              )
                              .toList(),
                      onChanged:
                          _isEdit
                              ? null // Read-only in edit
                              : (val) {
                                if (val != null) {
                                  final martName =
                                      _marts.firstWhere(
                                        (m) => m['id'] == val,
                                      )['name'];
                                  setState(() {
                                    _selectedMartId = val;
                                    _selectedMart = martName;
                                  });
                                  _loadItemsForMart(martName);
                                }
                              },
                      validator:
                          (val) => val == null ? 'Please select a mart' : null,
                      style: TextStyle(
                        color: _isEdit ? Colors.grey[700] : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // --- Item Section ---
                    _sectionHeader('Item'),
                    if (_isEdit)
                      // Read-only Text Field for Item name in edit mode
                      TextFormField(
                        initialValue: _selectedItem?['item_name'],
                        readOnly: true,
                        decoration: InputDecoration(
                          labelText: 'Item',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[100],
                        ),
                        style: TextStyle(color: Colors.grey[700]),
                      )
                    else
                      DropdownSearch<Map<String, dynamic>>(
                        asyncItems: (String filter) async {
                          // Local filtering for simplicity/perf as per prev implementation logic
                          if (_items.isEmpty) return [];
                          if (filter.isEmpty) {
                            return _items.cast<Map<String, dynamic>>();
                          }
                          final lower = filter.toLowerCase();
                          return _items
                              .cast<Map<String, dynamic>>()
                              .where(
                                (item) => (item['item_name'] as String)
                                    .toLowerCase()
                                    .contains(lower),
                              )
                              .toList();
                        },
                        selectedItem: _selectedItem,
                        itemAsString: (item) => item['item_name'] as String,
                        dropdownDecoratorProps: DropDownDecoratorProps(
                          dropdownSearchDecoration: InputDecoration(
                            labelText: 'Select Item',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                          ),
                        ),
                        popupProps: const PopupProps.dialog(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: 'Search item...',
                            ),
                          ),
                        ),
                        onChanged: (item) {
                          if (item != null) {
                            setState(() {
                              _selectedItem = item;
                              _unit = item['uom'] as String;
                              _unitOptions = [_unit];
                            });
                          }
                        },
                        validator:
                            (item) =>
                                item == null ? 'Please select an item' : null,
                      ),
                    if (_selectedMart != null && _items.isEmpty && !_isEdit)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      // ignore: deprecated_member_use
                      value: _unit.isNotEmpty ? _unit : null,
                      decoration: InputDecoration(
                        labelText: 'Unit',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor:
                            _isEdit ? Colors.grey[100] : Colors.white, // Locked
                      ),
                      items:
                          _unitOptions
                              .map(
                                (u) =>
                                    DropdownMenuItem(value: u, child: Text(u)),
                              )
                              .toList(),
                      onChanged: null, // Always locked per 1:1 rule + Edit rule
                      validator:
                          (v) => v == null || v.isEmpty ? 'Enter unit' : null,
                    ),
                    const SizedBox(height: 24),

                    // --- Quantity Section ---
                    _sectionHeader('Quantity'),
                    TextFormField(
                      initialValue: _quantity,
                      decoration: InputDecoration(
                        labelText: 'Quantity',
                        helperText: 'Enter quantity to order',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                      ),
                      keyboardType: TextInputType.number,
                      onSaved: (v) => _quantity = v!.trim(),
                      validator:
                          (v) =>
                              v == null || v.isEmpty ? 'Enter quantity' : null,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 32),

                    // --- Error & Submit ---
                    if (_submitError != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _submitError!,
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_isDuplicate) ...[
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton(
                                  onPressed: () => context.pop(),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: Colors.red.shade700,
                                    side: BorderSide(
                                      color: Colors.red.shade300,
                                    ),
                                  ),
                                  child: const Text('View existing orders'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        onPressed: _isLoading ? null : _submit,
                        child:
                            _isLoading
                                ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                                : Text(
                                  _isEdit ? 'Adjust Order' : 'Create Order',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                      ),
                    ),
                    const SizedBox(height: 48), // Bottom padding
                  ],
                ),
              ),
    );
  }
}
