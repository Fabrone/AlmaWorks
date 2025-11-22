import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleNotification {
  final String id;
  final String projectId;
  final String taskId;
  final String taskName;
  final DateTime startDate;
  final String message;
  final DateTime createdAt;
  final bool isRead;
  final String? userId; // Optional - for when auth is not implemented
  final String deviceId; // To handle device-specific tracking

  // NEW FIELDS for tracking lifecycle
  final bool isTriggered;              // Has device notification been shown?
  final DateTime? triggeredAt;         // When was device notification shown?
  final int? notificationId;           // System notification ID (for cancellation)
  final bool openedFromTray;           // Did user open from system tray?
  final DateTime? openedAt;            // When user opened notification
  final DateTime? dismissedAt;         // When user dismissed notification
  final String deliveryStatus;         // 'pending', 'delivered', 'failed', 'cancelled'
  final String? readSource;            // 'app', 'system_tray', 'notification_center'
  final String triggerSource;          // 'foreground_app', 'background_task'
  final DateTime? lastAttemptAt;       // Last time system tried to trigger
  final int attemptCount;              // Number of trigger attempts
  final DateTime expiresAt;            // When this notification is no longer relevant (set to task startDate)

  final String type; // NEW: 'overdue' or 'starting_soon' for color distinctions

  ScheduleNotification({
    required this.id,
    required this.projectId,
    required this.taskId,
    required this.taskName,
    required this.startDate,
    required this.message,
    required this.createdAt,
    this.isRead = false,
    this.userId, // optional
    required this.deviceId,
    // NEW defaults
    this.isTriggered = false,
    this.triggeredAt,
    this.notificationId,
    this.openedFromTray = false,
    this.openedAt,
    this.dismissedAt,
    this.deliveryStatus = 'pending',
    this.readSource,
    required this.triggerSource,
    this.lastAttemptAt,
    this.attemptCount = 0,
    required this.expiresAt,
    required this.type, // NEW: Required type
  });

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'taskId': taskId,
      'taskName': taskName,
      'startDate': Timestamp.fromDate(startDate),
      'message': message,
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      if (userId != null) 'userId': userId, // Include if present
      'deviceId': deviceId,
      // NEW fields
      'isTriggered': isTriggered,
      'triggeredAt': triggeredAt != null ? Timestamp.fromDate(triggeredAt!) : null,
      'notificationId': notificationId,
      'openedFromTray': openedFromTray,
      'openedAt': openedAt != null ? Timestamp.fromDate(openedAt!) : null,
      'dismissedAt': dismissedAt != null ? Timestamp.fromDate(dismissedAt!) : null,
      'deliveryStatus': deliveryStatus,
      'readSource': readSource,
      'triggerSource': triggerSource,
      'lastAttemptAt': lastAttemptAt != null ? Timestamp.fromDate(lastAttemptAt!) : null,
      'attemptCount': attemptCount,
      'expiresAt': Timestamp.fromDate(expiresAt),
      'type': type, // NEW: Include type
    };
  }

  factory ScheduleNotification.fromFirestore(String id, Map<String, dynamic> data) {
    return ScheduleNotification(
      id: id,
      projectId: data['projectId'] ?? '',
      taskId: data['taskId'] ?? '',
      taskName: data['taskName'] ?? '',
      startDate: (data['startDate'] as Timestamp).toDate(),
      message: data['message'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      isRead: data['isRead'] ?? false,
      userId: data['userId'], // Will be null if not present
      deviceId: data['deviceId'] ?? '',
      // NEW fields
      isTriggered: data['isTriggered'] ?? false,
      triggeredAt: data['triggeredAt'] != null ? (data['triggeredAt'] as Timestamp).toDate() : null,
      notificationId: data['notificationId'],
      openedFromTray: data['openedFromTray'] ?? false,
      openedAt: data['openedAt'] != null ? (data['openedAt'] as Timestamp).toDate() : null,
      dismissedAt: data['dismissedAt'] != null ? (data['dismissedAt'] as Timestamp).toDate() : null,
      deliveryStatus: data['deliveryStatus'] ?? 'pending',
      readSource: data['readSource'],
      triggerSource: data['triggerSource'] ?? 'unknown',
      lastAttemptAt: data['lastAttemptAt'] != null ? (data['lastAttemptAt'] as Timestamp).toDate() : null,
      attemptCount: data['attemptCount'] ?? 0,
      expiresAt: (data['expiresAt'] as Timestamp).toDate(),
      type: data['type'] ?? 'unknown', // NEW: Include type
    );
  }

  ScheduleNotification copyWith({
    bool? isRead,
    bool? isTriggered,
    DateTime? triggeredAt,
    int? notificationId,
    bool? openedFromTray,
    DateTime? openedAt,
    DateTime? dismissedAt,
    String? deliveryStatus,
    String? readSource,
    String? triggerSource,
    DateTime? lastAttemptAt,
    int? attemptCount,
    DateTime? expiresAt,
    String? type, // NEW: Handle type
  }) {
    return ScheduleNotification(
      id: id,
      projectId: projectId,
      taskId: taskId,
      taskName: taskName,
      startDate: startDate,
      message: message,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      userId: userId, // Pass through as-is
      deviceId: deviceId,
      isTriggered: isTriggered ?? this.isTriggered,
      triggeredAt: triggeredAt ?? this.triggeredAt,
      notificationId: notificationId ?? this.notificationId,
      openedFromTray: openedFromTray ?? this.openedFromTray,
      openedAt: openedAt ?? this.openedAt,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      deliveryStatus: deliveryStatus ?? this.deliveryStatus,
      readSource: readSource ?? this.readSource,
      triggerSource: triggerSource ?? this.triggerSource,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      attemptCount: attemptCount ?? this.attemptCount,
      expiresAt: expiresAt ?? this.expiresAt,
      type: type ?? this.type, // NEW: Handle type
    );
  }
}