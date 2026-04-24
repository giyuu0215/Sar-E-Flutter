import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } catch (e) {
    debugPrint('Firebase initialization failed: $e\n'
        'Run `flutterfire configure` to generate firebase_options.dart.');
  }
  runApp(const ProviderScope(child: SarEApp()));
}

class SarEApp extends StatelessWidget {
  const SarEApp({super.key});

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
          home: const _AppEntry(),
        );
      },
    );
  }
}

/// Root widget that decides which screen to show based on auth state.
class _AppEntry extends ConsumerWidget {
  const _AppEntry();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AsyncValue<AuthState> authAsync = ref.watch(authProvider);

    return authAsync.when(
      loading: () => const _SplashScreen(),
      error: (Object e, _) => Center(child: Text('Error: $e')),
      data: (AuthState auth) {
        if (auth.isFirstRun) {
          return const SetupScreen();
        }
        if (auth.isLoggedIn) {
          return const MainShell();
        }
        return const LoginScreen();
      },
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    // Use the brand red seed color directly — no context theme needed
    const Color brandRed = Color(0xFFC9352C);
    return Scaffold(
      backgroundColor: brandRed,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Logo on the red background
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.asset(
                'assets/images/sare_logo.png',
                height: 100,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 28),
            // App name
            const Text(
              'Sar-E',
              style: TextStyle(
                color: Colors.white,
                fontSize: 36,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Point of Sale',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 48),
            // Progress indicator in white
            const SizedBox(
              width: 140,
              child: LinearProgressIndicator(
                color: Colors.white,
                backgroundColor: Colors.white24,
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
