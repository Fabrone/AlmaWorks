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

  Future<void> markAllAsRead(String projectId) async {
    if (_deviceId == null) await initialize();

    try {
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('projectId', isEqualTo: projectId)
          .where('deviceId', isEqualTo: _deviceId);
      
      // Only filter by userId if authentication is implemented
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }
      
      final snapshot = await query.where('isRead', isEqualTo: false).get();

      final batch = _firestore.batch();
      for (var doc in snapshot.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
      
      logger.i('✅ All notifications marked as read for project $projectId');
    } catch (e) {
      logger.e('Error marking all notifications as read', error: e);
    }
  }

  Stream<int> getUnreadCount(String projectId) {
    return Stream.fromFuture(_ensureInitialized()).asyncExpand((_) {
      Query query = _firestore
          .collection('ScheduleNotifications')
          .where('projectId', isEqualTo: projectId)
          .where('deviceId', isEqualTo: _deviceId);
      
      if (userId != null) {
        query = query.where('userId', isEqualTo: userId);
      }

      return query
          .where('isRead', isEqualTo: false)
          .snapshots()
          .map((snapshot) => snapshot.docs.length);
    });
  }

  Stream<List<ScheduleNotification>> getNotifications(String projectId) {
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