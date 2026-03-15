import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/user_role.dart';
import '../core/navigation/create_result.dart';
import '../core/session/session_controller.dart';
import '../core/ui/snackbar_service.dart';
import '../models/warehouse_access.dart';
import '../providers/user_provider.dart';
import '../ui/theme/agro_spacing.dart';

class CreateUserScreen extends ConsumerStatefulWidget {
  const CreateUserScreen({super.key});

  @override
  ConsumerState<CreateUserScreen> createState() => _CreateUserScreenState();
}

class _CreateUserScreenState extends ConsumerState<CreateUserScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final Set<int> _selectedWarehouseIds = <int>{};

  bool _submitting = false;
  String? _selectedRole;

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
    final role = ref.read(sessionProvider).role;
    final allowed = _allowedRoles(role);
    _selectedRole = allowed.isEmpty ? null : allowed.first;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final role = _selectedRole;
    if (role == null) {
      SnackbarService.showError(context, 'Role is required');
      return;
    }

    if (role != 'OWNER' && _selectedWarehouseIds.isEmpty) {
      SnackbarService.showError(
        context,
        'Select at least one warehouse for non-owner users',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      final repo = ref.read(userRepositoryProvider);
      final user = await repo.createUser(
        username: _usernameController.text.trim(),
        fullName: _fullNameController.text.trim(),
        password: _passwordController.text,
        role: role,
      );

      if (role != 'OWNER') {
        for (final warehouseId in _selectedWarehouseIds) {
          await repo.assignWarehouse(userId: user.id, warehouseId: warehouseId);
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

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(sessionProvider);
    final availableWarehouses = session.warehouses ?? const <WarehouseAccess>[];
    final allowedRoles = _allowedRoles(session.role);
    final selectedRole = _selectedRole ?? allowedRoles.first;

    return PopScope(
      canPop: true,
      onPopInvokedWithResult: _handleCancelPop,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Create User'),
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
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Full name is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AgroSpacing.md),
                TextFormField(
                  controller: _usernameController,
                  decoration: const InputDecoration(labelText: 'Username'),
                  textInputAction: TextInputAction.next,
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Username is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AgroSpacing.md),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Password is required';
                    }
                    if (value.length < 8) {
                      return 'Password must be at least 8 characters';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: AgroSpacing.md),
                DropdownButtonFormField<String>(
                  value: selectedRole,
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
                      : (value) {
                          setState(() {
                            _selectedRole = value;
                            if (value == 'OWNER') {
                              _selectedWarehouseIds.clear();
                            }
                          });
                        },
                  validator: (value) =>
                      value == null || value.isEmpty ? 'Role is required' : null,
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
                else if (availableWarehouses.isEmpty)
                  const Text('No warehouses available')
                else
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
                const SizedBox(height: AgroSpacing.xl),
                SizedBox(
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _submitting ? null : _submit,
                    child: _submitting
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Create'),
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
