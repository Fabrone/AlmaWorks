import 'package:almaworks/authentication/login_screen.dart';
import 'package:almaworks/authentication/welcome_screen.dart';
import 'package:almaworks/providers/locale_provider.dart';
import 'package:almaworks/rbacsystem/auth_service.dart';
import 'package:almaworks/screens/utils/app_theme.dart';
import 'package:almaworks/services/notification_service.dart';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_localizations/flutter_localizations.dart'; // ← ADDED
import 'package:flutter_quill/flutter_quill.dart' show FlutterQuillLocalizations; // ← ADDED
import 'package:logger/logger.dart';
import 'firebase_options.dart';

// ─── Global LocaleProvider ────────────────────────────────────────────────────
final LocaleProvider localeProvider = LocaleProvider();
// ─────────────────────────────────────────────────────────────────────────────

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

    // Initialize Awesome Notifications for schedule/task notifications
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
        NotificationChannel(
          channelKey: 'client_requests',
          channelName: 'Client Access Requests',
          channelDescription: 'Notifications for client access requests',
          defaultColor: const Color(0xFF0A2E5A),
          ledColor: const Color(0xFF0A2E5A),
          importance: NotificationImportance.Max,
          channelShowBadge: true,
          playSound: true,
          enableVibration: true,
        ),
      ],
      debug: false,
    );
    logger.i('✅ Awesome Notifications initialized successfully');

    // Initialize Flutter Local Notifications Service for client requests
    try {
      await NotificationService(logger: logger).initialize();
      logger.i('✅ Notification Service initialized successfully');
    } catch (e) {
      logger.w('⚠️ Notification Service initialization failed (non-critical): $e');
      // Non-critical - app can continue without notification service
    }

    runApp(AlmaWorksApp(logger: logger));
    logger.i('✅ AlmaWorks app started successfully');
  } catch (e, stackTrace) {
    logger.e('❌ Failed to initialize AlmaWorks app',
        error: e, stackTrace: stackTrace);
    runApp(ErrorApp(error: e.toString()));
  }
}

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

    // Listen to notification actions when user taps from system tray
    AwesomeNotifications().setListeners(
      onActionReceivedMethod: (ReceivedAction receivedAction) async {
        widget.logger.i('👆 User tapped notification: ${receivedAction.id}');

        if (receivedAction.payload != null) {
          final notificationType = receivedAction.payload!['type'];

          // Handle schedule/task notifications
          if (notificationType == 'schedule' || notificationType == null) {
            final projectId = receivedAction.payload!['projectId'];
            final taskId = receivedAction.payload!['taskId'];
            final notificationId = receivedAction.payload!['notificationId'];

            widget.logger.d(
                'Schedule notification: projectId=$projectId, taskId=$taskId, notifId=$notificationId');

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
          }

          // Handle client request notifications
          else if (notificationType == 'client_request') {
            widget.logger.d('Client request notification tapped');
            // Navigation will be handled by the NotificationService
          }
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

    // ListenableBuilder rebuilds MaterialApp whenever localeProvider changes,
    // which causes the entire widget tree to adopt the new locale immediately.
    return ListenableBuilder(
      listenable: localeProvider,
      builder: (context, _) => MaterialApp(
        navigatorKey: navigatorKey,
        title: 'AlmaWorks',
        theme: AppTheme.lightTheme,
        debugShowCheckedModeBanner: false,
        locale: localeProvider.locale,

        // ── Localization delegates ────────────────────────────────────────
        // GlobalMaterialLocalizations  → Material widget strings (date pickers, etc.)
        // GlobalCupertinoLocalizations → Cupertino widget strings (iOS-style widgets)
        // GlobalWidgetsLocalizations   → Text direction (LTR / RTL)
        // FlutterQuillLocalizations    → Quill toolbar tooltips & editor strings
        //                               Without this, every QuillSimpleToolbar button
        //                               throws MissingFlutterQuillLocalizationException.
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,   // ← ADDED
          GlobalCupertinoLocalizations.delegate,  // ← ADDED
          GlobalWidgetsLocalizations.delegate,    // ← ADDED
          FlutterQuillLocalizations.delegate,     // ← ADDED (fixes Quill crash)
        ],

        supportedLocales: LocaleProvider.supportedLocales,
        home: AuthenticationWrapper(logger: widget.logger),
      ),
    );
  }
}

// Authentication wrapper to handle persistent login
class AuthenticationWrapper extends StatefulWidget {
  final Logger logger;

  const AuthenticationWrapper({super.key, required this.logger});

  @override
  State<AuthenticationWrapper> createState() => _AuthenticationWrapperState();
}

class _AuthenticationWrapperState extends State<AuthenticationWrapper> {
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  bool _isLoggedIn = false;
  String _username = '';
  String _role = '';

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      widget.logger.i('🔍 Checking authentication status...');

      final isLoggedIn = await _authService.isUserLoggedIn();

      if (isLoggedIn) {
        widget.logger.i('✅ User is logged in, fetching user data...');

        final userData = await _authService.getUserData();

        if (userData != null) {
          setState(() {
            _isLoggedIn = true;
            _username = userData['username'] ?? '';
            _role = userData['role'] ?? 'Client';
            _isLoading = false;
          });

          widget.logger.i('✅ User data loaded: $_username ($_role)');
        } else {
          widget.logger.w('⚠️ User data not found, redirecting to login');
          setState(() {
            _isLoggedIn = false;
            _isLoading = false;
          });
        }
      } else {
        widget.logger.i('❌ User not logged in');
        setState(() {
          _isLoggedIn = false;
          _isLoading = false;
        });
      }
    } catch (e) {
      widget.logger.e('❌ Error checking authentication: $e');
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A2E5A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 20),
              const Text(
                'AlmaWorks',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Site Management System',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.8),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoggedIn) {
      widget.logger.i('🎯 Routing to WelcomeScreen for $_username');
      return WelcomeScreen(
        username: _username,
        initialRole: _role,
      );
    } else {
      widget.logger.i('🎯 Routing to LoginScreen');
      return const LoginScreen();
    }
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