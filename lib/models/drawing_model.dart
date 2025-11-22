import 'package:cloud_firestore/cloud_firestore.dart';

class DrawingModel {
  final String id;
  final String projectId;
  final String title;
  final String fileName;
  final String url;
  final String type; 
  final int revisionNumber;
  final bool isFinal;
  final bool isAsBuilt;
  final bool isContract; // NEW FIELD ADDED
  final DateTime uploadedAt;
  final DateTime? finalizedAt;
  final Map<String, dynamic>? metadata;

  DrawingModel({
    required this.id,
    required this.projectId,
    required this.title,
    required this.fileName,
    required this.url,
    required this.type,
    required this.revisionNumber,
    this.isFinal = false,
    this.isAsBuilt = false,
    this.isContract = false, // DEFAULT TO FALSE
    required this.uploadedAt,
    this.finalizedAt,
    this.metadata,
  });

  factory DrawingModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DrawingModel(
      id: doc.id,
      projectId: data['projectId'] ?? '',
      title: data['title'] ?? '',
      fileName: data['fileName'] ?? '',
      url: data['url'] ?? '',
      type: data['type'] ?? '',
      revisionNumber: data['revisionNumber'] ?? 1,
      isFinal: data['isFinal'] ?? false,
      isAsBuilt: data['isAsBuilt'] ?? false,
      isContract: data['isContract'] ?? false, // READ FROM FIRESTORE
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      finalizedAt: data['finalizedAt'] != null 
          ? (data['finalizedAt'] as Timestamp).toDate() 
          : null,
      metadata: data['metadata'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'projectId': projectId,
      'title': title,
      'fileName': fileName,
      'url': url,
      'type': type,
      'revisionNumber': revisionNumber,
      'isFinal': isFinal,
      'isAsBuilt': isAsBuilt,
      'isContract': isContract, // SAVE TO FIRESTORE
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'finalizedAt': finalizedAt != null ? Timestamp.fromDate(finalizedAt!) : null,
      'metadata': metadata,
    };
  }

  DrawingModel copyWith({
    String? id,
    String? projectId,
    String? title,
    String? fileName,
    String? url,
    String? type,
    int? revisionNumber,
    bool? isFinal,
    bool? isAsBuilt,
    bool? isContract, // ADDED TO COPYWITH
    DateTime? uploadedAt,
    DateTime? finalizedAt,
    Map<String, dynamic>? metadata,
  }) {
    return DrawingModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      title: title ?? this.title,
      fileName: fileName ?? this.fileName,
      url: url ?? this.url,
      type: type ?? this.type,
      revisionNumber: revisionNumber ?? this.revisionNumber,
      isFinal: isFinal ?? this.isFinal,
      isAsBuilt: isAsBuilt ?? this.isAsBuilt,
      isContract: isContract ?? this.isContract, // ADDED TO COPYWITH
      uploadedAt: uploadedAt ?? this.uploadedAt,
      finalizedAt: finalizedAt ?? this.finalizedAt,
      metadata: metadata ?? this.metadata,
    );
  }
}

class DrawingGroup {
  final String title;
  final List<DrawingModel> revisions;
  final DrawingModel? latestRevision;
  final DrawingModel? finalRevision;

  DrawingGroup({
    required this.title,
    required this.revisions,
    this.latestRevision,
    this.finalRevision,
  });

  factory DrawingGroup.fromDrawings(String title, List<DrawingModel> drawings) {
    // Sort by revision number descending
    final sortedRevisions = drawings
        .where((d) => d.title == title)
        .toList()
      ..sort((a, b) => b.revisionNumber.compareTo(a.revisionNumber));

    final latestRevision = sortedRevisions.isNotEmpty ? sortedRevisions.first : null;
    final finalRevision = sortedRevisions.where((d) => d.isFinal).firstOrNull;

    return DrawingGroup(
      title: title,
      revisions: sortedRevisions,
      latestRevision: latestRevision,
      finalRevision: finalRevision,
    );
  }

  int get nextRevisionNumber {
    if (revisions.isEmpty) return 1;
    return revisions.map((r) => r.revisionNumber).reduce((a, b) => a > b ? a : b) + 1;
  }
}