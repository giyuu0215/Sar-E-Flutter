import 'package:flutter/material.dart';
import 'dart:ui';

import '../theme/app_theme.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onLogin,
    required this.onToggleTheme,
  });

  final VoidCallback onLogin;
  final VoidCallback onToggleTheme;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _registerMode = false;
  bool _showPassword = false;

  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: <Widget>[
          Positioned(
            left: -80,
            top: -90,
            child: _GlowCircle(
              color: c.primary.withValues(alpha: dark ? 0.18 : 0.12),
              size: 300,
            ),
          ),
          Positioned(
            right: -80,
            bottom: -110,
            child: _GlowCircle(
              color: c.accent.withValues(alpha: dark ? 0.14 : 0.18),
              size: 320,
            ),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Align(
                        alignment: Alignment.topRight,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                            child: Material(
                              color: c.surface.withValues(alpha: 0.76),
                              child: IconButton(
                                onPressed: widget.onToggleTheme,
                                icon: Icon(
                                  dark
                                      ? Icons.wb_sunny_outlined
                                      : Icons.nightlight_outlined,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                          child: Container(
                            width: 96,
                            height: 96,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: c.surface.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: c.border),
                            ),
                            alignment: Alignment.center,
                            child: Image.asset(
                              'assets/images/sare_logo.png',
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Smart POS for Retail Stores',
                        style: TextStyle(
                          color: c.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 20),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                          child: Card(
                            color: c.surface.withValues(alpha: 0.74),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                children: <Widget>[
                                  Container(
                                    decoration: BoxDecoration(
                                      color: c.surfaceMuted,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(color: c.border),
                                    ),
                                    child: Row(
                                      children: <Widget>[
                                        Expanded(
                                          child: _AuthTabButton(
                                            selected: !_registerMode,
                                            label: 'Login',
                                            onTap: () => setState(
                                              () => _registerMode = false,
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: _AuthTabButton(
                                            selected: _registerMode,
                                            label: 'Register',
                                            onTap: () => setState(
                                              () => _registerMode = true,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  if (_registerMode) ...<Widget>[
                                    TextField(
                                      controller: _nameController,
                                      decoration: const InputDecoration(
                                        labelText: 'Owner Name',
                                        hintText: 'John Doe',
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                  ],
                                  TextField(
                                    controller: _emailController,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      hintText: 'you@store.com',
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  TextField(
                                    controller: _passwordController,
                                    obscureText: !_showPassword,
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      suffixIcon: IconButton(
                                        onPressed: () => setState(
                                          () => _showPassword = !_showPassword,
                                        ),
                                        icon: Icon(
                                          _showPassword
                                              ? Icons.visibility_off
                                              : Icons.visibility,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      onPressed: widget.onLogin,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: c.primary,
                                        foregroundColor: dark
                                            ? const Color(0xFF0D1117)
                                            : Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            14,
                                          ),
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 13,
                                        ),
                                      ),
                                      child: Text(
                                        _registerMode
                                            ? 'Create Account'
                                            : 'Login',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AuthTabButton extends StatelessWidget {
  const _AuthTabButton({
    required this.selected,
    required this.label,
    required this.onTap,
  });

  final bool selected;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: selected
              ? LinearGradient(colors: <Color>[c.primary, c.primaryDark])
              : null,
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          style: TextStyle(
            color: selected ? Colors.white : c.textSecondary,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _GlowCircle extends StatelessWidget {
  const _GlowCircle({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: <BoxShadow>[
          BoxShadow(color: color, blurRadius: 110, spreadRadius: 50),
        ],
      ),
    );
  }
}
