import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum ToastType { success, error, info }

class ToastOverlay {
  static void show(
    BuildContext context, {
    required String message,
    ToastType type = ToastType.info,
  }) {
    final AppColors c = appColors(context);
    final (Color color, IconData icon) = switch (type) {
      ToastType.success => (c.primary, Icons.check_circle_outline),
      ToastType.error => (c.error, Icons.error_outline),
      ToastType.info => (c.info, Icons.info_outline),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Row(
          children: <Widget>[
            Icon(icon, color: color, size: 18),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}
