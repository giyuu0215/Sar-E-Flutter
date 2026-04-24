import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _pinCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _pinCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_pinCtrl.text.trim().length < 4) return;
    final bool ok =
        await ref.read(authProvider.notifier).login(_pinCtrl.text.trim());
    if (!ok && mounted) {
      _pinCtrl.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final AuthState auth =
        ref.watch(authProvider).value ?? const AuthState();

    // storeNameHint is populated even when logged out (loaded from DB in build())
    final String storeName = auth.storeNameHint ?? 'My Store';

    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: <Widget>[
                const SizedBox(height: 60),
                // ── Logo ────────────────────────────────────────────────
                Container(
                  width: 90,
                  height: 90,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: c.primary.withValues(alpha: 0.35),
                        blurRadius: 40,
                        spreadRadius: 8,
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(26),
                    child: Image.asset('assets/images/sare_logo.png',
                        fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'SarE',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                        color: c.text,
                      ),
                ),
                Text(
                  'Smart POS for Retail Stores',
                  style: TextStyle(
                      color: c.textSecondary, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 40),
                // ── Login card ──────────────────────────────────────────
                ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: c.surface.withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: c.border),
                      ),
                      child: Column(
                        children: <Widget>[
                          Text(
                            'Welcome back!',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            storeName,
                            style: TextStyle(
                              color: c.primary,
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Enter your PIN to continue',
                            style: TextStyle(
                                color: c.textSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 20),
                          // ── PIN input ──────────────────────────────────
                          TextField(
                            controller: _pinCtrl,
                            obscureText: _obscure,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(letterSpacing: 8),
                            inputFormatters: <TextInputFormatter>[
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(6),
                            ],
                            onSubmitted: (_) => _submit(),
                            decoration: InputDecoration(
                              hintText: '● ● ● ●',
                              hintStyle: TextStyle(
                                  letterSpacing: 8, color: c.textTertiary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscure
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  color: c.textSecondary,
                                ),
                                onPressed: () =>
                                    setState(() => _obscure = !_obscure),
                              ),
                            ),
                          ),
                          if (auth.errorMessage != null) ...<Widget>[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: c.error.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Row(
                                children: <Widget>[
                                  Icon(Icons.warning_amber_rounded,
                                      color: c.error, size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      auth.errorMessage!,
                                      style: TextStyle(
                                          color: c.error, fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 20),
                          Row(
                            children: <Widget>[
                              Expanded(
                                child: ElevatedButton(
                                  onPressed:
                                      auth.isLoading ? null : _submit,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: c.primary,
                                    foregroundColor: dark
                                        ? const Color(0xFF0D1117)
                                        : Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: auth.isLoading
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white),
                                        )
                                      : const Text('Login',
                                          style: TextStyle(
                                              fontWeight: FontWeight.w700)),
                                ),
                              ),
                              const SizedBox(width: 12),
                              // Biometric button
                              ElevatedButton(
                                onPressed: auth.isLoading
                                    ? null
                                    : () async {
                                        await ref
                                            .read(authProvider.notifier)
                                            .loginWithBiometrics();
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: c.surface,
                                  foregroundColor: c.primary,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 14, horizontal: 16),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(color: c.primary),
                                  ),
                                ),
                                child:
                                    const Icon(Icons.fingerprint, size: 26),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          // Contextual PIN recovery hint
                          Text(
                            auth.isOfflineMode
                                ? 'Forgot PIN? Reinstall the app to reset (offline — no cloud backup).'
                                : 'Forgot PIN? Sign in with Google again to restore access.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: c.textTertiary, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
