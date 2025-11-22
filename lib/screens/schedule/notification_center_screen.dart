import 'package:almaworks/models/notification_model.dart';
import 'package:almaworks/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart'; // NEW: Import Logger for logging

class NotificationCenterScreen extends StatelessWidget {
  final String projectId;
  final NotificationService notificationService;
  final Logger _logger = Logger(); // NEW: Logger instance for tracing

  NotificationCenterScreen({
    super.key,
    required this.projectId,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    _logger.d('Building NotificationCenterScreen for projectId: $projectId');
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
        title: Text(
          'Notifications',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          StreamBuilder<int>(
            stream: notificationService.getUnreadCount(projectId),
            builder: (context, snapshot) {
              final unreadCount = snapshot.data ?? 0;
              _logger.d('Unread count stream update: $unreadCount');
              if (unreadCount == 0) return const SizedBox.shrink();
              
              return TextButton.icon(
                onPressed: () async {
                  try {
                    _logger.d('Marking all as read for projectId: $projectId');
                    await notificationService.markAllAsRead(projectId);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'All notifications marked as read',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: const Color(0xFF0A2E5A),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    _logger.e('Error marking all as read', error: e);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Error marking notifications as read',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.done_all, size: 18, color: Colors.white),
                label: Text(
                  'Mark All Read ($unreadCount)',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white,
                  ),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Force refresh by triggering a cleanup which will cause stream to update
          _logger.d('Manual refresh triggered');
          await notificationService.cleanupOldNotifications();
        },
        child: StreamBuilder<List<ScheduleNotification>>(
          stream: notificationService.getNotifications(projectId, limit: 100),
          builder: (context, snapshot) {
            _logger.d('Notifications stream builder called. Connection state: ${snapshot.connectionState}');
            
            if (snapshot.connectionState == ConnectionState.waiting) {
              _logger.d('Showing loading indicator');
              return const Center(
                child: CircularProgressIndicator(),
              );
            }

            if (snapshot.hasError) {
              _logger.e('Error in notifications stream', error: snapshot.error, stackTrace: snapshot.stackTrace);
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.red.shade400),
                      const SizedBox(height: 16),
                      Text(
                        'Error loading notifications',
                        style: GoogleFonts.poppins(
                          color: Colors.red,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Pull down to retry',
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.arrow_back),
                        label: Text(
                          'Go Back',
                          style: GoogleFonts.poppins(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF0A2E5A),
                          foregroundColor: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }

            final notifications = snapshot.data ?? [];
            _logger.d('Received ${notifications.length} notifications from stream');

            if (notifications.isEmpty) {
              _logger.d('No notifications to display');
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.notifications_none, size: 80, color: Colors.grey.shade400),
                    const SizedBox(height: 16),
                    Text(
                      'No notifications yet',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pull down to refresh',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              );
            }

            _logger.d('Building ListView with ${notifications.length} items');
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: notifications.length,
              itemBuilder: (context, index) {
                final notification = notifications[index];
                _logger.d('Building item $index: Task ${notification.taskName}, Type: ${notification.type}, Read: ${notification.isRead}');
                return _buildNotificationItem(context, notification);
              },
            );
          },
        ),
      ),
    );
  }

  // UPDATED: Replaced withOpacity with withAlpha for deprecation fix, use type for distinguished colors
  Widget _buildNotificationItem(BuildContext context, ScheduleNotification notification) {
    final dateFormat = DateFormat('MMM dd, yyyy - HH:mm');
    
    // UPDATED: Distinguished colors based on type
    Color typeColor;
    switch (notification.type) {
      case 'overdue':
        typeColor = Colors.red;
        break;
      case 'starting_soon':
        typeColor = Colors.orange;
        break;
      default:
        typeColor = const Color(0xFF0A2E5A);
    }
    
    // Enhanced visual for read/unread
    final cardColor = notification.isRead ? Colors.grey.shade50 : Colors.white;
    final borderColor = notification.isRead 
        ? Colors.grey.shade300 
        : typeColor.withAlpha(77);  // FIXED: 0.3 * 255 ≈ 77, use typeColor
    final borderWidth = notification.isRead ? 1.0 : 2.0;
    final elevation = notification.isRead ? 0.0 : 2.0;
    final iconColor = notification.isRead ? Colors.grey.shade600 : typeColor;
    final titleWeight = notification.isRead ? FontWeight.w500 : FontWeight.w600;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: elevation,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: borderColor,
          width: borderWidth,
        ),
      ),
      child: InkWell(
        onTap: () async {
          if (!notification.isRead) {
            _logger.d('Marking notification as read: ID ${notification.id}'); // NEW: Log mark as read action
            await notificationService.markAsRead(notification.id, readSource: 'app');
          }
          // Optionally show details dialog if needed; for now, just mark read
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: notification.isRead 
                          ? Colors.grey.shade200 
                          : typeColor.withAlpha(26),  // FIXED: 0.1 * 255 ≈ 26, use typeColor
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      notification.isRead 
                          ? Icons.notifications_outlined 
                          : Icons.notifications_active,
                      size: 20,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          notification.taskName,
                          style: GoogleFonts.poppins(
                            fontWeight: titleWeight,
                            fontSize: 15,
                            color: Colors.grey.shade800,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          dateFormat.format(notification.createdAt),
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (!notification.isRead)
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: typeColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                notification.message,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined, 
                      size: 14, 
                      color: Colors.grey.shade600),
                  const SizedBox(width: 6),
                  Text(
                    'Starts: ${DateFormat('MMM dd, yyyy').format(notification.startDate)}',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              // OPTIONAL: Show new fields like triggeredAt if relevant
              // if (notification.triggeredAt != null) Text('Triggered: ${dateFormat.format(notification.triggeredAt!)}'),
            ],
          ),
        ),
      ),
    );
  }
}