
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
  final String? parentId;
  final Map<String, dynamic>? dependency; // New field for dependency

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
    this.parentId,
    this.dependency, // Added to constructor
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
      parentId: data['parentId'] as String?,
      dependency: data['dependency'] as Map<String, dynamic>?, // Handle dependency field
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
      if (parentId != null) 'parentId': parentId,
      if (dependency != null) 'dependency': dependency, // Include dependency if not null
    };
  }
}