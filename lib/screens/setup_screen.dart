import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_provider.dart';
import '../theme/app_theme.dart';

// ─── Setup flow mode ────────────────────────────────────────────────────────
enum _SetupMode {
  landing, // Step 0: choose Google or Offline
  googleNew, // Step 1a: Google OK, new store → enter name + PIN
  googleExisting, // Step 1b: Google OK, existing store → enter PIN only
  offline, // Step 1c: local-only → enter name + PIN
}

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen>
    with SingleTickerProviderStateMixin {
  _SetupMode _mode = _SetupMode.landing;
  bool _isLoading = false;
  String? _error;
  GoogleLinkResult? _googleResult; // set after a successful Google Sign-In

  // Form fields
  final TextEditingController _nameCtrl = TextEditingController();
  final TextEditingController _pinCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  bool _pinVisible = false;

  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeIn);
    _fadeCtrl.forward();
  }

  @override
  void dispose() {
    _fadeCtrl.dispose();
    _nameCtrl.dispose();
    _pinCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ─── Actions ────────────────────────────────────────────────────────────

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final GoogleLinkResult? result =
        await ref.read(authProvider.notifier).linkStoreWithGoogle();

    if (!mounted) return;

    if (result == null) {
      // Error is already set on authProvider, but also surface it locally
      final String? msg = ref.read(authProvider).value?.errorMessage;
      setState(() {
        _isLoading = false;
        _error = msg ?? 'Google Sign-In failed. Please try again.';
      });
      return;
    }

    _googleResult = result;
    if (result.isExistingStore) {
      _nameCtrl.text = result.existingStoreName ?? '';
    }

    _fadeCtrl.reset();
    setState(() {
      _mode = result.isExistingStore
          ? _SetupMode.googleExisting
          : _SetupMode.googleNew;
      _isLoading = false;
      _error = null;
    });
    _fadeCtrl.forward();
  }

  Future<void> _goOffline() async {
    _fadeCtrl.reset();
    setState(() {
      _mode = _SetupMode.offline;
      _error = null;
    });
    _fadeCtrl.forward();
  }

  Future<void> _submitForm() async {
    final String pin = _pinCtrl.text;
    final String confirm = _confirmCtrl.text;
    final String name = _nameCtrl.text.trim();

    // Validate name (not needed for googleExisting — name is pre-filled)
    if (_mode != _SetupMode.googleExisting && name.isEmpty) {
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
      _isLoading = true;
      _error = null;
    });

    bool ok = false;
    if (_mode == _SetupMode.offline) {
      ok = await ref.read(authProvider.notifier).continueOffline(pin, name);
    } else {
      // googleNew or googleExisting — storeId already set by linkStoreWithGoogle
      ok = await ref
          .read(authProvider.notifier)
          .register(pin, _mode == _SetupMode.googleExisting ? _nameCtrl.text : name);
    }

    if (mounted && !ok) {
      final String? msg = ref.read(authProvider).value?.errorMessage;
      setState(() {
        _isLoading = false;
        _error = msg ?? 'Setup failed. Please try again.';
      });
    }
  }

  void _back() {
    _fadeCtrl.reset();
    setState(() {
      _mode = _SetupMode.landing;
      _error = null;
      _pinCtrl.clear();
      _confirmCtrl.clear();
      _nameCtrl.clear();
    });
    _fadeCtrl.forward();
  }

  // ─── Builders ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnim,
          child: _buildCurrentStep(c),
        ),
      ),
    );
  }

  Widget _buildCurrentStep(AppColors c) {
    return switch (_mode) {
      _SetupMode.landing => _buildLanding(c),
      _SetupMode.googleNew => _buildForm(
          c,
          title: 'Set Up Your Store',
          subtitle: 'Google account linked. Enter your store details.',
          showNameField: true,
        ),
      _SetupMode.googleExisting => _buildForm(
          c,
          title: 'Welcome Back! 👋',
          subtitle:
              'Found your store "${_googleResult?.existingStoreName ?? 'My Store'}". Create a PIN for this device.',
          showNameField: false,
        ),
      _SetupMode.offline => _buildForm(
          c,
          title: 'Offline Setup',
          subtitle: 'Your data stays on this device only (no cloud sync).',
          showNameField: true,
        ),
    };
  }

  // ─── Landing Screen ──────────────────────────────────────────────────────

  Widget _buildLanding(AppColors c) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset(
                'assets/images/sare_logo.png',
                width: 96,
                height: 96,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 24),
            Text('Welcome to Sar-E',
                style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: c.text)),
            const SizedBox(height: 8),
            Text(
              'Set up your point-of-sale in seconds.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textSecondary, fontSize: 15),
            ),
            const SizedBox(height: 48),

            // Google Sign-In button
            if (_isLoading)
              const CircularProgressIndicator()
            else ...<Widget>[
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _handleGoogleSignIn,
                  icon: const _GoogleIcon(),
                  label: const Text('Continue with Google'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _goOffline,
                  icon: const Icon(Icons.wifi_off_rounded),
                  label: const Text('Continue without account'),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: c.border),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
            ],

            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(_error!,
                  textAlign: TextAlign.center,
                  style: TextStyle(color: c.error, fontSize: 13)),
            ],

            const SizedBox(height: 32),
            Text(
              'Google accounts enable cloud backup & multi-device sync.',
              textAlign: TextAlign.center,
              style: TextStyle(color: c.textTertiary, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Form Screen (shared by all 3 flow paths) ────────────────────────────

  Widget _buildForm(
    AppColors c, {
    required String title,
    required String subtitle,
    required bool showNameField,
  }) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            IconButton(
              onPressed: _isLoading ? null : _back,
              icon: const Icon(Icons.arrow_back_rounded),
            ),
            const SizedBox(height: 12),

            // Offline badge
            if (_mode == _SetupMode.offline)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: c.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: c.warning.withValues(alpha: 0.4)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(Icons.wifi_off_rounded,
                        size: 14, color: c.warning),
                    const SizedBox(width: 6),
                    Text('Offline Mode — No cloud sync',
                        style:
                            TextStyle(fontSize: 12, color: c.warning)),
                  ],
                ),
              ),

            Text(title,
                style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: c.text)),
            const SizedBox(height: 6),
            Text(subtitle,
                style:
                    TextStyle(color: c.textSecondary, fontSize: 14)),
            const SizedBox(height: 28),

            if (showNameField) ...<Widget>[
              _label('Store Name', c),
              const SizedBox(height: 6),
              TextField(
                controller: _nameCtrl,
                enabled: !_isLoading,
                textCapitalization: TextCapitalization.words,
                decoration: _inputDec(
                    'e.g. Maria\'s Sari-Sari Store', Icons.store_outlined),
              ),
              const SizedBox(height: 20),
            ],

            _label('Create PIN', c),
            const SizedBox(height: 6),
            TextField(
              controller: _pinCtrl,
              enabled: !_isLoading,
              obscureText: !_pinVisible,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: _inputDec(
                'At least 4 digits',
                Icons.lock_outline,
              ).copyWith(
                suffixIcon: IconButton(
                  icon: Icon(
                      _pinVisible ? Icons.visibility_off : Icons.visibility),
                  onPressed: () =>
                      setState(() => _pinVisible = !_pinVisible),
                ),
              ),
            ),
            const SizedBox(height: 16),

            _label('Confirm PIN', c),
            const SizedBox(height: 6),
            TextField(
              controller: _confirmCtrl,
              enabled: !_isLoading,
              obscureText: !_pinVisible,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(8),
              ],
              decoration: _inputDec('Re-enter PIN', Icons.lock_outline),
              onSubmitted: (_) => _submitForm(),
            ),

            if (_error != null) ...<Widget>[
              const SizedBox(height: 14),
              Text(_error!,
                  style: TextStyle(color: c.error, fontSize: 13)),
            ],

            const SizedBox(height: 28),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submitForm,
                style: ElevatedButton.styleFrom(
                  backgroundColor: c.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('Finish Setup'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Helpers ─────────────────────────────────────────────────────────────

  Widget _label(String text, AppColors c) => Text(
        text,
        style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 13,
            color: c.textSecondary),
      );

  InputDecoration _inputDec(String hint, IconData icon) => InputDecoration(
        prefixIcon: Icon(icon, size: 20),
        hintText: hint,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

/// Minimal Google "G" logo widget using Canvas.
class _GoogleIcon extends StatelessWidget {
  const _GoogleIcon();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 22,
      height: 22,
      child: CustomPaint(painter: _GPainter()),
    );
  }
}

class _GPainter extends CustomPainter {
  const _GPainter();

  @override
  void paint(Canvas canvas, Size size) {
    // Simplified four-colour Google 'G'
    final Paint p = Paint()..style = PaintingStyle.fill;
    final double cx = size.width / 2;
    final double cy = size.height / 2;
    final double r = size.width / 2;

    p.color = const Color(0xFF4285F4); // Blue
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        -1.57, 3.14, true, p);

    p.color = const Color(0xFF34A853); // Green
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        1.57, 1.57, true, p);

    p.color = const Color(0xFFFBBC05); // Yellow
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.14, 0.79, true, p);

    p.color = const Color(0xFFEA4335); // Red
    canvas.drawArc(Rect.fromCircle(center: Offset(cx, cy), radius: r),
        3.93, 0.79, true, p);

    // White inner circle
    p.color = Colors.white;
    canvas.drawCircle(Offset(cx, cy), r * 0.65, p);

    // Right bar of 'G'
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.18, r, r * 0.36),
      Paint()..color = const Color(0xFF4285F4),
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
