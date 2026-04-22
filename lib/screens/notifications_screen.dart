import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/liquid_background.dart';

class Notice {
  const Notice({
    required this.id,
    required this.type,
    required this.title,
    required this.message,
    required this.time,
    required this.read,
  });

  final String id;
  final String type;
  final String title;
  final String message;
  final String time;
  final bool read;

  Notice copyWith({bool? read}) {
    return Notice(
      id: id,
      type: type,
      title: title,
      message: message,
      time: time,
      read: read ?? this.read,
    );
  }
}

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Notice> notices = <Notice>[
    const Notice(
      id: '1',
      type: 'alert',
      title: 'Low Stock Alert',
      message: '5 products are running low on stock.',
      time: '5 min ago',
      read: false,
    ),
    const Notice(
      id: '2',
      type: 'alert',
      title: 'Overdue Payment',
      message: '2 customers have overdue credit payments.',
      time: '1 hour ago',
      read: false,
    ),
    const Notice(
      id: '3',
      type: 'success',
      title: 'Sales Target Reached',
      message: 'You reached today\'s sales target.',
      time: '3 hours ago',
      read: true,
    ),
    const Notice(
      id: '4',
      type: 'info',
      title: 'Price Update',
      message: '3 products have suggested prices.',
      time: 'Yesterday',
      read: true,
    ),
  ];

  int get unread => notices.where((Notice n) => !n.read).length;

  @override
  Widget build(BuildContext context) {
    final AppColors c = appColors(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: <Widget>[
          if (unread > 0)
            TextButton(
              onPressed: () => setState(
                () => notices = notices
                    .map((Notice n) => n.copyWith(read: true))
                    .toList(),
              ),
              child: const Text('Mark all as read'),
            ),
        ],
      ),
      body: LiquidBackground(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 20),
          children: <Widget>[
            Text(
              unread > 0 ? '$unread unread' : 'All caught up!',
              style: TextStyle(color: c.textSecondary),
            ),
            const SizedBox(height: 10),
            if (notices.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Center(
                  child: Text(
                    'No notifications',
                    style: TextStyle(color: c.textSecondary),
                  ),
                ),
              ),
            ...notices.map((Notice n) {
              final (IconData icon, Color color) = switch (n.type) {
                'alert' => (Icons.warning_amber_rounded, c.warning),
                'success' => (Icons.check_circle_outline, c.primary),
                _ => (Icons.trending_up, c.info),
              };
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.15),
                    child: Icon(icon, color: color),
                  ),
                  title: Text(n.title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const SizedBox(height: 2),
                      Text(n.message),
                      const SizedBox(height: 4),
                      Row(
                        children: <Widget>[
                          Icon(Icons.schedule, size: 12, color: c.textTertiary),
                          const SizedBox(width: 4),
                          Text(
                            n.time,
                            style: TextStyle(
                              color: c.textTertiary,
                              fontSize: 11,
                            ),
                          ),
                          if (!n.read) ...<Widget>[
                            const SizedBox(width: 8),
                            GestureDetector(
                              onTap: () {
                                setState(() {
                                  notices = notices
                                      .map(
                                        (Notice it) => it.id == n.id
                                            ? it.copyWith(read: true)
                                            : it,
                                      )
                                      .toList();
                                });
                              },
                              child: Text(
                                'Mark as read',
                                style: TextStyle(
                                  color: c.primary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(
                      () => notices = notices
                          .where((Notice it) => it.id != n.id)
                          .toList(),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}
