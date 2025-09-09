import 'package:almaworks/models/drawing_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:logger/logger.dart';
import 'dart:typed_data'; 

class DrawingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final Logger _logger = Logger();

  // Get all drawings for a project
  Stream<List<DrawingModel>> getProjectDrawings(String projectId) {
    return _firestore
        .collection('Drawings')
        .where('projectId', isEqualTo: projectId)
        .orderBy('title')
        .orderBy('revisionNumber', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrawingModel.fromFirestore(doc))
            .toList());
  }

  // Get revision drawings (not as-built)
  Stream<List<DrawingModel>> getRevisionDrawings(String projectId) {
    return _firestore
        .collection('Drawings')
        .where('projectId', isEqualTo: projectId)
        .where('isAsBuilt', isEqualTo: false)
        .orderBy('title')
        .orderBy('revisionNumber', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrawingModel.fromFirestore(doc))
            .toList());
  }

  // Get as-built drawings
  Stream<List<DrawingModel>> getAsBuiltDrawings(String projectId) {
    return _firestore
        .collection('Drawings')
        .where('projectId', isEqualTo: projectId)
        .where('isAsBuilt', isEqualTo: true)
        .orderBy('title')
        .orderBy('finalizedAt', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => DrawingModel.fromFirestore(doc))
            .toList());
  }

  // Group drawings by title
  List<DrawingGroup> groupDrawingsByTitle(List<DrawingModel> drawings) {
    final Map<String, List<DrawingModel>> groupedDrawings = {};
    
    for (final drawing in drawings) {
      if (!groupedDrawings.containsKey(drawing.title)) {
        groupedDrawings[drawing.title] = [];
      }
      groupedDrawings[drawing.title]!.add(drawing);
    }

    return groupedDrawings.entries
        .map((entry) => DrawingGroup.fromDrawings(entry.key, entry.value))
        .toList()
      ..sort((a, b) => a.title.compareTo(b.title));
  }

  // Upload new drawing
  Future<DrawingModel> uploadDrawing({
    required String projectId,
    required String title,
    required String fileName,
    required List<int> fileBytes,
    required String fileExtension,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      _logger.i('📤 DrawingService: Starting upload for $fileName');

      // Get next revision number for this title
      final existingDrawings = await _firestore
          .collection('Drawings')
          .where('projectId', isEqualTo: projectId)
          .where('title', isEqualTo: title)
          .get();

      final nextRevision = existingDrawings.docs.isEmpty
          ? 1
          : existingDrawings.docs
                  .map((doc) => (doc.data()['revisionNumber'] as int?) ?? 1)
                  .reduce((a, b) => a > b ? a : b) +
              1;

      // Upload to Firebase Storage
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = _storage
          .ref()
          .child('drawings/$projectId/$title/rev_${nextRevision}_${timestamp}_$fileName');

      final uploadTask = storageRef.putData(
        Uint8List.fromList(fileBytes),
        SettableMetadata(
          contentType: _getContentType(fileExtension),
          customMetadata: {
            'projectId': projectId,
            'title': title,
            'revisionNumber': nextRevision.toString(),
            ...?metadata,
          },
        ),
      );

      await uploadTask;
      final downloadUrl = await storageRef.getDownloadURL();

      // Create drawing document
      final drawing = DrawingModel(
        id: '', // Will be set by Firestore
        projectId: projectId,
        title: title,
        fileName: fileName,
        url: downloadUrl,
        type: fileExtension,
        revisionNumber: nextRevision,
        uploadedAt: DateTime.now(),
        metadata: metadata,
      );

      // Save to Firestore
      final docRef = await _firestore
          .collection('Drawings')
          .add(drawing.toFirestore());

      _logger.i('✅ DrawingService: Upload completed for $fileName');
      return drawing.copyWith(id: docRef.id);
    } catch (e) {
      _logger.e('❌ DrawingService: Upload failed', error: e);
      rethrow;
    }
  }

  // Mark revision as final and move to as-built
  Future<DrawingModel> markAsFinal(String drawingId) async {
    try {
      _logger.i('🏁 DrawingService: Marking drawing as final: $drawingId');

      final drawingDoc = await _firestore
          .collection('Drawings')
          .doc(drawingId)
          .get();

      if (!drawingDoc.exists) {
        throw Exception('Drawing not found');
      }

      final drawing = DrawingModel.fromFirestore(drawingDoc);

      // Check if there's already a final revision for this title
      final existingFinal = await _firestore
          .collection('Drawings')
          .where('projectId', isEqualTo: drawing.projectId)
          .where('title', isEqualTo: drawing.title)
          .where('isFinal', isEqualTo: true)
          .get();

      if (existingFinal.docs.isNotEmpty) {
        // Remove final status from existing final revision
        for (final doc in existingFinal.docs) {
          await doc.reference.update({
            'isFinal': false,
            'isAsBuilt': false,
          });
        }
      }

      // Update current drawing as final and as-built
      await _firestore.collection('Drawings').doc(drawingId).update({
        'isFinal': true,
        'isAsBuilt': true,
        'finalizedAt': Timestamp.now(),
      });

      _logger.i('✅ DrawingService: Drawing marked as final');
      return drawing.copyWith(
        isFinal: true,
        isAsBuilt: true,
        finalizedAt: DateTime.now(),
      );
    } catch (e) {
      _logger.e('❌ DrawingService: Failed to mark as final', error: e);
      rethrow;
    }
  }

  // Delete drawing
  Future<void> deleteDrawing(String drawingId) async {
    try {
      _logger.i('🗑️ DrawingService: Deleting drawing: $drawingId');

      final drawingDoc = await _firestore
          .collection('Drawings')
          .doc(drawingId)
          .get();

      if (!drawingDoc.exists) {
        throw Exception('Drawing not found');
      }

      final drawing = DrawingModel.fromFirestore(drawingDoc);

      // Delete from Storage
      final ref = _storage.refFromURL(drawing.url);
      await ref.delete();

      // Delete from Firestore
      await _firestore.collection('Drawings').doc(drawingId).delete();

      _logger.i('✅ DrawingService: Drawing deleted successfully');
    } catch (e) {
      _logger.e('❌ DrawingService: Failed to delete drawing', error: e);
      rethrow;
    }
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'dwg':
        return 'application/acad';
      case 'dxf':
        return 'application/dxf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      default:
        return 'application/octet-stream';
    }
  }
}
