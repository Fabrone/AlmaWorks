import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
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

  // Task category lists
  List<GanttRowData> _overdueTasks = [];
  List<GanttRowData> _startingSoonTasks = [];
  List<GanttRowData> _ongoingTasks = [];
  List<GanttRowData> _otherUpcomingTasks = [];
  List<GanttRowData> _completedTasks = [];

  Stream<List<GanttRowData>> _getTasksStream() {
    if (widget.showAllProjects) {
      return _firestore.collection('Schedule').snapshots().map((snapshot) {
        List<GanttRowData> tasks = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            final task = GanttRowData.fromFirebaseMap(doc.id, data);
            if (task.hasData && task.startDate != null && task.endDate != null) {
              tasks.add(task);
            }
          } catch (e) {
            continue;
          }
        }

        return tasks;
      });
    } else if (widget.projectId != null && widget.projectId!.isNotEmpty) {
      return _firestore
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.projectId)
          .snapshots()
          .map((snapshot) {
        List<GanttRowData> tasks = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            final task = GanttRowData.fromFirebaseMap(doc.id, data);
            if (task.hasData && task.startDate != null && task.endDate != null) {
              tasks.add(task);
            }
          } catch (e) {
            continue;
          }
        }

        return tasks;
      });
    } else {
      return Stream.value([]);
    }
  }

  void _categorizeTasks(List<GanttRowData> tasks) {
    final DateTime now = DateTime.now();

    _overdueTasks = [];
    _startingSoonTasks = [];
    _ongoingTasks = [];
    _otherUpcomingTasks = [];
    _completedTasks = [];

    for (var task in tasks) {
      if (task.startDate == null || task.endDate == null) continue;

      TaskStatus effectiveStatus = task.status ?? TaskStatus.upcoming;

      // Auto-update overdue status
      if (task.startDate!.isBefore(now) &&
          (effectiveStatus != TaskStatus.started &&
              effectiveStatus != TaskStatus.ongoing &&
              effectiveStatus != TaskStatus.completed)) {
        effectiveStatus = TaskStatus.overdue;
        _updateTaskStatus(task, TaskStatus.overdue);
      }

      // Categorize tasks based on status
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

    // Sort tasks
    _overdueTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!));
    _startingSoonTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!));
    _otherUpcomingTasks.sort((a, b) => a.startDate!.compareTo(b.startDate!));
    _ongoingTasks.sort((a, b) => a.endDate!.compareTo(b.endDate!));
    _completedTasks.sort((a, b) => b.endDate!.compareTo(a.endDate!));
  }

  Future<void> _updateTaskStatus(GanttRowData task, TaskStatus newStatus) async {
    try {
      await _firestore
          .collection('Schedule')
          .doc(task.firestoreId ?? task.id)
          .update({'status': newStatus.toString().split('.').last.toUpperCase()});
    } catch (e) {
      widget.logger?.e('Error updating task status: $e');
    }
  }

  Color _getStatusColor(TaskStatus? status) {
    switch (status) {
      case TaskStatus.overdue:
        return Colors.red.shade700;
      case TaskStatus.ongoing:
      case TaskStatus.started:
        return Colors.blue.shade600;
      case TaskStatus.completed:
        return Colors.green.shade600;
      case TaskStatus.upcoming:
      default:
        return Colors.orange.shade700;
    }
  }

  String _getDeadlineText(DateTime startDate, DateTime endDate, TaskStatus? status) {
    final now = DateTime.now();
    final daysUntilStart = startDate.difference(now).inDays;
    final daysUntilEnd = endDate.difference(now).inDays;

    if (status == TaskStatus.overdue) {
      return 'Overdue by ${now.difference(endDate).inDays} days';
    }

    if (status == TaskStatus.ongoing || status == TaskStatus.started) {
      return 'Due in $daysUntilEnd day${daysUntilEnd == 1 ? '' : 's'}';
    }

    if (status == TaskStatus.completed) {
      return 'Completed ${_dateFormat.format(endDate)}';
    }

    // Upcoming tasks
    if (daysUntilStart == 0) {
      return 'Starting today';
    }

    if (daysUntilStart == 1) {
      return 'Starting tomorrow';
    }

    if (daysUntilStart <= 7) {
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

    return StreamBuilder<List<GanttRowData>>(
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
    // Priority display: Overdue > Starting Soon only
    List<Widget> priorityItems = [];
    
    // Add overdue tasks
    for (var task in _overdueTasks) {
      priorityItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
    }
    
    // Add starting soon tasks
    for (var task in _startingSoonTasks) {
      priorityItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
    }

    // Prepare "View All" items (shown when expanded)
    List<Widget> expandedItems = [];
    
    if (_ongoingTasks.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader('Ongoing', _ongoingTasks.length, Colors.blue.shade600, isMobile));
      for (var task in _ongoingTasks) {
        expandedItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }
    
    if (_otherUpcomingTasks.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader('Upcoming', _otherUpcomingTasks.length, Colors.grey.shade700, isMobile));
      for (var task in _otherUpcomingTasks) {
        expandedItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }
    
    if (_completedTasks.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader('Completed', _completedTasks.length, Colors.green.shade600, isMobile));
      for (var task in _completedTasks) {
        expandedItems.add(_buildTodoItem(task, isMobile, widget.showAllProjects));
      }
    }

    final totalTasks = _overdueTasks.length +
        _startingSoonTasks.length +
        _ongoingTasks.length +
        _otherUpcomingTasks.length +
        _completedTasks.length;

    final hasHiddenTasks = expandedItems.isNotEmpty;

    if (priorityItems.isEmpty && expandedItems.isEmpty) {
      return _buildEmptyState(isMobile);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              // Priority section header
              if (priorityItems.isNotEmpty) ...[
                _buildCategoryHeader(
                  'Priority Tasks',
                  _overdueTasks.length + _startingSoonTasks.length,
                  Colors.red.shade700,
                  isMobile,
                ),
                ...priorityItems,
              ],
              // Expanded items
              if (_isExpanded) ...expandedItems,
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
              'No priority tasks at the moment',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: isMobile ? 12 : 14,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              'All tasks are on track!',
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
              'Tasks not yet added',
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

  Widget _buildTodoItem(GanttRowData task, bool isMobile, bool showAllProjects) {
    final statusColor = _getStatusColor(task.status);
    final deadlineText = _getDeadlineText(task.startDate!, task.endDate!, task.status);
    final bool isUrgent = task.status == TaskStatus.overdue || 
        (task.status == TaskStatus.upcoming && 
         task.startDate!.difference(DateTime.now()).inDays <= 3);

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
                        task.taskName ?? 'Untitled Task',
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
                if (showAllProjects && task.projectName != null) ...[
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
                          task.projectName!,
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
          if (task.status != null) ...[
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
                _getStatusLabel(task.status!),
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

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.overdue:
        return 'OVERDUE';
      case TaskStatus.ongoing:
      case TaskStatus.started:
        return 'ONGOING';
      case TaskStatus.completed:
        return 'DONE';
      case TaskStatus.upcoming:
        return 'SOON';
    }
  }
}