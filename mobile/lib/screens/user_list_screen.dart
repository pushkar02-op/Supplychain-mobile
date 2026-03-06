import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/user_read.dart';
import '../core/session/session_controller.dart';
import '../providers/user_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_error_state.dart';
import '../ui/widgets/agro_snack_bar.dart';

class UserListScreen extends ConsumerWidget {
  const UserListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(userListProvider);
    final currentUserId = ref.watch(
      sessionProvider.select((session) => session.userId),
    );

    return Scaffold(
      backgroundColor: AgroColors.background,
      appBar: AppBar(
        title: const Text('User Management'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 1,
      ),
      body: stateAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (err, _) => AgroErrorState.loadFailed(
              message: err.toString(),
              onRetry: () => ref.read(userListProvider.notifier).refresh(),
            ),
        data:
            (state) => RefreshIndicator(
              onRefresh: () => ref.read(userListProvider.notifier).refresh(),
              child:
                  state.users.isEmpty
                      ? const Center(child: Text('No users found'))
                      : ListView.builder(
                        padding: const EdgeInsets.all(
                          AgroSpacing.screenPadding,
                        ),
                        itemCount: state.users.length,
                        itemBuilder: (context, index) {
                          final user = state.users[index];
                          return _UserCard(
                            user: user,
                            isSelf: user.id == currentUserId,
                            onRoleChange:
                                () => _showRoleSheet(context, ref, user),
                            onDeactivate:
                                () => _confirmDeactivate(
                                  context,
                                  ref,
                                  user,
                                  currentUserId,
                                ),
                          );
                        },
                      ),
            ),
      ),
    );
  }

  void _showRoleSheet(BuildContext context, WidgetRef ref, UserRead user) {
    String selectedRole = user.role;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (ctx) => StatefulBuilder(
            builder:
                (ctx, setSheetState) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Update Role for ${user.fullName}',
                        style: AgroTypography.sectionTitle,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        value: selectedRole,
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'OWNER',
                            child: Text('Owner'),
                          ),
                          DropdownMenuItem(
                            value: 'MANAGER',
                            child: Text('Manager'),
                          ),
                          DropdownMenuItem(
                            value: 'WORKER',
                            child: Text('Worker'),
                          ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setSheetState(() => selectedRole = v);
                          }
                        },
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton(
                          onPressed:
                              selectedRole == user.role
                                  ? null
                                  : () async {
                                    Navigator.pop(ctx);
                                    try {
                                      await ref
                                          .read(userListProvider.notifier)
                                          .updateRole(user.id, selectedRole);
                                      if (context.mounted) {
                                        AgroSnackBar.success(
                                          context,
                                          'Role updated to $selectedRole',
                                        );
                                      }
                                    } catch (e) {
                                      if (context.mounted) {
                                        AgroSnackBar.error(
                                          context,
                                          'Failed to update role: $e',
                                        );
                                      }
                                    }
                                  },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AgroColors.primary,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Update Role'),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
          ),
    );
  }

  void _confirmDeactivate(
    BuildContext context,
    WidgetRef ref,
    UserRead user,
    int? currentUserId,
  ) {
    // Self-deactivation guard
    if (user.id == currentUserId) {
      showDialog(
        context: context,
        builder:
            (ctx) => AlertDialog(
              title: const Text('Not Allowed'),
              content: const Text('You cannot deactivate your own account.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('OK'),
                ),
              ],
            ),
      );
      return;
    }

    showDialog(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Deactivate User'),
            content: Text(
              'Are you sure you want to deactivate "${user.fullName}" (${user.username})?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await ref
                        .read(userListProvider.notifier)
                        .deactivateUser(user.id);
                    if (context.mounted) {
                      AgroSnackBar.success(context, 'User deactivated');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      AgroSnackBar.error(context, 'Failed to deactivate: $e');
                    }
                  }
                },
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Deactivate'),
              ),
            ],
          ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserRead user;
  final bool isSelf;
  final VoidCallback onRoleChange;
  final VoidCallback onDeactivate;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.onRoleChange,
    required this.onDeactivate,
  });

  @override
  Widget build(BuildContext context) {
    final roleColor = switch (user.role) {
      'OWNER' => AgroColors.adminAccent,
      'MANAGER' => Colors.blue,
      _ => Colors.grey,
    };

    return Card(
      margin: const EdgeInsets.only(bottom: AgroSpacing.sm),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AgroShapes.cardRadius,
        side: BorderSide(
          color: user.isActive ? AgroColors.dividerLight : Colors.red.shade200,
        ),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: roleColor.withValues(alpha: 0.15),
          child: Text(
            user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
            style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
          ),
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                user.fullName,
                style: AgroTypography.cardTitle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (isSelf)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AgroColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(
                    fontSize: 10,
                    color: AgroColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Row(
          children: [
            Text(user.username, style: AgroTypography.cardSubtitle),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: roleColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                user.role,
                style: TextStyle(
                  fontSize: 11,
                  color: roleColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!user.isActive) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'INACTIVE',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) {
            if (action == 'role') onRoleChange();
            if (action == 'deactivate') onDeactivate();
          },
          itemBuilder:
              (_) => [
                const PopupMenuItem(value: 'role', child: Text('Change Role')),
                if (user.isActive)
                  const PopupMenuItem(
                    value: 'deactivate',
                    child: Text(
                      'Deactivate',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
              ],
        ),
      ),
    );
  }
}
