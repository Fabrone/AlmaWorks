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
  List<GanttRowData> _completedActivities = [];
  List<GanttRowData> _ongoingActivities = [];
  List<GanttRowData> _startingSoonActivities = [];
  List<GanttRowData> _otherUpcomingActivities = [];

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
    
    _completedActivities = [];
    _ongoingActivities = [];
    _startingSoonActivities = [];
    _otherUpcomingActivities = [];

    final DateTime now = DateTime.now();

    for (var task in tasks) {
      if (task.startDate == null || task.endDate == null) {
        widget.logger?.w('⚠️ ActivityFeed: Skipping task with null dates: ${task.taskName}');
        continue;
      }

      TaskStatus effectiveStatus = _getEffectiveStatus(task);
      
      widget.logger?.d('📋 ActivityFeed: Task "${task.taskName}" has effective status: $effectiveStatus');

      switch (effectiveStatus) {
        case TaskStatus.completed:
          _completedActivities.add(task);
          widget.logger?.d('✅ ActivityFeed: Added to completed: ${task.taskName}');
          break;
        case TaskStatus.ongoing:
        case TaskStatus.started:
          _ongoingActivities.add(task);
          widget.logger?.d('➕ ActivityFeed: Added to ongoing: ${task.taskName}');
          break;
        case TaskStatus.upcoming:
          if (task.startDate!.isAfter(now)) {
            final diff = task.startDate!.difference(now).inDays;
            if (diff <= 3) {
              _startingSoonActivities.add(task);
              widget.logger?.d('📆 ActivityFeed: Added to starting soon: ${task.taskName}');
            } else {
              _otherUpcomingActivities.add(task);
              widget.logger?.d('📅 ActivityFeed: Added to other upcoming: ${task.taskName}');
            }
          }
          break;
        case TaskStatus.overdue:
          // Skip overdue tasks - not displayed in activity feed
          widget.logger?.d('⏭️ ActivityFeed: Skipping overdue task: ${task.taskName}');
          break;
      }
    }

    // Sort activities
    _completedActivities.sort((a, b) => b.endDate!.compareTo(a.endDate!)); // Most recent first
    _ongoingActivities.sort((a, b) => a.endDate!.compareTo(b.endDate!)); // Due soonest first
    _startingSoonActivities.sort((a, b) => a.startDate!.compareTo(b.startDate!)); // Starting soonest first
    _otherUpcomingActivities.sort((a, b) => a.startDate!.compareTo(b.startDate!)); // Starting soonest first
    
    widget.logger?.i('📊 ActivityFeed: Categorization complete - Completed: ${_completedActivities.length}, Ongoing: ${_ongoingActivities.length}, Starting Soon: ${_startingSoonActivities.length}, Other Upcoming: ${_otherUpcomingActivities.length}');
  }

  // Helper method to get effective status of a task
  TaskStatus _getEffectiveStatus(GanttRowData task) {
    final DateTime now = DateTime.now();
    TaskStatus effectiveStatus = task.status ?? TaskStatus.upcoming;
    
    // Priority 1: Check actualEndDate - if set, it's completed
    if (task.actualEndDate != null) {
      return TaskStatus.completed;
    }
    // Priority 2: Check actualStartDate - if set, it's started/ongoing
    else if (task.actualStartDate != null) {
      return TaskStatus.started;
    }
    // Priority 3: Auto-detect overdue
    else if (task.startDate != null && 
            task.startDate!.isBefore(now) && 
            effectiveStatus != TaskStatus.started && 
            effectiveStatus != TaskStatus.ongoing && 
            effectiveStatus != TaskStatus.completed) {
      return TaskStatus.overdue;
    }
    // Priority 4: Ensure upcoming status is set for future tasks
    else if (task.startDate != null && 
            task.startDate!.isAfter(now) && 
            (task.status == null || task.status == TaskStatus.upcoming)) {
      return TaskStatus.upcoming;
    }
    
    return effectiveStatus;
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
      final relative = _getRelativeTime(task.actualEndDate ?? task.endDate!, true);
      return 'Completed $relative';
    } else if (task.status == TaskStatus.ongoing || task.status == TaskStatus.started) {
      final relative = _getRelativeTime(task.actualStartDate ?? task.startDate!, false);
      return 'Started $relative';
    } else {
      // Upcoming tasks
      final now = DateTime.now();
      final daysUntil = task.startDate!.difference(now).inDays;
      if (daysUntil == 0) {
        return 'Starting today';
      } else if (daysUntil == 1) {
        return 'Starting tomorrow';
      } else if (daysUntil <= 3) {
        return 'Starts in $daysUntil days';
      } else {
        return 'Starts ${DateFormat('MMM dd').format(task.startDate!)}';
      }
    }
  }

  IconData _getIcon(TaskStatus? status) {
    switch (status) {
      case TaskStatus.completed:
        return Icons.check_circle;
      case TaskStatus.ongoing:
      case TaskStatus.started:
        return Icons.play_circle_filled;
      case TaskStatus.upcoming:
        return Icons.schedule;
      case TaskStatus.overdue:
        return Icons.error_outline;
      case null:
        return Icons.help_outline; // Default icon for null status
    }
  }

  Color _getColor(TaskStatus? status) {
    switch (status) {
      case TaskStatus.completed:
        return Colors.green.shade600;
      case TaskStatus.ongoing:
      case TaskStatus.started:
        return Colors.blue.shade600;
      case TaskStatus.upcoming:
        return Colors.orange.shade700;
      case TaskStatus.overdue:
        return Colors.red.shade700;
      case null:
        return Colors.grey.shade600; // Default color for null status
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
    // Smart priority display: Fill up to 6 items from available categories
    // Priority order: Completed > Ongoing > Starting Soon > Other Upcoming
    List<Widget> priorityItems = [];
    List<GanttRowData> displayedTasks = [];
    
    const int maxInitialDisplay = 6;
    int remainingSlots = maxInitialDisplay;
    
    // Distribute slots intelligently
    int completedToShow = 0;
    int ongoingToShow = 0;
    int startingSoonToShow = 0;
    int otherUpcomingToShow = 0;
    
    // Calculate how many from each category to show initially
    if (_completedActivities.isNotEmpty || _ongoingActivities.isNotEmpty || 
        _startingSoonActivities.isNotEmpty || _otherUpcomingActivities.isNotEmpty) {
      
      // Priority allocation logic
      completedToShow = _completedActivities.length.clamp(0, remainingSlots);
      remainingSlots -= completedToShow;
      
      if (remainingSlots > 0) {
        ongoingToShow = _ongoingActivities.length.clamp(0, remainingSlots);
        remainingSlots -= ongoingToShow;
      }
      
      if (remainingSlots > 0) {
        startingSoonToShow = _startingSoonActivities.length.clamp(0, remainingSlots);
        remainingSlots -= startingSoonToShow;
      }
      
      if (remainingSlots > 0) {
        otherUpcomingToShow = _otherUpcomingActivities.length.clamp(0, remainingSlots);
        remainingSlots -= otherUpcomingToShow;
      }
      
      // If we still have remaining slots and some categories weren't fully shown, redistribute
      while (remainingSlots > 0) {
        bool addedAny = false;
        
        if (completedToShow < _completedActivities.length && remainingSlots > 0) {
          completedToShow++;
          remainingSlots--;
          addedAny = true;
        }
        
        if (ongoingToShow < _ongoingActivities.length && remainingSlots > 0) {
          ongoingToShow++;
          remainingSlots--;
          addedAny = true;
        }
        
        if (startingSoonToShow < _startingSoonActivities.length && remainingSlots > 0) {
          startingSoonToShow++;
          remainingSlots--;
          addedAny = true;
        }
        
        if (otherUpcomingToShow < _otherUpcomingActivities.length && remainingSlots > 0) {
          otherUpcomingToShow++;
          remainingSlots--;
          addedAny = true;
        }
        
        if (!addedAny) break; // No more tasks to add
      }
    }
    
    // Build priority display with headers
    if (completedToShow > 0) {
      final displayCompleted = _completedActivities.take(completedToShow).toList();
      priorityItems.add(_buildCategoryHeader('Completed', displayCompleted.length, Colors.green.shade600, isMobile));
      for (var task in displayCompleted) {
        priorityItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
        displayedTasks.add(task);
      }
    }
    
    if (ongoingToShow > 0) {
      final displayOngoing = _ongoingActivities.take(ongoingToShow).toList();
      priorityItems.add(_buildCategoryHeader('Ongoing', displayOngoing.length, Colors.blue.shade600, isMobile));
      for (var task in displayOngoing) {
        priorityItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
        displayedTasks.add(task);
      }
    }
    
    if (startingSoonToShow > 0) {
      final displayStartingSoon = _startingSoonActivities.take(startingSoonToShow).toList();
      priorityItems.add(_buildCategoryHeader('Starting Soon (≤3 days)', displayStartingSoon.length, Colors.orange.shade700, isMobile));
      for (var task in displayStartingSoon) {
        priorityItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
        displayedTasks.add(task);
      }
    }
    
    if (otherUpcomingToShow > 0) {
      final displayOtherUpcoming = _otherUpcomingActivities.take(otherUpcomingToShow).toList();
      priorityItems.add(_buildCategoryHeader('Other Upcoming', displayOtherUpcoming.length, Colors.grey.shade700, isMobile));
      for (var task in displayOtherUpcoming) {
        priorityItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
        displayedTasks.add(task);
      }
    }

    // Prepare expanded view: ALL remaining tasks grouped by category
    List<Widget> expandedItems = [];
    
    // Show ALL completed (including those already shown - we'll show full category)
    if (_completedActivities.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader('All Completed', _completedActivities.length, Colors.green.shade600, isMobile));
      for (var task in _completedActivities) {
        expandedItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }
    
    // Show ALL ongoing
    if (_ongoingActivities.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader('All Ongoing', _ongoingActivities.length, Colors.blue.shade600, isMobile));
      for (var task in _ongoingActivities) {
        expandedItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }
    
    // Show ALL starting soon
    if (_startingSoonActivities.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader('All Starting Soon (≤3 days)', _startingSoonActivities.length, Colors.orange.shade700, isMobile));
      for (var task in _startingSoonActivities) {
        expandedItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }
    
    // Show ALL other upcoming
    if (_otherUpcomingActivities.isNotEmpty) {
      expandedItems.add(_buildCategoryHeader('All Other Upcoming', _otherUpcomingActivities.length, Colors.grey.shade700, isMobile));
      for (var task in _otherUpcomingActivities) {
        expandedItems.add(_buildActivityItem(task, isMobile, widget.showAllProjects));
      }
    }

    final totalActivities = _completedActivities.length + 
                            _ongoingActivities.length + 
                            _startingSoonActivities.length + 
                            _otherUpcomingActivities.length;
    final displayedCount = displayedTasks.length;
    final hasMoreActivities = totalActivities > displayedCount;

    widget.logger?.d('📊 ActivityFeed: Building list - Total: $totalActivities, Initially Displayed: $displayedCount, Has More: $hasMoreActivities');

    if (priorityItems.isEmpty) {
      widget.logger?.w('⚠️ ActivityFeed: No priority items to display');
      return _buildEmptyState(isMobile);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              if (!_isExpanded) ...[
                // Collapsed view: Smart initial display
                ...priorityItems,
              ] else ...[
                // Expanded view: Full categorized display
                ...expandedItems,
              ],
            ],
          ),
        ),
        if (hasMoreActivities)
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
    // Get the effective status instead of using task.status directly
    final effectiveStatus = _getEffectiveStatus(task);
    final color = _getColor(effectiveStatus);
    final icon = _getIcon(effectiveStatus);
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
                      effectiveStatus == TaskStatus.completed
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
              _getStatusLabel(effectiveStatus),
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

  String _getStatusLabel(TaskStatus? status) {
    switch (status) {
      case TaskStatus.completed:
        return 'DONE';
      case TaskStatus.ongoing:
      case TaskStatus.started:
        return 'ACTIVE';
      case TaskStatus.upcoming:
        return 'UPCOMING';
      case TaskStatus.overdue:
        return 'OVERDUE';
      case null:
        return 'UNKNOWN'; // Handle null status
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
                ? 'No activities yet'
                : 'No project activities',
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
                  ? 'Start working on tasks or schedule upcoming work'
                  : 'Add and manage tasks to track activity',
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