import 'package:cloud_firestore/cloud_firestore.dart';

class ResourceModel {
  final String id;
  final String name;
  final String quantity;
  final String status;
  final String projectId;
  final String projectName;
  final DateTime updatedAt;

  ResourceModel({
    required this.id,
    required this.name,
    required this.quantity,
    required this.status,
    required this.projectId,
    required this.projectName,
    required this.updatedAt,
  });

  factory ResourceModel.fromMap(String id, Map<String, dynamic> data) {
    return ResourceModel(
      id: id,
      name: data['name'] as String? ?? '',
      quantity: data['quantity'] as String? ?? '',
      status: data['status'] as String? ?? '',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'status': status,
      'projectId': projectId,
      'projectName': projectName,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}