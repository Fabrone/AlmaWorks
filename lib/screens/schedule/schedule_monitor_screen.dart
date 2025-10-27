import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
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
      // Initialize timezone
      tzdata.initializeTimeZones();

      // Get projectId from inputData
      final String? projectId = inputData?['projectId'] as String?;

      if (projectId == null) {
        return Future.value(false);
      }

      // Fetch tasks from Firestore
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: projectId)
          .get();

      final List<GanttRowData> tasks = snapshot.docs.map((doc) {
        return GanttRowData.fromFirebaseMap(doc.id, doc.data() as Map<String, dynamic>);
      }).toList();

      // Use dynamic current date
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

      if (upcomingTasks.isNotEmpty) {
        // Initialize notifications in background
        final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
        const AndroidInitializationSettings androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
        final DarwinInitializationSettings iosInit = DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        );
        final InitializationSettings initSettings = InitializationSettings(android: androidInit, iOS: iosInit);
        await notifications.initialize(initSettings);

        // Prepare notification content
        final String taskNames = upcomingTasks.map((t) => t.taskName ?? 'Untitled').join(', ');
        final String body = 'Upcoming tasks: $taskNames – Starting soon!';

        // Notification details
        const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
          'schedule_monitor_channel',
          'Schedule Monitor Notifications',
          importance: Importance.high,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('snooze', 'Snooze (1 day)'),
            AndroidNotificationAction('open', 'Open App'),
          ],
        );
        const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
        final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

        // Show notification
        await notifications.show(
          projectId.hashCode,
          'Tasks Starting Soon',
          body,
          details,
          payload: projectId, // Payload for handling tap
        );

        // Play ringtone
        FlutterRingtonePlayer().playNotification();
      }

      return Future.value(true);
    } catch (e) {
      // Log error if possible, but no logger in background
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

  FlutterLocalNotificationsPlugin? _flutterLocalNotificationsPlugin;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  List<GanttRowData> _startingSoonTasks = [];
  List<GanttRowData> _otherUpcomingTasks = [];
  List<GanttRowData> _ongoingTasks = [];
  List<GanttRowData> _completedTasks = [];
  List<GanttRowData> _overdueTasks = [];

  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
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

    // Set up periodic refresh every minute while app is open
    _refreshTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {});
      }
    });
  }

  void _initializeBackgroundTasks() {
    // Initialize Workmanager (assume called once, but safe to call multiple times)
    Workmanager().initialize(callbackDispatcher);

    // Register periodic task for hourly checks (minimum reliable frequency)
    Workmanager().registerPeriodicTask(
      "${widget.projectId}_hourly_check",
      "scheduleMonitorTask",
      frequency: const Duration(hours: 1),
      inputData: {'projectId': widget.projectId},
      existingWorkPolicy: ExistingPeriodicWorkPolicy.keep, // Corrected type
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
      if (task.startDate == null || task.endDate == null) continue; // Edge case: Skip invalid dates

      TaskStatus effectiveStatus = task.status ?? TaskStatus.upcoming;

      // Auto-overdue if conditions met (manual override possible later)
      if (task.startDate!.isBefore(now) &&
          (effectiveStatus != TaskStatus.started && effectiveStatus != TaskStatus.ongoing && effectiveStatus != TaskStatus.completed)) {
        effectiveStatus = TaskStatus.overdue;
        _updateTaskStatus(task, TaskStatus.overdue); // Sync to Firestore
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

    // Sorting
    _startingSoonTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!)); // Soonest first
    _otherUpcomingTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!)); // Soonest first
    _overdueTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!)); // Oldest overdue first
    _ongoingTasks.sort((a, b) => a.endDate!.compareTo(b.endDate!)); // Soonest end first
    _completedTasks.sort((a, b) => b.endDate!.compareTo(a.endDate!)); // Most recent first

    // Manual check for notifications on screen load
    _checkForNotifications();
  }

  Future<void> _checkForNotifications() async {
    if (kIsWeb) return;

    final List<GanttRowData> notifyTasks = _startingSoonTasks;

    if (notifyTasks.isNotEmpty) {
      final String taskNames = notifyTasks.map((t) => t.taskName ?? 'Untitled').join(', ');
      final String body = 'Upcoming tasks: $taskNames – Starting soon!';

      // Show in-app elegant notification
      ElegantNotification.info(
        title: const Text('Tasks Starting Soon'),
        description: Text(body),
      ).show(context);

      // Also schedule local notification (for foreground/background)
      const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'schedule_monitor_channel',
        'Schedule Monitor Notifications',
        importance: Importance.high,
        priority: Priority.high,
        actions: <AndroidNotificationAction>[
          AndroidNotificationAction('snooze', 'Snooze (1 day)'),
          AndroidNotificationAction('open', 'Open App'),
        ],
      );
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails();
      final NotificationDetails details = NotificationDetails(android: androidDetails, iOS: iosDetails);

      await _flutterLocalNotificationsPlugin!.show(
        widget.projectId.hashCode,
        'Tasks Starting Soon',
        body,
        details,
        payload: widget.projectId,
      );

      FlutterRingtonePlayer().playNotification();
    }
  }

  Future<void> _updateTaskStatus(GanttRowData task, TaskStatus newStatus) async {
    try {
      await FirebaseFirestore.instance
          .collection('Schedule')
          .doc(task.firestoreId ?? task.id)
          .update({'status': newStatus.toString().split('.').last.toUpperCase()});
      widget.logger.i('Updated task ${task.id} status to $newStatus');
    } catch (e) {
      widget.logger.e('Error updating task status: $e');
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
              _checkForNotifications();
            },
            child: Column(
              children: [
                // Search bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
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
    // Calculate progress indicator
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
              // Colored accent strip on the left
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
              // Main content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Task name and menu
                      Row(
                        children: [
                          // Status indicator dot
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
                          // Action menu
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
                      
                      // Date range with icons
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
                      
                      // Duration with icon
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
                      
                      // Urgency chip (if applicable)
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
      ),
    );
  }
}