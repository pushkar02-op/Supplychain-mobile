import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/uom_repository.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/widgets/agro_snack_bar.dart';

class UomManagementScreen extends ConsumerStatefulWidget {
  const UomManagementScreen({super.key});

  @override
  ConsumerState<UomManagementScreen> createState() => _UomManagementScreenState();
}

class _UomManagementScreenState extends ConsumerState<UomManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _uoms = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = ref.read(uomRepositoryProvider);
      final uoms = await repo.fetchUoms();
      if (!mounted) return;
      setState(() {
        _uoms = uoms;
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

  Future<void> _showEditor({Map<String, dynamic>? uom}) async {
    final codeController = TextEditingController(text: uom?['code']?.toString() ?? '');
    final descriptionController = TextEditingController(
      text: uom?['description']?.toString() ?? '',
    );
    bool isActive = uom?['is_active'] as bool? ?? true;
    final isEdit = uom != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) => AlertDialog(
          title: Text(isEdit ? 'Edit Unit' : 'Create Unit'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: codeController,
                decoration: const InputDecoration(labelText: 'Code'),
              ),
              const SizedBox(height: AgroSpacing.sm),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: AgroSpacing.sm),
              SwitchListTile(
                value: isActive,
                contentPadding: EdgeInsets.zero,
                title: const Text('Active'),
                onChanged: (value) => setDialogState(() => isActive = value),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final payload = {
                  'code': codeController.text.trim(),
                  'description': descriptionController.text.trim().isEmpty
                      ? null
                      : descriptionController.text.trim(),
                  'is_active': isActive,
                };
                try {
                  final repo = ref.read(uomRepositoryProvider);
                  if (isEdit) {
                    await repo.updateUom(uom['id'] as int, payload);
                  } else {
                    await repo.createUom(payload);
                  }
                  if (!dialogContext.mounted) return;
                  Navigator.pop(dialogContext);
                  await _load();
                  if (!mounted) return;
                  AgroSnackBar.success(
                    context,
                    isEdit ? 'Unit updated' : 'Unit created',
                  );
                } catch (e) {
                  if (!mounted) return;
                  AgroSnackBar.error(context, e.toString());
                }
              },
              child: Text(isEdit ? 'Save' : 'Create'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Unit Management')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? ListView(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AgroSpacing.screenPadding),
                        child: Text(_error!, style: const TextStyle(color: Colors.red)),
                      ),
                    ],
                  )
                : _uoms.isEmpty
                    ? const Center(child: Text('No units configured'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AgroSpacing.screenPadding),
                        itemCount: _uoms.length,
                        itemBuilder: (context, index) {
                          final uom = _uoms[index];
                          final isActive = uom['is_active'] as bool? ?? true;
                          return Card(
                            child: ListTile(
                              title: Text(uom['code']?.toString() ?? ''),
                              subtitle: Text(uom['description']?.toString() ?? ''),
                              trailing: Wrap(
                                spacing: 8,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  Text(
                                    isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      color: isActive ? Colors.green : Colors.grey,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.edit),
                                    onPressed: () => _showEditor(uom: uom),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}
