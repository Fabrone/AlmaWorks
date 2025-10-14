import 'package:cloud_firestore/cloud_firestore.dart';

class PhotoModel {
  final String id;
  final String name;
  final String url;
  final String category;
  final String phase;
  final DateTime uploadedAt;
  final bool isDeleted;
  final String projectId;

  PhotoModel({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.phase,
    required this.uploadedAt,
    this.isDeleted = false,
    required this.projectId,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'category': category,
      'phase': phase,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isDeleted': isDeleted,
      'projectId': projectId,
    };
  }

  static PhotoModel fromMap(String id, Map<String, dynamic> data) {
    return PhotoModel(
      id: id,
      name: data['name'],
      url: data['url'],
      category: data['category'],
      phase: data['phase'],
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      isDeleted: data['isDeleted'] ?? false,
      projectId: data['projectId'] ?? '',
    );
  }
}