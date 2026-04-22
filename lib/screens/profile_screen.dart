import 'package:flutter/material.dart';
import 'dart:ui';

import '../theme/app_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, required this.onLogout});

  final VoidCallback onLogout;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _editing = false;

  final TextEditingController _name = TextEditingController(text: 'John Doe');
  final TextEditingController _store = TextEditingController(
    text: 'SARIE Store',
  );
  final TextEditingController _email = TextEditingController(
    text: 'john@sariestore.com',
  );
  final TextEditingController _phone = TextEditingController(
    text: '09171234567',
  );
  final TextEditingController _address = TextEditingController(
    text: '123 Main Street, City',
  );

  @override
  void dispose() {
    _name.dispose();
    _store.dispose();
    _email.dispose();
    _phone.dispose();
    _address.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1300),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: <Color>[c.background, c.backgroundSecondary],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 90),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Icon(Icons.account_circle_outlined, color: c.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Profile',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const Spacer(),
                    _HeaderEditButton(
                      editing: _editing,
                      onTap: () {
                        if (_editing) {
                          setState(() => _editing = false);
                          _showMessage('Profile saved');
                          return;
                        }
                        setState(() => _editing = true);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _AnimatedEntry(
                  delay: const Duration(milliseconds: 60),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          children: <Widget>[
                            CircleAvatar(
                              radius: 34,
                              backgroundColor: c.primary,
                              child: const Icon(
                                Icons.account_circle_outlined,
                                color: Colors.white,
                                size: 42,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _name.text,
                              style: TextStyle(
                                color: c.text,
                                fontWeight: FontWeight.w800,
                                fontSize: 32 / 2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 7,
                              ),
                              decoration: BoxDecoration(
                                color: c.primary.withValues(alpha: 0.10),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: c.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: <Widget>[
                                  Icon(
                                    Icons.storefront_outlined,
                                    size: 14,
                                    color: c.primary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    _store.text,
                                    style: TextStyle(
                                      color: c.primary,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),
                            _ProfileField(
                              label: 'Full Name',
                              icon: Icons.account_circle_outlined,
                              controller: _name,
                              editing: _editing,
                            ),
                            _ProfileField(
                              label: 'Store Name',
                              icon: Icons.store_outlined,
                              controller: _store,
                              editing: _editing,
                            ),
                            _ProfileField(
                              label: 'Email',
                              icon: Icons.mail_outline,
                              controller: _email,
                              editing: _editing,
                            ),
                            _ProfileField(
                              label: 'Phone',
                              icon: Icons.phone_outlined,
                              controller: _phone,
                              editing: _editing,
                            ),
                            _ProfileField(
                              label: 'Address',
                              icon: Icons.location_on_outlined,
                              controller: _address,
                              editing: _editing,
                            ),
                            if (_editing) ...<Widget>[
                              const SizedBox(height: 4),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: () =>
                                          setState(() => _editing = false),
                                      child: const Text('Cancel'),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: ElevatedButton(
                                      onPressed: () {
                                        setState(() => _editing = false);
                                        _showMessage('Profile saved');
                                      },
                                      child: const Text('Save'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                _AnimatedEntry(
                  delay: const Duration(milliseconds: 120),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(18),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: c.surface.withValues(alpha: 0.74),
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: c.border),
                        ),
                        child: Column(
                          children: <Widget>[
                            _SettingTile(
                              title: 'Privacy & Security',
                              icon: Icons.shield_outlined,
                              onTap: () => _showMessage('Coming soon'),
                            ),
                            _SettingTile(
                              title: 'Notification Settings',
                              icon: Icons.notifications_active_outlined,
                              onTap: () => _showMessage('Coming soon'),
                            ),
                            _SettingTile(
                              title: 'Help & Support',
                              icon: Icons.help_outline,
                              onTap: () => _showMessage('Coming soon'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                _AnimatedEntry(
                  delay: const Duration(milliseconds: 180),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                      child: Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: c.error.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: c.error.withValues(alpha: 0.45),
                          ),
                        ),
                        child: TextButton.icon(
                          onPressed: widget.onLogout,
                          icon: Icon(Icons.logout, color: c.error),
                          label: Text(
                            'Logout',
                            style: TextStyle(
                              color: c.error,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    'SARIE POS v1.0.0',
                    style: TextStyle(color: c.textTertiary, fontSize: 11),
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

class _HeaderEditButton extends StatelessWidget {
  const _HeaderEditButton({required this.editing, required this.onTap});

  final bool editing;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: c.primary.withValues(alpha: 0.11),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: <Widget>[
            Icon(
              editing ? Icons.save_outlined : Icons.edit_outlined,
              size: 15,
              color: c.primary,
            ),
            const SizedBox(width: 6),
            Text(
              editing ? 'Save' : 'Edit',
              style: TextStyle(
                color: c.primary,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileField extends StatelessWidget {
  const _ProfileField({
    required this.label,
    required this.icon,
    required this.controller,
    required this.editing,
  });

  final String label;
  final IconData icon;
  final TextEditingController controller;
  final bool editing;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: editing,
            style: TextStyle(color: c.text, fontWeight: FontWeight.w500),
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 14,
                horizontal: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 10, 10, 0),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: c.border),
          ),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: c.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(icon, color: c.primary, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: c.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 16 / 1.2,
                  ),
                ),
              ),
              Icon(Icons.chevron_right, color: c.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnimatedEntry extends StatefulWidget {
  const _AnimatedEntry({required this.child, required this.delay});

  final Widget child;
  final Duration delay;

  @override
  State<_AnimatedEntry> createState() => _AnimatedEntryState();
}

class _AnimatedEntryState extends State<_AnimatedEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 360),
    );
    Future<void>.delayed(widget.delay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Animation<double> curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    final Animation<Offset> slide = Tween<Offset>(
      begin: const Offset(0, 0.03),
      end: Offset.zero,
    ).animate(curve);
    return FadeTransition(
      opacity: curve,
      child: SlideTransition(position: slide, child: widget.child),
    );
  }
}
