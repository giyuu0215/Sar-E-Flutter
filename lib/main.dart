import 'package:flutter/material.dart';
import 'package:dynamic_color/dynamic_color.dart';

import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'theme/app_theme.dart';

void main() {
  runApp(const SariFigmaApp());
}

class SariFigmaApp extends StatefulWidget {
  const SariFigmaApp({super.key});

  @override
  State<SariFigmaApp> createState() => _SariFigmaAppState();
}

class _SariFigmaAppState extends State<SariFigmaApp> {
  bool _loggedIn = false;
  bool _showSplash = true;

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp(
          debugShowCheckedModeBanner: false,
          title: 'SarE',
          themeMode: ThemeMode.system,
          theme: buildTheme(Brightness.light, dynamicScheme: lightDynamic),
          darkTheme: buildTheme(Brightness.dark, dynamicScheme: darkDynamic),
          home: AnimatedSwitcher(
            duration: const Duration(milliseconds: 420),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (Widget child, Animation<double> animation) {
              final Animation<Offset> slide = Tween<Offset>(
                begin: const Offset(0.03, 0.02),
                end: Offset.zero,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: _showSplash
                ? _StartupSplash(
                    key: const ValueKey<String>('splash'),
                    onFinished: () {
                      if (!mounted) {
                        return;
                      }
                      setState(() => _showSplash = false);
                    },
                  )
                : (_loggedIn
                      ? MainShell(
                          key: const ValueKey<String>('main-shell'),
                          onLogout: () => setState(() => _loggedIn = false),
                        )
                      : LoginScreen(
                          key: const ValueKey<String>('login'),
                          onLogin: () => setState(() => _loggedIn = true),
                        )),
          ),
        );
      },
    );
  }
}

class _StartupSplash extends StatefulWidget {
  const _StartupSplash({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<_StartupSplash> createState() => _StartupSplashState();
}

class _StartupSplashState extends State<_StartupSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _logoScale;
  late final Animation<double> _logoOpacity;
  late final Animation<Offset> _logoSlide;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1300),
    );
    _logoScale = Tween<double>(
      begin: 0.8,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));
    _logoOpacity = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
    Future<void>.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) {
        return;
      }
      widget.onFinished();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[c.background, c.backgroundSecondary],
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _logoOpacity,
            child: SlideTransition(
              position: _logoSlide,
              child: ScaleTransition(
                scale: _logoScale,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Image.asset(
                      'assets/images/sare_logo.png',
                      width: 150,
                      fit: BoxFit.contain,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'SAR-E POS',
                      style: TextStyle(
                        color: c.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: 120,
                      child: LinearProgressIndicator(
                        minHeight: 4,
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
