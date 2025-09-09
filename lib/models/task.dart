import 'package:flutter/material.dart';

class Task {
  final String id;
  final String title;
  final String description;
  final String deadline;
  final String priority;
  final String assignedTo;
  final DateTime createdAt;

  Task({
    required this.id,
    required this.title,
    required this.description,
    required this.deadline,
    required this.priority,
    required this.assignedTo,
    required this.createdAt,
  });

  bool get isUrgent => priority == 'High' || deadline.contains('Tomorrow');

  Color get priorityColor {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'deadline': deadline,
      'priority': priority,
      'assignedTo': assignedTo,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      deadline: json['deadline'],
      priority: json['priority'],
      assignedTo: json['assignedTo'],
      createdAt: DateTime.parse(json['createdAt']),
    );
  }
}