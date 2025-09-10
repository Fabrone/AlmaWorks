import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/schedule_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class GanttChartScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const GanttChartScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<GanttChartScreen> createState() => _GanttChartScreenState();
}

class _GanttChartScreenState extends State<GanttChartScreen> {
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  double _scale = 1.0;
  List<ScheduleModel> _tasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTasks();
  }

  Future<void> _fetchTasks() async {
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
      widget.logger.i('📅 GanttChartScreen: Loaded ${_tasks.length} tasks');
    } catch (e) {
      widget.logger.e('❌ GanttChartScreen: Error loading tasks', error: e);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _addTask() async {
    final titleController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    int? duration;
    String? selectedLevel;
    String? selectedParentId;

    final levels = ['1', '2', '3', '4', '5'];
    final existingMainTasks = _tasks.where((task) => task.taskType == 'MainTask').toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Task', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        contentPadding: const EdgeInsets.all(16.0),
        content: DefaultTabController(
          length: 2,
          child: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: TabBar(
                    tabs: [
                      Tab(text: 'MainTask'),
                      Tab(text: 'ActualTask'),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: SizedBox(
                    height: 300,
                    child: TabBarView(
                      children: [
                        // MainTask Form
                        SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonFormField<String>(
                                initialValue: selectedLevel,
                                hint: Text('Select Level', style: GoogleFonts.poppins()),
                                items: levels.map((level) {
                                  final enabled = levels.indexOf(level) == 0 ||
                                      existingMainTasks.any((task) => task.level == int.parse(level) - 1);
                                  return DropdownMenuItem(
                                    value: enabled ? level : null,
                                    enabled: enabled,
                                    child: Text('Level $level', style: GoogleFonts.poppins()),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() => selectedLevel = value),
                                decoration: InputDecoration(labelText: 'Level', border: OutlineInputBorder()),
                              ),
                              SizedBox(height: 16.0),
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(labelText: 'Task Name', border: OutlineInputBorder()),
                                style: GoogleFonts.poppins(),
                              ),
                              SizedBox(height: 16.0),
                              TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: 'Duration (days)', border: OutlineInputBorder()),
                                onChanged: (value) => duration = int.tryParse(value),
                              ),
                              SizedBox(height: 16.0),
                              ListTile(
                                title: Text(startDate == null ? 'Select Start Date' : _dateFormat.format(startDate!)),
                                trailing: Icon(Icons.calendar_today),
                                onTap: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (selected != null) setState(() => startDate = selected);
                                },
                              ),
                              SizedBox(height: 16.0),
                              ListTile(
                                title: Text(endDate == null ? 'Select End Date' : _dateFormat.format(endDate!)),
                                trailing: Icon(Icons.calendar_today),
                                onTap: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (selected != null) setState(() => endDate = selected);
                                },
                              ),
                            ],
                          ),
                        ),
                        // ActualTask Form
                        SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              DropdownButtonFormField<String>(
                                hint: Text('Select Parent MainTask', style: GoogleFonts.poppins()),
                                items: existingMainTasks.map((task) {
                                  return DropdownMenuItem(
                                    value: task.id,
                                    child: SizedBox(
                                      width: 300.0,
                                      child: Text(task.title, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins()),
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) => setState(() => selectedParentId = value),
                                decoration: InputDecoration(labelText: 'Parent MainTask', border: OutlineInputBorder()),
                              ),
                              SizedBox(height: 16.0),
                              TextField(
                                controller: titleController,
                                decoration: InputDecoration(labelText: 'Task Name', border: OutlineInputBorder()),
                                style: GoogleFonts.poppins(),
                              ),
                              SizedBox(height: 16.0),
                              TextField(
                                keyboardType: TextInputType.number,
                                decoration: InputDecoration(labelText: 'Duration (days)', border: OutlineInputBorder()),
                                onChanged: (value) => duration = int.tryParse(value),
                              ),
                              SizedBox(height: 16.0),
                              ListTile(
                                title: Text(startDate == null ? 'Select Start Date' : _dateFormat.format(startDate!)),
                                trailing: Icon(Icons.calendar_today),
                                onTap: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (selected != null) setState(() => startDate = selected);
                                },
                              ),
                              SizedBox(height: 16.0),
                              ListTile(
                                title: Text(endDate == null ? 'Select End Date' : _dateFormat.format(endDate!)),
                                trailing: Icon(Icons.calendar_today),
                                onTap: () async {
                                  final selected = await showDatePicker(
                                    context: context,
                                    initialDate: DateTime.now(),
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime(2030),
                                  );
                                  if (selected != null) setState(() => endDate = selected);
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && startDate != null && endDate != null && duration != null) {
                Navigator.pop(context, true);
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill all fields', style: GoogleFonts.poppins())),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A2E5A), foregroundColor: Colors.white),
            child: Text('Save', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != true || startDate == null || endDate == null || duration == null) return;

    try {
      String taskTitle = titleController.text;
      String taskType = selectedLevel != null ? 'MainTask' : 'ActualTask';
      int? level = selectedLevel != null ? int.parse(selectedLevel!) : null;
      String? parentId = selectedParentId;

      final newTask = ScheduleModel(
        id: '',
        title: taskTitle,
        projectId: widget.project.id,
        projectName: widget.project.name,
        startDate: startDate!,
        endDate: endDate!,
        duration: duration!,
        updatedAt: DateTime.now(),
        taskType: taskType,
        level: level,
        parentId: parentId, // No need for ?? '' since parentId is now nullable
      );
      await FirebaseFirestore.instance.collection('Schedule').add(newTask.toMap());
      widget.logger.i('✅ GanttChartScreen: Task added successfully: ${titleController.text}');
      _fetchTasks();
    } catch (e) {
      widget.logger.e('❌ GanttChartScreen: Error adding task', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding task: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    // Build hierarchy
    List<ScheduleModel> sortedTasks = [];
    var mainTasks = _tasks.where((t) => t.taskType == 'MainTask').toList()..sort((a, b) => (a.level ?? 0).compareTo(b.level ?? 0));
    Map<String, int> mainLevels = {for (var main in mainTasks) main.id: main.level ?? 0};
    for (var main in mainTasks) {
      sortedTasks.add(main);
      var actuals = _tasks.where((t) => t.parentId == main.id).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
      sortedTasks.addAll(actuals);
    }

    final startDate = sortedTasks.isNotEmpty ? sortedTasks.map((t) => t.startDate).reduce((a, b) => a.isBefore(b) ? a : b) : DateTime.now();
    final endDate = sortedTasks.isNotEmpty ? sortedTasks.map((t) => t.endDate).reduce((a, b) => a.isAfter(b) ? a : b) : DateTime.now();
    final days = endDate.difference(startDate).inDays + 1;
    final dayWidth = 20.0 * _scale;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Project Timeline', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              ElevatedButton(
                onPressed: _addTask,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF0A2E5A), foregroundColor: Colors.white),
                child: Text('Add Task', style: GoogleFonts.poppins(fontSize: 16)),
              ),
            ],
          ),
        ),
        Expanded(
          child: GestureDetector(
            onScaleUpdate: (details) => setState(() => _scale = (_scale * details.scale).clamp(0.5, 2.0)),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              controller: _horizontalScrollController,
              child: SingleChildScrollView(
                controller: _verticalScrollController,
                child: Column(
                  children: [
                    // Header Row
                    Row(
                      children: [
                        SizedBox(width: 50, child: Text('Number', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        SizedBox(width: 200, child: Text('Task Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        SizedBox(width: 80, child: Text('Duration', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('Start Date', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        SizedBox(width: 100, child: Text('End Date', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                        SizedBox(width: days * dayWidth, child: Text('Gantt', style: GoogleFonts.poppins(fontWeight: FontWeight.bold))),
                      ],
                    ),
                    Divider(),
                    ...List.generate(sortedTasks.length, (index) {
                      final task = sortedTasks[index];
                      int effectiveLevel = task.level ?? (task.parentId != null && mainLevels.containsKey(task.parentId) ? mainLevels[task.parentId]! : 0) + 1;
                      final paddingLeft = (effectiveLevel - 1) * 20.0;
                      return Column(
                        children: [
                          Row(
                            children: [
                              SizedBox(width: 50, child: Text((index + 1).toString())),
                              SizedBox(
                                width: 200,
                                child: Padding(
                                  padding: EdgeInsets.only(left: paddingLeft),
                                  child: Text(
                                    task.title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: task.taskType == 'MainTask' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                  ),
                                ),
                              ),
                              SizedBox(width: 80, child: Text(task.duration.toString())),
                              SizedBox(width: 100, child: Text(_dateFormat.format(task.startDate))),
                              SizedBox(width: 100, child: Text(_dateFormat.format(task.endDate))),
                              SizedBox(
                                width: days * dayWidth,
                                height: 20.0,
                                child: CustomPaint(
                                  painter: TaskGanttPainter(task, startDate, dayWidth, _scale),
                                ),
                              ),
                            ],
                          ),
                          Divider(),
                        ],
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class TaskGanttPainter extends CustomPainter {
  final ScheduleModel task;
  final DateTime startDate;
  final double dayWidth;
  final double scale;

  TaskGanttPainter(this.task, this.startDate, this.dayWidth, this.scale);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 2.0;
    final startOffset = task.startDate.difference(startDate).inDays * dayWidth * scale;
    final duration = task.endDate.difference(task.startDate).inDays + 1;
    final width = duration * dayWidth * scale;

    paint.color = task.taskType == 'MainTask' ? Colors.blue : Colors.green;
    canvas.drawRect(
      Rect.fromLTWH(startOffset, 0, width, 20.0),
      paint..style = PaintingStyle.fill,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}