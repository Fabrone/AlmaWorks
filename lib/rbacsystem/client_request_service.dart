// services/client_request_service.dart
import 'package:almaworks/rbacsystem/client_request_model.dart';
import 'package:almaworks/rbacsystem/notification_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class ClientRequestService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final Logger _logger = Logger();

  // Submit a client access request
  Future<String?> submitClientRequest({
    required String clientUsername,
    required String clientEmail,
    required String clientUid,
  }) async {
    try {
      _logger.i('📝 Submitting client request for: $clientUsername');

      // Check if user already has a pending request
      final existingRequest = await _firestore
          .collection('ClientRequests')
          .where('clientUid', isEqualTo: clientUid)
          .where('status', isEqualTo: 'pending')
          .get();

      if (existingRequest.docs.isNotEmpty) {
        _logger.w('⚠️ User already has a pending request');
        return 'You already have a pending access request.';
      }

      // Create new request
      final request = ClientRequest(
        requestId: '', // Will be set by Firestore
        clientUsername: clientUsername,
        clientEmail: clientEmail,
        clientUid: clientUid,
        requestDate: DateTime.now(),
        status: 'pending',
      );

      final docRef = await _firestore
          .collection('ClientRequests')
          .add(request.toFirestore());

      _logger.i('✅ Client request created: ${docRef.id}');

      // Notify all admins
      await _notificationService.notifyAdminsOfClientRequest(
        clientUsername: clientUsername,
        requestId: docRef.id,
      );

      return null; // Success
    } catch (e) {
      _logger.e('❌ Error submitting client request: $e');
      return 'Failed to submit request. Please try again.';
    }
  }

  // Get all pending requests (for admins)
  Stream<List<ClientRequest>> getPendingRequests() {
    return _firestore
        .collection('ClientRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClientRequest.fromFirestore(doc))
            .toList());
  }

  // Get all requests (for admins)
  Stream<List<ClientRequest>> getAllRequests() {
    return _firestore
        .collection('ClientRequests')
        .orderBy('requestDate', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ClientRequest.fromFirestore(doc))
            .toList());
  }

  // Get client's request status
  Stream<ClientRequest?> getClientRequestStatus(String clientUid) {
    return _firestore
        .collection('ClientRequests')
        .where('clientUid', isEqualTo: clientUid)
        .orderBy('requestDate', descending: true)
        .limit(1)
        .snapshots()
        .map((snapshot) {
          if (snapshot.docs.isEmpty) return null;
          return ClientRequest.fromFirestore(snapshot.docs.first);
        });
  }

  // Approve client request
  Future<String?> approveClientRequest({
    required String requestId,
    required List<String> projectIds,
    required String approvedByUsername,
    required String approvedByUid,
  }) async {
    try {
      _logger.i('✅ Approving request: $requestId');

      // Get the request first
      final requestDoc = await _firestore
          .collection('ClientRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return 'Request not found';
      }

      final request = ClientRequest.fromFirestore(requestDoc);

      // Update request status
      await _firestore.collection('ClientRequests').doc(requestId).update({
        'status': 'approved',
        'grantedProjects': projectIds,
        'approvedBy': approvedByUsername,
        'approvedByUid': approvedByUid,
        'approvalDate': Timestamp.now(),
      });

      // Update user's role to include project access
      await _updateClientProjectAccess(
        clientUid: request.clientUid,
        projectIds: projectIds,
      );

      // Get project names for notification
      final projectNames = await _getProjectNames(projectIds);

      // Notify client
      await _notificationService.notifyClientOfApproval(
        clientUsername: request.clientUsername,
        projectNames: projectNames,
      );

      _logger.i('✅ Request approved successfully');
      return null; // Success
    } catch (e) {
      _logger.e('❌ Error approving request: $e');
      return 'Failed to approve request. Please try again.';
    }
  }

  // Deny client request
  Future<String?> denyClientRequest({
    required String requestId,
    required String deniedByUsername,
    required String deniedByUid,
    String? reason,
  }) async {
    try {
      _logger.i('❌ Denying request: $requestId');

      // Get the request first
      final requestDoc = await _firestore
          .collection('ClientRequests')
          .doc(requestId)
          .get();

      if (!requestDoc.exists) {
        return 'Request not found';
      }

      final request = ClientRequest.fromFirestore(requestDoc);

      // Update request status
      await _firestore.collection('ClientRequests').doc(requestId).update({
        'status': 'denied',
        'approvedBy': deniedByUsername,
        'approvedByUid': deniedByUid,
        'approvalDate': Timestamp.now(),
        'denialReason': reason,
      });

      // Notify client
      await _notificationService.notifyClientOfDenial(
        clientUsername: request.clientUsername,
        reason: reason,
      );

      _logger.i('✅ Request denied successfully');
      return null; // Success
    } catch (e) {
      _logger.e('❌ Error denying request: $e');
      return 'Failed to deny request. Please try again.';
    }
  }

  // Update client's project access
  Future<void> _updateClientProjectAccess({
    required String clientUid,
    required List<String> projectIds,
  }) async {
    try {
      // Find the user document by UID
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: clientUid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        throw Exception('User not found');
      }

      final userDoc = userQuery.docs.first;

      // Get existing granted projects
      final userData = userDoc.data();
      final existingProjects = List<String>.from(
        userData['grantedProjects'] ?? [],
      );

      // Merge with new projects (avoid duplicates)
      final updatedProjects = {...existingProjects, ...projectIds}.toList();

      // Update user document
      await _firestore.collection('Users').doc(userDoc.id).update({
        'grantedProjects': updatedProjects,
      });

      _logger.i('✅ Client project access updated');
    } catch (e) {
      _logger.e('❌ Error updating client project access: $e');
      rethrow;
    }
  }

  // Get project names
  Future<List<String>> _getProjectNames(List<String> projectIds) async {
    try {
      final projectNames = <String>[];

      for (final projectId in projectIds) {
        final projectDoc = await _firestore
            .collection('projects')
            .doc(projectId)
            .get();

        if (projectDoc.exists) {
          final data = projectDoc.data();
          projectNames.add(data?['name'] ?? 'Unknown Project');
        }
      }

      return projectNames;
    } catch (e) {
      _logger.e('❌ Error getting project names: $e');
      return [];
    }
  }

  // Revoke client access to specific projects
  Future<String?> revokeClientAccess({
    required String clientUid,
    required List<String> projectIdsToRevoke,
  }) async {
    try {
      _logger.i('🔒 Revoking access for client: $clientUid');

      // Find the user document
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: clientUid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return 'User not found';
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      final currentProjects = List<String>.from(
        userData['grantedProjects'] ?? [],
      );

      // Remove the specified projects
      final updatedProjects = currentProjects
          .where((id) => !projectIdsToRevoke.contains(id))
          .toList();

      // Update user document
      await _firestore.collection('Users').doc(userDoc.id).update({
        'grantedProjects': updatedProjects,
      });

      _logger.i('✅ Client access revoked successfully');
      return null; // Success
    } catch (e) {
      _logger.e('❌ Error revoking client access: $e');
      return 'Failed to revoke access. Please try again.';
    }
  }

  // Get client's granted projects
  Future<List<String>> getClientGrantedProjects(String clientUid) async {
    try {
      final userQuery = await _firestore
          .collection('Users')
          .where('uid', isEqualTo: clientUid)
          .limit(1)
          .get();

      if (userQuery.docs.isEmpty) {
        return [];
      }

      final userData = userQuery.docs.first.data();
      return List<String>.from(userData['grantedProjects'] ?? []);
    } catch (e) {
      _logger.e('❌ Error getting client granted projects: $e');
      return [];
    }
  }
}