import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class CriticalPathScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final Logger logger;
  final ProjectModel project;

  const CriticalPathScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.logger,
    required this.project,
  });

  @override
  State<CriticalPathScreen> createState() => _CriticalPathScreenState();
}

class _CriticalPathScreenState extends State<CriticalPathScreen>
    with SingleTickerProviderStateMixin {
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  int _totalSlackDays = 0;
  double _criticalityRatio = 0.0;
  double _totalProjectDuration = 0;
  DateTime? _projectStartDate;
  DateTime? _projectEndDate;
  List<CriticalPathNode> _criticalPath = [];
  List<CriticalPathNode> _nonCriticalTasks = [];

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
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _calculateCriticalPath(List<GanttRowData> tasks) {
    if (tasks.isEmpty) {
      _projectStartDate = null;
      _projectEndDate = null;
      _totalProjectDuration = 0;
      _totalSlackDays = 0;
      _criticalityRatio = 0;
      _criticalPath = [];
      _nonCriticalTasks = [];
      return;
    }

    _projectStartDate = tasks.map((t) => t.startDate!).reduce((a, b) => a.isBefore(b) ? a : b);
    _projectEndDate = tasks.map((t) => t.endDate!).reduce((a, b) => a.isAfter(b) ? a : b);
    _totalProjectDuration = _projectEndDate!.difference(_projectStartDate!).inDays.toDouble() + 1;

    List<CriticalPathNode> nodes = [];
    Map<String, CriticalPathNode> nodeMap = {};

    for (var task in tasks) {
      final node = CriticalPathNode(
        task: task,
        earliestStart: task.startDate!,
        latestStart: task.startDate!,
        earliestFinish: task.endDate!,
        latestFinish: task.endDate!,
        totalFloat: 0,
        freeFloat: 0,
        predecessors: [],
        successors: [],
      );
      nodes.add(node);
      nodeMap[task.id] = node;
    }

    _buildHierarchyDependencies(nodes, nodeMap);

    _forwardPass(nodes);

    _backwardPass(nodes);

    for (var node in nodes) {
      node.totalFloat = node.latestStart.difference(node.earliestStart).inDays.toDouble();
      node.freeFloat = _calculateFreeFloat(node, nodes);
    }

    _criticalPath = nodes.where((node) => node.isCritical).toList()..sort((a, b) => a.earliestStart.compareTo(b.earliestStart));
    _nonCriticalTasks = nodes.where((node) => !node.isCritical).toList()..sort((a, b) => b.totalFloat.compareTo(a.totalFloat));

    _totalSlackDays = _nonCriticalTasks.map((n) => n.totalFloat.toInt()).fold(0, (a, b) => a + b);
    _criticalityRatio = tasks.isNotEmpty ? _criticalPath.length / tasks.length : 0;

    widget.logger.i('📊 CriticalPath: Analyzed ${tasks.length} tasks, ${_criticalPath.length} on critical path');
  }

  void _buildHierarchyDependencies(List<CriticalPathNode> nodes, Map<String, CriticalPathNode> nodeMap) {
    for (var node in nodes) {
      if (node.task.parentId != null) {
        final parent = nodeMap[node.task.parentId];
        if (parent != null) {
          parent.successors.add(node);
          node.predecessors.add(parent);
        }
      }
      for (var childId in node.task.childIds) {
        final child = nodeMap[childId];
        if (child != null) {
          node.successors.add(child);
          child.predecessors.add(node);
        }
      }
    }

    nodes.sort((a, b) => a.task.displayOrder.compareTo(b.task.displayOrder));
    for (int i = 0; i < nodes.length - 1; i++) {
      final current = nodes[i];
      final next = nodes[i + 1];
      if (current.task.parentId == next.task.parentId && next.earliestStart.isAfter(current.earliestFinish)) {
        current.successors.add(next);
        next.predecessors.add(current);
      }
    }
  }

  void _forwardPass(List<CriticalPathNode> nodes) {
    var visited = <String>{};
    var sorted = <CriticalPathNode>[];

    void visit(CriticalPathNode node) {
      if (visited.contains(node.task.id)) {
        return;
      }
      visited.add(node.task.id);
      for (var pred in node.predecessors) {
        visit(pred);
      }
      sorted.add(node);
    }

    for (var node in nodes) {
      visit(node);
    }

    for (var node in sorted) {
      if (node.predecessors.isEmpty) {
        node.earliestStart = node.task.startDate!;
      } else {
        var latestPredFinish = node.predecessors
            .map((p) => p.earliestFinish)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        node.earliestStart = latestPredFinish.add(const Duration(days: 1));
      }
      node.earliestFinish = node.earliestStart.add(Duration(days: (node.task.duration ?? 1) - 1));
    }
  }

  void _backwardPass(List<CriticalPathNode> nodes) {
    var projectEnd = nodes.map((n) => n.earliestFinish).reduce((a, b) => a.isAfter(b) ? a : b);
    var visited = <String>{};
    var sorted = <CriticalPathNode>[];

    void visit(CriticalPathNode node) {
      if (visited.contains(node.task.id)) {
        return;
      }
      visited.add(node.task.id);
      for (var succ in node.successors) {
        visit(succ);
      }
      sorted.add(node);
    }

    for (var node in nodes) {
      visit(node);
    }

    for (var node in sorted) {
      if (node.successors.isEmpty) {
        node.latestFinish = projectEnd;
      } else {
        var earliestSuccStart = node.successors
            .map((s) => s.latestStart)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        node.latestFinish = earliestSuccStart.subtract(const Duration(days: 1));
      }
      node.latestStart = node.latestFinish.subtract(Duration(days: (node.task.duration ?? 1) - 1));
    }
  }

  double _calculateFreeFloat(CriticalPathNode node, List<CriticalPathNode> nodes) {
    if (node.successors.isEmpty) return node.totalFloat;
    var minSuccEarliestStart = node.successors
        .map((s) => s.earliestStart)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return minSuccEarliestStart.difference(node.earliestFinish).inDays.toDouble() - 1;
  }

  TaskStatus _getTaskStatus(GanttRowData task) {
    final now = DateTime.now();
    if (task.endDate!.isBefore(now)) return TaskStatus.overdue;
    if (task.startDate!.isBefore(now) || task.startDate == now) return TaskStatus.ongoing;
    return TaskStatus.upcoming;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.projectId)
          .orderBy('displayOrder')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('❌ CriticalPath: Error in stream', error: snapshot.error);
          return Center(child: Text('Error loading data', style: GoogleFonts.poppins(color: Colors.red)));
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

        _calculateCriticalPath(tasks);
        _animationController.forward();

        if (tasks.isEmpty) return _buildEmptyState();

        return RefreshIndicator(
          onRefresh: () async {},
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            children: [
              FadeTransition(
                opacity: _fadeAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProjectSummaryCard(),
                    const SizedBox(height: 16),
                    _buildAnalyticsCard(),
                    const SizedBox(height: 16),
                    _buildCriticalPathSection(),
                    const SizedBox(height: 16),
                    _buildNonCriticalTasksSection(),
                    const SizedBox(height: 16),
                    _buildCriticalPathVisualization(),
                    const SizedBox(height: 16),
                    _buildRecommendationsCard(tasks),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.timeline, size: isWide ? 100 : 80, color: Colors.grey.shade400),
                const SizedBox(height: 24),
                Text(
                  'No Schedule Data Available',
                  style: GoogleFonts.poppins(
                    fontSize: isWide ? 28 : 24,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  'Add tasks in the Gantt Chart to see\ncritical path analysis',
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
      },
    );
  }

  Widget _buildProjectSummaryCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardPadding = isWide ? 32.0 : 24.0;
        final textSize = isWide ? 24.0 : 22.0;
        return Card(
          elevation: 8,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.blue.shade600, Colors.blue.shade400],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isWide ? 16 : 12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.analytics, color: Colors.white, size: isWide ? 32 : 28),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Critical Path Analysis',
                            style: GoogleFonts.poppins(
                              fontSize: textSize,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            widget.projectName,
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              color: Colors.white.withValues(alpha: 0.9),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: _buildSummaryMetric(
                        'Project Duration',
                        '${_totalProjectDuration.toInt()} days',
                        Icons.schedule,
                        Colors.white,
                        isWide,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildSummaryMetric(
                        'Critical Path',
                        '${_criticalPath.length} tasks',
                        Icons.priority_high,
                        Colors.white,
                        isWide,
                      ),
                    ),
                  ],
                ),
                if (_projectStartDate != null && _projectEndDate != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Start Date',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                _dateFormat.format(_projectStartDate!),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward, color: Colors.white.withValues(alpha: 0.7)),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'End Date',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                              Text(
                                _dateFormat.format(_projectEndDate!),
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryMetric(String title, String value, IconData icon, Color color, bool isWide) {
    return Container(
      padding: EdgeInsets.all(isWide ? 20 : 16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isWide ? 22 : 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: color.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isWide ? 24 : 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardPadding = isWide ? 28.0 : 20.0;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.insights, color: Colors.orange.shade600, size: isWide ? 28 : 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Schedule Analytics',
                        style: GoogleFonts.poppins(
                          fontSize: isWide ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade800,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: _buildAnalyticsMetric(
                        'Criticality Ratio',
                        '${(_criticalityRatio * 100).toInt()}%',
                        'Percentage of critical tasks',
                        Icons.warning_amber,
                        _criticalityRatio > 0.5 ? Colors.red : Colors.orange,
                        isWide,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildAnalyticsMetric(
                        'Total Slack',
                        '$_totalSlackDays days',
                        'Available scheduling buffer',
                        Icons.schedule_outlined,
                        Colors.green.shade600,
                        isWide,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildScheduleHealthIndicator(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAnalyticsMetric(String title, String value, String subtitle, IconData icon, Color color, bool isWide) {
    return Container(
      padding: EdgeInsets.all(isWide ? 20 : 16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: isWide ? 24 : 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: isWide ? 28 : 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildScheduleHealthIndicator() {
    Color healthColor;
    String healthText;
    IconData healthIcon;

    if (_criticalityRatio > 0.7) {
      healthColor = Colors.red;
      healthText = 'High Risk';
      healthIcon = Icons.dangerous;
    } else if (_criticalityRatio > 0.4) {
      healthColor = Colors.orange;
      healthText = 'Medium Risk';
      healthIcon = Icons.warning;
    } else {
      healthColor = Colors.green;
      healthText = 'Low Risk';
      healthIcon = Icons.check_circle;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWide ? 20 : 16),
          decoration: BoxDecoration(
            color: healthColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: healthColor.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              Icon(healthIcon, color: healthColor, size: isWide ? 28 : 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Schedule Health',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      healthText,
                      style: GoogleFonts.poppins(
                        fontSize: isWide ? 20 : 18,
                        fontWeight: FontWeight.bold,
                        color: healthColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCriticalPathSection() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardPadding = isWide ? 28.0 : 20.0;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isWide ? 14 : 10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.priority_high, color: Colors.red.shade600, size: isWide ? 28 : 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Critical Path Tasks',
                            style: GoogleFonts.poppins(
                              fontSize: isWide ? 22 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.red.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Zero float - delays will impact project completion',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                if (_criticalPath.isEmpty)
                  _buildEmptySection('No critical path identified', Icons.timeline)
                else
                  ..._criticalPath.asMap().entries.map((entry) {
                    final index = entry.key;
                    final node = entry.value;
                    return _buildCriticalTaskItem(node, index, isWide);
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCriticalTaskItem(CriticalPathNode node, int index, bool isWide) {
    final task = node.task;
    final status = _getTaskStatus(task);
    final isMainTask = task.taskType == TaskType.mainTask;
    final isSubTask = task.taskType == TaskType.subTask;

    Color statusColor;
    String statusText;
    switch (status) {
      case TaskStatus.overdue:
        statusColor = Colors.red;
        statusText = 'Overdue';
        break;
      case TaskStatus.ongoing:
        statusColor = Colors.orange;
        statusText = 'Ongoing';
        break;
      case TaskStatus.upcoming:
        statusColor = Colors.green;
        statusText = 'Upcoming';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: isWide ? 56 : 48,
                height: isWide ? 56 : 48,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.red.shade600, Colors.red.shade400],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    '${index + 1}',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isWide ? 20 : 18,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                fit: FlexFit.loose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.taskName ?? 'Untitled Task',
                      style: GoogleFonts.poppins(
                        fontWeight: isMainTask ? FontWeight.bold : FontWeight.w600,
                        fontSize: isWide ? 20 : 18,
                        color: Colors.red.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildTaskSubtitleRow(task, isWide, isMainTask, isSubTask),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.red.shade600,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'CRITICAL',
                      style: GoogleFonts.poppins(
                        fontSize: isWide ? 12 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Float: ${node.totalFloat.toInt()}d',
                    style: GoogleFonts.poppins(
                      fontSize: isWide ? 12 : 10,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: isWide ? 12 : 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTaskSubtitleRow(GanttRowData task, bool isWide, bool isMainTask, bool isSubTask) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.calendar_today, size: isWide ? 16 : 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                '${_dateFormat.format(task.startDate!)} → ${_dateFormat.format(task.endDate!)}',
                style: GoogleFonts.poppins(
                  fontSize: isWide ? 14 : 13,
                  color: Colors.grey.shade700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.timer, size: isWide ? 16 : 14, color: Colors.grey.shade600),
            const SizedBox(width: 6),
            Text(
              '${task.duration} days',
              style: GoogleFonts.poppins(
                fontSize: isWide ? 14 : 13,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: isMainTask
                    ? Colors.purple.shade100
                    : isSubTask
                        ? Colors.blue.shade100
                        : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                isMainTask ? 'Main Task' : isSubTask ? 'Subtask' : 'Task',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isMainTask
                      ? Colors.purple.shade700
                      : isSubTask
                          ? Colors.blue.shade700
                          : Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNonCriticalTasksSection() {
    if (_nonCriticalTasks.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardPadding = isWide ? 28.0 : 20.0;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isWide ? 14 : 10),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(Icons.check_circle, color: Colors.green.shade600, size: isWide ? 28 : 24),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Non-Critical Tasks',
                            style: GoogleFonts.poppins(
                              fontSize: isWide ? 22 : 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.green.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            'Have scheduling flexibility (float) without affecting completion',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.grey.shade600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                ..._nonCriticalTasks.map((node) => _buildNonCriticalTaskItem(node, isWide)),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildNonCriticalTaskItem(CriticalPathNode node, bool isWide) {
    final task = node.task;
    final status = _getTaskStatus(task);
    final isMainTask = task.taskType == TaskType.mainTask;
    final isSubTask = task.taskType == TaskType.subTask;
    final floatDays = node.totalFloat.toInt();

    Color floatColor;
    if (floatDays <= 2) {
      floatColor = Colors.orange.shade600;
    } else if (floatDays <= 5) {
      floatColor = Colors.blue.shade600;
    } else {
      floatColor = Colors.green.shade600;
    }

    Color statusColor;
    String statusText;
    switch (status) {
      case TaskStatus.overdue:
        statusColor = Colors.red;
        statusText = 'Overdue';
        break;
      case TaskStatus.ongoing:
        statusColor = Colors.orange;
        statusText = 'Ongoing';
        break;
      case TaskStatus.upcoming:
        statusColor = Colors.green;
        statusText = 'Upcoming';
        break;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: isWide ? 56 : 48,
                height: isWide ? 56 : 48,
                decoration: BoxDecoration(
                  color: floatColor,
                  borderRadius: BorderRadius.circular(28),
                ),
                child: Center(
                  child: Text(
                    '${floatDays}d',
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: isWide ? 16 : 14,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Flexible(
                fit: FlexFit.loose,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      task.taskName ?? 'Untitled Task',
                      style: GoogleFonts.poppins(
                        fontWeight: isMainTask ? FontWeight.bold : FontWeight.w600,
                        fontSize: isWide ? 18 : 16,
                        color: Colors.grey.shade800,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    _buildTaskSubtitleRow(task, isWide, isMainTask, isSubTask),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: floatColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${floatDays}D FLOAT',
                      style: GoogleFonts.poppins(
                        fontSize: isWide ? 12 : 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    floatDays <= 2 ? 'Low Buffer' : floatDays <= 5 ? 'Med Buffer' : 'High Buffer',
                    style: GoogleFonts.poppins(
                      fontSize: isWide ? 10 : 9,
                      color: floatColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: isWide ? 12 : 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      statusText.toUpperCase(),
                      style: GoogleFonts.poppins(
                        fontSize: isWide ? 12 : 10,
                        fontWeight: FontWeight.bold,
                        color: statusColor,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalPathVisualization() {
    if (_criticalPath.isEmpty) return const SizedBox.shrink();

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final itemWidth = isWide ? 160.0 : 140.0;
        final cardPadding = isWide ? 28.0 : 20.0;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.timeline, color: Colors.purple.shade600, size: isWide ? 28 : 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Critical Path Flow',
                        style: GoogleFonts.poppins(
                          fontSize: isWide ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.purple.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Sequential flow of critical tasks that determine project duration',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: isWide ? 140 : 120,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: _criticalPath.length,
                    itemBuilder: (context, index) {
                      final node = _criticalPath[index];
                      final isLast = index == _criticalPath.length - 1;
                      final isMainTask = node.task.taskType == TaskType.mainTask;

                      return Row(
                        children: [
                          Container(
                            width: itemWidth,
                            height: isWide ? 120 : 100,
                            padding: EdgeInsets.all(isWide ? 16 : 12),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: isMainTask
                                    ? [Colors.red.shade600, Colors.red.shade400]
                                    : [Colors.red.shade500, Colors.red.shade300],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.red.withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      width: isWide ? 28 : 24,
                                      height: isWide ? 28 : 24,
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(alpha: 0.3),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: GoogleFonts.poppins(
                                            fontSize: isWide ? 14 : 12,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    if (isMainTask)
                                      Icon(Icons.star, color: Colors.white, size: isWide ? 20 : 16),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Expanded(
                                  child: Text(
                                    node.task.taskName ?? 'Untitled',
                                    style: GoogleFonts.poppins(
                                      fontSize: isWide ? 15 : 13,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Row(
                                  children: [
                                    Icon(Icons.timer, color: Colors.white.withValues(alpha: 0.8), size: isWide ? 16 : 14),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${node.task.duration}d',
                                      style: GoogleFonts.poppins(
                                        fontSize: isWide ? 14 : 12,
                                        color: Colors.white.withValues(alpha: 0.9),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (!isLast)
                            SizedBox(
                              width: isWide ? 50 : 40,
                              height: isWide ? 120 : 100,
                              child: Center(
                                child: Icon(
                                  Icons.arrow_forward,
                                  color: Colors.red.shade600,
                                  size: isWide ? 28 : 24,
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRecommendationsCard(List<GanttRowData> tasks) {
    List<String> recommendations = [];

    if (_criticalityRatio > 0.7) {
      recommendations.add('Consider adding parallel tasks to reduce critical path dependencies');
      recommendations.add('Review task durations for optimization opportunities');
    }

    if (_totalSlackDays < 5) {
      recommendations.add('Low schedule buffer - consider adding contingency time');
    }

    if (_criticalPath.length > tasks.length * 0.8) {
      recommendations.add('Most tasks are critical - review project structure for efficiency');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Schedule appears well-balanced with good flexibility');
      recommendations.add('Monitor critical path tasks closely for any delays');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        final cardPadding = isWide ? 28.0 : 20.0;
        return Card(
          elevation: 4,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: EdgeInsets.all(cardPadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.lightbulb, color: Colors.amber.shade600, size: isWide ? 28 : 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Recommendations',
                        style: GoogleFonts.poppins(
                          fontSize: isWide ? 20 : 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ...recommendations.asMap().entries.map((entry) {
                  final index = entry.key;
                  final recommendation = entry.value;
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    width: double.infinity,
                    padding: EdgeInsets.all(isWide ? 20 : 16),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isWide ? 28 : 24,
                          height: isWide ? 28 : 24,
                          decoration: BoxDecoration(
                            color: Colors.amber.shade600,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: GoogleFonts.poppins(
                                fontSize: isWide ? 14 : 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            recommendation,
                            style: GoogleFonts.poppins(
                              fontSize: isWide ? 16 : 14,
                              color: Colors.grey.shade800,
                            ),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptySection(String message, IconData icon) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth > 600;
        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(isWide ? 32 : 24),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: isWide ? 64 : 48, color: Colors.grey.shade400),
              const SizedBox(height: 12),
              Text(
                message,
                style: GoogleFonts.poppins(
                  fontSize: isWide ? 18 : 16,
                  color: Colors.grey.shade600,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        );
      },
    );
  }
}

class CriticalPathNode {
  final GanttRowData task;
  DateTime earliestStart;
  DateTime latestStart;
  DateTime earliestFinish;
  DateTime latestFinish;
  double totalFloat;
  double freeFloat;
  List<CriticalPathNode> predecessors;
  List<CriticalPathNode> successors;

  CriticalPathNode({
    required this.task,
    required this.earliestStart,
    required this.latestStart,
    required this.earliestFinish,
    required this.latestFinish,
    required this.totalFloat,
    required this.freeFloat,
    required this.predecessors,
    required this.successors,
  });

  bool get isCritical => totalFloat <= 0.5;

  @override
  String toString() {
    return 'CriticalPathNode(${task.taskName}, float: $totalFloat)';
  }
}

enum TaskStatus { overdue, ongoing, upcoming }