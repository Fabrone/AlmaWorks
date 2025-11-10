import 'package:almaworks/models/notification_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'dart:io' show Platform;

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Logger logger;
  String? _deviceId;
  final String? userId; // Optional for testing phase

  NotificationService({required this.logger, this.userId});

  // Initialize device ID
  Future<void> initialize() async {
    _deviceId = await _getDeviceId();
  }

  Future<String> _getDeviceId() async {
    final deviceInfo = DeviceInfoPlugin();
    try {
      if (kIsWeb) {
        final webInfo = await deviceInfo.webBrowserInfo;
        return 'web_${webInfo.userAgent?.hashCode ?? 'unknown'}';
      } else if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return 'android_${androidInfo.id}';
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return 'ios_${iosInfo.identifierForVendor ?? 'unknown'}';
      } else if (Platform.isWindows) {
        final windowsInfo = await deviceInfo.windowsInfo;
        return 'windows_${windowsInfo.deviceId}';
      } else if (Platform.isMacOS) {
        final macInfo = await deviceInfo.macOsInfo;
        return 'macos_${macInfo.systemGUID ?? 'unknown'}';
      } else if (Platform.isLinux) {
        final linuxInfo = await deviceInfo.linuxInfo;
        return 'linux_${linuxInfo.machineId ?? 'unknown'}';
      }
    } catch (e) {
      logger.e('Error getting device ID', error: e);
    }
    return 'unknown_${DateTime.now().millisecondsSinceEpoch}';
  }

  Future<bool> wasNotificationSentToday(String projectId, String taskId) async {
    if (_deviceId == null) await initialize();
    
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    try {
      // Start with base query
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('projectId', isEqualTo: projectId)
          .where('taskId', isEqualTo: taskId)
          .where('deviceId', isEqualTo: _deviceId);
      
      // Only filter by userId if authentication is implemented
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      final snapshot = await query
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } catch (e) {
      logger.e('Error checking notification history', error: e);
      return false;
    }
  }

  // Save notification to Firestore
  Future<String?> saveNotification({
    required String projectId,
    required String taskId,
    required String taskName,
    required DateTime startDate,
    required String message,
  }) async {
    if (_deviceId == null) await initialize();

    try {
      final notification = ScheduleNotification(
        id: '', // Will be set by Firestore
        projectId: projectId,
        taskId: taskId,
        taskName: taskName,
        startDate: startDate,
        message: message,
        createdAt: DateTime.now(),
        isRead: false,
        userId: userId,
        deviceId: _deviceId!,
      );

      final docRef = await _firestore
          .collection('ScheduleNotifications')
          .add(notification.toFirestore());

      logger.i('✅ Notification saved with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      logger.e('Error saving notification', error: e);
      return null;
    }
  }

  // NEW: Batch check if notifications were sent today
  Future<Map<String, bool>> batchCheckNotificationsSentToday(
    String projectId, 
    List<String> taskIds,
  ) async {
    if (_deviceId == null) await initialize();
    
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    
    try {
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('projectId', isEqualTo: projectId)
          .where('deviceId', isEqualTo: _deviceId)
          .where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay));
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      final snapshot = await query.get();
      
      // Create a map of taskId -> wasSentToday
      final Map<String, bool> sentStatus = {};
      final Set<String> sentTaskIds = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .map((data) => data['taskId'] as String?)
          .where((id) => id != null)
          .cast<String>()
          .toSet();
      
      for (var taskId in taskIds) {
        sentStatus[taskId] = sentTaskIds.contains(taskId);
      }
      
      return sentStatus;
    } catch (e) {
      logger.e('Error batch checking notification history', error: e);
      // Return all false on error to allow notifications
      return { for (var id in taskIds) id : false };
    }
  }

  // NEW: Batch save notifications
  Future<List<String>> batchSaveNotifications({
    required String projectId,
    required List<Map<String, dynamic>> notifications,
  }) async {
    if (_deviceId == null) await initialize();

    try {
      final batch = _firestore.batch();
      final List<String> docIds = [];
      final now = DateTime.now();

      for (var notificationData in notifications) {
        final docRef = _firestore.collection('ScheduleNotifications').doc();
        docIds.add(docRef.id);

        final notification = ScheduleNotification(
          id: docRef.id,
          projectId: projectId,
          taskId: notificationData['taskId'] as String,
          taskName: notificationData['taskName'] as String,
          startDate: notificationData['startDate'] as DateTime,
          message: notificationData['message'] as String,
          createdAt: now,
          isRead: false,
          userId: userId,
          deviceId: _deviceId!,
        );

        batch.set(docRef, notification.toFirestore());
      }

      await batch.commit();
      logger.i('✅ Batch saved ${notifications.length} notifications');
      return docIds;
    } catch (e) {
      logger.e('Error batch saving notifications', error: e);
      return [];
    }
  }

  // Mark notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore
          .collection('ScheduleNotifications')
          .doc(notificationId)
          .update({'isRead': true});
      logger.i('✅ Notification $notificationId marked as read');
    } catch (e) {
      logger.e('Error marking notification as read', error: e);
    }
  }

  // UPDATED: Batch mark as read with better error handling
  Future<void> markAllAsRead(String projectId) async {
    if (_deviceId == null) await initialize();

    try {
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('projectId', isEqualTo: projectId)
          .where('deviceId', isEqualTo: _deviceId)
          .where('isRead', isEqualTo: false);
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      final snapshot = await query.get();

      if (snapshot.docs.isEmpty) {
        logger.i('ℹ️ No unread notifications to mark');
        return;
      }

      // Firestore batch limit is 500, so chunk if needed
      final chunks = <List<QueryDocumentSnapshot>>[];
      for (var i = 0; i < snapshot.docs.length; i += 500) {
        chunks.add(snapshot.docs.skip(i).take(500).toList());
      }

      for (var chunk in chunks) {
        final batch = _firestore.batch();
        for (var doc in chunk) {
          batch.update(doc.reference, {'isRead': true});
        }
        await batch.commit();
      }
      
      logger.i('✅ Marked ${snapshot.docs.length} notifications as read for project $projectId');
    } catch (e) {
      logger.e('Error marking all notifications as read', error: e);
      rethrow;
    }
  }

  // UPDATED: More efficient unread count
  Stream<int> getUnreadCount(String projectId) {
    return Stream.fromFuture(_ensureInitialized()).asyncExpand((_) {
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('projectId', isEqualTo: projectId)
          .where('deviceId', isEqualTo: _deviceId)
          .where('isRead', isEqualTo: false);
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      return query
          .snapshots()
          .map((snapshot) => snapshot.size); // More efficient than docs.length
    });
  }

  // UPDATED: Optimized with pagination support
  Stream<List<ScheduleNotification>> getNotifications(
    String projectId, {
    int limit = 50,
  }) {
    return Stream.fromFuture(_ensureInitialized()).asyncExpand((_) {
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('projectId', isEqualTo: projectId)
          .where('deviceId', isEqualTo: _deviceId);
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      return query
          .orderBy('createdAt', descending: true)
          .limit(limit)
          .snapshots()
          .map((snapshot) => snapshot.docs
              .map((doc) => ScheduleNotification.fromFirestore(
                  doc.id, doc.data() as Map<String, dynamic>))
              .toList());
    });
  }

  // Add this helper method to the class
  Future<void> _ensureInitialized() async {
    if (_deviceId == null) {
      await initialize();
    }
  }

  Future<void> cleanupOldNotifications({int daysToKeep = 30}) async {
    if (_deviceId == null) await initialize();

    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));
    
    try {
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('deviceId', isEqualTo: _deviceId);
      
      // Only filter by userId if authentication is implemented
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      final snapshot = await query
          .where('createdAt', isLessThan: Timestamp.fromDate(cutoffDate))
          .get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();
      
      logger.i('✅ Cleaned up ${snapshot.docs.length} old notifications');
    } catch (e) {
      logger.e('Error cleaning up old notifications', error: e);
    }
  }
}