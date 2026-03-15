import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../core/session/session_controller.dart';
import '../core/ui/snackbar_service.dart';
import '../providers/user_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_error_state.dart';

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentUserProfileProvider);

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: AgroColors.surface,
        foregroundColor: AgroColors.textPrimary,
        elevation: 1,
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, _) => AgroErrorState.loadFailed(
              customTitle: 'Could not load profile',
              message: error.toString(),
              onRetry: () => ref.invalidate(currentUserProfileProvider),
            ),
        data: (user) {
          final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
          return ListView(
            padding: const EdgeInsets.all(AgroSpacing.screenPadding),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AgroShapes.cardRadius,
                  side: const BorderSide(color: AgroColors.dividerLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AgroSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: AgroTypography.cardTitle),
                      const SizedBox(height: AgroSpacing.xs),
                      Text(
                        '@${user.username}',
                        style: AgroTypography.bodySecondary,
                      ),
                      const SizedBox(height: AgroSpacing.md),
                      _ProfileRow(label: 'Role', value: user.role),
                      _ProfileRow(
                        label: 'Status',
                        value: user.isActive ? 'Active' : 'Inactive',
                      ),
                      _ProfileRow(
                        label: 'Created',
                        value: dateFormat.format(user.createdAt),
                      ),
                      _ProfileRow(
                        label: 'Updated',
                        value: dateFormat.format(user.updatedAt),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AgroSpacing.lg),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AgroShapes.cardRadius,
                  side: const BorderSide(color: AgroColors.dividerLight),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AgroSpacing.cardPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Warehouses', style: AgroTypography.cardTitle),
                      const SizedBox(height: AgroSpacing.md),
                      if (user.warehouses.isEmpty)
                        const Text(
                          'No assigned warehouses',
                          style: AgroTypography.bodySecondary,
                        )
                      else
                        ...user.warehouses.map(
                          (warehouse) => Padding(
                            padding: const EdgeInsets.only(
                              bottom: AgroSpacing.sm,
                            ),
                            child: Row(
                              children: [
                                const Text(
                                  '• ',
                                  style: AgroTypography.body,
                                ),
                                Expanded(
                                  child: Text(
                                    warehouse.displayCode.isEmpty
                                        ? warehouse.name
                                        : '${warehouse.name} (${warehouse.displayCode})',
                                    style: AgroTypography.body,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AgroSpacing.lg),
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: AgroShapes.cardRadius,
                  side: const BorderSide(color: AgroColors.dividerLight),
                ),
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.edit_outlined),
                      title: const Text('Edit Name'),
                      onTap: () => _showEditNameDialog(context, ref, user.fullName),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: const Icon(Icons.lock_outline),
                      title: const Text('Change Password'),
                      onTap: () => _showChangePasswordDialog(context, ref),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: Icon(
                        Icons.logout,
                        color: AgroColors.critical.text,
                      ),
                      title: Text(
                        'Logout',
                        style: AgroTypography.body.copyWith(
                          color: AgroColors.critical.text,
                        ),
                      ),
                      onTap: () => _confirmLogout(context, ref),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showEditNameDialog(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);
    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Edit Full Name'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: 'Full Name'),
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final newName = controller.text.trim();
                  if (newName.isEmpty) {
                    SnackbarService.showError(
                      dialogContext,
                      'Full name cannot be empty',
                    );
                    return;
                  }
                  try {
                    await ref.read(userRepositoryProvider).updateProfile(newName);
                    refreshProfile(ref);
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    SnackbarService.showSuccess(
                      context,
                      'Profile updated successfully',
                    );
                  } catch (e) {
                    if (dialogContext.mounted) {
                      SnackbarService.showError(
                        dialogContext,
                        e.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  }
                },
                child: const Text('Save'),
              ),
            ],
          ),
    );
  }

  Future<void> _showChangePasswordDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final oldPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    await showDialog<void>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: oldPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Old password'),
                ),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'New password'),
                ),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm new password',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final oldPassword = oldPasswordController.text;
                  final newPassword = newPasswordController.text;
                  final confirmPassword = confirmPasswordController.text;

                  if (newPassword.length < 8) {
                    SnackbarService.showError(
                      dialogContext,
                      'New password must be at least 8 characters long',
                    );
                    return;
                  }
                  if (newPassword != confirmPassword) {
                    SnackbarService.showError(
                      dialogContext,
                      'Password confirmation does not match',
                    );
                    return;
                  }

                  try {
                    await ref
                        .read(userRepositoryProvider)
                        .changePassword(oldPassword, newPassword);
                    if (!dialogContext.mounted) {
                      return;
                    }
                    Navigator.of(dialogContext).pop();
                    SnackbarService.showSuccess(context, 'Password updated');
                  } catch (e) {
                    if (dialogContext.mounted) {
                      SnackbarService.showError(
                        dialogContext,
                        e.toString().replaceAll('Exception: ', ''),
                      );
                    }
                  }
                },
                child: const Text('Update'),
              ),
            ],
          ),
    );
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('Logout'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await ref.read(sessionProvider.notifier).logout();
    }
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AgroSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 72,
            child: Text(label, style: AgroTypography.captionEmphasis),
          ),
          const SizedBox(width: AgroSpacing.sm),
          Expanded(child: Text(value, style: AgroTypography.body)),
        ],
      ),
    );
  }
}
