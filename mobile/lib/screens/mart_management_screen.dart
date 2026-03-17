import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/mart_repository.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/widgets/agro_snack_bar.dart';

class MartManagementScreen extends ConsumerStatefulWidget {
  const MartManagementScreen({super.key});

  @override
  ConsumerState<MartManagementScreen> createState() =>
      _MartManagementScreenState();
}

class _MartManagementScreenState extends ConsumerState<MartManagementScreen> {
  bool _loading = true;
  String? _error;
  List<Map<String, dynamic>> _marts = const [];

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
      final repo = ref.read(martRepositoryProvider);
      final marts = await repo.fetchMarts();
      if (!mounted) return;
      setState(() {
        _marts = marts;
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

  Future<void> _showEditor({Map<String, dynamic>? mart}) async {
    final nameController = TextEditingController(text: mart?['name']?.toString() ?? '');
    final companyController = TextEditingController(
      text: mart?['company_name']?.toString() ?? '',
    );
    final isEdit = mart != null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEdit ? 'Edit Mart' : 'Create Mart'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Mart name'),
            ),
            const SizedBox(height: AgroSpacing.sm),
            TextField(
              controller: companyController,
              decoration: const InputDecoration(labelText: 'Company name'),
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
                'name': nameController.text.trim(),
                'company_name': companyController.text.trim(),
                if (!isEdit) 'is_active': true,
              };
              try {
                final repo = ref.read(martRepositoryProvider);
                if (isEdit) {
                  await repo.updateMart(mart['id'] as int, payload);
                } else {
                  await repo.createMart(payload);
                }
                if (!dialogContext.mounted) return;
                Navigator.pop(dialogContext);
                await _load();
                if (!mounted) return;
                AgroSnackBar.success(
                  context,
                  isEdit ? 'Mart updated' : 'Mart created',
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
    );
  }

  Future<void> _setStatus(Map<String, dynamic> mart, bool isActive) async {
    try {
      final repo = ref.read(martRepositoryProvider);
      await repo.setMartStatus(mart['id'] as int, isActive);
      await _load();
      if (!mounted) return;
      AgroSnackBar.success(
        context,
        isActive ? 'Mart activated' : 'Mart deactivated',
      );
    } catch (e) {
      if (!mounted) return;
      AgroSnackBar.error(context, e.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mart Management')),
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
                : _marts.isEmpty
                    ? const Center(child: Text('No marts configured'))
                    : ListView.builder(
                        padding: const EdgeInsets.all(AgroSpacing.screenPadding),
                        itemCount: _marts.length,
                        itemBuilder: (context, index) {
                          final mart = _marts[index];
                          final isActive = mart['is_active'] as bool? ?? true;
                          return Card(
                            child: ListTile(
                              leading: Icon(
                                isActive ? Icons.storefront : Icons.storefront_outlined,
                                color: isActive ? AgroColors.primary : Colors.grey,
                              ),
                              title: Text(mart['name']?.toString() ?? 'Unnamed Mart'),
                              subtitle: Text(mart['company_name']?.toString() ?? ''),
                              trailing: PopupMenuButton<String>(
                                onSelected: (value) {
                                  if (value == 'edit') _showEditor(mart: mart);
                                  if (value == 'toggle') _setStatus(mart, !isActive);
                                },
                                itemBuilder: (context) => [
                                  const PopupMenuItem(
                                    value: 'edit',
                                    child: Text('Edit'),
                                  ),
                                  PopupMenuItem(
                                    value: 'toggle',
                                    child: Text(isActive ? 'Deactivate' : 'Activate'),
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
