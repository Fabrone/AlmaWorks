import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/schedule_monitor_model.dart';
import 'package:almaworks/screens/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class TodoWidget extends StatefulWidget {
  final String? projectId;
  final ProjectModel? project;
  final Logger? logger;
  final bool showAllProjects;

  const TodoWidget({
    super.key,
    this.projectId,
    this.project,
    this.logger,
    this.showAllProjects = false,
  });

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  bool _isExpanded = false;

  /// Normalizes a DateTime to midnight in the device's local timezone
  DateTime _normalizeToMidnight(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  /// Calculates calendar days between two dates
  int _calculateDaysBetween(DateTime from, DateTime to) {
    final normalizedFrom = _normalizeToMidnight(from);
    final normalizedTo = _normalizeToMidnight(to);
    return normalizedTo.difference(normalizedFrom).inDays;
  }

  // Task category lists
  List<ScheduleMonitorData> _overdueTasks = [];
  List<ScheduleMonitorData> _startingSoonTasks = [];
  List<ScheduleMonitorData> _ongoingTasks = [];
  List<ScheduleMonitorData> _otherUpcomingTasks = [];

  Stream<List<ScheduleMonitorData>> _getTasksStream() {
    if (widget.showAllProjects) {
      // Show tasks from all projects
      return _firestore.collection('ScheduleMonitor').snapshots().map((snapshot) {
        List<ScheduleMonitorData> tasks = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            final task = ScheduleMonitorData.fromFirestore(doc.id, data);
            // No null check needed - ScheduleMonitorData ensures non-null dates
            tasks.add(task);
          } catch (e) {
            // Skip malformed documents
            continue;
          }
        }

        return tasks;
      });
    } else if (widget.projectId != null && widget.projectId!.isNotEmpty) {
      // Show tasks for specific project
      return _firestore
          .collection('ScheduleMonitor')
          .where('projectId', isEqualTo: widget.projectId)
          .snapshots()
          .map((snapshot) {
        List<ScheduleMonitorData> tasks = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            final task = ScheduleMonitorData.fromFirestore(doc.id, data);
            // No null check needed - ScheduleMonitorData ensures non-null dates
            tasks.add(task);
          } catch (e) {
            // Skip malformed documents
            continue;
          }
        }

        return tasks;
      });
    } else {
      // No project selected and not showing all projects
      return Stream.value([]);
    }
  }

  void _categorizeTasks(List<ScheduleMonitorData> tasks) {
      _overdueTasks = [];
      _startingSoonTasks = [];
      _ongoingTasks = [];
      _otherUpcomingTasks = [];

      for (var task in tasks) {

        // Use the same categorization logic as ScheduleMonitorScreen
        if (task.isOverdue) {
          _overdueTasks.add(task);
        } else if (task.isOngoing) {
          _ongoingTasks.add(task);
        } else if (task.isUpcoming) {
          if (task.isStartingSoon) {
            _startingSoonTasks.add(task);
          } else {
            _otherUpcomingTasks.add(task);
          }
        }
        // Skip completed tasks - not displayed in todo widget
      }

      // Sort tasks using timezone-aware comparison
      _overdueTasks.sort((a, b) => a.startDate.compareTo(b.startDate));
      _startingSoonTasks.sort((a, b) => a.startDate.compareTo(b.startDate));
      _otherUpcomingTasks.sort((a, b) => a.startDate.compareTo(b.startDate));
      _ongoingTasks.sort((a, b) => a.endDate.compareTo(b.endDate));
    }

  Color _getStatusColor(MonitorStatus status) {
    switch (status) {
      case MonitorStatus.overdue:
        return Colors.red.shade700;
      case MonitorStatus.ongoing:
        return Colors.blue.shade600;
      case MonitorStatus.completed:
        return Colors.green.shade600;
      case MonitorStatus.upcoming:
        return Colors.orange.shade700;
    }
  }

  String _getDeadlineText(DateTime startDate, DateTime endDate, MonitorStatus status) {
    final now = DateTime.now();
    final daysUntilStart = _calculateDaysBetween(now, startDate);
    final daysUntilEnd = _calculateDaysBetween(now, endDate);

    if (status == MonitorStatus.overdue) {
      // Show how overdue it is based on start date
      final overdueByDays = _calculateDaysBetween(startDate, now).abs();
      return overdueByDays == 0 ? 'Overdue today!' : 'Overdue by $overdueByDays day${overdueByDays == 1 ? '' : 's'}';
    }

    if (status == MonitorStatus.ongoing) {
      if (daysUntilEnd < 0) {
        return 'Past due date';
      } else if (daysUntilEnd == 0) {
        return 'Due today';
      } else if (daysUntilEnd == 1) {
        return 'Due tomorrow';
      }
      return 'Due in $daysUntilEnd day${daysUntilEnd == 1 ? '' : 's'}';
    }

    // Upcoming tasks - show when starting
    if (daysUntilStart < 0) {
      return 'Should have started'; // Edge case
    } else if (daysUntilStart == 0) {
      return 'Starting today';
    } else if (daysUntilStart == 1) {
      return 'Starting tomorrow';
    } else if (daysUntilStart <= 7) {
      return 'Starts in $daysUntilStart days';
    }

    return 'Starts ${_dateFormat.format(startDate)}';
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    if (!widget.showAllProjects &&
        (widget.projectId == null || widget.projectId!.isEmpty)) {
      return _buildNoProjectState(isMobile);
    }

    return StreamBuilder<List<ScheduleMonitorData>>(
      stream: _getTasksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLoadingState(isMobile);
        }

        if (snapshot.hasError) {
          return _buildErrorState(isMobile);
        }

        final tasks = snapshot.data ?? [];
        _categorizeTasks(tasks);

        return Card(
          elevation: 2,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isMobile),
                const SizedBox(height: 12),
                Expanded(
                  child: tasks.isEmpty
                      ? _buildEmptyState(isMobile)
                      : _buildTasksList(isMobile),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(bool isMobile) {
    return Row(
      children: [
        Icon(
          Icons.assignment,
          color: Theme.of(context).primaryColor,
          size: isMobile ? 20 : 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.showAllProjects ? 'Tasks Overview' : 'Project Tasks',
            style: TextStyle(
              fontSize: isMobile ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildTasksList(bool isMobile) {
    final totalTasks = _overdueTasks.length +
        _startingSoonTasks.length +
        _ongoingTasks.length +
        _otherUpcomingTasks.length;

    if (totalTasks == 0) {
      return _buildEmptyState(isMobile);
    }

    // Priority display: Fill up to 6 items from available categories
    // Priority order: Overdue > Starting Soon > Ongoing > Other Upcoming
    List<Widget> priorityItems = [];

    const int maxInitialDisplay = 6;
    int remainingSlots = maxInitialDisplay;

    int overdueToShow = _overdueTasks.length.clamp(0, remainingSlots);
    remainingSlots -= overdueToShow;

    int startingSoonToShow = _startingSoonTasks.length.clamp(0, remainingSlots);
    remainingSlots -= startingSoonToShow;

    int ongoingToShow = _ongoingTasks.length.clamp(0, remainingSlots);
    remainingSlots -= ongoingToShow;

    int otherUpcomingToShow = _otherUpcomingTasks.length.clamp(0, remainingSlots);
    remainingSlots -= otherUpcomingToShow;

    // Redistribute remaining slots if possible
    while (remainingSlots > 0) {
      bool addedAny = false;

      if (overdueToShow < _overdueTasks.length && remainingSlots > 0) {
        overdueToShow++;
        remainingSlots--;
        addedAny = true;
      }

      if (startingSoonToShow < _startingSoonTasks.length && remainingSlots > 0) {
        startingSoonToShow++;
        remainingSlots--;
        addedAny = true;
      }

      if (ongoingToShow < _ongoingTasks.length && remainingSlots > 0) {
        ongoingToShow++;
        remainingSlots--;
        addedAny = true;
      }

      if (otherUpcomingToShow < _otherUpcomingTasks.length && remainingSlots > 0) {
        otherUpcomingToShow++;
        remainingSlots--;
        addedAny = true;
      }

      if (!addedAny) break;
    }

    // Build priority items with headers
    if (overdueToShow > 0) {
      priorityItems.add(_buildCategoryHeader(
        'Overdue',
        overdueToShow,
        Colors.red.shade700,
        isMobile,
      ));
      for (var task in _overdueTasks.take(overdueToShow)) {
        priorityItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    if (startingSoonToShow > 0) {
      priorityItems.add(_buildCategoryHeader(
        'Starting Soon (≤3 days)',
        startingSoonToShow,
        Colors.orange.shade700,
        isMobile,
      ));
      for (var task in _startingSoonTasks.take(startingSoonToShow)) {
        priorityItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    if (ongoingToShow > 0) {
      priorityItems.add(_buildCategoryHeader(
        'Ongoing',
        ongoingToShow,
        Colors.blue.shade600,
        isMobile,
      ));
      for (var task in _ongoingTasks.take(ongoingToShow)) {
        priorityItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    if (otherUpcomingToShow > 0) {
      priorityItems.add(_buildCategoryHeader(
        'Other Upcoming',
        otherUpcomingToShow,
        Colors.grey.shade700,
        isMobile,
      ));
      for (var task in _otherUpcomingTasks.take(otherUpcomingToShow)) {
        priorityItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    // Prepare expandable items: All tasks grouped by category
    List<Widget> expandedItems = [];

    if (_overdueTasks.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader(
        'All Overdue',
        _overdueTasks.length,
        Colors.red.shade700,
        isMobile,
      ));
      for (var task in _overdueTasks) {
        expandedItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    if (_startingSoonTasks.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader(
        'All Starting Soon (≤3 days)',
        _startingSoonTasks.length,
        Colors.orange.shade700,
        isMobile,
      ));
      for (var task in _startingSoonTasks) {
        expandedItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    if (_ongoingTasks.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader(
        'All Ongoing',
        _ongoingTasks.length,
        Colors.blue.shade600,
        isMobile,
      ));
      for (var task in _ongoingTasks) {
        expandedItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    if (_otherUpcomingTasks.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader(
        'All Other Upcoming',
        _otherUpcomingTasks.length,
        Colors.grey.shade700,
        isMobile,
      ));
      for (var task in _otherUpcomingTasks) {
        expandedItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    final displayedCount = overdueToShow +
        startingSoonToShow +
        ongoingToShow +
        otherUpcomingToShow;

    final hasHiddenTasks = totalTasks > displayedCount;

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              if (_isExpanded) ...expandedItems else ...priorityItems,
            ],
          ),
        ),
        if (hasHiddenTasks)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: isMobile ? 18 : 20,
                ),
                label: Text(
                  _isExpanded
                      ? 'Show Less'
                      : 'View All Tasks ($totalTasks)',
                  style: TextStyle(fontSize: isMobile ? 12 : 14),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCategoryHeader(String title, int count, Color color, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(top: 12, bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(6),
        border: Border(
          left: BorderSide(
            color: color,
            width: 3,
          ),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: isMobile ? 13 : 15,
              fontWeight: FontWeight.w600,
              color: color.withValues(alpha: 0.9),
            ),
          ),
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                fontSize: isMobile ? 11 : 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isMobile) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            const SizedBox(height: 12),
            const Expanded(
              child: Center(child: CircularProgressIndicator()),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(bool isMobile) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Text(
                  'Error loading tasks',
                  style: TextStyle(
                    color: Colors.red[600],
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoProjectState(bool isMobile) {
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(isMobile),
            const SizedBox(height: 12),
            Expanded(
              child: Center(
                child: Text(
                  'Select a project to view tasks',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: isMobile ? 12 : 14,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMobile) {
    if (widget.showAllProjects) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.check_circle,
              size: isMobile ? 40 : 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 8),
            Text(
              'No active tasks',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'All tasks are on track or completed!',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isMobile ? 10 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    } else {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: isMobile ? 40 : 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 12),
            Text(
              'No active tasks',
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: isMobile ? 13 : 15,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Add tasks from the Gantt Chart to track your project',
                style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: isMobile ? 11 : 12,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () {
                _navigateToGanttChart();
              },
              icon: Icon(Icons.timeline, size: isMobile ? 16 : 18),
              label: Text(
                'Go to Gantt Chart',
                style: TextStyle(fontSize: isMobile ? 12 : 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 12 : 16,
                  vertical: isMobile ? 8 : 10,
                ),
              ),
            ),
          ],
        ),
      );
    }
  }

  void _navigateToGanttChart() {
    if (widget.project == null) {
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => ScheduleScreen(
          project: widget.project!,
          logger: widget.logger ?? Logger(),
        ),
      ),
    );
  }

  Widget _buildTodoItem(ScheduleMonitorData task, bool isMobile, bool showAllProjects) {
    final statusColor = _getStatusColor(task.status);
    final deadlineText = _getDeadlineText(task.startDate, task.endDate, task.status);
    final now = DateTime.now();
    final bool isUrgent = task.isOverdue || 
        (task.isUpcoming && _calculateDaysBetween(now, task.startDate) <= 3);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: isUrgent ? statusColor.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: isUrgent ? 1.5 : 1,
        ),
        boxShadow: isUrgent
            ? [
                BoxShadow(
                  color: statusColor.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: isMobile ? 32 : 36,
            decoration: BoxDecoration(
              color: statusColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        task.taskName,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 12 : 14,
                          color: isUrgent ? statusColor : Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      isUrgent ? Icons.warning_amber : Icons.schedule,
                      size: isMobile ? 11 : 13,
                      color: statusColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deadlineText,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (showAllProjects && task.projectName.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: isMobile ? 10 : 12,
                        color: Colors.grey[600],
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          task.projectName,
                          style: TextStyle(
                            fontSize: isMobile ? 9 : 11,
                            color: Colors.grey[600],
                            fontStyle: FontStyle.italic,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          ...[
              const SizedBox(width: 8),
              Container(  
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: statusColor.withValues(alpha: 0.3),
                  ),
                ),
              child: Text(
              _getStatusLabel(task.status),
                style: TextStyle(
                  color: statusColor,
                  fontSize: isMobile ? 8 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getStatusLabel(MonitorStatus status) {
    switch (status) {
      case MonitorStatus.overdue:
        return 'OVERDUE';
      case MonitorStatus.ongoing:
        return 'ONGOING';
      case MonitorStatus.completed:
        return 'DONE';
      case MonitorStatus.upcoming:
        return 'SOON';
    }
  }
}