import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'application/auth_provider.dart';
import 'screens/login_screen.dart';
import 'screens/main_shell.dart';
import 'screens/setup_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp();
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
    final AppColors c = appColors(context);
    return Scaffold(
      backgroundColor: c.background,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Image.asset('assets/images/sare_logo.png', height: 80),
            const SizedBox(height: 24),
            CircularProgressIndicator(color: c.primary),
          ],
        ),
      ),
    );
  }
}
