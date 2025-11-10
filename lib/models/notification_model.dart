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
    );
  }

  ScheduleNotification copyWith({bool? isRead}) {
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
    );
  }
}