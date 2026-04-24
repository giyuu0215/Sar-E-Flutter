import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../application/locale_provider.dart';
import '../theme/app_theme.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _lowStockAlerts = true;
  bool _overdueAlerts = true;

  @override
  void initState() {
    super.initState();
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _lowStockAlerts = prefs.getBool('notif_low_stock') ?? true;
      _overdueAlerts = prefs.getBool('notif_overdue') ?? true;
    });
  }

  Future<void> _setBool(String key, bool value) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final AppLocale locale = ref.watch(localeProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t(locale, 'settings'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          // ── Language ──────────────────────────────────────────────────
          Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.translate),
                  title: Text(t(locale, 'language'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    locale == AppLocale.fil ? 'Filipino (Taglish)' : 'English',
                    style: const TextStyle(fontSize: 12),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: SegmentedButton<AppLocale>(
                    segments: const <ButtonSegment<AppLocale>>[
                      ButtonSegment<AppLocale>(
                        value: AppLocale.fil,
                        label: Text('Filipino'),
                        icon: Icon(Icons.flag),
                      ),
                      ButtonSegment<AppLocale>(
                        value: AppLocale.en,
                        label: Text('English'),
                        icon: Icon(Icons.language),
                      ),
                    ],
                    selected: <AppLocale>{locale},
                    onSelectionChanged: (Set<AppLocale> sel) {
                      ref.read(localeProvider.notifier).setLocale(sel.first);
                    },
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith(
                          (Set<WidgetState> states) {
                        if (states.contains(WidgetState.selected)) {
                          return c.primary.withValues(alpha: 0.12);
                        }
                        return null;
                      }),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── Notification Settings ─────────────────────────────────────
          Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: const Icon(Icons.notifications_outlined),
                  title: Text(t(locale, 'notification_settings'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(t(locale, 'low_stock_alerts')),
                  subtitle: Text(
                    locale == AppLocale.fil
                        ? 'Mag-alerto kapag mababa na ang stock ng produkto'
                        : 'Alert when product stock is low',
                    style: const TextStyle(fontSize: 12),
                  ),
                  secondary: Icon(Icons.inventory_2_outlined, color: c.warning),
                  value: _lowStockAlerts,
                  onChanged: (bool v) {
                    setState(() => _lowStockAlerts = v);
                    _setBool('notif_low_stock', v);
                  },
                ),
                const Divider(height: 1),
                SwitchListTile(
                  title: Text(t(locale, 'overdue_alerts')),
                  subtitle: Text(
                    locale == AppLocale.fil
                        ? 'Mag-alerto kapag overdue na ang utang ng customer'
                        : 'Alert when a credit entry is past due',
                    style: const TextStyle(fontSize: 12),
                  ),
                  secondary: Icon(Icons.schedule_outlined, color: c.error),
                  value: _overdueAlerts,
                  onChanged: (bool v) {
                    setState(() => _overdueAlerts = v);
                    _setBool('notif_overdue', v);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 12),

          // ── About ────────────────────────────────────────────────────
          const Card(
            child: Column(
              children: <Widget>[
                ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text('About Sar-E'),
                  subtitle:
                      Text('Version 1.0.0', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
