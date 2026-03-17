import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/navigation/create_result.dart';
import '../core/session/session_controller.dart';
import '../models/user_read.dart';
import '../providers/user_provider.dart';
import '../ui/theme/agro_colors.dart';
import '../ui/theme/agro_shapes.dart';
import '../ui/theme/agro_spacing.dart';
import '../ui/theme/agro_typography.dart';
import '../ui/widgets/agro_error_state.dart';

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
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final result = await context.push<CreateResult>('/admin/users/create');
          if (result == CreateResult.created) {
            ref.invalidate(userListProvider);
          }
        },
        child: const Icon(Icons.add),
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
                            onTap: () async {
                              final result = await context.push<CreateResult>(
                                '/admin/users/edit',
                                extra: user,
                              );
                              if (result == CreateResult.created) {
                                ref.invalidate(userListProvider);
                              }
                            },
                          );
                        },
                      ),
            ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  final UserRead user;
  final bool isSelf;
  final VoidCallback onTap;

  const _UserCard({
    required this.user,
    required this.isSelf,
    required this.onTap,
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
        onTap: onTap,
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
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }
}
