import 'package:flutter/material.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final List<NotificationItem> _notifications = [
    NotificationItem(
      id: '1',
      title: 'RFI Response Required',
      message: 'Foundation clarification request needs your attention',
      timestamp: DateTime.now().subtract(const Duration(minutes: 30)),
      type: NotificationType.urgent,
      isRead: false,
    ),
    NotificationItem(
      id: '2',
      title: 'Weather Alert',
      message: 'Heavy rain expected at Kilimani site tomorrow',
      timestamp: DateTime.now().subtract(const Duration(hours: 2)),
      type: NotificationType.weather,
      isRead: false,
    ),
    NotificationItem(
      id: '3',
      title: 'Safety Inspection Completed',
      message: 'Weekly safety inspection passed with score 9.2',
      timestamp: DateTime.now().subtract(const Duration(hours: 4)),
      type: NotificationType.safety,
      isRead: true,
    ),
    NotificationItem(
      id: '4',
      title: 'Budget Update',
      message: 'Project budget updated for Downtown Office Complex',
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
      type: NotificationType.financial,
      isRead: true,
    ),
    NotificationItem(
      id: '5',
      title: 'Task Assignment',
      message: 'New task assigned: Review Change Order #23',
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
      type: NotificationType.task,
      isRead: true,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: const Text('Mark All Read', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _notifications.length,
        itemBuilder: (context, index) {
          final notification = _notifications[index];
          return _buildNotificationItem(notification);
        },
      ),
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: notification.isRead ? Colors.white : Colors.blue.withValues(alpha: 0.05),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: notification.getTypeColor().withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            notification.getTypeIcon(),
            color: notification.getTypeColor(),
            size: 20,
          ),
        ),
        title: Text(
          notification.title,
          style: TextStyle(
            fontWeight: notification.isRead ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(notification.message),
            const SizedBox(height: 4),
            Text(
              _formatTimestamp(notification.timestamp),
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: notification.isRead 
          ? null 
          : Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.blue,
                shape: BoxShape.circle,
              ),
            ),
        onTap: () {
          setState(() {
            notification.isRead = true;
          });
        },
      ),
    );
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${difference.inDays}d ago';
    }
  }

  void _markAllAsRead() {
    setState(() {
      for (var notification in _notifications) {
        notification.isRead = true;
      }
    });
  }
}

class NotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final NotificationType type;
  bool isRead;

  NotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.type,
    required this.isRead,
  });

  IconData getTypeIcon() {
    switch (type) {
      case NotificationType.urgent:
        return Icons.warning;
      case NotificationType.weather:
        return Icons.cloud;
      case NotificationType.safety:
        return Icons.security;
      case NotificationType.financial:
        return Icons.attach_money;
      case NotificationType.task:
        return Icons.assignment;
      case NotificationType.general:
        return Icons.info;
    }
  }

  Color getTypeColor() {
    switch (type) {
      case NotificationType.urgent:
        return Colors.red;
      case NotificationType.weather:
        return Colors.blue;
      case NotificationType.safety:
        return Colors.orange;
      case NotificationType.financial:
        return Colors.green;
      case NotificationType.task:
        return Colors.purple;
      case NotificationType.general:
        return Colors.grey;
    }
  }
}

enum NotificationType {
  urgent,
  weather,
  safety,
  financial,
  task,
  general,
}
