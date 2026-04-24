import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  // key → SharedPreferences key, label → display name
  static const List<Map<String, String>> _qrSlots = <Map<String, String>>[
    <String, String>{'key': 'qr_gcash', 'label': 'GCash'},
    <String, String>{'key': 'qr_maya', 'label': 'Maya'},
    <String, String>{'key': 'qr_maribank', 'label': 'MariBank'},
    <String, String>{'key': 'qr_other', 'label': 'Other'},
  ];

  final Map<String, String?> _qrPaths = <String, String?>{};
  final Map<String, String> _otherLabels = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadQrPaths();
  }

  Future<void> _loadQrPaths() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      for (final Map<String, String> slot in _qrSlots) {
        _qrPaths[slot['key']!] = prefs.getString('${slot['key']!}_path');
        _otherLabels[slot['key']!] =
            prefs.getString('${slot['key']!}_label') ?? slot['label']!;
      }
      // Migrate legacy single QR
      final String? legacy = prefs.getString('paymentQrPath');
      if (legacy != null && _qrPaths['qr_gcash'] == null) {
        _qrPaths['qr_gcash'] = legacy;
      }
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  Future<void> _pickQr(String key) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (file == null) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString('${key}_path', file.path);
    if (mounted) setState(() => _qrPaths[key] = file.path);
    _showMessage('QR updated');
  }

  Future<void> _removeQr(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('${key}_path');
    if (mounted) setState(() => _qrPaths[key] = null);
    _showMessage('QR removed');
  }

  Future<void> _setOtherLabel(String key) async {
    final TextEditingController ctrl =
        TextEditingController(text: _otherLabels[key] ?? 'Other');
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Payment Method Name'),
        content: TextField(
          controller: ctrl,
          decoration:
              const InputDecoration(hintText: 'e.g. BDO, BPI, Instapay'),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setString('${key}_label', ctrl.text.trim());
              if (mounted) {
                setState(() => _otherLabels[key] = ctrl.text.trim());
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _changeStoreName() async {
    final UserCredential? user = ref.read(authProvider).value?.user;
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
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
                    decoration: const InputDecoration(labelText: 'Current PIN'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: newCtrl,
                    obscureText: true,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'New PIN'),
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

  /// Logout = end PIN session only. Store data & storeId preserved.
  Future<void> _logout() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text(
            'You\'ll be taken to the PIN screen. Your store data stays intact.'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: appColors(context).error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      // Pop ProfileScreen first, then trigger auth change so _AppEntry rebuilds
      Navigator.of(context).pop();
      widget.onLogout();
    }
  }

  /// Sign Out = full reset. Different warning for offline vs Google-linked.
  Future<void> _signOut() async {
    final bool isOffline = ref.read(authProvider).value?.isOfflineMode ?? false;
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) {
        final AppColors c = appColors(ctx);
        return AlertDialog(
          title: Row(children: <Widget>[
            Icon(Icons.warning_amber_rounded, color: c.error),
            const SizedBox(width: 8),
            const Text('Sign Out?'),
          ]),
          content: Text(
            isOffline
                ? '⚠️ OFFLINE ACCOUNT WARNING\n\nSigning out will permanently delete all local data — products, transactions, and settings.\n\nThere is NO cloud backup. This cannot be undone.'
                : 'This will sign you out completely and remove your PIN from this device.\n\nYour products and transaction history are safely backed up in the cloud. Sign back in with the same Google account to restore everything.',
            style: const TextStyle(fontSize: 13),
          ),
          actions: <Widget>[
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: appColors(ctx).error,
                  foregroundColor: Colors.white),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isOffline ? 'Delete & Sign Out' : 'Sign Out'),
            ),
          ],
        );
      },
    );
    if (confirmed == true && mounted) {
      // Pop ProfileScreen first so _AppEntry route transition is clean
      Navigator.of(context).pop();
      await ref.read(authProvider.notifier).signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final AuthState auth = ref.watch(authProvider).value ?? const AuthState();
    final SyncState sync = ref.watch(syncProvider).value ?? const SyncState();

    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── Store card ─────────────────────────────────────────────────
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
                  child: Icon(Icons.store_outlined, color: c.primary, size: 28),
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
                        '${auth.user?.role.toUpperCase() ?? 'OWNER'}${auth.isOfflineMode ? ' · Offline' : ''}',
                        style: TextStyle(color: c.textSecondary, fontSize: 12),
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

          // ── Sync status ────────────────────────────────────────────────
          if (!auth.isOfflineMode) ...<Widget>[
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
                      sync.isOnline
                          ? Icons.cloud_done_outlined
                          : Icons.cloud_off_outlined,
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
                            style: TextStyle(color: c.warning, fontSize: 11)),
                      ),
                  ]),
                  if (sync.lastSyncedAt != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text(
                      'Last sync: ${DateFormat('MMM d, h:mm a').format(sync.lastSyncedAt!)}',
                      style: TextStyle(color: c.textSecondary, fontSize: 12),
                    ),
                  ],
                  if (sync.lastError != null) ...<Widget>[
                    const SizedBox(height: 4),
                    Text('Error: ${sync.lastError}',
                        style: TextStyle(color: c.error, fontSize: 11)),
                  ],
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: sync.isSyncing
                          ? null
                          : () => ref.read(syncProvider.notifier).sync(),
                      icon: sync.isSyncing
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.sync),
                      label: Text(sync.isSyncing ? 'Syncing...' : 'Sync Now'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ] else ...<Widget>[
            // Offline mode notice
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: c.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: c.warning.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: <Widget>[
                  Icon(Icons.wifi_off_rounded, color: c.warning, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Offline mode — data is stored on this device only.',
                      style: TextStyle(color: c.warning, fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── Payment QRs ─────────────────────────────────────────────────
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const ListTile(
                  leading: Icon(Icons.qr_code_2),
                  title: Text('Payment QR Codes',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                      'Customer scans these at checkout. Add GCash, Maya, MariBank, or any bank QR.',
                      style: TextStyle(fontSize: 12)),
                ),
                const Divider(height: 1),
                ...List<Widget>.generate(_qrSlots.length, (int i) {
                  final String key = _qrSlots[i]['key']!;
                  final String defaultLabel = _qrSlots[i]['label']!;
                  final String label = _otherLabels[key] ?? defaultLabel;
                  final String? path = _qrPaths[key];
                  final bool hasQr = path != null && File(path).existsSync();
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      ListTile(
                        dense: true,
                        leading: Icon(
                          hasQr
                              ? Icons.check_circle_outline
                              : Icons.radio_button_unchecked,
                          color: hasQr ? Colors.green : c.textTertiary,
                          size: 20,
                        ),
                        title: Text(label,
                            style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            if (key == 'qr_other')
                              IconButton(
                                onPressed: () => _setOtherLabel(key),
                                icon: const Icon(Icons.edit_outlined, size: 18),
                                tooltip: 'Rename',
                              ),
                            IconButton(
                              onPressed: () => _pickQr(key),
                              icon: Icon(
                                hasQr
                                    ? Icons.swap_horiz
                                    : Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              tooltip: hasQr ? 'Change QR' : 'Upload QR',
                            ),
                            if (hasQr)
                              IconButton(
                                onPressed: () => _removeQr(key),
                                icon: Icon(Icons.delete_outline,
                                    color: c.error, size: 18),
                                tooltip: 'Remove',
                              ),
                          ],
                        ),
                      ),
                      if (hasQr) ...<Widget>[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(File(path),
                                  height: 140, fit: BoxFit.contain),
                            ),
                          ),
                        ),
                      ],
                      if (i < _qrSlots.length - 1) const Divider(height: 1),
                    ],
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // ── Settings tiles ─────────────────────────────────────────────
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
                      final TextEditingController pinCtrl =
                          TextEditingController();
                      await showDialog<void>(
                        context: context,
                        builder: (BuildContext ctx) => AlertDialog(
                          title: const Text('New Cashier PIN'),
                          content: TextField(
                            controller: pinCtrl,
                            obscureText: true,
                            keyboardType: TextInputType.number,
                            decoration:
                                const InputDecoration(labelText: '4-digit PIN'),
                          ),
                          actions: <Widget>[
                            TextButton(
                                onPressed: () => Navigator.pop(ctx),
                                child: const Text('Cancel')),
                            ElevatedButton(
                              onPressed: () async {
                                if (pinCtrl.text.length < 4) return;
                                Navigator.pop(ctx);
                                await ref
                                    .read(authProvider.notifier)
                                    .addCashier(pinCtrl.text);
                                _showMessage('Cashier added!');
                              },
                              style: ElevatedButton.styleFrom(
                                  backgroundColor: c.primary,
                                  foregroundColor: Colors.white),
                              child: const Text('Add'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                ],
                // Logout — session only
                ListTile(
                  leading: Icon(Icons.logout, color: c.error),
                  title: Text('Logout', style: TextStyle(color: c.error)),
                  subtitle: const Text('Returns to PIN screen',
                      style: TextStyle(fontSize: 12)),
                  onTap: _logout,
                ),
                const Divider(height: 1),
                // Sign Out — full reset
                ListTile(
                  leading: Icon(Icons.exit_to_app, color: c.error),
                  title: Text('Sign Out',
                      style: TextStyle(
                          color: c.error, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    auth.isOfflineMode
                        ? '⚠️ Clears all local data permanently'
                        : 'Removes this device — sign back in to restore',
                    style: const TextStyle(fontSize: 12),
                  ),
                  onTap: _signOut,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
