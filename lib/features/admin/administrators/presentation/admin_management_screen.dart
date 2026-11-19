// lib/features/admin/administrators/presentation/admin_management_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/app_exception.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/skeleton_list.dart';
import '../../../../data/models/app_user.dart';
import '../../../../data/models/enums.dart';
import '../../../../data/repositories/admin_repository.dart';
import '../providers/admin_management_providers.dart';

class AdminManagementScreen extends ConsumerStatefulWidget {
  const AdminManagementScreen({super.key});

  @override
  ConsumerState<AdminManagementScreen> createState() =>
      _AdminManagementScreenState();
}

class _AdminManagementScreenState extends ConsumerState<AdminManagementScreen> {
  String? _lastActionResultMessage;

  void _showAddAdminDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _AddAdminDialog(
        onSuccess: (message) {
          setState(() {
            _lastActionResultMessage = message;
          });
        },
      ),
    );
  }

  Future<void> _handleRevoke(AppUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Revoke Admin Access?'),
        content: Text(
          'Are you sure you want to revoke administrative access for '
          '${user.email ?? user.name ?? user.id}? '
          'They will be downgraded to a standard user.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Revoke'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(adminActionControllerProvider.notifier).revokeAdmin(
            email: user.email,
            uid: user.id,
          );

      if (!mounted) return;
      final msg = 'Administrator access revoked for ${user.email ?? user.id}. '
          'The user must sign out and sign back in for the changes to take effect; '
          'the app refreshes the token with getIdToken(true) on next start.';

      setState(() {
        _lastActionResultMessage = msg;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      _showErrorDialog(e);
    }
  }

  void _showErrorDialog(Object error) {
    final message = error is AppException
        ? error.message
        : error.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.error_outline, color: Theme.of(ctx).colorScheme.error),
            const SizedBox(width: AppSpacing.sm),
            const Text('Action Blocked'),
          ],
        ),
        content: Text(message),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final adminsAsync = ref.watch(administratorsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Administrator Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add_outlined),
            tooltip: 'Add Administrator',
            onPressed: () => _showAddAdminDialog(context),
          ),
        ],
      ),
      body: Column(
        children: [
          // Informational banner about token refresh
          if (_lastActionResultMessage != null)
            Container(
              margin: const EdgeInsets.all(AppSpacing.md),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer.withOpacity(0.4),
                borderRadius: BorderRadius.circular(AppRadius.md),
                border: Border.all(
                  color: theme.colorScheme.primary.withOpacity(0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      _lastActionResultMessage!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () {
                      setState(() {
                        _lastActionResultMessage = null;
                      });
                    },
                    tooltip: 'Dismiss',
                  ),
                ],
              ),
            ),

          Expanded(
            child: adminsAsync.when(
              loading: () => const SkeletonList(itemCount: 4),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 48,
                        color: theme.colorScheme.error,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Failed to load administrators',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Text(
                        err.toString(),
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      AppButton.secondary(
                        label: 'Retry',
                        onPressed: () =>
                            ref.invalidate(administratorsStreamProvider),
                      ),
                    ],
                  ),
                ),
              ),
              data: (admins) {
                if (admins.isEmpty) {
                  return EmptyStateWidget(
                    title: 'No Administrators Found',
                    subtitle:
                        'Add administrators by email using the button below.',
                    icon: Icons.admin_panel_settings_outlined,
                    actionLabel: 'Add Administrator',
                    onAction: () => _showAddAdminDialog(context),
                  );
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  itemCount: admins.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (context, index) {
                    final admin = admins[index];
                    return _AdminUserCard(
                      user: admin,
                      onRevoke: () => _handleRevoke(admin),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddAdminDialog(context),
        icon: const Icon(Icons.add),
        label: const Text('Add by Email'),
      ),
    );
  }
}

class _AdminUserCard extends StatelessWidget {
  const _AdminUserCard({
    required this.user,
    required this.onRevoke,
  });

  final AppUser user;
  final VoidCallback onRevoke;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSuper = user.role == UserRole.superAdmin;
    final initials =
        (user.name ?? user.email ?? 'A').trim().substring(0, 1).toUpperCase();

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.md),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: isSuper
                  ? theme.colorScheme.primaryContainer
                  : theme.colorScheme.secondaryContainer,
              foregroundColor: isSuper
                  ? theme.colorScheme.onPrimaryContainer
                  : theme.colorScheme.onSecondaryContainer,
              child: Text(
                initials,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          user.name ?? user.email ?? 'Unknown User',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      _RoleBadge(role: user.role),
                    ],
                  ),
                  if (user.email != null && user.name != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.email!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    user.createdAt != null
                        ? 'Added: ${_formatDate(user.createdAt!)}'
                        : 'UID: ${user.id}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.remove_circle_outline),
              color: theme.colorScheme.error,
              tooltip: 'Revoke Admin Access',
              onPressed: onRevoke,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) {
    final isSuper = role == UserRole.superAdmin;
    final theme = Theme.of(context);

    final bg = isSuper
        ? theme.colorScheme.primaryContainer
        : theme.colorScheme.secondaryContainer;
    final fg = isSuper
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSecondaryContainer;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AppRadius.xs),
      ),
      child: Text(
        isSuper ? 'SUPER_ADMIN' : 'ADMIN',
        style: TextStyle(
          color: fg,
          fontSize: 10,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _AddAdminDialog extends ConsumerStatefulWidget {
  const _AddAdminDialog({required this.onSuccess});

  final ValueChanged<String> onSuccess;

  @override
  ConsumerState<_AddAdminDialog> createState() => _AddAdminDialogState();
}

class _AddAdminDialogState extends ConsumerState<_AddAdminDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _selectedRole = 'ADMIN';
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final email = _emailController.text.trim();
      await ref.read(adminRepositoryProvider).setUserRole(
            email: email,
            role: _selectedRole,
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      final successMsg =
          'User $email has been granted $_selectedRole privileges. '
          'Note: The affected user must re-login to activate new permissions. '
          'The app refreshes tokens with getIdToken(true) on next start.';

      widget.onSuccess(successMsg);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(successMsg),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 6),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e is AppException
          ? e.message
          : e.toString().replaceFirst(RegExp(r'^Exception:\s*'), '');
      setState(() {
        _errorMessage = msg;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Add Administrator by Email'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter the email address of the existing user to grant administrative access.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'User Email',
                  hintText: 'user@company.com',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email is required';
                  }
                  final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
                  if (!emailRegex.hasMatch(val.trim())) {
                    return 'Please enter a valid email address';
                  }
                  return null;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                'Role Assignment',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              DropdownButtonFormField<String>(
                initialValue: _selectedRole,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.security_outlined),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ADMIN',
                    child: Text('ADMIN — Regular Admin'),
                  ),
                  DropdownMenuItem(
                    value: 'SUPER_ADMIN',
                    child: Text('SUPER_ADMIN — Full System Access'),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _selectedRole = val;
                    });
                  }
                },
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: AppSpacing.md),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(AppRadius.xs),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: theme.colorScheme.onErrorContainer,
                        size: 18,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: theme.colorScheme.onErrorContainer,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _submit,
          child: _isLoading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Assign Role'),
        ),
      ],
    );
  }
}
