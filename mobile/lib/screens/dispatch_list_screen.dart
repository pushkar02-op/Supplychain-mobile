import 'package:dropdown_button2/dropdown_button2.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../services/dispatch_service.dart';

class DispatchListScreen extends StatefulWidget {
  const DispatchListScreen({super.key});

  @override
  State<DispatchListScreen> createState() => _DispatchListScreenState();
}

class _DispatchListScreenState extends State<DispatchListScreen> {
  DateTime _selectedDate = DateTime.now();
  String? _selectedMart;
  List<String> _marts = [];
  List<dynamic> _dispatches = [];
  bool _isLoading = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    _loadMarts();
    _fetch();
  }

  Future<void> _loadMarts() async {
    try {
      final list = await DispatchService.fetchMartNames();
      setState(() => _marts = list);
    } catch (_) {}
  }

  Future<void> _fetch() async {
    setState(() {
      _isLoading = true;
      _error = '';
    });
    try {
      final list = await DispatchService.fetchDispatches(
        dispatchDate: DateFormat('yyyy-MM-dd').format(_selectedDate),
        martName: _selectedMart,
      );
      setState(() => _dispatches = list);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(today.year - 1),
      lastDate: today,
    );
    if (d != null) {
      setState(() => _selectedDate = d);
      _fetch();
    }
  }

  Future<void> _confirmDelete(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Delete Dispatch'),
            content: const Text('Really delete this entry?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete'),
              ),
            ],
          ),
    );
    if (ok == true) {
      await DispatchService.deleteDispatch(id);
      _fetch();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text('DISPATCH LIST')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(DateFormat('yyyy-MM-dd').format(_selectedDate)),
                  onPressed: _pickDate,
                ),
                const SizedBox(width: 12),

                Expanded(
                  child: DropdownButtonFormField2<String>(
                    isExpanded: true,
                    value: _selectedMart,
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
                        _selectedMart = v;
                        _fetch();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),

                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                  ),
                  icon: const Icon(Icons.add),
                  label: const Text('New Dispatch'),
                  onPressed: () => context.push('/orders'),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Expanded(
              child:
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : _error.isNotEmpty
                      ? Center(
                        child: Text(
                          _error,
                          style: const TextStyle(color: Colors.red),
                        ),
                      )
                      : _dispatches.isEmpty
                      ? const Center(child: Text('No dispatches found'))
                      : ListView.builder(
                        itemCount: _dispatches.length,
                        itemBuilder: (ctx, i) {
                          final d = _dispatches[i];
                          final batch = d['batch'] ?? {};
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(
                                '${batch['item_name']} — ${d['quantity']} ${d['unit']}',
                              ),
                              subtitle: Text(
                                '${d['dispatch_date']} @ ${d['mart_name']}',
                              ),
                              trailing: PopupMenuButton<String>(
                                onSelected: (v) async {
                                  if (v == 'edit') {
                                    final ok = await context.push(
                                      '/dispatch-entry',
                                      extra: d,
                                    );
                                    if (ok == true) _fetch();
                                  } else {
                                    _confirmDelete(d['id'] as int);
                                  }
                                },
                                itemBuilder:
                                    (_) => const [
                                      // PopupMenuItem(
                                      //   value: 'edit',
                                      //   child: Text('Edit'),
                                      // ),
                                      PopupMenuItem(
                                        value: 'delete',
                                        child: Text('Delete'),
                                      ),
                                    ],
                              ),
                            ),
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
