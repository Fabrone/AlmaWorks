import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/screens/schedule/notification_center_screen.dart';
import 'package:almaworks/services/notification_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:elegant_notification/elegant_notification.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:workmanager/workmanager.dart' hide TaskStatus;
import 'dart:async';

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((taskName, inputData) async {
    try {
      tzdata.initializeTimeZones();

      final String? projectId = inputData?['projectId'] as String?;
      final String? userId = inputData?['userId'] as String?; // Can be null

      if (projectId == null) {
        return Future.value(false);
      }

      // Initialize notification service for background
      final notificationService = NotificationService(
        logger: Logger(),
        userId: userId, // Pass null if not provided
      );
      await notificationService.initialize();

      // Fetch tasks from Firestore
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: projectId)
          .get();

      final List<GanttRowData> tasks = snapshot.docs.map((doc) {
        return GanttRowData.fromFirebaseMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      final DateTime now = DateTime.now();

      // Auto-update overdue tasks
      for (var task in tasks) {
        if (task.startDate != null && task.startDate!.isBefore(now) &&
            (task.status == null || (task.status != TaskStatus.started && task.status != TaskStatus.completed))) {
          await FirebaseFirestore.instance
              .collection('Schedule')
              .doc(task.firestoreId)
              .update({'status': TaskStatus.overdue.toString().split('.').last.toUpperCase()});
        }
      }

      // Check for upcoming tasks within <=3 days
      final List<GanttRowData> upcomingTasks = tasks.where((task) {
        if (task.startDate == null) return false;
        final diff = task.startDate!.difference(now).inDays;
        return diff <= 3 && diff > 0 && (task.status == null || task.status != TaskStatus.completed);
      }).toList();

      if (upcomingTasks.isEmpty) {
        return Future.value(true);
      }

      // Check which notifications haven't been sent today
      final List<GanttRowData> unsentTasks = [];
      for (var task in upcomingTasks) {
        final wasSent = await notificationService.wasNotificationSentToday(
          projectId,
          task.firestoreId ?? '',
        );
        if (!wasSent) {
          unsentTasks.add(task);
        }
      }

      if (unsentTasks.isEmpty) {
        return Future.value(true);
      }

      // Save notifications to tracking system
      for (var task in unsentTasks) {
        await notificationService.saveNotification(
          projectId: projectId,
          taskId: task.firestoreId ?? '',
          taskName: task.taskName ?? 'Untitled',
          startDate: task.startDate!,
          message: 'Task starts in ${task.startDate!.difference(now).inDays} days',
        );
      }

      // Initialize and show grouped notification
      final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
      const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
      final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      final InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
      await notifications.initialize(initSettings);

      final String taskNames = unsentTasks.map((t) => t.taskName ?? 'Untitled').join(', ');
      final String body = unsentTasks.length == 1
          ? 'Task "${unsentTasks.first.taskName}" is starting soon!'
          : '${unsentTasks.length} tasks starting soon: $taskNames';

      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'schedule_monitor_channel',
        'Schedule Monitor Notifications',
        importance: Importance.high,
        priority: Priority.high,
        ongoing: true,
        autoCancel: false,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('open', 'View Tasks'),
        ],
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await notifications.show(
        projectId.hashCode,
        'Tasks Starting Soon',
        body,
        details,
        payload: projectId,
      );

      FlutterRingtonePlayer().playNotification();

      return Future.value(true);
    } catch (e) {
      return Future.value(false);
    }
  });
}

class ScheduleMonitorScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final Logger logger;
  final ProjectModel project;

  const ScheduleMonitorScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.logger,
    required this.project,
  });

  @override
  State<ScheduleMonitorScreen> createState() => _ScheduleMonitorScreenState();
}

class _ScheduleMonitorScreenState extends State<ScheduleMonitorScreen> with SingleTickerProviderStateMixin {
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late NotificationService _notificationService;
  int _unreadNotificationCount = 0;
  DateTime? _lastNotificationCheck;
  bool _isCheckingNotifications = false;

  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<GanttRowData> _startingSoonTasks = [];
  List<GanttRowData> _otherUpcomingTasks = [];
  List<GanttRowData> _ongoingTasks = [];
  List<GanttRowData> _completedTasks = [];
  List<GanttRowData> _overdueTasks = [];

