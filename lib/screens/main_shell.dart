import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';
import 'analytics_screen.dart';
import 'inventory_screen.dart';
import 'listahan_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'scanner_screen.dart';
import 'transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({
    super.key,
    required this.onToggleTheme,
    required this.onLogout,
  });

  final VoidCallback onToggleTheme;
  final VoidCallback onLogout;

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);

    final List<Widget> tabs = <Widget>[
      const ScannerScreen(),
      const ListahanScreen(),
      const InventoryScreen(),
      AnalyticsScreen(
        onOpenTransactions: () {
          Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const TransactionsScreen()),
          );
        },
      ),
    ];

    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/sare_logo.png',
          height: 42,
          fit: BoxFit.contain,
        ),
        actions: <Widget>[
          _HeaderActionButton(
            tooltip: 'Theme',
            icon: Theme.of(context).brightness == Brightness.dark
                ? Icons.wb_sunny_outlined
                : Icons.nightlight_outlined,
            iconColor: c.primary,
            onTap: widget.onToggleTheme,
          ),
          _HeaderActionButton(
            tooltip: 'Notifications',
            icon: Icons.notifications_none_rounded,
            iconColor: c.warning,
            showDot: true,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const NotificationsScreen(),
              ),
            ),
          ),
          _HeaderActionButton(
            tooltip: 'Profile',
            icon: Icons.account_circle_outlined,
            iconColor: c.primary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ProfileScreen(onLogout: widget.onLogout),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: LiquidBackground(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          transitionBuilder: (Widget child, Animation<double> animation) {
            final Animation<Offset> offset = Tween<Offset>(
              begin: const Offset(0.02, 0),
              end: Offset.zero,
            ).animate(animation);
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(position: offset, child: child),
            );
          },
          child: KeyedSubtree(key: ValueKey<int>(_index), child: tabs[_index]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int value) => setState(() => _index = value),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.qr_code_scanner_outlined),
            selectedIcon: Icon(Icons.qr_code_scanner),
            label: 'Scanner',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'Credits',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
        ],
      ),
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
