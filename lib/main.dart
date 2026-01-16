import 'package:almaworks/authentication/registration_screen.dart';
import 'package:almaworks/screens/utils/app_theme.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
//import 'screens/dashboard_screen.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  final Logger logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 8,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );

  try {
    logger.i('🚀 Starting AlmaWorks application initialization');
    
    // Initialize Firebase with proper options
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    logger.i('✅ Firebase initialized successfully');
    
    // Enable Firestore offline persistence
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
    logger.i('✅ Firestore settings configured');

    // UPDATED: Initialize Awesome Notifications early
    await AwesomeNotifications().initialize(
      null, // Use default app icon
      [
        NotificationChannel(
          channelKey: 'schedule_overdue',
          channelName: 'Overdue Tasks',
          channelDescription: 'Notifications for overdue tasks',
          defaultColor: Colors.red,
          ledColor: Colors.red,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'schedule_starting_soon',
          channelName: 'Starting Soon Tasks',
          channelDescription: 'Notifications for tasks starting soon',
          defaultColor: Colors.orange,
          ledColor: Colors.orange,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
        NotificationChannel(
          channelKey: 'schedule_summary',
          channelName: 'Task Summary',
          channelDescription: 'Grouped task notifications',
          defaultColor: Colors.blue,
          ledColor: Colors.blue,
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: false,
    );
    logger.i('✅ Awesome Notifications initialized successfully');

    runApp(AlmaWorksApp(logger: logger));
    logger.i('✅ AlmaWorks app started successfully');
    
  } catch (e, stackTrace) {
    logger.e('❌ Failed to initialize AlmaWorks app', error: e, stackTrace: stackTrace);
    runApp(ErrorApp(error: e.toString()));
  }
}

// UPDATED: Changed to StatefulWidget to handle notification actions
class AlmaWorksApp extends StatefulWidget {
  final Logger logger;
  
  const AlmaWorksApp({super.key, required this.logger});

  @override
  State<AlmaWorksApp> createState() => _AlmaWorksAppState();
}

class _AlmaWorksAppState extends State<AlmaWorksApp> {
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    
    widget.logger.i('🔔 Setting up notification action listeners');
    
    // ADDED: Listen to notification actions when user taps from system tray
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        widget.logger.i('👆 User tapped notification: ${receivedAction.id}');
        
        // Handle different button actions
        if (receivedAction.payload != null) {
          final projectId = receivedAction.payload!['projectId'];
          final taskId = receivedAction.payload!['taskId'];
          final notificationId = receivedAction.payload!['notificationId'];
          
          widget.logger.d('Payload: projectId=$projectId, taskId=$taskId, notifId=$notificationId');
          
          // Mark as read and opened when user taps
          if (notificationId != null) {
            try {
              await FirebaseFirestore.instance
                  .collection('ScheduleNotifications')
                  .doc(notificationId)
                  .update({
                    'isRead': true,
                    'openedFromTray': true,
                    'openedAt': FieldValue.serverTimestamp(),
                    'readSource': 'system_tray',
                  });
              widget.logger.i('✅ Marked notification as read from system tray');
            } catch (e) {
              widget.logger.e('Error marking notification as read', error: e);
            }
          }
          
          // The notification center will show all notifications when opened
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    widget.logger.i('🏗️ Building AlmaWorks main app widget');
    
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      navigatorKey: navigatorKey,
      title: 'AlmaWorks',
      theme: AppTheme.lightTheme,
      //home: DashboardScreen(logger: widget.logger),
      home: RegistrationScreen(logger: widget.logger),
      debugShowCheckedModeBanner: false,
    );
  }
}

class ErrorApp extends StatelessWidget {
  final String error;
  
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Failed to initialize AlmaWorks',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}