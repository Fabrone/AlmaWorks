import 'package:cloud_firestore/cloud_firestore.dart';

enum ResourceType {
  material,
  equipment,
  labor,
  other,
}

class PurchaseResourceModel {
  final String id;
  final String name;
  final ResourceType type;
  final String quantity; // e.g., "500 kg", "5 units", "8 workers"
  final String status; // e.g., "On site", "Not Ordered", "Ordered", "Not Available", "In storage"
  final String projectId;
  final String projectName;
  final DateTime updatedAt;

  PurchaseResourceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.quantity,
    required this.status,
    required this.projectId,
    required this.projectName,
    required this.updatedAt,
  });

  factory PurchaseResourceModel.fromFirebaseMap(String id, Map<String, dynamic> data) {
    return PurchaseResourceModel(
      id: id,
      name: data['name'] as String? ?? '',
      type: parseResourceType(data['type'] as String? ?? 'other'),
      quantity: data['quantity'] as String? ?? '',
      status: data['status'] as String? ?? 'On site',
      projectId: data['projectId'] as String? ?? '',
      projectName: data['projectName'] as String? ?? '',
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toFirebaseMap() {
    return {
      'name': name,
      'type': type.toString().split('.').last,
      'quantity': quantity,
      'status': status,
      'projectId': projectId,
      'projectName': projectName,
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  static ResourceType parseResourceType(String typeString) {
    switch (typeString.toLowerCase()) {
      case 'material':
        return ResourceType.material;
      case 'equipment':
        return ResourceType.equipment;
      case 'labor':
        return ResourceType.labor;
      default:
        return ResourceType.other;
    }
  }
}