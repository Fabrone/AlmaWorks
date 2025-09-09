import 'package:almaworks/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class NotificationsScreen extends StatefulWidget {
  final Logger? logger;
  
  const NotificationsScreen({super.key, this.logger});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final Logger _logger;
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
  void initState() {
    super.initState();
    _logger = widget.logger ?? Logger();
    _logger.i('🔔 NotificationsScreen: Initialized');
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(isTablet),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildNotificationsList(true)),
          _buildFooter(context, true),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(bool isTablet) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSidebar(context, isTablet),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildNotificationsList(false)),
                _buildFooter(context, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSidebar(context, false),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildNotificationsList(false)),
                _buildFooter(context, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text(
        'Notifications',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF0A2E5A),
      foregroundColor: Colors.white,
      actions: [
        TextButton(
          onPressed: _markAllAsRead,
          child: const Text(
            'Mark All Read',
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildSidebar(BuildContext context, bool isTablet) {
    return Container(
      width: isTablet ? 280 : 300,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0A2E5A),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'AlmaWorks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Site Management',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Projects'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  selected: true,
                  onTap: () {},
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'System Sections',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Documents'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.architecture),
                  title: const Text('Drawings'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Schedule'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Quality & Safety'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Reports'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photo Gallery'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Financials'),
                  enabled: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationsList(bool isMobile) {
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _notifications.length,
      itemBuilder: (context, index) {
        final notification = _notifications[index];
        return _buildNotificationItem(notification);
      },
    );
  }

  Widget _buildNotificationItem(NotificationItem notification) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: notification.isRead 
          ? Colors.white 
          : const Color(0xFF0A2E5A).withValues(alpha: 0.05),
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
                  color: Color(0xFF0A2E5A),
                  shape: BoxShape.circle,
                ),
              ),
        onTap: () {
          setState(() {
            notification.isRead = true;
          });
          _logger.i('📖 NotificationsScreen: Notification marked as read: ${notification.title}');
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: const Color(0xFF0A2E5A),
      child: Text(
        '© 2025 JV Alma C.I.S Site Management System',
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
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
    _logger.i('✅ NotificationsScreen: All notifications marked as read');
  }

  @override
  void dispose() {
    _logger.i('🧹 NotificationsScreen: Disposing resources');
    super.dispose();
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