  Timer? _refreshTimer;

  // UPDATED: Better timer management
  @override
  void initState() {
    super.initState();
    
    _notificationService = NotificationService(
      logger: widget.logger,
      userId: null,
    );
    
    _notificationService.initialize().then((_) {
      if (mounted && !kIsWeb) {
        // Initial check after 2 seconds
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) _scheduleNotificationCheck();
        });
      }
    });
    
    _notificationService.getUnreadCount(widget.projectId).listen((unreadCount) {
      if (mounted) {
        setState(() {
          _unreadNotificationCount = unreadCount;
        });
      }
    }, onError: (error) {
      widget.logger.e('Error listening to unread count', error: error);
    });
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    tzdata.initializeTimeZones();
    
    if (!kIsWeb) {
      _initializeNotifications();
      _initializeBackgroundTasks();
    }

    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });

    // Check notifications every 30 minutes (reduced frequency)
    _refreshTimer = Timer.periodic(const Duration(minutes: 30), (timer) {
      if (mounted && !kIsWeb) {
        _scheduleNotificationCheck();
      }
    });
  }

  void _initializeBackgroundTasks() {
    Workmanager().initialize(callbackDispatcher);

    Workmanager().registerPeriodicTask(
      "${widget.projectId}_hourly_check",
      "scheduleMonitorTask",
      frequency: const Duration(hours: 1),
      inputData: {
        'projectId': widget.projectId,
        'userId': null, // Set to null during testing
        // Later when I implement auth, change to:
        // 'userId': FirebaseAuth.instance.currentUser?.uid,
      },
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
    );
    widget.logger.i('Registered background task for project ${widget.projectId}');
  }

  Future<void> _initializeNotifications() async {
    _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

    const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
      notificationCategories: [
        DarwinNotificationCategory(
          'actions',
          actions: <DarwinNotificationAction>[
            DarwinNotificationAction.plain('snooze', 'Snooze (1 day)'),
            DarwinNotificationAction.plain('open', 'Open App'),
          ],
        ),
      ],
    );
    final InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);

    await _flutterLocalNotificationsPlugin!.initialize(
      initSettings,
      onDidReceiveNotificationResponse: _onDidReceiveNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: _onDidReceiveBackgroundNotificationResponse,
    );

    if (await Permission.notification.request().isGranted) {
      widget.logger.i('Notification permission granted');
    } else {
      widget.logger.w('Notification permission not granted');
    }
  }

  Future<void> _onDidReceiveNotificationResponse(NotificationResponse response) async {
    if (!kIsWeb) {
      FlutterRingtonePlayer().playNotification();
    }
    final projectId = response.payload;
    if (projectId != null && mounted) {
      if (response.actionId == 'snooze') {
        // Snooze: Schedule same notification for tomorrow
        // Logic to reschedule (simplified, assume re-check tomorrow)
        widget.logger.i('Snoozed notification for project $projectId');
      } else {
        // Open screen (but since already in app, perhaps refresh or navigate)
        // For now, just log
        widget.logger.i('Opened from notification for project $projectId');
      }
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _onDidReceiveBackgroundNotificationResponse(NotificationResponse response) async {
    if (!kIsWeb) {
      FlutterRingtonePlayer().playNotification();
    }
    final projectId = response.payload;
    if (projectId != null) {
      if (response.actionId == 'snooze') {
        // Handle snooze in background (reschedule)
      }
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _animationController.dispose();
    _searchController.dispose();
    _isCheckingNotifications = false;
    super.dispose();
  }

  void _categorizeTasks(List<GanttRowData> tasks) {
    final DateTime now = DateTime.now();

    _startingSoonTasks = [];
    _otherUpcomingTasks = [];
    _ongoingTasks = [];
    _completedTasks = [];
    _overdueTasks = [];

    for (var task in tasks) {
      if (task.startDate == null || task.endDate == null) continue;

      TaskStatus effectiveStatus = task.status ?? TaskStatus.upcoming;
      
      if (task.actualEndDate != null) {
        effectiveStatus = TaskStatus.completed;
      } else if (task.actualStartDate != null) {
        effectiveStatus = TaskStatus.started;
      } else if (task.startDate!.isBefore(now) && 
                effectiveStatus != TaskStatus.started && 
                effectiveStatus != TaskStatus.ongoing && 
                effectiveStatus != TaskStatus.completed) {
        effectiveStatus = TaskStatus.overdue;
        _updateTaskStatus(task, TaskStatus.overdue);
      }

      switch (effectiveStatus) {
        case TaskStatus.upcoming:
          if (task.startDate!.isAfter(now)) {
            final diff = task.startDate!.difference(now).inDays;
            if (diff <= 3) {
              _startingSoonTasks.add(task);
            } else {
              _otherUpcomingTasks.add(task);
            }
          }
          break;
        case TaskStatus.ongoing:
        case TaskStatus.started:
          _ongoingTasks.add(task);
          break;
        case TaskStatus.completed:
          _completedTasks.add(task);
          break;
        case TaskStatus.overdue:
          _overdueTasks.add(task);
          break;
      }
    }

    _startingSoonTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!));
    _otherUpcomingTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!));
    _overdueTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!));
    _ongoingTasks.sort((a, b) => a.endDate!.compareTo(b.endDate!));
    _completedTasks.sort((a, b) => b.endDate!.compareTo(a.endDate!));
  }

  // UPDATED: Better rate limiting
  void _scheduleNotificationCheck() {
    final now = DateTime.now();
    
    // Only check once every 30 minutes to prevent spam
    if (_lastNotificationCheck != null && 
        now.difference(_lastNotificationCheck!).inMinutes < 30) {
      return;
    }
    
    if (_isCheckingNotifications) {
      return;
    }
    
    _lastNotificationCheck = now;
    _checkForNotifications();
  }

  Future<void> _checkForNotifications() async {
    if (kIsWeb || _isCheckingNotifications) return;
    
    _isCheckingNotifications = true;
    
    try {
      // Only check tasks starting within 3 days
      final List<GanttRowData> notifyTasks = _startingSoonTasks.where((task) {
        if (task.startDate == null) return false;
        final diff = task.startDate!.difference(DateTime.now()).inDays;
        return diff >= 0 && diff <= 3;
      }).toList();

      if (notifyTasks.isEmpty) {
        _isCheckingNotifications = false;
        return;
      }

      // Batch check all tasks at once for better performance
      final List<String> taskIds = notifyTasks
          .where((t) => t.firestoreId != null)
          .map((t) => t.firestoreId!)
          .toList();
      
      if (taskIds.isEmpty) {
        _isCheckingNotifications = false;
        return;
      }

      // Check which notifications haven't been sent today (batch operation)
      final Map<String, bool> sentStatus = 
          await _notificationService.batchCheckNotificationsSentToday(
        widget.projectId,
        taskIds,
      );

      final List<GanttRowData> unsentTasks = notifyTasks
          .where((task) => sentStatus[task.firestoreId] == false)
          .toList();

      if (unsentTasks.isEmpty) {
        widget.logger.i('ℹ️ All notifications already sent today');
        _isCheckingNotifications = false;
        return;
      }

      // Save notifications in a batch operation
      final List<Map<String, dynamic>> notificationsToSave = unsentTasks.map((task) {
        final daysUntil = task.startDate!.difference(DateTime.now()).inDays;
        return {
          'taskId': task.firestoreId ?? '',
          'taskName': task.taskName ?? 'Untitled',
          'startDate': task.startDate!,
          'message': 'Task starts in $daysUntil day${daysUntil == 1 ? '' : 's'}',
        };
      }).toList();

      await _notificationService.batchSaveNotifications(
        projectId: widget.projectId,
        notifications: notificationsToSave,
      );

      // Show SINGLE grouped system notification
      await _showGroupedNotification(unsentTasks);
      
      widget.logger.i('✅ Sent grouped notification for ${unsentTasks.length} tasks');
    } catch (e, stackTrace) {
      widget.logger.e('Error checking notifications', error: e, stackTrace: stackTrace);
    } finally {
      _isCheckingNotifications = false;
    }
  }

  Future<void> _showGroupedNotification(List<GanttRowData> tasks) async {
    if (_flutterLocalNotificationsPlugin == null) return;

    final String taskNames = tasks.map((t) => t.taskName ?? 'Untitled').take(3).join(', ');
    final String body = tasks.length == 1
        ? 'Task "${tasks.first.taskName}" is starting soon!'
        : tasks.length <= 3
            ? 'Tasks starting soon: $taskNames'
            : '${tasks.length} tasks starting soon: $taskNames and ${tasks.length - 3} more';

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'schedule_monitor_channel',
      'Schedule Monitor Notifications',
      channelDescription: 'Notifications for upcoming project tasks',
      importance: Importance.high,
      priority: Priority.high,
      groupKey: 'com.almaworks.schedule_monitor',
      setAsGroupSummary: true,
      autoCancel: true,
      actions: <AndroidNotificationAction>[
        AndroidNotificationAction('open', 'View Tasks'),
        AndroidNotificationAction('dismiss', 'Dismiss'),
      ],
    );
    
    const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );
    
    final NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _flutterLocalNotificationsPlugin!.show(
      widget.projectId.hashCode,
      'Tasks Starting Soon',
      body,
      details,
      payload: widget.projectId,
    );

    if (!kIsWeb) {
      FlutterRingtonePlayer().playNotification();
    }
  }

  Future<void> _updateTaskStatus(GanttRowData task, TaskStatus newStatus) async {
    try {
      final now = DateTime.now();
      final firestore = FirebaseFirestore.instance;
      
      // NEW: Set actual dates based on new status
      DateTime? newActualStart;
      DateTime? newActualEnd;
      
      if (newStatus == TaskStatus.started || newStatus == TaskStatus.ongoing) {
        newActualStart = task.actualStartDate ?? now;  // Use current if not set
      } else if (newStatus == TaskStatus.completed) {
        newActualStart = task.actualStartDate ?? now;  // Ensure start is set
        newActualEnd = task.actualEndDate ?? now;
      }
      
      final updateData = {
        'status': newStatus.toString().split('.').last.toUpperCase(),
        if (newActualStart != null) 'actualStartDate': Timestamp.fromDate(newActualStart),
        if (newActualEnd != null) 'actualEndDate': Timestamp.fromDate(newActualEnd),
        'updatedAt': Timestamp.now(),
      };
      
      await firestore.collection('Schedule').doc(task.firestoreId).update(updateData);
      
      if (!mounted) return;
      widget.logger.i('📅 Updated task status for ${task.taskName} to $newStatus');
      
      if (!mounted) return;
      ElegantNotification.success(
        title: const Text('Task Updated'),
        description: Text('${task.taskName} marked as ${newStatus.name}'),
      ).show(context);
      
      // Re-categorize will happen via StreamBuilder
    } catch (e, stackTrace) {
      widget.logger.e('❌ Error updating task status', error: e, stackTrace: stackTrace);
      if (!mounted) return;
      ElegantNotification.error(
        title: const Text('Error'),
        description: const Text('Failed to update task status'),
      ).show(context);
    }
  }

  List<GanttRowData> _filterTasks(List<GanttRowData> tasks) {
    if (_searchQuery.isEmpty) return tasks;
    return tasks.where((task) => (task.taskName ?? '').toLowerCase().contains(_searchQuery)).toList();
  }

  @override
  Widget build(BuildContext context) {
    final Color overdueColor = Colors.red.shade700;
    final Color ongoingColor = Colors.blue.shade600;
    final Color startingSoonColor = Colors.orange.shade700;
    final Color upcomingColor = Colors.grey.shade700;
    final Color completedColor = Colors.green.shade600;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.projectId)
          .orderBy('displayOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('❌ ScheduleMonitor: Error in stream', error: snapshot.error);
          return Center(
            child: Text(
              'Error loading data',
              style: GoogleFonts.poppins(color: Colors.red),
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        List<GanttRowData> tasks = [];
        for (var doc in snapshot.data!.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final task = GanttRowData.fromFirebaseMap(doc.id, data);
          if (task.hasData) tasks.add(task);
        }

        _categorizeTasks(tasks);
        _animationController.forward();

        if (tasks.isEmpty) return _buildEmptyState();

        final filteredOverdue = _filterTasks(_overdueTasks);
        final filteredOngoing = _filterTasks(_ongoingTasks);
        final filteredStartingSoon = _filterTasks(_startingSoonTasks);
        final filteredOtherUpcoming = _filterTasks(_otherUpcomingTasks);
        final filteredCompleted = _filterTasks(_completedTasks);
        final upcomingCount = filteredStartingSoon.length + filteredOtherUpcoming.length;

        return DefaultTabController(
          length: 4,
          child: RefreshIndicator(
            onRefresh: () async {
              _scheduleNotificationCheck(); 
            },
            child: Column(
              children: [
                // Search bar with notification icon
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: 'Search Tasks',
                            suffixIcon: const Icon(Icons.search),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Stack(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.notifications_outlined, size: 28),
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => NotificationCenterScreen(
                                    projectId: widget.projectId,
                                    notificationService: _notificationService,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'View Notifications',
                          ),
                          if (_unreadNotificationCount > 0)
                            Positioned(
                              right: 8,
                              top: 8,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(
                                  minWidth: 18,
                                  minHeight: 18,
                                ),
                                child: Text(
                                  _unreadNotificationCount > 99 
                                      ? '99+' 
                                      : _unreadNotificationCount.toString(),
                                  style: GoogleFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Tabs
                TabBar(
                  tabs: [
                    Tab(text: 'Overdue (${filteredOverdue.length})'),
                    Tab(text: 'Ongoing (${filteredOngoing.length})'),
                    Tab(text: 'Upcoming ($upcomingCount)'),
                    Tab(text: 'Completed (${filteredCompleted.length})'),
                  ],
                ),
                // Tab views
                Expanded(
                  child: TabBarView(
                    children: [
                      _buildCategoryView(filteredOverdue, overdueColor, 'Overdue'),
                      _buildCategoryView(filteredOngoing, ongoingColor, 'Ongoing'),
                      _buildUpcomingView(filteredStartingSoon, filteredOtherUpcoming, startingSoonColor, upcomingColor),
                      _buildCategoryView(filteredCompleted, completedColor, 'Completed'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryView(List<GanttRowData> filteredTasks, Color color, String title) {
    if (filteredTasks.isEmpty) {
      return _buildNoTasksWidget(title);
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildSectionHeader(title, color, filteredTasks.length),
              ...filteredTasks.map((task) => _buildTaskItem(task, color)),
              const SizedBox(height: 24), // Bottom padding
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingView(List<GanttRowData> filteredStartingSoon, List<GanttRowData> filteredOtherUpcoming, Color startingColor, Color upcomingColor) {
    if (filteredStartingSoon.isEmpty && filteredOtherUpcoming.isEmpty) {
      return _buildNoTasksWidget('Upcoming');
    }
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        FadeTransition(
          opacity: _fadeAnimation,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (filteredStartingSoon.isNotEmpty) ...[
                _buildSectionHeader('Starting Soon (≤3 days)', startingColor, filteredStartingSoon.length),
                ...filteredStartingSoon.map((task) => _buildTaskItem(task, startingColor)),
              ],
              if (filteredOtherUpcoming.isNotEmpty) ...[
                _buildSectionHeader('Other Upcoming', upcomingColor, filteredOtherUpcoming.length),
                ...filteredOtherUpcoming.map((task) => _buildTaskItem(task, upcomingColor)),
              ],
              const SizedBox(height: 24), // Bottom padding
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoTasksWidget(String title) {
    final bool isSearch = _searchQuery.isNotEmpty;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isSearch ? Icons.search_off : Icons.timeline, size: 64, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(
              isSearch ? 'No tasks match your search' : 'No $title tasks',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color color, int count) {
    return Container(
      margin: const EdgeInsets.only(top: 16, bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border(
          left: BorderSide(
            color: color,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count.toString(),
              style: GoogleFonts.poppins(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 80, color: Colors.grey.shade400),
            const SizedBox(height: 24),
            Text(
              'No Schedule Data Available',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              'Add tasks in the Gantt Chart to see schedule monitoring',
              style: GoogleFonts.poppins(
                fontSize: 16,
                color: Colors.grey.shade500,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(GanttRowData task, Color accentColor) {
    final DateTime now = DateTime.now();
    final int daysUntilStart = task.startDate!.difference(now).inDays;
    final int daysUntilEnd = task.endDate!.difference(now).inDays;
    
    String urgencyText = '';
    IconData urgencyIcon = Icons.info_outline;
    
    if (daysUntilStart <= 3 && daysUntilStart > 0) {
      urgencyText = 'Starts in $daysUntilStart day${daysUntilStart == 1 ? '' : 's'}';
      urgencyIcon = Icons.timer_outlined;
    } else if (daysUntilEnd <= 3 && daysUntilEnd >= 0) {
      urgencyText = 'Due in $daysUntilEnd day${daysUntilEnd == 1 ? '' : 's'}';
      urgencyIcon = Icons.warning_amber_outlined;
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withValues(alpha: 0.3), width: 1),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(
                width: 5,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      accentColor,
                      accentColor.withValues(alpha: 0.7),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: accentColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              task.taskName ?? 'Untitled Task',
                              style: GoogleFonts.poppins(
                                fontWeight: FontWeight.w600,
                                fontSize: 15,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ),
                          Material(
                            color: Colors.transparent,
                            child: PopupMenuButton<String>(
                              icon: Icon(
                                Icons.more_vert,
                                color: Colors.grey.shade600,
                                size: 20,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              onSelected: (value) {
                                TaskStatus newStatus = value == 'started' 
                                    ? TaskStatus.started 
                                    : TaskStatus.completed;
                                _updateTaskStatus(task, newStatus);
                              },
                              itemBuilder: (context) => [
                                PopupMenuItem(
                                  value: 'started',
                                  child: Row(
                                    children: [
                                      Icon(Icons.play_circle_outline, 
                                          size: 20, 
                                          color: Colors.blue.shade600),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Mark Started',
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                                PopupMenuItem(
                                  value: 'completed',
                                  child: Row(
                                    children: [
                                      Icon(Icons.check_circle_outline, 
                                          size: 20, 
                                          color: Colors.green.shade600),
                                      const SizedBox(width: 10),
                                      Text(
                                        'Mark Completed',
                                        style: GoogleFonts.poppins(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      
                      Row(
                        children: [
                          Icon(Icons.calendar_today_outlined, 
                              size: 14, 
                              color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            '${_dateFormat.format(task.startDate!)} - ${_dateFormat.format(task.endDate!)}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      
                      Row(
                        children: [
                          Icon(Icons.timelapse_outlined, 
                              size: 14, 
                              color: Colors.grey.shade600),
                          const SizedBox(width: 6),
                          Text(
                            'Duration: ${task.duration} day${task.duration == 1 ? '' : 's'}',
                            style: GoogleFonts.poppins(
                              fontSize: 13,
                              color: Colors.grey.shade600,
                            ),
                          ),
                        ],
                      ),
                      
                      // NEW: Display started and completion dates if available
                      if (task.actualStartDate != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.play_arrow_outlined, 
                                size: 14, 
                                color: Colors.blue.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Started: ${_dateFormat.format(task.actualStartDate!)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (task.actualEndDate != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.check_circle_outlined, 
                                size: 14, 
                                color: Colors.green.shade600),
                            const SizedBox(width: 6),
                            Text(
                              'Completed: ${_dateFormat.format(task.actualEndDate!)}',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                color: Colors.green.shade600,
                              ),
                            ),
                          ],
                        ),
                      ],
                      
                      if (urgencyText.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                              color: accentColor.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                urgencyIcon,
                                size: 14,
                                color: accentColor,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                urgencyText,
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: accentColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      )
    );
  }
}