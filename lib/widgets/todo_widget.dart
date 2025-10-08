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

  Stream<List<GanttRowData>> _getTasksStream() {
    final now = DateTime.now();
    final twoWeeksFromNow = now.add(const Duration(days: 14));

    if (widget.showAllProjects) {
      return _firestore
          .collection('Schedule')
          .snapshots()
          .map((snapshot) {
        List<GanttRowData> tasks = [];

        for (var doc in snapshot.docs) {
          final data = doc.data();  // Removed unnecessary cast
          try {
            final task = GanttRowData.fromFirebaseMap(doc.id, data);
            
            if (task.hasData && task.startDate != null && task.endDate != null) {
              final taskStart = task.startDate!;
              final taskEnd = task.endDate!;

              if ((taskStart.isBefore(twoWeeksFromNow) && taskEnd.isAfter(now)) ||
                  (taskStart.isBefore(twoWeeksFromNow) && taskStart.isAfter(now.subtract(const Duration(days: 1))))) {
                tasks.add(task);
              }
            }
          } catch (e) {
            continue;
          }
        }

        tasks.sort((a, b) {
          final aPriority = _calculatePriority(a.startDate!, a.endDate!);
          final bPriority = _calculatePriority(b.startDate!, b.endDate!);
          
          if (aPriority != bPriority) {
            return aPriority.compareTo(bPriority);
          }
          
          return a.startDate!.compareTo(b.startDate!);
        });

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
          final data = doc.data();  // Removed unnecessary cast
          try {
            final task = GanttRowData.fromFirebaseMap(doc.id, data);
            if (task.hasData) {
              tasks.add(task);
            }
          } catch (e) {
            continue;
          }
        }

        tasks.sort((a, b) => a.startDate!.compareTo(b.startDate!));

        return tasks;
      });
    } else {
      return Stream.value([]);
    }
  }

  int _calculatePriority(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    final daysUntilStart = startDate.difference(now).inDays;
    final daysUntilEnd = endDate.difference(now).inDays;

    // Overdue (highest priority = 0)
    if (endDate.isBefore(now)) {
      return 0;
    }

    // Happening now (priority = 1)
    if (daysUntilStart <= 0 && daysUntilEnd >= 0) {
      return 1;
    }

    // Starting very soon (within 2 days, priority = 2)
    if (daysUntilStart <= 2) {
      return 2;
    }

    // Starting within a week (priority = 3)
    if (daysUntilStart <= 7) {
      return 3;
    }

    // Starting later (priority = 4)
    return 4;
  }

  Color _getPriorityColor(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    final daysUntilStart = startDate.difference(now).inDays;
    final daysUntilEnd = endDate.difference(now).inDays;

    // Overdue
    if (endDate.isBefore(now)) {
      return Colors.red;
    }

    // Happening now or due soon (within 3 days)
    if (daysUntilStart <= 0 && daysUntilEnd >= 0) {
      return Colors.deepOrange;
    }

    if (daysUntilStart <= 3) {
      return Colors.orange;
    }

    // Upcoming
    return Colors.blue;
  }

  String _getDeadlineText(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    final daysUntilStart = startDate.difference(now).inDays;
    final daysUntilEnd = endDate.difference(now).inDays;

    if (endDate.isBefore(now)) {
      return 'Overdue by ${now.difference(endDate).inDays} days';
    }

    if (daysUntilStart <= 0 && daysUntilEnd >= 0) {
      return 'Ongoing until ${_dateFormat.format(endDate)}';
    }

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

  bool _isUrgent(DateTime startDate, DateTime endDate) {
    final now = DateTime.now();
    final daysUntilStart = startDate.difference(now).inDays;

    // Urgent if overdue or starting soon (within 2 days)
    return endDate.isBefore(now) || daysUntilStart <= 2;
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

        return Card(
          elevation: 2,
          child: Container(
            width: double.infinity,
            height: double.infinity,
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.assignment, color: Theme.of(context).primaryColor, size: isMobile ? 20 : 24),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        widget.showAllProjects ? 'Tasks Due Soon' : 'Upcoming Deadlines',
                        style: TextStyle(
                          fontSize: isMobile ? 16 : 18,
                          fontWeight: FontWeight.bold,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: tasks.isEmpty
                      ? _buildEmptyState(isMobile)
                      : Column(
                          children: [
                            Expanded(
                              child: ListView.builder(
                                itemCount: _isExpanded ? tasks.length : (tasks.length > 4 ? 4 : tasks.length),
                                itemBuilder: (context, index) {
                                  return _buildTodoItem(tasks[index], isMobile, widget.showAllProjects);
                                },
                              ),
                            ),
                            if (tasks.length > 4)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Center(
                                  child: TextButton(
                                    onPressed: () {
                                      setState(() {
                                        _isExpanded = !_isExpanded;
                                      });
                                    },
                                    child: Text(
                                      _isExpanded
                                          ? 'Show Less'
                                          : 'View All Tasks (${tasks.length})',
                                    ),
                                  ),
                                ),
                              ),
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
            Row(
              children: [
                Icon(Icons.assignment, color: Theme.of(context).primaryColor, size: isMobile ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.showAllProjects ? 'Tasks Due Soon' : 'Upcoming Deadlines',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
            Row(
              children: [
                Icon(Icons.assignment, color: Theme.of(context).primaryColor, size: isMobile ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    widget.showAllProjects ? 'Tasks Due Soon' : 'Upcoming Deadlines',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
            Row(
              children: [
                Icon(Icons.assignment, color: Theme.of(context).primaryColor, size: isMobile ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upcoming Deadlines',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
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
    // Dashboard view - all projects
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
            'No tasks due in the next two weeks',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'You\'re all caught up!',
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
    // Project-specific view
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
              'Add tasks from the Gantt Chart to see upcoming deadlines',
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

  // Navigate to the ScheduleScreen which contains the Gantt Chart tab
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
    final priorityColor = _getPriorityColor(task.startDate!, task.endDate!);
    final deadlineText = _getDeadlineText(task.startDate!, task.endDate!);
    final urgent = _isUrgent(task.startDate!, task.endDate!);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: urgent ? priorityColor.withValues(alpha: 0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: urgent ? Border.all(color: priorityColor.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: isMobile ? 28 : 32,
            decoration: BoxDecoration(
              color: priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.taskName ?? 'Untitled Task',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 14,
                    color: urgent ? priorityColor : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      urgent ? Icons.warning : Icons.schedule,
                      size: isMobile ? 10 : 12,
                      color: priorityColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        deadlineText,
                        style: TextStyle(
                          color: priorityColor,
                          fontSize: isMobile ? 10 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (showAllProjects) ...[
                      const SizedBox(width: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          task.projectName ?? 'N/A',
                          style: TextStyle(
                            fontSize: isMobile ? 8 : 10,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (urgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: priorityColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'URGENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 8 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}