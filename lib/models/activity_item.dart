import 'package:flutter/material.dart';

class ActivityItem {
  final String title;
  final String description;
  final String timestamp;
  final IconData icon;
  final Color color;

  ActivityItem({
    required this.title,
    required this.description,
    required this.timestamp,
    required this.icon,
    required this.color,
  });

  static List<ActivityItem> getMockActivities() {
    return [
      ActivityItem(
        title: 'RFI Submitted',
        description: 'Foundation clarification request submitted',
        timestamp: '2 hours ago',
        icon: Icons.help_outline,
        color: Colors.blue,
      ),
      ActivityItem(
        title: 'Document Updated',
        description: 'Site plans revised - Version 2.1',
        timestamp: '4 hours ago',
        icon: Icons.description,
        color: Colors.green,
      ),
      ActivityItem(
        title: 'Safety Inspection',
        description: 'Weekly safety inspection completed',
        timestamp: '1 day ago',
        icon: Icons.security,
        color: Colors.orange,
      ),
      ActivityItem(
        title: 'Payment Approved',
        description: 'Progress payment #3 approved',
        timestamp: '2 days ago',
        icon: Icons.attach_money,
        color: Colors.purple,
      ),
      ActivityItem(
        title: 'Schedule Update',
        description: 'Concrete pour rescheduled due to weather',
        timestamp: '3 days ago',
        icon: Icons.schedule,
        color: Colors.red,
      ),
    ];
  }
}