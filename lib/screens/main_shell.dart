import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_provider.dart';
import '../application/analytics_provider.dart';
import '../application/inventory_provider.dart';
import '../application/listahan_provider.dart';
import '../application/locale_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';
import 'analytics_screen.dart';
import 'inventory_screen.dart';
import 'listahan_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';
import 'settings_screen.dart';
import 'transactions_screen.dart';

class MainShell extends ConsumerStatefulWidget {
  const MainShell({super.key});

  @override
  ConsumerState<MainShell> createState() => _MainShellState();
}

class _MainShellState extends ConsumerState<MainShell> {
  int _index = 0;

  void _logout() {
    // Pop all pushed routes (e.g. ProfileScreen) before state changes,
    // otherwise the old stack persists on top of the new LoginScreen.
    Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
    ref.read(authProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);

    final AuthState auth = ref.watch(authProvider).value ?? const AuthState();
    final bool isOwner = auth.user?.role == 'owner';
    final AppLocale locale = ref.watch(localeProvider);

    // Calculate total alerts
    final invAsync = ref.watch(inventoryProvider);
    final listAsync = ref.watch(listahanProvider);
    final int lowStock =
        invAsync.value?.products.where((p) => p.isLowStock).length ?? 0;
    final int overdue =
        listAsync.value?.entries.where((e) => e.isOverdue).length ?? 0;
    final bool hasAlerts = (lowStock + overdue) > 0;

    final List<Widget> tabs = isOwner
        ? <Widget>[
            const ScannerScreen(),
            const ListahanScreen(),
            const InventoryScreen(),
            AnalyticsScreen(
              onOpenTransactions: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                      builder: (_) => const TransactionsScreen()),
                );
              },
            ),
          ]
        : <Widget>[
            const ScannerScreen(), // Cashiers ONLY see POS
          ];

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/sare_logo.png',
          height: 42,
          fit: BoxFit.contain,
        ),
        actions: <Widget>[
          if (isOwner)
            _HeaderActionButton(
              tooltip: 'Notifications',
              icon: Icons.notifications_none_rounded,
              iconColor: c.warning,
              showDot: hasAlerts,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const NotificationsScreen(),
                ),
              ),
            ),
          _HeaderActionButton(
            tooltip: 'Settings',
            icon: Icons.settings_outlined,
            iconColor: c.textSecondary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
          _HeaderActionButton(
            tooltip: t(locale, 'profile'),
            icon: Icons.account_circle_outlined,
            iconColor: c.primary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(onLogout: _logout),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: LiquidBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          transitionBuilder: (Widget child, Animation<double> animation) {
            return FadeTransition(
              opacity: animation,
              child: child,
            );
          },
          child: KeyedSubtree(key: ValueKey<int>(_index), child: tabs[_index]),
        ),
      ),
      bottomNavigationBar: isOwner
          ? NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (int value) {
                setState(() => _index = value);
                // Force analytics to reload whenever the tab is opened
                if (value == 3) {
                  ref.invalidate(analyticsProvider);
                }
              },
              destinations: <NavigationDestination>[
                NavigationDestination(
                  icon: const Icon(Icons.point_of_sale_outlined),
                  selectedIcon: const Icon(Icons.point_of_sale),
                  label: t(locale, 'tab_pos'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.menu_book_outlined),
                  selectedIcon: const Icon(Icons.menu_book),
                  label: t(locale, 'tab_listahan'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.inventory_2_outlined),
                  selectedIcon: const Icon(Icons.inventory_2),
                  label: t(locale, 'tab_inventory'),
                ),
                NavigationDestination(
                  icon: const Icon(Icons.analytics_outlined),
                  selectedIcon: const Icon(Icons.analytics),
                  label: t(locale, 'tab_analytics'),
                ),
              ],
            )
          : null, // Cashier has no bottom nav since they only have 1 screen
    );
  }
}

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    required this.tooltip,
    required this.icon,
    required this.iconColor,
    required this.onTap,
    this.showDot = false,
  });

  final String tooltip;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;
  final bool showDot;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Tooltip(
        message: tooltip,
        child: Stack(
          clipBehavior: Clip.none,
          children: <Widget>[
            IconButton.filledTonal(
              onPressed: onTap,
              icon: Icon(icon, size: 18, color: iconColor),
              style: IconButton.styleFrom(
                backgroundColor: c.surfaceMuted,
                foregroundColor: iconColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            if (showDot)
              Positioned(
                top: 5,
                right: 5,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: c.error,
                    shape: BoxShape.circle,
                    border: Border.all(color: c.surface, width: 1.25),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
