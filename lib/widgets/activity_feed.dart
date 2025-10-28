import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class ActivityFeed extends StatefulWidget {
  final String? projectId;
  final ProjectModel? project;
  final Logger? logger;
  final bool showAllProjects;

  const ActivityFeed({
    super.key,
    this.projectId,
    this.project,
    this.logger,
    this.showAllProjects = false,
  });

  @override
  State<ActivityFeed> createState() => _ActivityFeedState();
}

class _ActivityFeedState extends State<ActivityFeed> {
  bool _isExpanded = false;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Activity category lists
  List<GanttRowData> _ongoingActivities = [];
  List<GanttRowData> _completedActivities = [];

  Stream<List<GanttRowData>> _getTasksStream() {
    widget.logger?.d('📡 ActivityFeed: Getting tasks stream, showAllProjects: ${widget.showAllProjects}, projectId: ${widget.projectId}');
    
    if (widget.showAllProjects) {
      widget.logger?.d('📡 ActivityFeed: Fetching all projects tasks');
      return _firestore.collection('Schedule').snapshots().map((snapshot) {
        widget.logger?.d('📦 ActivityFeed: Received ${snapshot.docs.length} documents from all projects');
        List<GanttRowData> tasks = [];
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            final task = GanttRowData.fromFirebaseMap(doc.id, data);
            widget.logger?.d('✅ ActivityFeed: Parsed task: ${task.taskName}, status: ${task.status}, hasData: ${task.hasData}');
            
            if (task.hasData && task.startDate != null && task.endDate != null) {
              tasks.add(task);
              widget.logger?.d('✅ ActivityFeed: Added task to list: ${task.taskName}');
            } else {
              widget.logger?.w('⚠️ ActivityFeed: Skipped task due to missing data - hasData: ${task.hasData}, startDate: ${task.startDate}, endDate: ${task.endDate}');
            }
          } catch (e) {
            widget.logger?.e('❌ ActivityFeed: Error parsing task: $e');
            continue;
          }
        }
        
        widget.logger?.i('📊 ActivityFeed: Total valid tasks from all projects: ${tasks.length}');
        return tasks;
      });
    } else if (widget.projectId != null && widget.projectId!.isNotEmpty) {
      widget.logger?.d('📡 ActivityFeed: Fetching tasks for projectId: ${widget.projectId}');
      return _firestore
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.projectId)
          .snapshots()
          .map((snapshot) {
        widget.logger?.d('📦 ActivityFeed: Received ${snapshot.docs.length} documents for project');
        List<GanttRowData> tasks = [];
        
        for (var doc in snapshot.docs) {
          final data = doc.data();
          try {
            final task = GanttRowData.fromFirebaseMap(doc.id, data);
            widget.logger?.d('✅ ActivityFeed: Parsed project task: ${task.taskName}, status: ${task.status}');
            
            if (task.hasData && task.startDate != null && task.endDate != null) {
              tasks.add(task);
              widget.logger?.d('✅ ActivityFeed: Added project task to list: ${task.taskName}');
            } else {
              widget.logger?.w('⚠️ ActivityFeed: Skipped project task due to missing data');
            }
          } catch (e) {
            widget.logger?.e('❌ ActivityFeed: Error parsing project task: $e');
            continue;
          }
        }
        
        widget.logger?.i('📊 ActivityFeed: Total valid tasks for project: ${tasks.length}');
        return tasks;
      });
    } else {
      widget.logger?.w('⚠️ ActivityFeed: No project selected, returning empty stream');
      return Stream.value([]);
    }
  }

  void _categorizeActivities(List<GanttRowData> tasks) {
    widget.logger?.d('🗂️ ActivityFeed: Categorizing ${tasks.length} tasks');
    
    _ongoingActivities = [];
    _completedActivities = [];

    for (var task in tasks) {
      if (task.startDate == null || task.endDate == null) {
        widget.logger?.w('⚠️ ActivityFeed: Skipping task with null dates: ${task.taskName}');
        continue;
      }

      final effectiveStatus = task.status ?? TaskStatus.upcoming;
      widget.logger?.d('📋 ActivityFeed: Task "${task.taskName}" has status: $effectiveStatus');

      switch (effectiveStatus) {
        case TaskStatus.ongoing:
        case TaskStatus.started:
          _ongoingActivities.add(task);
          widget.logger?.d('➕ ActivityFeed: Added to ongoing: ${task.taskName}');
          break;
        case TaskStatus.completed:
          _completedActivities.add(task);
          widget.logger?.d('✅ ActivityFeed: Added to completed: ${task.taskName}');
          break;
        case TaskStatus.overdue:
        case TaskStatus.upcoming:
          widget.logger?.d('⏭️ ActivityFeed: Skipping overdue/upcoming task: ${task.taskName}');
          break;
      }
    }

    // Sort: Most recent activity first (by start date for ongoing, end date for completed)
    _ongoingActivities.sort((a, b) => b.startDate!.compareTo(a.startDate!));
    _completedActivities.sort((a, b) => b.endDate!.compareTo(a.endDate!));
    
    widget.logger?.i('📊 ActivityFeed: Categorization complete - Ongoing: ${_ongoingActivities.length}, Completed: ${_completedActivities.length}');
  }

  String _getRelativeTime(DateTime timestamp, bool isCompleted) {
    final now = DateTime.now();
    final diff = now.difference(timestamp);

    if (diff.inMinutes < 1) {
      return 'just now';
    } else if (diff.inMinutes < 60) {
      final minutes = diff.inMinutes;
      return '$minutes minute${minutes == 1 ? '' : 's'} ago';
    } else if (diff.inHours < 24) {
      final hours = diff.inHours;
      return '$hours hour${hours == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 7) {
      final days = diff.inDays;
      return '$days day${days == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '$weeks week${weeks == 1 ? '' : 's'} ago';
    } else if (diff.inDays < 365) {
      final months = (diff.inDays / 30).floor();
      return '$months month${months == 1 ? '' : 's'} ago';
    } else {
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  String _getActivityTitle(GanttRowData task) {
    return task.taskName ?? 'Untitled Task';
  }

  String _getActivityDescription(GanttRowData task) {
    if (task.status == TaskStatus.completed) {
      final relative = _getRelativeTime(task.endDate!, true);
      return 'Completed $relative';
    } else {
      final relative = _getRelativeTime(task.startDate!, false);
      return 'Started $relative';
    }
  }

  IconData _getIcon(TaskStatus? status) {
    if (status == TaskStatus.completed) {
      return Icons.check_circle;
    } else {
      return Icons.play_circle_filled;
    }
  }

  Color _getColor(TaskStatus? status) {
    if (status == TaskStatus.completed) {
      return Colors.green.shade600;
    } else {
      return Colors.blue.shade600;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    widget.logger?.d('🎨 ActivityFeed: Building widget, isMobile: $isMobile');

    if (!widget.showAllProjects &&
        (widget.projectId == null || widget.projectId!.isEmpty)) {
      widget.logger?.w('⚠️ ActivityFeed: No project selected, showing no project state');
      return _buildNoProjectState(isMobile);
    }

    return StreamBuilder<List<GanttRowData>>(
      stream: _getTasksStream(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          widget.logger?.d('⏳ ActivityFeed: Waiting for data...');
          return _buildLoadingState(isMobile);
        }

        if (snapshot.hasError) {
          widget.logger?.e('❌ ActivityFeed: Error loading activities: ${snapshot.error}');
          return _buildErrorState(isMobile);
        }

        final tasks = snapshot.data ?? [];
        widget.logger?.i('📊 ActivityFeed: Received ${tasks.length} tasks from stream');
        
        _categorizeActivities(tasks);

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
                  child: (_ongoingActivities.isEmpty && _completedActivities.isEmpty)
                      ? _buildEmptyState(isMobile)
                      : _buildActivitiesList(isMobile),
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
          Icons.timeline,
          color: Theme.of(context).primaryColor,
          size: isMobile ? 20 : 24,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            widget.showAllProjects ? 'Recent Activity' : 'Project Activity',
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

  Widget _buildActivitiesList(bool isMobile) {
    // Priority display: Show first 4 activities (2 ongoing + 2 completed, or whatever is available)
    List<Widget> priorityItems = [];
    
    // Add ongoing activities (limit to 2 for priority display)
    final displayOngoing = _ongoingActivities.take(2).toList();
    if (displayOngoing.isNotEmpty) {
      priorityItems.add(_buildCategoryHeader('Ongoing', displayOngoing.length, Colors.blue.shade600, isMobile));
      for (var task in displayOngoing) {
        priorityItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }
    
    // Add completed activities (limit to 2 for priority display)
    final displayCompleted = _completedActivities.take(2).toList();
    if (displayCompleted.isNotEmpty) {
      priorityItems.add(_buildCategoryHeader('Completed', displayCompleted.length, Colors.green.shade600, isMobile));
      for (var task in displayCompleted) {
        priorityItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }

    // Prepare "View All" items (shown when expanded)
    List<Widget> expandedItems = [];
    
    // Remaining ongoing activities (after first 2)
    if (_ongoingActivities.length > 2) {
      final remainingOngoing = _ongoingActivities.skip(2).toList();
      expandedItems.add(_buildCategoryHeader('More Ongoing', remainingOngoing.length, Colors.blue.shade600, isMobile));
      for (var task in remainingOngoing) {
        expandedItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }
    
    // Remaining completed activities (after first 2)
    if (_completedActivities.length > 2) {
      final remainingCompleted = _completedActivities.skip(2).toList();
      expandedItems.add(_buildCategoryHeader('More Completed', remainingCompleted.length, Colors.green.shade600, isMobile));
      for (var task in remainingCompleted) {
        expandedItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }

    final totalActivities = _ongoingActivities.length + _completedActivities.length;
    final displayedActivities = displayOngoing.length + displayCompleted.length;
    final hasHiddenActivities = totalActivities > displayedActivities;

    widget.logger?.d('📊 ActivityFeed: Building list - Total: $totalActivities, Displayed: $displayedActivities, Hidden: $hasHiddenActivities');

    if (priorityItems.isEmpty) {
      widget.logger?.w('⚠️ ActivityFeed: No priority items to display');
      return _buildEmptyState(isMobile);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              ...priorityItems,
              // Expanded items
              if (_isExpanded) ...expandedItems,
            ],
          ),
        ),
        if (hasHiddenActivities)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                  widget.logger?.i('🔄 ActivityFeed: View All toggled, isExpanded: $_isExpanded');
                },
                icon: Icon(
                  _isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: isMobile ? 18 : 20,
                ),
                label: Text(
                  _isExpanded
                      ? 'Show Less'
                      : 'View All Activities ($totalActivities)',
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

  Widget _buildActivityItem(GanttRowData task, bool isMobile, bool showAllProjects) {
    final color = _getColor(task.status);
    final icon = _getIcon(task.status);
    final title = _getActivityTitle(task);
    final description = _getActivityDescription(task);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon container
          Container(
            width: isMobile ? 32 : 36,
            height: isMobile ? 32 : 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(isMobile ? 16 : 18),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: isMobile ? 16 : 18,
            ),
          ),
          const SizedBox(width: 12),
          // Content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 13 : 15,
                          color: Colors.grey[800],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      size: isMobile ? 11 : 13,
                      color: color,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        description,
                        style: TextStyle(
                          color: color,
                          fontSize: isMobile ? 11 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                if (showAllProjects && task.projectName != null) ...[
                  const SizedBox(height: 6),
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
                            fontSize: isMobile ? 10 : 11,
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
                const SizedBox(height: 6),
                // Duration info
                Row(
                  children: [
                    Icon(
                      Icons.event_available,
                      size: isMobile ? 10 : 12,
                      color: Colors.grey[500],
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.status == TaskStatus.completed
                          ? 'Duration: ${task.duration} day${task.duration == 1 ? '' : 's'}'
                          : 'Expected: ${task.duration} day${task.duration == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: isMobile ? 10 : 11,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Status badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
              ),
            ),
            child: Text(
              _getStatusLabel(task.status!),
              style: TextStyle(
                color: color,
                fontSize: isMobile ? 8 : 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusLabel(TaskStatus status) {
    switch (status) {
      case TaskStatus.completed:
        return 'DONE';
      case TaskStatus.ongoing:
      case TaskStatus.started:
        return 'ACTIVE';
      case TaskStatus.overdue:
        return 'OVERDUE';
      case TaskStatus.upcoming:
        return 'UPCOMING';
    }
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
                  'Error loading activities',
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
                  'Select a project to view activities',
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.timeline,
            size: isMobile ? 40 : 48,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            widget.showAllProjects 
                ? 'No recent activities'
                : 'No activities yet',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: isMobile ? 12 : 14,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              widget.showAllProjects
                  ? 'Start working on tasks to see activity'
                  : 'Mark tasks as started or completed',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: isMobile ? 10 : 12,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}