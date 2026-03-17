import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/user_role.dart';
import '../core/navigation/create_result.dart';
import '../core/session/session_controller.dart';
import '../core/ui/snackbar_service.dart';
import '../models/user_read.dart';
import '../models/warehouse_access.dart';
import '../providers/user_provider.dart';
import '../ui/theme/agro_spacing.dart';

class EditUserScreen extends ConsumerStatefulWidget {
  const EditUserScreen({super.key, required this.user});

  final UserRead user;

  @override
  ConsumerState<EditUserScreen> createState() => _EditUserScreenState();
}

class _EditUserScreenState extends ConsumerState<EditUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final Set<int> _selectedWarehouseIds = <int>{};
  final Set<int> _initialWarehouseIds = <int>{};

  late final TextEditingController _fullNameController;
  bool _loadingAssignments = true;
  bool _submitting = false;
  String? _selectedRole;
  String? _loadError;

  List<String> _allowedRoles(UserRole? role) {
    switch (role) {
      case UserRole.manager:
        return const ['WORKER'];
      case UserRole.owner:
        return const ['OWNER', 'MANAGER', 'WORKER'];
      case UserRole.worker:
      case null:
        return const ['WORKER'];
    }
  }

  void _handleCancelPop(bool didPop, Object? result) {
    if (didPop) {
      return;
    }
    Navigator.of(context).pop(CreateResult.cancelled);
  }

  @override
  void initState() {
    super.initState();
    _fullNameController = TextEditingController(text: widget.user.fullName);
    _selectedRole = widget.user.role;
    _loadAssignments();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadAssignments() async {
    final role = _selectedRole ?? widget.user.role;
    if (role == 'OWNER') {
      setState(() {
        _loadingAssignments = false;
        _loadError = null;
      });
      return;
    }

    setState(() {
      _loadingAssignments = true;
      _loadError = null;
    });
    try {
      final repo = ref.read(userRepositoryProvider);
      final warehouses = await repo.listUserWarehouses(widget.user.id);
      if (!mounted) {
        return;
      }
      setState(() {
        _initialWarehouseIds
          ..clear()
          ..addAll(warehouses.map((warehouse) => warehouse.id));
        _selectedWarehouseIds
          ..clear()
          ..addAll(_initialWarehouseIds);
        _loadingAssignments = false;
      });
    } catch (e) {
      if (!mounted) {
        return;
      }
      setState(() {
        _loadError = e.toString().replaceFirst('Exception: ', '');
        _loadingAssignments = false;
      });
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final selectedRole = _selectedRole;
    if (selectedRole == null) {
      SnackbarService.showError(context, 'Role is required');
      return;
    }
    if (selectedRole != 'OWNER' && _selectedWarehouseIds.isEmpty) {
      SnackbarService.showError(
        context,
        'Select at least one warehouse for non-owner users',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final session = ref.read(sessionProvider);
      final warehouseId = session.warehouseId;

      await repo.updateUser(
        userId: widget.user.id,
        fullName: _fullNameController.text.trim(),
      );

      if (selectedRole != widget.user.role && warehouseId != null) {
        await repo.updateUserRole(warehouseId, widget.user.id, selectedRole);
      }

      if (selectedRole != 'OWNER') {
        final missing = _selectedWarehouseIds.difference(_initialWarehouseIds);
        for (final warehouseId in missing) {
          await repo.assignWarehouse(userId: widget.user.id, warehouseId: warehouseId);
        }
      }

      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(CreateResult.created);
    } catch (e) {
      if (mounted) {
        SnackbarService.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _deactivate() async {
    final currentUserId = ref.read(sessionProvider).userId;
    if (widget.user.id == currentUserId) {
      SnackbarService.showError(
        context,
        'You cannot deactivate your own account.',
      );
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Deactivate User'),
        content: Text(
          'Deactivate ${widget.user.fullName} (${widget.user.username})?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) {
      return;
    }
    if (!mounted) {
      return;
    }

    setState(() => _submitting = true);
    try {
      final warehouseId = ref.read(sessionProvider).warehouseId;
      if (warehouseId == null) {
        SnackbarService.showError(context, 'No active warehouse selected');
        return;
      }
      await ref.read(userRepositoryProvider).deactivateUser(warehouseId, widget.user.id);
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop(CreateResult.created);
    } catch (e) {
      if (mounted) {
        SnackbarService.showError(
          context,
          e.toString().replaceFirst('Exception: ', ''),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final currentUserId = session.userId;
    final availableWarehouses = session.warehouses ?? const <WarehouseAccess>[];
    final allowedRoles = _allowedRoles(session.role);
    final selectedRole = _selectedRole ?? widget.user.role;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: _handleCancelPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Edit User'),
          leading: BackButton(
            onPressed: () {
              Navigator.of(context).pop(CreateResult.cancelled);
            },
          ),
        ),
        body: SafeArea(
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(AgroSpacing.screenPadding),
              children: [
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(labelText: 'Full Name'),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AgroSpacing.md),
                TextFormField(
                  initialValue: widget.user.username,
                  decoration: const InputDecoration(labelText: 'Username'),
                  enabled: false,
                ),
                const SizedBox(height: AgroSpacing.md),
                DropdownButtonFormField<String>(
                  value: allowedRoles.contains(selectedRole)
                      ? selectedRole
                      : allowedRoles.first,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: allowedRoles
                      .map(
                        (role) => DropdownMenuItem<String>(
                          value: role,
                          child: Text(role),
                        ),
                      )
                      .toList(),
                  onChanged: _submitting
                      ? null
                      : (value) async {
                          if (value == null) {
                            return;
                          }
                          setState(() {
                            _selectedRole = value;
                            if (value == 'OWNER') {
                              _selectedWarehouseIds.clear();
                              _initialWarehouseIds.clear();
                            }
                          });
                          if (value != 'OWNER') {
                            await _loadAssignments();
                          }
                        },
                ),
                const SizedBox(height: AgroSpacing.lg),
                Text(
                  'Warehouse Assignment',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: AgroSpacing.sm),
                if (selectedRole == 'OWNER')
                  const Text(
                    'Owners have implicit access to all active warehouses.',
                  )
                else if (_loadingAssignments)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: AgroSpacing.md),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (_loadError != null)
                  Text(_loadError!, style: const TextStyle(color: Colors.red))
                else if (availableWarehouses.isEmpty)
                  const Text('No warehouses available')
                else ...[
                  const Text(
                    'Selecting additional warehouses will assign them. Unchecking does not remove existing assignments.',
                  ),
                  const SizedBox(height: AgroSpacing.sm),
                  ...availableWarehouses.map(
                    (warehouse) => CheckboxListTile(
                      value: _selectedWarehouseIds.contains(warehouse.id),
                      title: Text(warehouse.name),
                      subtitle: warehouse.displayCode.isEmpty
                          ? null
                          : Text(warehouse.displayCode),
                      contentPadding: EdgeInsets.zero,
                      onChanged: _submitting
                          ? null
                          : (checked) {
                              setState(() {
                                if (checked ?? false) {
                                  _selectedWarehouseIds.add(warehouse.id);
                                } else {
                                  _selectedWarehouseIds.remove(warehouse.id);
                                }
                              });
                            },
                    ),
                  ),
                ],
                const SizedBox(height: AgroSpacing.xl),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _save,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save'),
                  ),
                ),
                const SizedBox(height: AgroSpacing.md),
                SizedBox(
                  height: 48,
                  child: OutlinedButton(
                    onPressed: _submitting || widget.user.id == currentUserId
                        ? null
                        : _deactivate,
                    child: const Text('Deactivate'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
