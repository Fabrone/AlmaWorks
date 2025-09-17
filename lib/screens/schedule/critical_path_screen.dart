import 'package:almaworks/models/gantt_row_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class CriticalPathScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final Logger logger;

  const CriticalPathScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.logger,
  });

  @override
  State<CriticalPathScreen> createState() => _CriticalPathScreenState();
}

class _CriticalPathScreenState extends State<CriticalPathScreen>
    with SingleTickerProviderStateMixin {
  final DateFormat _dateFormat = DateFormat('MMM dd, yyyy');
  List<GanttRowData> _tasks = [];
  List<CriticalPathNode> _criticalPath = [];
  List<CriticalPathNode> _nonCriticalTasks = [];
  bool _isLoading = true;
  double _totalProjectDuration = 0;
  DateTime? _projectStartDate;
  DateTime? _projectEndDate;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Analysis metrics
  int _totalSlackDays = 0;
  double _criticalityRatio = 0.0;

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
    _fetchAndAnalyzeTasks();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _fetchAndAnalyzeTasks() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.projectId)
          .orderBy('startDate', descending: false)
          .get();

      List<GanttRowData> loadedTasks = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        final task = GanttRowData.fromFirebaseMap(doc.id, data);
        if (task.hasData) {
          loadedTasks.add(task);
        }
      }

      _tasks = loadedTasks;
      _calculateCriticalPath();
      _animationController.forward();
      
      widget.logger.i('📊 CriticalPath: Loaded ${_tasks.length} tasks, ${_criticalPath.length} on critical path');
    } catch (e) {
      widget.logger.e('❌ CriticalPath: Error loading tasks', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading tasks: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _calculateCriticalPath() {
    if (_tasks.isEmpty) return;

    // Calculate project bounds
    _projectStartDate = _tasks.map((t) => t.startDate!).reduce((a, b) => a.isBefore(b) ? a : b);
    _projectEndDate = _tasks.map((t) => t.endDate!).reduce((a, b) => a.isAfter(b) ? a : b);
    _totalProjectDuration = _projectEndDate!.difference(_projectStartDate!).inDays.toDouble() + 1;

    // Build task network and dependencies
    List<CriticalPathNode> nodes = [];
    Map<String, CriticalPathNode> nodeMap = {};

    // Create nodes for each task
    for (var task in _tasks) {
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

    // Build dependencies based on task hierarchy and scheduling logic
    _buildTaskDependencies(nodes, nodeMap);

    // Forward pass - calculate earliest start and finish times
    _forwardPass(nodes);

    // Backward pass - calculate latest start and finish times
    _backwardPass(nodes);

    // Calculate float values
    for (var node in nodes) {
      node.totalFloat = node.latestStart.difference(node.earliestStart).inDays.toDouble();
      node.freeFloat = _calculateFreeFloat(node, nodes);
    }

    // Identify critical path
    _criticalPath = nodes.where((node) => node.isCritical).toList();
    _nonCriticalTasks = nodes.where((node) => !node.isCritical).toList();

    // Calculate metrics
    
    _totalSlackDays = _nonCriticalTasks.map((n) => n.totalFloat.toInt()).fold(0, (a, b) => a + b);
    _criticalityRatio = _tasks.isNotEmpty ? _criticalPath.length / _tasks.length : 0;

    // Sort critical path by earliest start date
    _criticalPath.sort((a, b) => a.earliestStart.compareTo(b.earliestStart));
  }

  void _buildTaskDependencies(List<CriticalPathNode> nodes, Map<String, CriticalPathNode> nodeMap) {
    // Group tasks by type and establish logical dependencies
    var mainTasks = nodes.where((n) => n.task.taskType == TaskType.mainTask).toList();
    var subTasks = nodes.where((n) => n.task.taskType == TaskType.subTask).toList();
    var regularTasks = nodes.where((n) => n.task.taskType == TaskType.task).toList();

    // Sort by start date for dependency logic
    mainTasks.sort((a, b) => a.earliestStart.compareTo(b.earliestStart));
    subTasks.sort((a, b) => a.earliestStart.compareTo(b.earliestStart));
    regularTasks.sort((a, b) => a.earliestStart.compareTo(b.earliestStart));

    // Link main tasks in sequence if they overlap or are sequential
    for (int i = 0; i < mainTasks.length - 1; i++) {
      final current = mainTasks[i];
      final next = mainTasks[i + 1];
      
      // If next task starts before current ends, create dependency
      if (next.earliestStart.isBefore(current.earliestFinish) || 
          next.earliestStart.difference(current.earliestFinish).inDays <= 1) {
        current.successors.add(next);
        next.predecessors.add(current);
      }
    }

    // Link subtasks to their logical main task predecessors
    for (var subTask in subTasks) {
      var closestMainTask = _findClosestPredecessorMainTask(subTask, mainTasks);
      if (closestMainTask != null) {
        closestMainTask.successors.add(subTask);
        subTask.predecessors.add(closestMainTask);
      }
    }

    // Link regular tasks to their logical predecessors (subtasks or main tasks)
    for (var task in regularTasks) {
      var closestPredecessor = _findClosestPredecessor(task, [...subTasks, ...mainTasks]);
      if (closestPredecessor != null) {
        closestPredecessor.successors.add(task);
        task.predecessors.add(closestPredecessor);
      }
    }
  }

  CriticalPathNode? _findClosestPredecessorMainTask(CriticalPathNode subTask, List<CriticalPathNode> mainTasks) {
    CriticalPathNode? closest;
    for (var mainTask in mainTasks) {
      if (mainTask.earliestFinish.isBefore(subTask.earliestStart) ||
          mainTask.earliestFinish.isAtSameMomentAs(subTask.earliestStart)) {
        if (closest == null || mainTask.earliestFinish.isAfter(closest.earliestFinish)) {
          closest = mainTask;
        }
      }
    }
    return closest;
  }

  CriticalPathNode? _findClosestPredecessor(CriticalPathNode task, List<CriticalPathNode> candidates) {
    CriticalPathNode? closest;
    for (var candidate in candidates) {
      if (candidate.earliestFinish.isBefore(task.earliestStart) ||
          candidate.earliestFinish.isAtSameMomentAs(task.earliestStart)) {
        if (closest == null || candidate.earliestFinish.isAfter(closest.earliestFinish)) {
          closest = candidate;
        }
      }
    }
    return closest;
  }

  void _forwardPass(List<CriticalPathNode> nodes) {
    // Topological sort for forward pass
    var visited = <String>{};
    var sorted = <CriticalPathNode>[];
    
    void visit(CriticalPathNode node) {
      if (visited.contains(node.task.id)) return;
      visited.add(node.task.id);
      
      for (var predecessor in node.predecessors) {
        visit(predecessor);
      }
      sorted.add(node);
    }

    for (var node in nodes) {
      visit(node);
    }

    // Calculate earliest start and finish
    for (var node in sorted) {
      if (node.predecessors.isEmpty) {
        node.earliestStart = node.task.startDate!;
      } else {
        var latestPredecessorFinish = node.predecessors
            .map((p) => p.earliestFinish)
            .reduce((a, b) => a.isAfter(b) ? a : b);
        node.earliestStart = latestPredecessorFinish.add(const Duration(days: 1));
      }
      
      node.earliestFinish = node.earliestStart.add(Duration(days: (node.task.duration ?? 1) - 1));
    }
  }

  void _backwardPass(List<CriticalPathNode> nodes) {
    // Start from project end date
    var projectEnd = nodes.map((n) => n.earliestFinish).reduce((a, b) => a.isAfter(b) ? a : b);
    
    // Reverse topological sort for backward pass
    var visited = <String>{};
    var sorted = <CriticalPathNode>[];
    
    void visit(CriticalPathNode node) {
      if (visited.contains(node.task.id)) return;
      visited.add(node.task.id);
      
      for (var successor in node.successors) {
        visit(successor);
      }
      sorted.add(node);
    }

    for (var node in nodes) {
      visit(node);
    }

    // Calculate latest finish and start
    for (var node in sorted) {
      if (node.successors.isEmpty) {
        node.latestFinish = projectEnd;
      } else {
        var earliestSuccessorStart = node.successors
            .map((s) => s.latestStart)
            .reduce((a, b) => a.isBefore(b) ? a : b);
        node.latestFinish = earliestSuccessorStart.subtract(const Duration(days: 1));
      }
      
      node.latestStart = node.latestFinish.subtract(Duration(days: (node.task.duration ?? 1) - 1));
    }
  }

  double _calculateFreeFloat(CriticalPathNode node, List<CriticalPathNode> allNodes) {
    if (node.successors.isEmpty) return node.totalFloat;
    
    var minSuccessorEarliestStart = node.successors
        .map((s) => s.earliestStart)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    
    return minSuccessorEarliestStart.difference(node.earliestFinish).inDays.toDouble() - 1;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return _buildEmptyState();
    }

    return FadeTransition(
      opacity: _fadeAnimation,
      child: RefreshIndicator(
        onRefresh: _fetchAndAnalyzeTasks,
        child: ListView(
          padding: const EdgeInsets.all(16),
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
            _buildRecommendationsCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
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
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back),
            label: Text('Go to Gantt Chart', style: GoogleFonts.poppins()),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue.shade600,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard() {
    return Card(
      elevation: 8,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.analytics, color: Colors.white, size: 28),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Critical Path Analysis',
                        style: GoogleFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        widget.projectName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
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
                  ),
                ),
                Expanded(
                  child: _buildSummaryMetric(
                    'Critical Path',
                    '${_criticalPath.length} tasks',
                    Icons.priority_high,
                    Colors.white,
                  ),
                ),
              ],
            ),
            if (_projectStartDate != null && _projectEndDate != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
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
                        ),
                      ],
                    ),
                    Icon(Icons.arrow_forward, color: Colors.white.withValues(alpha: 0.7)),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
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
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: Colors.orange.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Schedule Analytics',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade800,
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
                  ),
                ),
                Expanded(
                  child: _buildAnalyticsMetric(
                    'Total Slack',
                    '$_totalSlackDays days',
                    'Available scheduling buffer',
                    Icons.schedule_outlined,
                    Colors.green.shade600,
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
  }

  Widget _buildAnalyticsMetric(String title, String value, String subtitle, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade600,
            ),
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

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: healthColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: healthColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(healthIcon, color: healthColor, size: 24),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Schedule Health',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                healthText,
                style: GoogleFonts.poppins(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: healthColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryMetric(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(
                title,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: color.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCriticalPathSection() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.priority_high, color: Colors.red.shade600, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Critical Path Tasks',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                      Text(
                        'Zero float - delays will impact project completion',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
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
                return _buildCriticalTaskItem(node, index);
              }),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalTaskItem(CriticalPathNode node, int index) {
    final task = node.task;
    final isMainTask = task.taskType == TaskType.mainTask;
    final isSubTask = task.taskType == TaskType.subTask;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200, width: 1.5),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.red.shade600, Colors.red.shade400],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ),
        ),
        title: Text(
          task.taskName ?? 'Untitled Task',
          style: GoogleFonts.poppins(
            fontWeight: isMainTask ? FontWeight.bold : FontWeight.w600,
            fontSize: isMainTask ? 18 : 16,
            color: Colors.red.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${_dateFormat.format(task.startDate!)} → ${_dateFormat.format(task.endDate!)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${task.duration} days',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
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
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.red.shade600,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'CRITICAL',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Float: ${node.totalFloat.toInt()}d',
              style: GoogleFonts.poppins(
                fontSize: 10,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNonCriticalTasksSection() {
    if (_nonCriticalTasks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Non-Critical Tasks',
                        style: GoogleFonts.poppins(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade700,
                        ),
                      ),
                      Text(
                        'Have scheduling flexibility (float) without affecting completion',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            // Sort by total float (ascending) to show tasks with least flexibility first
            ...(_nonCriticalTasks..sort((a, b) => a.totalFloat.compareTo(b.totalFloat)))
                .map((node) => _buildNonCriticalTaskItem(node)),
          ],
        ),
      ),
    );
  }

  Widget _buildNonCriticalTaskItem(CriticalPathNode node) {
    final task = node.task;
    final isMainTask = task.taskType == TaskType.mainTask;
    final isSubTask = task.taskType == TaskType.subTask;
    final floatDays = node.totalFloat.toInt();
    
    // Color coding based on float amount
    Color floatColor;
    if (floatDays <= 2) {
      floatColor = Colors.orange.shade600;
    } else if (floatDays <= 5) {
      floatColor = Colors.blue.shade600;
    } else {
      floatColor = Colors.green.shade600;
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: floatColor,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Center(
            child: Text(
              '${floatDays}d',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
        ),
        title: Text(
          task.taskName ?? 'Untitled Task',
          style: GoogleFonts.poppins(
            fontWeight: isMainTask ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
            color: Colors.grey.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${_dateFormat.format(task.startDate!)} → ${_dateFormat.format(task.endDate!)}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 6),
                Text(
                  '${task.duration} days',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey.shade700,
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
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: floatColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${floatDays}D FLOAT',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              floatDays <= 2 ? 'Low Buffer' : floatDays <= 5 ? 'Med Buffer' : 'High Buffer',
              style: GoogleFonts.poppins(
                fontSize: 9,
                color: floatColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalPathVisualization() {
    if (_criticalPath.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.purple.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Critical Path Flow',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.purple.shade700,
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
            ),
            const SizedBox(height: 20),
            SizedBox(
              height: 120,
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
                        width: 140,
                        height: 100,
                        padding: const EdgeInsets.all(12),
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
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.3),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      '${index + 1}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                if (isMainTask)
                                  Icon(Icons.star, color: Colors.white, size: 16),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              node.task.taskName ?? 'Untitled',
                              style: GoogleFonts.poppins(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const Spacer(),
                            Row(
                              children: [
                                Icon(Icons.timer, color: Colors.white.withValues(alpha: 0.8), size: 14),
                                const SizedBox(width: 4),
                                Text(
                                  '${node.task.duration}d',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
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
                          width: 40,
                          height: 100,
                          child: Center(
                            child: Icon(
                              Icons.arrow_forward,
                              color: Colors.red.shade600,
                              size: 24,
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
  }

  Widget _buildRecommendationsCard() {
    List<String> recommendations = [];

    if (_criticalityRatio > 0.7) {
      recommendations.add('Consider adding parallel tasks to reduce critical path dependencies');
      recommendations.add('Review task durations for optimization opportunities');
    }
    
    if (_totalSlackDays < 5) {
      recommendations.add('Low schedule buffer - consider adding contingency time');
    }

    if (_criticalPath.length > _tasks.length * 0.8) {
      recommendations.add('Most tasks are critical - review project structure for efficiency');
    }

    if (recommendations.isEmpty) {
      recommendations.add('Schedule appears well-balanced with good flexibility');
      recommendations.add('Monitor critical path tasks closely for any delays');
    }

    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber.shade600, size: 24),
                const SizedBox(width: 12),
                Text(
                  'Recommendations',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.amber.shade700,
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
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.amber.shade600,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
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
                          fontSize: 14,
                          color: Colors.grey.shade800,
                        ),
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
  }

  Widget _buildEmptySection(String message, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 12),
            Text(
              message,
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

  bool get isCritical => totalFloat <= 0.5; // Allow for small rounding differences

  @override
  String toString() {
    return 'CriticalPathNode(${task.taskName}, float: $totalFloat)';
  }
}