import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialDocumentModel {
  final String id;
  final String title;
  final String? url;
  final String projectId;
  final String projectName;
  final DateTime uploadedAt;
  final String role;
  final String fileName; // Add this line

  FinancialDocumentModel({
    required this.id,
    required this.title,
    this.url,
    required this.projectId,
    required this.projectName,
    required this.uploadedAt,
    required this.role,
    required this.fileName, // Add this line
  });

  // Factory method to create an instance from Firestore document data
  factory FinancialDocumentModel.fromMap(String id, Map<String, dynamic> data) {
    return FinancialDocumentModel(
      id: id,
      title: data['title'] ?? '',
      url: data['url'],
      projectId: data['projectId'] ?? '',
      projectName: data['projectName'] ?? '',
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      role: data['role'] ?? '',
      fileName: data['fileName'] ?? '', // Add this line
    );
  }

  // Method to convert an instance to a map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'url': url,
      'projectId': projectId,
      'projectName': projectName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'role': role,
      'fileName': fileName, // Add this line
    };
  }
}
