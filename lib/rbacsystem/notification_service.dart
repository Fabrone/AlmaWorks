import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final Logger _logger = Logger();

  // Initialize notifications (using existing Awesome Notifications)
  Future<void> initialize() async {
    try {
      // Request permissions for notifications
      await _requestPermissions();

      // Configure FCM
      await _configureFCM();

      _logger.i('✅ NotificationService: Initialized successfully');
    } catch (e) {
      _logger.e('❌ NotificationService: Initialization failed', error: e);
    }
  }

  // Request notification permissions
  Future<void> _requestPermissions() async {
    try {
      // Request permissions using Awesome Notifications
      final isAllowed = await AwesomeNotifications().isNotificationAllowed();
      
      if (!isAllowed) {
        await AwesomeNotifications().requestPermissionToSendNotifications();
      }

      // iOS FCM permissions
      await _fcm.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      _logger.i('✅ Notification permissions requested');
    } catch (e) {
      _logger.e('❌ Error requesting permissions', error: e);
    }
  }

  // Configure Firebase Cloud Messaging
  Future<void> _configureFCM() async {
    try {
      // Get FCM token
      final token = await _fcm.getToken();
      _logger.i('📱 FCM Token: $token');

      // Handle foreground messages
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _logger.i('📨 Foreground message received: ${message.notification?.title}');
        _showLocalNotification(
          title: message.notification?.title ?? 'New Notification',
          body: message.notification?.body ?? '',
          payload: message.data,
        );
      });

      // Handle background message taps
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _logger.i('📬 Notification tapped (background): ${message.data}');
        _handleNotificationRoute(message.data);
      });

      // Handle terminated state message taps
      final initialMessage = await _fcm.getInitialMessage();
      if (initialMessage != null) {
        _logger.i('📭 Notification tapped (terminated): ${initialMessage.data}');
        _handleNotificationRoute(initialMessage.data);
      }
    } catch (e) {
      _logger.e('❌ Error configuring FCM', error: e);
    }
  }

  // Show local notification using Awesome Notifications
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    Map<String, dynamic>? payload,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'client_requests',
          title: title,
          body: body,
          payload: payload?.map((key, value) => MapEntry(key, value.toString())),
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          category: NotificationCategory.Message,
        ),
      );
      
      _logger.i('✅ Local notification shown');
    } catch (e) {
      _logger.e('❌ Error showing notification', error: e);
    }
  }

  // Handle notification routing
  void _handleNotificationRoute(Map<String, dynamic> data) {
    final route = data['route'] ?? '';
    _logger.i('📍 Routing to: $route');
    // Navigation will be handled by the app's navigation system
  }

  // Send notification to all admins about client request
  Future<void> notifyAdminsOfClientRequest({
    required String clientUsername,
    required String requestId,
  }) async {
    try {
      // Get all admin users
      final adminsSnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('role', whereIn: ['Admin', 'MainAdmin'])
          .get();

      _logger.i('📢 Sending notifications to ${adminsSnapshot.docs.length} admins');

      // Show local notification using Awesome Notifications
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'client_requests',
          title: '🔔 New Client Access Request',
          body: '$clientUsername is requesting access to projects',
          payload: {
            'type': 'client_request',
            'route': 'client_requests',
            'requestId': requestId,
          },
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          category: NotificationCategory.Message,
        ),
        actionButtons: [
          NotificationActionButton(
            key: 'VIEW',
            label: 'View Request',
            actionType: ActionType.Default,
          ),
        ],
      );

      _logger.i('✅ Admin notifications sent successfully');
    } catch (e) {
      _logger.e('❌ Error sending admin notifications: $e');
    }
  }

  // Send notification to client about request approval
  Future<void> notifyClientOfApproval({
    required String clientUsername,
    required List<String> projectNames,
  }) async {
    try {
      final projectList = projectNames.join(', ');
      
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'client_requests',
          title: '✅ Access Granted',
          body: 'Your request has been approved! You now have access to: $projectList',
          payload: {
            'type': 'client_request',
            'route': 'dashboard',
            'status': 'approved',
          },
          notificationLayout: NotificationLayout.BigText,
          wakeUpScreen: true,
          category: NotificationCategory.Message,
        ),
      );

      _logger.i('✅ Client approval notification sent');
    } catch (e) {
      _logger.e('❌ Error sending client approval notification: $e');
    }
  }

  // Send notification to client about request denial
  Future<void> notifyClientOfDenial({
    required String clientUsername,
    String? reason,
  }) async {
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          channelKey: 'client_requests',
          title: '❌ Request Denied',
          body: reason ?? 'Your access request was denied by an administrator.',
          payload: {
            'type': 'client_request',
            'route': 'dashboard',
            'status': 'denied',
          },
          notificationLayout: NotificationLayout.Default,
          wakeUpScreen: true,
          category: NotificationCategory.Message,
        ),
      );

      _logger.i('✅ Client denial notification sent');
    } catch (e) {
      _logger.e('❌ Error sending client denial notification: $e');
    }
  }
}