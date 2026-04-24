import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../application/auth_provider.dart';
import '../application/sync_provider.dart';
import '../domain/entities/user_credential.dart';
import '../theme/app_theme.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _changeStoreName() async {
    final UserCredential? user =
        ref.read(authProvider).value?.user;
    final TextEditingController ctrl =
        TextEditingController(text: user?.storeName ?? '');
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Store Name'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(labelText: 'Store Name'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await ref
                  .read(authProvider.notifier)
                  .updateStoreName(ctrl.text.trim());
              _showMessage('Store name updated');
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: appColors(ctx).primary,
                foregroundColor: Colors.white),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changePin() async {
    final TextEditingController oldCtrl = TextEditingController();
    final TextEditingController newCtrl = TextEditingController();
    final TextEditingController confirmCtrl = TextEditingController();
    String? error;

    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (_, StateSetter setS) {
            return AlertDialog(
              title: const Text('Change PIN'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  TextField(
                    controller: oldCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Current PIN'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'New PIN'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: confirmCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration:
                        const InputDecoration(labelText: 'Confirm New PIN'),
                  ),
                  if (error != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(error!,
                        style: TextStyle(
                            color: appColors(ctx).error, fontSize: 12)),
                  ],
                ],
              ),
              actions: <Widget>[
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    final UserCredential? user =
                        ref.read(authProvider).value?.user;
                    if (user == null) return;
                    if (hashPin(oldCtrl.text) != user.pinHash) {
                      setS(() => error = 'Current PIN is wrong');
                      return;
                    }
                    if (newCtrl.text.length < 4) {
                      setS(() => error = 'PIN must be at least 4 digits');
                      return;
                    }
                    if (newCtrl.text != confirmCtrl.text) {
                      setS(() => error = 'PINs do not match');
                      return;
                    }
                    Navigator.pop(ctx);
                    await ref
                        .read(authProvider.notifier)
                        .changePin(newCtrl.text);
                    _showMessage('PIN changed successfully');
                  },
                  style: ElevatedButton.styleFrom(
                      backgroundColor: appColors(ctx).primary,
                      foregroundColor: Colors.white),
                  child: const Text('Change'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final AuthState auth =
        ref.watch(authProvider).value ?? const AuthState();
    final SyncState sync =
        ref.watch(syncProvider).value ?? const SyncState();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // User card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 28,
                  backgroundColor: c.primary.withValues(alpha: 0.15),
                  child: Icon(Icons.store_outlined,
                      color: c.primary, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        auth.user?.storeName ?? 'My Store',
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      Text(
                        auth.user?.role.toUpperCase() ?? 'OWNER',
                        style: TextStyle(
                            color: c.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _changeStoreName,
                  icon: Icon(Icons.edit_outlined, color: c.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sync status card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: c.border),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(children: <Widget>[
                  Icon(
                    sync.isOnline ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                    color: sync.isOnline ? c.info : c.textTertiary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    sync.isOnline ? 'Online' : 'Offline',
                    style: TextStyle(
                      color: sync.isOnline ? c.info : c.textTertiary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  if (sync.pendingCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: c.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('${sync.pendingCount} pending',
                          style: TextStyle(
                              color: c.warning, fontSize: 11)),
                    ),
                ]),
                if (sync.lastSyncedAt != null) ...<Widget>[
                  const SizedBox(height: 4),
                  Text(
                    'Last sync: ${DateFormat('MMM d, h:mm a').format(sync.lastSyncedAt!)}',
                    style:
                        TextStyle(color: c.textSecondary, fontSize: 12),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: sync.isSyncing
                        ? null
                        : () =>
                            ref.read(syncProvider.notifier).sync(),
                    icon: sync.isSyncing
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2))
                        : const Icon(Icons.sync),
                    label:
                        Text(sync.isSyncing ? 'Syncing...' : 'Sync Now'),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Settings
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Change PIN'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _changePin,
                ),
                const Divider(height: 1),
                if (auth.user?.role == 'owner') ...<Widget>[
                  ListTile(
                    leading: const Icon(Icons.person_add_alt_1_outlined),
                    title: const Text('Add Cashier'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () async {
                      final TextEditingController pinCtrl = TextEditingController();
                      await showDialog<void>(
                        context: context,
                        builder: (BuildContext ctx) => AlertDialog(
                          title: const Text('New Cashier PIN'),
                          content: TextField(
                            controller: pinCtrl,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: '4-digit PIN'),
                          ),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Cancel'),
                            ),
                            ElevatedButton(
                              onPressed: () async {
                                if (pinCtrl.text.length < 4) return;
                                Navigator.pop(ctx);
                                await ref.read(authProvider.notifier).addCashier(pinCtrl.text);
                                _showMessage('Cashier added successfully!');
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary, foregroundColor: Colors.white),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
                ListTile(
                  leading: Icon(Icons.logout, color: c.error),
                  title: Text('Logout',
                      style: TextStyle(color: c.error)),
                  onTap: () async {
                    final bool? confirmed = await showDialog<bool>(
                      context: context,
                      builder: (_) => AlertDialog(
                        title: const Text('Logout?'),
                        content: const Text(
                            'Are you sure you want to log out?'),
                        actions: <Widget>[
                          TextButton(
                              onPressed: () =>
                                  Navigator.pop(context, false),
                              child: const Text('Cancel')),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                                backgroundColor: c.error,
                                foregroundColor: Colors.white),
                            onPressed: () =>
                                Navigator.pop(context, true),
                            child: const Text('Logout'),
                          ),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      widget.onLogout();
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
