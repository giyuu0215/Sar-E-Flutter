import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  // Default fixed slots — always present, only 'other_N' slots are deletable
  static const List<Map<String, String>> _defaultSlots = <Map<String, String>>[
    <String, String>{'key': 'qr_gcash', 'label': 'GCash'},
    <String, String>{'key': 'qr_maya', 'label': 'Maya'},
    <String, String>{'key': 'qr_maribank', 'label': 'MariBank'},
  ];

  // Mutable list — default slots + dynamically added ones
  List<Map<String, String>> _qrSlots = <Map<String, String>>[];
  // key → decoded QR data string (from scanning the uploaded image)
  final Map<String, String?> _qrData = <String, String?>{};
  // key → display label
  final Map<String, String> _labels = <String, String>{};

  @override
  void initState() {
    super.initState();
    _loadQrData();
  }

  Future<void> _loadQrData() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    // Load dynamic extra slots (stored as 'qr_extra_count' + 'qr_extra_N_key')
    final int extraCount = prefs.getInt('qr_extra_count') ?? 0;
    final List<Map<String, String>> slots = <Map<String, String>>[
      ..._defaultSlots,
      for (int i = 0; i < extraCount; i++)
        <String, String>{
          'key': 'qr_extra_$i',
          'label': prefs.getString('qr_extra_${i}_label') ?? 'Other ${i + 1}',
        },
    ];

    final Map<String, String?> data = <String, String?>{};
    final Map<String, String> labels = <String, String>{};
    for (final Map<String, String> slot in slots) {
      final String k = slot['key']!;
      // Try new decoded-data key first, fall back to legacy path for migration
      data[k] = prefs.getString('${k}_qrdata');
      labels[k] = prefs.getString('${k}_label') ?? slot['label']!;
    }

    setState(() {
      _qrSlots = slots;
      _qrData.addAll(data);
      _labels.addAll(labels);
    });
  }

  void _showMessage(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
    );
  }

  /// Pick QR image → auto-scan to extract QR data → store decoded string
  Future<void> _pickQr(String key) async {
    final ImagePicker picker = ImagePicker();
    final XFile? file =
        await picker.pickImage(source: ImageSource.gallery, imageQuality: 95);
    if (file == null) return;

    _showMessage('Scanning QR from image…');

    // Use mobile_scanner to decode the QR from the image file
    String? decoded;
    try {
      final MobileScannerController ctrl = MobileScannerController();
      final BarcodeCapture? capture = await ctrl.analyzeImage(file.path);
      await ctrl.dispose();
      decoded = capture?.barcodes.firstOrNull?.rawValue;
    } catch (e) {
      debugPrint('QR scan from image failed: $e');
    }

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (decoded != null && decoded.isNotEmpty) {
      await prefs.setString('${key}_qrdata', decoded);
      if (mounted) {
        setState(() => _qrData[key] = decoded);
        _showMessage('QR scanned & saved ✅');
      }
    } else {
      // Fallback: store image path as raw data for display
      await prefs.setString('${key}_qrdata', 'IMAGE:${file.path}');
      if (mounted) {
        setState(() => _qrData[key] = 'IMAGE:${file.path}');
        _showMessage('Could not decode QR — image saved as-is');
      }
    }
  }

  Future<void> _removeQr(String key) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('${key}_qrdata');
    if (mounted) setState(() => _qrData[key] = null);
    _showMessage('QR removed');
  }

  Future<void> _renameSlot(String key) async {
    final TextEditingController ctrl =
        TextEditingController(text: _labels[key] ?? 'Other');
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
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              await prefs.setString('${key}_label', ctrl.text.trim());
              if (mounted) setState(() => _labels[key] = ctrl.text.trim());
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _addQrSlot() async {
    final TextEditingController ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('Add Payment Option'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Name',
            hintText: 'e.g. BDO, BPI, Palawan, Instapay',
          ),
        ),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final String name = ctrl.text.trim();
              if (name.isEmpty) return;
              Navigator.pop(ctx);
              final SharedPreferences prefs =
                  await SharedPreferences.getInstance();
              final int count = prefs.getInt('qr_extra_count') ?? 0;
              final String newKey = 'qr_extra_$count';
              await prefs.setInt('qr_extra_count', count + 1);
              await prefs.setString('${newKey}_label', name);
              if (mounted) {
                setState(() {
                  _qrSlots.add(<String, String>{
                    'key': newKey,
                    'label': name,
                  });
                  _qrData[newKey] = null;
                  _labels[newKey] = name;
                });
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSlot(String key) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove slot?'),
        content: Text('Remove "${_labels[key]}" payment option?'),
        actions: <Widget>[
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: appColors(context).error,
                foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('${key}_qrdata');
    await prefs.remove('${key}_label');
    if (mounted) {
      setState(() {
        _qrSlots.removeWhere((Map<String, String> s) => s['key'] == key);
        _qrData.remove(key);
        _labels.remove(key);
      });
    }
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
      appBar: AppBar(title: const Text('Profile')),
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
                  Row(children: <Widget>[
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sync.isSyncing
                            ? null
                            : () => ref.read(syncProvider.notifier).sync(),
                        icon: sync.isSyncing
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2))
                            : const Icon(Icons.sync),
                        label: Text(sync.isSyncing ? 'Syncing...' : 'Sync Now'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: sync.isSyncing
                            ? null
                            : () async {
                                final bool? ok = await showDialog<bool>(
                                  context: context,
                                  builder: (BuildContext ctx) => AlertDialog(
                                    title: const Text('Force Full Sync'),
                                    content: const Text(
                                      'This will re-upload ALL local data to the cloud. '
                                      'Use this if your cloud data is missing or out of date.',
                                    ),
                                    actions: <Widget>[
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, false),
                                          child: const Text('Cancel')),
                                      ElevatedButton(
                                          onPressed: () =>
                                              Navigator.pop(ctx, true),
                                          child: const Text('Force Sync')),
                                    ],
                                  ),
                                );
                                if (ok == true) {
                                  ref
                                      .read(syncProvider.notifier)
                                      .forceFullSync();
                                }
                              },
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Full Sync'),
                      ),
                    ),
                  ]),
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
                ListTile(
                  leading: const Icon(Icons.qr_code_2),
                  title: const Text('Payment QR Codes',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: const Text(
                      'Upload your GCash/Maya/bank QR — Sar-E auto-regenerates it in brand colors.',
                      style: TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    onPressed: _addQrSlot,
                    icon: const Icon(Icons.add_circle_outline),
                    tooltip: 'Add payment option',
                  ),
                ),
                const Divider(height: 1),
                ...List<Widget>.generate(_qrSlots.length, (int i) {
                  final String key = _qrSlots[i]['key']!;
                  final String label = _labels[key] ?? _qrSlots[i]['label']!;
                  final String? data = _qrData[key];
                  final bool hasQr = data != null &&
                      data.isNotEmpty &&
                      !data.startsWith('IMAGE:');
                  final bool hasImage =
                      data != null && data.startsWith('IMAGE:');
                  final bool isDeletable = key.startsWith('qr_extra_');
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
                            style:
                                const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            IconButton(
                              onPressed: () => _renameSlot(key),
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              tooltip: 'Rename',
                            ),
                            IconButton(
                              onPressed: () => _pickQr(key),
                              icon: Icon(
                                hasQr || hasImage
                                    ? Icons.swap_horiz
                                    : Icons.add_photo_alternate_outlined,
                                size: 18,
                              ),
                              tooltip: hasQr ? 'Change QR' : 'Upload QR',
                            ),
                            if (hasQr || hasImage)
                              IconButton(
                                onPressed: () => _removeQr(key),
                                icon: Icon(Icons.delete_outline,
                                    color: c.error, size: 18),
                                tooltip: 'Remove QR',
                              ),
                            if (isDeletable)
                              IconButton(
                                onPressed: () => _deleteSlot(key),
                                icon: Icon(Icons.remove_circle_outline,
                                    color: c.error, size: 18),
                                tooltip: 'Delete slot',
                              ),
                          ],
                        ),
                      ),
                      // Show regenerated QR if we have decoded data
                      if (hasQr) ...<Widget>[
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                            child: Column(
                              children: <Widget>[
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: c.primary.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                        color:
                                            c.primary.withValues(alpha: 0.25)),
                                  ),
                                  child: SizedBox(
                                    width: 160,
                                    height: 160,
                                    child: QrImageView(
                                      data: data,
                                      version: QrVersions.auto,
                                      size: 160,
                                      backgroundColor: Colors.transparent,
                                      eyeStyle: QrEyeStyle(
                                        eyeShape: QrEyeShape.square,
                                        color: c.primaryDark,
                                      ),
                                      dataModuleStyle: QrDataModuleStyle(
                                        dataModuleShape:
                                            QrDataModuleShape.square,
                                        color: c.primaryDark,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Regenerated from your $label QR',
                                  style: TextStyle(
                                      color: c.textTertiary, fontSize: 11),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ] else if (hasImage) ...<Widget>[
                        // Fallback: show original image if QR couldn't be decoded
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                            child: Column(
                              children: <Widget>[
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(File(data.substring(6)),
                                      height: 140, fit: BoxFit.contain),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'QR could not be auto-decoded — showing image',
                                  style:
                                      TextStyle(color: c.warning, fontSize: 11),
                                ),
                              ],
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
