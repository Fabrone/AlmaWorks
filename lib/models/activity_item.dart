import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

class ActivityItem {
  final String id;
  final String? projectId;
  final String? projectName;
  final String? taskId;
  final String? taskName;
  final String? action;
  final String title;
  final String description;
  final Timestamp timestamp;
  final IconData icon;
  final Color color;

  ActivityItem({
    required this.id,
    this.projectId,
    this.projectName,
    this.taskId,
    this.taskName,
    this.action,
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  factory ActivityItem.fromFirebaseMap(String id, Map<String, dynamic> data) {
    return ActivityItem(
      id: id,
      projectId: data['projectId'],
      projectName: data['projectName'],
      taskId: data['taskId'],
      taskName: data['taskName'],
      action: data['action'],
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      icon: Icons.timeline,  // Default, or map from action
      color: Colors.grey,    // Default, or map from action
    );
  }

  // Remove or update getMockActivities to empty or test data
  static List<ActivityItem> getMockActivities() {
    return [];
  }
}