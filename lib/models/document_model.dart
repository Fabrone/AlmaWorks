import 'package:cloud_firestore/cloud_firestore.dart';

class DocumentModel {
  final String id;
  final String name;
  final String url;
  final String projectId;
  final String projectName;
  final DateTime uploadedAt;

  DocumentModel({
    required this.id,
    required this.name,
    required this.url,
    required this.projectId,
    required this.projectName,
    required this.uploadedAt,
  });

  factory DocumentModel.fromMap(String id, Map<String, dynamic> map) {
    return DocumentModel(
      id: id,
      name: map['name'] as String,
      url: map['url'] as String,
      projectId: map['projectId'] as String,
      projectName: map['projectName'] as String,
      uploadedAt: (map['uploadedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'projectId': projectId,
      'projectName': projectName,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
    };
  }
}