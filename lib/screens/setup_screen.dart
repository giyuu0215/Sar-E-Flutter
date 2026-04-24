import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';

/// First-run screen with a clear 2-step onboarding flow:
///   Step 1 – Enter store name + PIN
///   Step 2 – Link with Google (generates storeId) → auto-login → done
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();

  int _step = 1; // 1 = store details, 2 = google link
  bool _isLoading = false;
  String? _error;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fade = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  /// Validates Step 1 and advances to Step 2.
  void _nextStep() {
    final String name = _nameCtrl.text.trim();
    final String pin = _pinCtrl.text.trim();
    final String confirm = _confirmCtrl.text.trim();

    if (name.isEmpty) {
      setState(() => _error = 'Please enter your store name.');
      return;
    }
    if (pin.length < 4) {
      setState(() => _error = 'PIN must be at least 4 digits.');
      return;
    }
    if (pin != confirm) {
      setState(() => _error = 'PINs do not match.');
      return;
    }

    setState(() {
      _error = null;
      _step = 2;
    });
    _fadeCtrl
      ..reset()
      ..forward();
  }

  /// Called from Step 2: sign in with Google, then register locally.
  Future<void> _linkAndRegister() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final AuthNotifier notifier = ref.read(authProvider.notifier);

    // Step A: Google Sign-In → storeId
    final String? storeId = await notifier.linkStoreWithGoogle();
    if (storeId == null) {
      // Error message is already stored in AuthState; show it.
      setState(() => _isLoading = false);
      return;
    }

    // Step B: Register local owner with PIN + store name.
    final bool ok = await notifier.register(
      _pinCtrl.text.trim(),
      _nameCtrl.text.trim(),
    );

    if (mounted) setState(() => _isLoading = false);

    if (!ok && mounted) {
      setState(() => _error = 'Registration failed. Please try again.');
    }
    // On success, auth state changes → _AppEntry in main.dart navigates automatically.
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final AuthState auth =
        ref.watch(authProvider).value ?? const AuthState();

    return Scaffold(
      body: LiquidBackground(
        child: SafeArea(
          child: FadeTransition(
            opacity: _fade,
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // ── Header ────────────────────────────────────────────
                  Center(
                    child: Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: <BoxShadow>[
                          BoxShadow(
                            color: c.primary.withValues(alpha: 0.3),
                            blurRadius: 30,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: Image.asset('assets/images/sare_logo.png',
                            fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Center(
                    child: Text(
                      'Welcome to SarE',
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            color: c.text,
                          ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Center(
                    child: Text(
                      _step == 1
                          ? 'Step 1 of 2 – Store details'
                          : 'Step 2 of 2 – Link your store',
                      style: TextStyle(color: c.textSecondary),
                    ),
                  ),
                  // ── Step indicator ────────────────────────────────────
                  const SizedBox(height: 16),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: c.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          height: 4,
                          decoration: BoxDecoration(
                            color: _step == 2
                                ? c.primary
                                : c.border,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // ── Card ──────────────────────────────────────────────
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: c.border),
                        ),
                        child: _step == 1
                            ? _buildStep1(c, dark)
                            : _buildStep2(c, dark, auth),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Step 1: Store name + PIN ───────────────────────────────────────────────

  Widget _buildStep1(AppColors c, bool dark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _label('Store Name', c),
        const SizedBox(height: 6),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: "e.g. Nanay Aling's Store",
            prefixIcon: Icon(Icons.store_outlined),
          ),
        ),
        const SizedBox(height: 20),
        _label('Owner PIN (4–6 digits)', c),
        const SizedBox(height: 6),
        TextField(
          controller: _pinCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            hintText: '● ● ● ●',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _confirmCtrl,
          obscureText: true,
          keyboardType: TextInputType.number,
          inputFormatters: <TextInputFormatter>[
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            hintText: 'Confirm PIN',
            prefixIcon: Icon(Icons.lock_outline),
          ),
        ),
        if (_error != null) ...<Widget>[
          const SizedBox(height: 12),
          _errorBox(_error!, c),
        ],
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _nextStep,
            style: ElevatedButton.styleFrom(
              backgroundColor: c.primary,
              foregroundColor: dark ? const Color(0xFF0D1117) : Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: const Text('Next →',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ),
      ],
    );
  }

  // ── Step 2: Google Sign-In to link store ───────────────────────────────────

  Widget _buildStep2(AppColors c, bool dark, AuthState auth) {
    final String? authError = auth.errorMessage;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // Summary of what was filled in Step 1
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: c.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: <Widget>[
              Icon(Icons.check_circle_outline, color: c.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      _nameCtrl.text.trim(),
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: c.text),
                    ),
                    Text('PIN set • Ready to link',
                        style:
                            TextStyle(color: c.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              TextButton(
                onPressed: () {
                  setState(() {
                    _step = 1;
                    _error = null;
                  });
                  _fadeCtrl
                    ..reset()
                    ..forward();
                },
                child: const Text('Edit'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Link your store to the cloud',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          'Sign in with Google to create a unique store ID. '
          'This enables cloud sync and multi-device support. '
          'Each Google account = one store.',
          style: TextStyle(color: c.textSecondary, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 20),
        if (authError != null || _error != null) ...<Widget>[
          _errorBox(authError ?? _error!, c),
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: (_isLoading || auth.isLoading) ? null : _linkAndRegister,
            icon: (_isLoading || auth.isLoading)
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Image.asset(
                    'assets/images/sare_logo.png',
                    width: 20,
                    height: 20,
                    errorBuilder: (_, __, ___) =>
                        const Icon(Icons.login, size: 20),
                  ),
            label: Text(
              (_isLoading || auth.isLoading)
                  ? 'Signing in…'
                  : 'Continue with Google',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF4285F4),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Center(
          child: Text(
            '🔒  Your data stays private. Each store is isolated.',
            style: TextStyle(color: c.textTertiary, fontSize: 11),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Widget _label(String text, AppColors c) => Text(
        text,
        style: TextStyle(
          color: c.textSecondary,
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
      );

  Widget _errorBox(String message, AppColors c) => Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: c.error.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: <Widget>[
            Icon(Icons.error_outline, color: c.error, size: 16),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message,
                  style: TextStyle(color: c.error, fontSize: 13)),
            ),
          ],
        ),
      );
}
