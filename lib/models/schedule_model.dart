import 'package:cloud_firestore/cloud_firestore.dart';

class ScheduleModel {
  final String id;
  final String title;
  final String description;
  final String projectId;
  final String projectName;
  final DateTime startDate;
  final DateTime endDate;
  final double progress;
  final DateTime updatedAt;

  ScheduleModel({
    required this.id,
    required this.title,
    required this.description,
    required this.projectId,
    required this.projectName,
    required this.startDate,
    required this.endDate,
    required this.progress,
    required this.updatedAt,
  });

  factory ScheduleModel.fromMap(String id, Map<String, dynamic> data) {
    return ScheduleModel(
      id: id,
      title: data['title'] as String? ?? '',
      description: data['description'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      startDate: (data['startDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      endDate: (data['endDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      progress: (data['progress'] as num?)?.toDouble() ?? 0.0,
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'projectId': projectId,
      'projectName': projectName,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': Timestamp.fromDate(endDate),
      'progress': progress,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}