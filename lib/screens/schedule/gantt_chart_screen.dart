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
    String? selectedParentId;

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
            child: NestedScrollView(
              headerSliverBuilder: (context, innerBoxIsScrolled) => [
                SliverAppBar(
                  pinned: true,
                  floating: true,
                  backgroundColor: Colors.white,
                  elevation: 0,
                  flexibleSpace: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: TabBar(
                      tabs: [
                        Tab(text: 'MainTask'),
                        Tab(text: 'ActualTask'),
                      ],
                    ),
                  ),
                ),
              ],
              body: TabBarView(
                children: [
                  // MainTask Form
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
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
                        if (startDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Selected: ${_dateFormat.format(startDate!)}', style: GoogleFonts.poppins()),
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
                        if (endDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Selected: ${_dateFormat.format(endDate!)}', style: GoogleFonts.poppins()),
                          ),
                      ],
                    ),
                  ),
                  // ActualTask Form
                  SingleChildScrollView(
                    padding: const EdgeInsets.only(top: 8.0),
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
                        if (startDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Selected: ${_dateFormat.format(startDate!)}', style: GoogleFonts.poppins()),
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
                        if (endDate != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text('Selected: ${_dateFormat.format(endDate!)}', style: GoogleFonts.poppins()),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
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
      String taskType = selectedParentId == null ? 'MainTask' : 'ActualTask';
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
        parentId: parentId,
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
    var mainTasks = _tasks.where((t) => t.taskType == 'MainTask').toList();
    for (var main in mainTasks) {
      sortedTasks.add(main);
      var actuals = _tasks.where((t) => t.parentId == main.id).toList()..sort((a, b) => a.startDate.compareTo(b.startDate));
      sortedTasks.addAll(actuals);
    }

    // Use first main task for project timeline if available
    final firstMainTask = mainTasks.isNotEmpty ? mainTasks.first : null;
    final projectStartDate = firstMainTask?.startDate ?? DateTime.now();
    final projectEndDate = firstMainTask?.endDate ?? DateTime.now();
    final days = projectEndDate.difference(projectStartDate).inDays + 1;
    final dayWidth = 20.0 * _scale;

    // Generate month-based header
    List<Widget> monthHeaders = [];
    DateTime currentDate = projectStartDate;
    while (currentDate.isBefore(projectEndDate) || currentDate.isAtSameMomentAs(projectEndDate)) {
      final monthName = DateFormat('MMMM').format(currentDate);
      final monthStart = DateTime(currentDate.year, currentDate.month, 1);
      final monthEnd = DateTime(currentDate.year, currentDate.month + 1, 0);
      final monthDays = monthEnd.difference(monthStart).inDays + 1;
      final monthWidth = monthDays * dayWidth * _scale;

      monthHeaders.add(
        SizedBox(
          width: monthWidth,
          child: Column(
            children: [
              Text(monthName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              Text(
                '${_dateFormat.format(monthStart)} - ${_dateFormat.format(monthEnd)}',
                style: GoogleFonts.poppins(),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
      currentDate = DateTime(currentDate.year, currentDate.month + 1, 1);
    }

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
                        Container(
                          width: 70,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Number', style: GoogleFonts.poppins(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                        Container(
                          width: 200,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Task Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                        Container(
                          width: 80,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Duration', style: GoogleFonts.poppins(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                        Container(
                          width: 100,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('Start Date', style: GoogleFonts.poppins(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                        Container(
                          width: 100,
                          decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text('End Date', style: GoogleFonts.poppins(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                          ),
                        ),
                        ...monthHeaders,
                      ],
                    ),
                    Divider(color: Colors.black, thickness: 2.0),
                    ...List.generate(sortedTasks.length, (index) {
                      final task = sortedTasks[index];
                      final paddingLeft = task.parentId != null ? 20.0 : 0.0; // Indent actual tasks
                      return Column(
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 70,
                                decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text((index + 1).toString(), style: GoogleFonts.poppins()),
                                ),
                              ),
                              Container(
                                width: 200,
                                decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                                child: Padding(
                                  padding: EdgeInsets.only(left: paddingLeft, top: 4.0, bottom: 4.0),
                                  child: Text(
                                    task.title,
                                    style: GoogleFonts.poppins(
                                      fontWeight: task.taskType == 'MainTask' ? FontWeight.bold : FontWeight.normal,
                                    ),
                                    softWrap: true,
                                    maxLines: 1,
                                  ),
                                ),
                              ),
                              Container(
                                width: 80,
                                decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(task.duration.toString(), style: GoogleFonts.poppins()),
                                ),
                              ),
                              Container(
                                width: 100,
                                decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(_dateFormat.format(task.startDate), style: GoogleFonts.poppins()),
                                ),
                              ),
                              Container(
                                width: 100,
                                decoration: BoxDecoration(border: Border.all(color: Colors.black)),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                                  child: Text(_dateFormat.format(task.endDate), style: GoogleFonts.poppins()),
                                ),
                              ),
                              SizedBox(
                                width: days * dayWidth,
                                height: 20.0,
                                child: CustomPaint(
                                  painter: TaskGanttPainter(task, projectStartDate, dayWidth, _scale),
                                ),
                              ),
                            ],
                          ),
                          Divider(color: Colors.black, thickness: 1.0),
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
