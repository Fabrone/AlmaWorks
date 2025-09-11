import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/schedule_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class CriticalPathScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const CriticalPathScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<CriticalPathScreen> createState() => _CriticalPathScreenState();
}

class _CriticalPathScreenState extends State<CriticalPathScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  List<ScheduleModel> _tasks = [];
  List<CriticalPathNode> _criticalPath = [];
  List<ScheduleModel> _nonCriticalTasks = [];
  bool _isLoading = true;
  double _totalProjectDuration = 0;
  double _criticalPathDuration = 0;

  @override
  void initState() {
    super.initState();
    _fetchAndAnalyzeTasks();
  }

  Future<void> _fetchAndAnalyzeTasks() async {
    setState(() => _isLoading = true);
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.project.id)
          .orderBy('startDate', descending: false)
          .get();
      
      _tasks = snapshot.docs.map((doc) {
        final data = doc.data();
        return ScheduleModel.fromMap(doc.id, data);
      }).toList();
      
      _calculateCriticalPath();
      widget.logger.i('📊 CriticalPath: Loaded ${_tasks.length} tasks, ${_criticalPath.length} on critical path');
    } catch (e) {
      widget.logger.e('❌ CriticalPath: Error loading tasks', error: e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _calculateCriticalPath() {
    if (_tasks.isEmpty) return;

    // Calculate project timeline
    final projectStart = _tasks.map((t) => t.startDate).reduce((a, b) => a.isBefore(b) ? a : b);
    final projectEnd = _tasks.map((t) => t.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
    _totalProjectDuration = projectEnd.difference(projectStart).inDays.toDouble() + 1;

    // Build task dependencies and calculate critical path
    List<CriticalPathNode> nodes = [];
    List<ScheduleModel> criticalTasks = [];
    List<ScheduleModel> nonCritical = [];

    // Create nodes for each task
    for (var task in _tasks) {
      final node = CriticalPathNode(
        task: task,
        earliestStart: task.startDate,
        latestStart: task.startDate,
        earliestFinish: task.endDate,
        latestFinish: task.endDate,
        totalFloat: 0,
        freeFloat: 0,
      );
      nodes.add(node);
    }

    // Calculate critical path using task hierarchy and dates
    _criticalPath = [];

    // Find main tasks first
    var mainTasks = _tasks.where((t) => t.taskType == 'MainTask').toList();
    mainTasks.sort((a, b) => a.startDate.compareTo(b.startDate));

    for (var mainTask in mainTasks) {
      // Check if this main task is on critical path
      final hasSubtasks = _tasks.any((t) => t.parentId == mainTask.id);
      
      if (hasSubtasks) {
        // Find subtasks and determine if any are critical
        var subtasks = _tasks.where((t) => t.parentId == mainTask.id).toList();
        subtasks.sort((a, b) => a.startDate.compareTo(b.startDate));
        
        // Check for tasks with no slack/float
        for (var subtask in subtasks) {
          final subtaskNode = nodes.firstWhere((n) => n.task.id == subtask.id);
          final isOnCriticalPath = _isTaskCritical(subtask, mainTask, subtasks);
          
          if (isOnCriticalPath) {
            subtaskNode.totalFloat = 0;
            subtaskNode.freeFloat = 0;
            _criticalPath.add(subtaskNode);
            criticalTasks.add(subtask);
          } else {
            // Calculate float for non-critical tasks
            final float = _calculateTaskFloat(subtask, mainTask);
            subtaskNode.totalFloat = float;
            subtaskNode.freeFloat = float;
            nonCritical.add(subtask);
          }
        }
      } else {
        // Standalone main task
        final mainNode = nodes.firstWhere((n) => n.task.id == mainTask.id);
        final isMainCritical = _isMainTaskCritical(mainTask, mainTasks);
        
        if (isMainCritical) {
          mainNode.totalFloat = 0;
          mainNode.freeFloat = 0;
          _criticalPath.add(mainNode);
          criticalTasks.add(mainTask);
        } else {
          final float = _calculateMainTaskFloat(mainTask, mainTasks);
          mainNode.totalFloat = float;
          mainNode.freeFloat = float;
          nonCritical.add(mainTask);
        }
      }
    }

    _criticalPathDuration = _criticalPath.isNotEmpty 
        ? _criticalPath.map((n) => n.task.duration).reduce((a, b) => a + b).toDouble()
        : 0;
    
    _nonCriticalTasks = nonCritical;
  }

  bool _isTaskCritical(ScheduleModel task, ScheduleModel mainTask, List<ScheduleModel> siblings) {
    // A task is critical if delaying it would delay the entire project
    // Check if task has the longest duration path or no scheduling flexibility
    
    final taskEnd = task.endDate;
    final mainTaskEnd = mainTask.endDate;
    
    // If task ends at the same time as main task, it's likely critical
    if (taskEnd.isAtSameMomentAs(mainTaskEnd) || 
        taskEnd.difference(mainTaskEnd).inDays.abs() <= 1) {
      return true;
    }

    // Check if this is the longest path among siblings
    final maxSiblingEnd = siblings.map((s) => s.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
    return taskEnd.isAtSameMomentAs(maxSiblingEnd);
  }

  bool _isMainTaskCritical(ScheduleModel mainTask, List<ScheduleModel> allMainTasks) {
    // A main task is critical if it's on the longest path
    final taskEnd = mainTask.endDate;
    final projectEnd = allMainTasks.map((t) => t.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
    
    return taskEnd.isAtSameMomentAs(projectEnd) || 
           taskEnd.difference(projectEnd).inDays.abs() <= 1;
  }

  double _calculateTaskFloat(ScheduleModel task, ScheduleModel mainTask) {
    // Calculate total float (slack) for non-critical tasks
    final latestFinish = mainTask.endDate;
    final earliestFinish = task.endDate;
    return latestFinish.difference(earliestFinish).inDays.toDouble();
  }

  double _calculateMainTaskFloat(ScheduleModel mainTask, List<ScheduleModel> allMainTasks) {
    final projectEnd = allMainTasks.map((t) => t.endDate).reduce((a, b) => a.isAfter(b) ? a : b);
    final taskEnd = mainTask.endDate;
    return projectEnd.difference(taskEnd).inDays.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.timeline, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No schedule data available',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add tasks in the Gantt Chart tab to see the critical path analysis',
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchAndAnalyzeTasks,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildProjectSummaryCard(),
          const SizedBox(height: 16),
          _buildCriticalPathSection(),
          const SizedBox(height: 16),
          _buildNonCriticalTasksSection(),
          const SizedBox(height: 16),
          _buildCriticalPathVisualization(),
        ],
      ),
    );
  }

  Widget _buildProjectSummaryCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.analytics, color: Colors.blue.shade600, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Critical Path Analysis',
                  style: GoogleFonts.poppins(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Duration',
                    '${_totalProjectDuration.toInt()} days',
                    Icons.schedule,
                    Colors.grey.shade700,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Critical Path',
                    '${_criticalPathDuration.toInt()} days',
                    Icons.priority_high,
                    Colors.red.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Critical Tasks',
                    '${_criticalPath.length}',
                    Icons.warning_amber,
                    Colors.orange.shade600,
                  ),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Non-Critical',
                    '${_nonCriticalTasks.length}',
                    Icons.check_circle,
                    Colors.green.shade600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontSize: 18,
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
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.priority_high, color: Colors.red.shade600, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Critical Path Tasks',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These tasks have zero float and must be completed on time to avoid project delays.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            if (_criticalPath.isEmpty)
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    'No critical path identified',
                    style: GoogleFonts.poppins(color: Colors.grey.shade600),
                  ),
                ),
              )
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
    final isMainTask = task.taskType == 'MainTask';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.red.shade50, Colors.white],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red.shade200, width: 1),
      ),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.red.shade600,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              '${index + 1}',
              style: GoogleFonts.poppins(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ),
        title: Text(
          task.title,
          style: GoogleFonts.poppins(
            fontWeight: isMainTask ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
            color: Colors.red.shade800,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${_dateFormat.format(task.startDate)} → ${_dateFormat.format(task.endDate)}',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.timer, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(
                  '${task.duration} days',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
                if (!isMainTask) ...[
                  const SizedBox(width: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade100,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      'Subtask',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.blue.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
      ),
    );
  }

  Widget _buildNonCriticalTasksSection() {
    if (_nonCriticalTasks.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 20),
                ),
                const SizedBox(width: 12),
                Text(
                  'Non-Critical Tasks',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'These tasks have scheduling flexibility and can be delayed without affecting the project completion date.',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ..._nonCriticalTasks.map((task) => _buildNonCriticalTaskItem(task)),
          ],
        ),
      ),
    );
  }

  Widget _buildNonCriticalTaskItem(ScheduleModel task) {
    final isMainTask = task.taskType == 'MainTask';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.green.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green.shade200, width: 1),
      ),
      child: ListTile(
        leading: Icon(
          isMainTask ? Icons.folder : Icons.assignment,
          color: Colors.green.shade600,
        ),
        title: Text(
          task.title,
          style: GoogleFonts.poppins(
            fontWeight: isMainTask ? FontWeight.bold : FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Row(
          children: [
            Icon(Icons.calendar_today, size: 12, color: Colors.grey.shade600),
            const SizedBox(width: 4),
            Text(
              '${_dateFormat.format(task.startDate)} → ${_dateFormat.format(task.endDate)}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '(${task.duration} days)',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.green.shade600,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            'FLEXIBLE',
            style: GoogleFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCriticalPathVisualization() {
    if (_criticalPath.isEmpty) return const SizedBox.shrink();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Colors.blue.shade600, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Critical Path Flow',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 80,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _criticalPath.length,
                itemBuilder: (context, index) {
                  final node = _criticalPath[index];
                  final isLast = index == _criticalPath.length - 1;
                  
                  return Row(
                    children: [
                      Container(
                        width: 120,
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.red.shade100,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              node.task.title,
                              style: GoogleFonts.poppins(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${node.task.duration} days',
                              style: GoogleFonts.poppins(
                                fontSize: 10,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (!isLast)
                        SizedBox(
                          width: 30,
                          child: Icon(
                            Icons.arrow_forward,
                            color: Colors.red.shade600,
                            size: 20,
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
}

class CriticalPathNode {
  final ScheduleModel task;
  final DateTime earliestStart;
  final DateTime latestStart;
  final DateTime earliestFinish;
  final DateTime latestFinish;
  double totalFloat;
  double freeFloat;

  CriticalPathNode({
    required this.task,
    required this.earliestStart,
    required this.latestStart,
    required this.earliestFinish,
    required this.latestFinish,
    required this.totalFloat,
    required this.freeFloat,
  });

  bool get isCritical => totalFloat == 0;
}