import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/app_ui.dart';
import '../data/notification_service.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _notifications = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    setState(() => _isLoading = true);
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() => _isLoading = false);
        return;
      }

      final notifications = await NotificationService.getAllNotifications(
        userId,
      );

      if (mounted) {
        setState(() {
          _notifications = notifications;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // The screen is pushed onto the root navigator from either dashboard, so
    // the system back gesture should simply pop it. Intercepting the pop and
    // forcing `/doctor-dashboard` sent students to the wrong side of the app.
    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.pageBg,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            tooltip: 'Back',
            // This screen is reachable from both dashboards, so pop back to
            // whichever one opened it rather than hard-coding the doctor's.
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/student-dashboard');
              }
            },
          ),
          title: const Text('Notifications'),
          actions: [
            if (_notifications.any(
              (n) => !((n['is_read'] as bool?) ?? false),
            ))
              TextButton(
                onPressed: _markAllAsRead,
                child: const Text(
                  'Mark all read',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            IconButton(
              icon: const Icon(Icons.refresh_rounded),
              onPressed: _loadNotifications,
              tooltip: 'Refresh',
            ),
          ],
        ),
        body: _isLoading
            ? ListView.separated(
                padding: const EdgeInsets.all(AppSpacing.gutter),
                itemCount: 4,
                separatorBuilder: (_, _) =>
                    const SizedBox(height: AppSpacing.md),
                itemBuilder: (_, _) => const AppSkeletonRow(),
              )
            : _notifications.isEmpty
            ? _buildEmptyState()
            : _buildNotificationList(),
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Padding(
      padding: EdgeInsets.all(AppSpacing.gutter),
      child: AppEmptyState(
        icon: Icons.notifications_none_rounded,
        title: 'No notifications yet',
        message:
            "You'll be told here about new bookings, emergency requests and "
            'record approvals.',
      ),
    );
  }

  Widget _buildNotificationList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _NotificationCard(
          notification: notification,
          onTap: () => _handleNotificationTap(notification),
        );
      },
    );
  }

  Future<void> _handleNotificationTap(
    Map<String, dynamic> notification,
  ) async {
    final id = notification['id']?.toString();
    final wasUnread = !((notification['is_read'] as bool?) ?? false);
    if (id != null && wasUnread) {
      await NotificationService.markAsRead(id);
      if (mounted) {
        setState(() => notification['is_read'] = true);
      }
    }

    final type = notification['type'] as String?;
    final data = notification['data'] as Map<String, dynamic>? ?? {};

    // Navigate based on notification type
    if (type == 'booking' || type == 'emergency') {
      if (!mounted) return;
      context.push('/appointment-detail', extra: data);
    }
  }

  Future<void> _markAllAsRead() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    await NotificationService.markAllAsRead(userId);
    if (mounted) {
      setState(() {
        for (final n in _notifications) {
          n['is_read'] = true;
        }
      });
    }
  }
}

class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onTap;

  const _NotificationCard({required this.notification, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final title = (notification['title'] as String?) ?? '';
    final message = (notification['message'] as String?) ?? '';
    final type = (notification['type'] as String?) ?? 'info';
    final isRead = (notification['is_read'] as bool?) ?? false;
    final createdAt = notification['created_at'] as String?;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isRead
              ? AppColors.surface
              : _getTypeColor(type).withValues(alpha: 0.1),
          borderRadius: AppRadius.lgAll,
          border: Border.all(
            color: isRead
                ? AppColors.border
                : _getTypeColor(type).withValues(alpha: 0.3),
            width: isRead ? 1 : 1.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: _getTypeColor(type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                _getTypeIcon(type),
                color: _getTypeColor(type),
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _formatDate(createdAt),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'emergency':
        return AppColors.error;
      case 'booking':
        return AppColors.primary;
      case 'data_reset':
        return AppColors.warning;
      default:
        return AppColors.info;
    }
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'emergency':
        return Icons.emergency_rounded;
      case 'booking':
        return Icons.calendar_month_rounded;
      case 'data_reset':
        return Icons.refresh_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '';
    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) {
        return 'Just now';
      } else if (diff.inHours < 1) {
        return '${diff.inMinutes}m ago';
      } else if (diff.inDays < 1) {
        return '${diff.inHours}h ago';
      } else if (diff.inDays < 7) {
        return '${diff.inDays}d ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}
