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

  // Table column widths for consistency
  static const double numberColumnWidth = 60.0;
  static const double taskNameColumnWidth = 200.0;
  static const double durationColumnWidth = 80.0;
  static const double dateColumnWidth = 100.0;
  static const double dayWidth = 30.0;

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

  // Calculate project timeline boundaries
  (DateTime startDate, DateTime endDate) _calculateProjectTimeline() {
    if (_tasks.isEmpty) return (DateTime.now(), DateTime.now());
    
    DateTime earliestStart = _tasks.first.startDate;
    DateTime latestEnd = _tasks.first.endDate;
    
    for (var task in _tasks) {
      if (task.startDate.isBefore(earliestStart)) earliestStart = task.startDate;
      if (task.endDate.isAfter(latestEnd)) latestEnd = task.endDate;
    }
    
    return (earliestStart, latestEnd);
  }

  // Generate date headers with proper month and day display
  Widget _buildDateHeaders(DateTime startDate, DateTime endDate) {
    final totalDays = endDate.difference(startDate).inDays + 1;
    final scaledDayWidth = dayWidth * _scale;
    
    return Column(
      children: [
        // Month headers
        SizedBox(
          height: 40,
          child: _buildMonthHeaders(startDate, endDate, scaledDayWidth),
        ),
        // Day headers
        SizedBox(
          height: 30,
          child: _buildDayHeaders(startDate, totalDays, scaledDayWidth),
        ),
      ],
    );
  }

  Widget _buildMonthHeaders(DateTime startDate, DateTime endDate, double scaledDayWidth) {
    List<Widget> monthHeaders = [];
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);
    
    while (currentMonth.isBefore(endDate) || currentMonth.isAtSameMomentAs(endDate)) {
      // Calculate days in this month that fall within project timeline
      DateTime monthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      if (monthEnd.isAfter(endDate)) monthEnd = endDate;
      DateTime monthStart = currentMonth.isBefore(startDate) ? startDate : currentMonth;
      
      int daysInMonth = monthEnd.difference(monthStart).inDays + 1;
      double monthWidth = daysInMonth * scaledDayWidth;
      
      monthHeaders.add(
        Container(
          width: monthWidth,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
            color: Colors.grey.shade100,
          ),
          child: Center(
            child: Text(
              DateFormat('MMMM yyyy').format(currentMonth),
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
        ),
      );
      
      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }
    
    return Row(children: monthHeaders);
  }

  Widget _buildDayHeaders(DateTime startDate, int totalDays, double scaledDayWidth) {
    List<Widget> dayHeaders = [];
    
    for (int i = 0; i < totalDays; i++) {
      DateTime currentDate = startDate.add(Duration(days: i));
      dayHeaders.add(
        Container(
          width: scaledDayWidth,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
            color: Colors.white,
          ),
          child: Center(
            child: Text(
              currentDate.day.toString(),
              style: GoogleFonts.poppins(
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      );
    }
    
    return Row(children: dayHeaders);
  }

  // Build unified table structure
  Widget _buildGanttTable(DateTime projectStart, DateTime projectEnd) {
    // Build hierarchy
    List<ScheduleModel> sortedTasks = [];
    var mainTasks = _tasks.where((t) => t.taskType == 'MainTask').toList();
    mainTasks.sort((a, b) => a.startDate.compareTo(b.startDate));
    
    for (var main in mainTasks) {
      sortedTasks.add(main);
      var actuals = _tasks.where((t) => t.parentId == main.id).toList();
      actuals.sort((a, b) => a.startDate.compareTo(b.startDate));
      sortedTasks.addAll(actuals);
    }

    final totalDays = projectEnd.difference(projectStart).inDays + 1;
    final scaledDayWidth = dayWidth * _scale;
    final ganttWidth = totalDays * scaledDayWidth;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Table Header
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade600, width: 1),
            color: Colors.blue.shade50,
          ),
          child: Row(
            children: [
              // Fixed columns
              _buildHeaderCell('No.', numberColumnWidth),
              _buildHeaderCell('Task Name', taskNameColumnWidth),
              _buildHeaderCell('Duration', durationColumnWidth),
              _buildHeaderCell('Start Date', dateColumnWidth),
              _buildHeaderCell('End Date', dateColumnWidth),
              // Gantt header
              SizedBox(
                width: ganttWidth,
                child: _buildDateHeaders(projectStart, projectEnd),
              ),
            ],
          ),
        ),
        
        // Table Body
        ...List.generate(sortedTasks.length, (index) {
          final task = sortedTasks[index];
          return _buildTaskRow(task, index + 1, projectStart, ganttWidth, scaledDayWidth);
        }),
      ],
    );
  }

  Widget _buildHeaderCell(String title, double width) {
    return Container(
      width: width,
      height: 70, // Match date headers height
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade400, width: 0.5),
        color: Colors.blue.shade100,
      ),
      child: Center(
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTaskRow(ScheduleModel task, int rowNumber, DateTime projectStart, double ganttWidth, double scaledDayWidth) {
    final isMainTask = task.taskType == 'MainTask';
    final rowHeight = 40.0;
    
    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
        color: isMainTask ? Colors.blue.shade50 : Colors.white,
      ),
      child: Row(
        children: [
          // Number
          _buildDataCell(
            rowNumber.toString(),
            numberColumnWidth,
            rowHeight,
            alignment: Alignment.center,
          ),
          
          // Task Name (with indentation for subtasks)
          _buildDataCell(
            task.title,
            taskNameColumnWidth,
            rowHeight,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(left: isMainTask ? 8 : 24),
            fontWeight: isMainTask ? FontWeight.w600 : FontWeight.normal,
          ),
          
          // Duration
          _buildDataCell(
            '${task.duration} days',
            durationColumnWidth,
            rowHeight,
            alignment: Alignment.center,
          ),
          
          // Start Date
          _buildDataCell(
            _dateFormat.format(task.startDate),
            dateColumnWidth,
            rowHeight,
            alignment: Alignment.center,
          ),
          
          // End Date
          _buildDataCell(
            _dateFormat.format(task.endDate),
            dateColumnWidth,
            rowHeight,
            alignment: Alignment.center,
          ),
          
          // Gantt Chart
          Container(
            width: ganttWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: CustomPaint(
              painter: TaskGanttPainter(task, projectStart, scaledDayWidth),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDataCell(
    String text,
    double width,
    double height, {
    Alignment alignment = Alignment.center,
    EdgeInsets? padding,
    FontWeight fontWeight = FontWeight.normal,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300, width: 0.5),
      ),
      alignment: alignment,
      padding: padding ?? const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        text,
        style: GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: fontWeight,
        ),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
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
            Icon(Icons.calendar_view_month, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No tasks found',
              style: GoogleFonts.poppins(fontSize: 18, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _addTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5A),
                foregroundColor: Colors.white,
              ),
              child: Text('Add First Task', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    }

    final (projectStart, projectEnd) = _calculateProjectTimeline();

    return Column(
      children: [
        // Header with project info and controls
        Container(
          padding: const EdgeInsets.all(16),
          color: Colors.grey.shade100,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.project.name,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${_tasks.length} tasks • ${_dateFormat.format(projectStart)} to ${_dateFormat.format(projectEnd)}',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),
              Row(
                children: [
                  Tooltip(
                    message: 'Add Task',
                    child: ElevatedButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text('Add Task', style: GoogleFonts.poppins(fontSize: 14)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2E5A),
                        foregroundColor: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Zoom In',
                    child: IconButton(
                      icon: const Icon(Icons.zoom_in),
                      onPressed: () => setState(() => _scale = (_scale * 1.2).clamp(0.5, 3.0)),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0A2E5A),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Tooltip(
                    message: 'Zoom Out',
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out),
                      onPressed: () => setState(() => _scale = (_scale / 1.2).clamp(0.5, 3.0)),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0A2E5A),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        // Gantt Table
        Expanded(
          child: SingleChildScrollView(
            controller: _horizontalScrollController,
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              controller: _verticalScrollController,
              child: _buildGanttTable(projectStart, projectEnd),
            ),
          ),
        ),
      ],
    );
  }
}

class TaskGanttPainter extends CustomPainter {
  final ScheduleModel task;
  final DateTime projectStartDate;
  final double dayWidth;

  TaskGanttPainter(this.task, this.projectStartDate, this.dayWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..strokeWidth = 1.0;
    
    // Calculate position and width
    final startOffset = task.startDate.difference(projectStartDate).inDays * dayWidth;
    final duration = task.endDate.difference(task.startDate).inDays + 1;
    final width = duration * dayWidth;
    
    // Task bar
    final isMainTask = task.taskType == 'MainTask';
    final barHeight = isMainTask ? 16.0 : 12.0;
    final barTop = (size.height - barHeight) / 2;
    
    paint.color = isMainTask ? Colors.blue.shade600 : Colors.green.shade600;
    paint.style = PaintingStyle.fill;
    
    final rect = Rect.fromLTWH(startOffset + 2, barTop, width - 4, barHeight);
    final radius = Radius.circular(isMainTask ? 4.0 : 3.0);
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    
    // Task bar border
    paint.color = isMainTask ? Colors.blue.shade800 : Colors.green.shade800;
    paint.style = PaintingStyle.stroke;
    paint.strokeWidth = 1.0;
    canvas.drawRRect(RRect.fromRectAndRadius(rect, radius), paint);
    
    // Progress indicator (optional - you can add progress field to your model)
    final progressWidth = width * 0.6; // Example: 60% progress
    if (progressWidth > 0) {
      paint.color = isMainTask ? Colors.blue.shade300 : Colors.green.shade300;
      paint.style = PaintingStyle.fill;
      final progressRect = Rect.fromLTWH(startOffset + 2, barTop + 2, progressWidth - 4, barHeight - 4);
      canvas.drawRRect(RRect.fromRectAndRadius(progressRect, Radius.circular(2.0)), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}