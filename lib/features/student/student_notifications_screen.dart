import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:alara/core/services/notification_service.dart';
import 'package:alara/theme.dart';

class StudentNotificationsScreen extends StatelessWidget {
  const StudentNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notificationService = NotificationService.instance;

    return AnimatedBuilder(
      animation: notificationService,
      builder: (context, _) {
        final items = notificationService.notifications;

        return Scaffold(
          backgroundColor: LightModeColors.lightBackground,
          appBar: AppBar(
            title: const Text(
              'Notifications',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
            actions: [
              if (items.isNotEmpty)
                TextButton(
                  onPressed: notificationService.markAllAsRead,
                  child: const Text('Mark all read'),
                ),
            ],
          ),
          body: items.isEmpty
              ? _EmptyNotifications()
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final item = items[index];
                    return _NotificationTile(
                      item: item,
                      onTap: () => notificationService.markAsRead(item.id),
                    );
                  },
                ),
        );
      },
    );
  }
}

class _NotificationTile extends StatelessWidget {
  final InAppNotificationItem item;
  final VoidCallback onTap;

  const _NotificationTile({
    required this.item,
    required this.onTap,
  });

  IconData _iconForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.message:
        return Icons.chat_bubble_rounded;
      case AppNotificationType.assignment:
        return Icons.assignment_rounded;
      case AppNotificationType.attendance:
        return Icons.how_to_reg_rounded;
      case AppNotificationType.grading:
        return Icons.grading_rounded;
      case AppNotificationType.material:
        return Icons.menu_book_rounded;
      case AppNotificationType.announcement:
        return Icons.campaign_rounded;
      case AppNotificationType.notice:
        return Icons.notifications_active_rounded;
      case AppNotificationType.fees:
        return Icons.account_balance_wallet_rounded;
      case AppNotificationType.generic:
        return Icons.notifications_rounded;
    }
  }

  Color _colorForType(AppNotificationType type) {
    switch (type) {
      case AppNotificationType.message:
        return LightModeColors.accentBlue;
      case AppNotificationType.assignment:
        return LightModeColors.accentOrange;
      case AppNotificationType.attendance:
        return LightModeColors.accentGreen;
      case AppNotificationType.grading:
        return LightModeColors.accentPink;
      case AppNotificationType.material:
        return LightModeColors.lightTertiary;
      case AppNotificationType.announcement:
        return LightModeColors.accentOrange;
      case AppNotificationType.notice:
        return LightModeColors.lightPrimary;
      case AppNotificationType.fees:
        return LightModeColors.accentGreen;
      case AppNotificationType.generic:
        return LightModeColors.lightOnSurfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorForType(item.type);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: item.isRead
                ? null
                : Border.all(
                    color: LightModeColors.lightPrimary.withOpacity(0.25),
                    width: 1.5,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  _iconForType(item.type),
                  color: color,
                  size: 21,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.title,
                            style: TextStyle(
                              fontWeight:
                                  item.isRead ? FontWeight.w600 : FontWeight.w700,
                              color: LightModeColors.lightOnSurface,
                            ),
                          ),
                        ),
                        if (!item.isRead)
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: LightModeColors.lightPrimary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      item.body,
                      style: TextStyle(
                        color: LightModeColors.lightOnSurfaceVariant,
                        fontWeight:
                            item.isRead ? FontWeight.w400 : FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      DateFormat('MMM d, yyyy · HH:mm').format(item.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: LightModeColors.lightOnSurfaceVariant.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNotifications extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: LightModeColors.lightPrimary.withOpacity(0.08),
                borderRadius: BorderRadius.circular(26),
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                color: LightModeColors.lightPrimary,
                size: 40,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'No notifications yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              'Updates about messages, assignments, attendance, grading and materials will appear here.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: LightModeColors.lightOnSurfaceVariant,
                    height: 1.4,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
