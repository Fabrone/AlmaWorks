import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final String id;
  final String title;
  final String projectId;
  final String projectName;
  final DateTime startDate;
  final DateTime endDate;
  final int duration;
  final DateTime updatedAt;
  final String taskType;
  final int? level;
  final String? parentId; // Changed to nullable

  ScheduleModel({
    required this.id,
    required this.title,
    required this.projectId,
    required this.projectName,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.updatedAt,
    required this.taskType,
    this.level,
    this.parentId, // Updated to accept null
  });

  factory ScheduleModel.fromMap(String id, Map<String, dynamic> data) {
    return ScheduleModel(
      id: id,
      title: data['title'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      duration: data['duration'] as int? ?? 0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      taskType: data['taskType'] as String? ?? 'MainTask',
      level: data['level'] as int?,
      parentId: data['parentId'] as String?, // Updated to handle null
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'projectId': projectId,
      'projectName': projectName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'duration': duration,
      'updatedAt': Timestamp.fromDate(updatedAt),
      'taskType': taskType,
      if (level != null) 'level': level,
      if (parentId != null) 'parentId': parentId, // Only include if not null
    };
  }
}