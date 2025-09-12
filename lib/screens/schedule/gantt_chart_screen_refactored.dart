import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/schedule_model.dart';
import 'package:almaworks/screens/schedule/task_dialog_manager.dart';
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
  bool _editModeEnabled = false;
  bool _showAddNewRow = false;

  // Controllers for new task row
  final TextEditingController _newTaskTitleController = TextEditingController();
  DateTime? _newTaskStartDate;
  DateTime? _newTaskEndDate;
  int? _newTaskDuration;
  String? _newTaskParentId;
  String _newTaskType = 'Maintaskgroup';

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

  @override
  void dispose() {
    _newTaskTitleController.dispose();
    super.dispose();
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
    await TaskDialogManager.showAddTaskDialog(
      context: context,
      project: widget.project,
      tasks: _tasks,
      logger: widget.logger,
      onTaskAdded: _fetchTasks,
    );
  }

  void _toggleEditMode() {
    setState(() {
      _editModeEnabled = !_editModeEnabled;
      if (!_editModeEnabled) {
        _showAddNewRow = false;
        _clearNewTaskInputs();
      }
    });
    if (_editModeEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Edit mode enabled. Click on cells to edit inline or use the Add New Row button.',
            style: GoogleFonts.poppins(),
          ),
          duration: Duration(seconds: 3),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  void _clearNewTaskInputs() {
    _newTaskTitleController.clear();
    _newTaskStartDate = null;
    _newTaskEndDate = null;
    _newTaskDuration = null;
    _newTaskParentId = null;
    _newTaskType = 'Maintaskgroup';
  }

  Future<void> _handleInlineTaskNameEdit(ScheduleModel task) async {
    if (task.taskType == 'Maintaskgroup') {
      // For main tasks, just edit the title
      await _showInlineTextEditor(task.title, 'Edit Task Name', (
        newValue,
      ) async {
        final updatedTask = ScheduleModel(
          id: task.id,
          title: newValue,
          projectId: task.projectId,
          projectName: task.projectName,
          startDate: task.startDate,
          endDate: task.endDate,
          duration: task.duration,
          updatedAt: DateTime.now(),
          taskType: task.taskType,
          parentId: task.parentId,
        );

        await TaskDialogManager.saveInlineEdit(
          context: context,
          project: widget.project,
          task: updatedTask,
          logger: widget.logger,
          onTaskUpdated: _fetchTasks,
        );
      });
    } else {
      // For subtasks, allow parent selection too
      // Remove the unused 'result' variable and add mounted check
      if (!mounted) return;

      await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (context) => _TaskEditBottomSheet(
          task: task,
          tasks: _tasks,
          onSave: (updatedTask) async {
            // Add mounted check before using context
            if (mounted) {
              await TaskDialogManager.saveInlineEdit(
                context: context,
                project: widget.project,
                task: updatedTask,
                logger: widget.logger,
                onTaskUpdated: _fetchTasks,
              );
            }
          },
        ),
      );
    }
  }

  Future<void> _handleInlineDateEdit(
    ScheduleModel task,
    bool isStartDate,
  ) async {
    final selectedDate = await TaskDialogManager.showDatePickerDialog(
      context,
      isStartDate ? task.startDate : task.endDate,
    );

    if (selectedDate != null) {
      DateTime newStartDate = isStartDate ? selectedDate : task.startDate;
      DateTime newEndDate = isStartDate ? task.endDate : selectedDate;

      // Auto-calculate duration
      int newDuration = TaskDialogManager.calculateDuration(
        newStartDate,
        newEndDate,
      );

      final updatedTask = ScheduleModel(
        id: task.id,
        title: task.title,
        projectId: task.projectId,
        projectName: task.projectName,
        startDate: newStartDate,
        endDate: newEndDate,
        duration: newDuration,
        updatedAt: DateTime.now(),
        taskType: task.taskType,
        parentId: task.parentId,
      );

      if (mounted) {
        await TaskDialogManager.saveInlineEdit(
          context: context,
          project: widget.project,
          task: updatedTask,
          logger: widget.logger,
          onTaskUpdated: _fetchTasks,
        );
      }
    }
  }

  Future<void> _handleInlineDurationEdit(ScheduleModel task) async {
    await _showInlineTextEditor(
      task.duration.toString(),
      'Edit Duration (days)',
      (newValue) async {
        final duration = int.tryParse(newValue);
        if (duration != null && duration > 0) {
          // Recalculate end date based on new duration
          DateTime newEndDate = task.startDate.add(
            Duration(days: duration - 1),
          );

          final updatedTask = ScheduleModel(
            id: task.id,
            title: task.title,
            projectId: task.projectId,
            projectName: task.projectName,
            startDate: task.startDate,
            endDate: newEndDate,
            duration: duration,
            updatedAt: DateTime.now(),
            taskType: task.taskType,
            parentId: task.parentId,
          );

          await TaskDialogManager.saveInlineEdit(
            context: context,
            project: widget.project,
            task: updatedTask,
            logger: widget.logger,
            onTaskUpdated: _fetchTasks,
          );
        }
      },
      keyboardType: TextInputType.number,
    );
  }

  Future<void> _showInlineTextEditor(
    String initialValue,
    String title,
    Function(String) onSave, {
    TextInputType keyboardType = TextInputType.text,
  }) async {
    final controller = TextEditingController(text: initialValue);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          title,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter $title',
          ),
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
            ),
            child: Text('Save', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      onSave(result.trim());
    }

    controller.dispose();
  }

  Future<void> _addNewTaskInline() async {
    if (_newTaskTitleController.text.trim().isEmpty || 
        _newTaskStartDate == null || 
        _newTaskEndDate == null ||
        _newTaskDuration == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please fill all required fields', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final newTask = ScheduleModel(
      id: '',
      title: _newTaskTitleController.text.trim(),
      projectId: widget.project.id,
      projectName: widget.project.name,
      startDate: _newTaskStartDate!,
      endDate: _newTaskEndDate!,
      duration: _newTaskDuration!,
      updatedAt: DateTime.now(),
      taskType: _newTaskType,
      parentId: _newTaskParentId,
    );

    await TaskDialogManager.addInlineTask(
      context: context,
      project: widget.project,
      newTask: newTask,
      logger: widget.logger,
      onTaskAdded: () {
        _fetchTasks();
        setState(() {
          _showAddNewRow = false;
          _clearNewTaskInputs();
        });
      },
    );
  }

  // Calculate project timeline boundaries
  (DateTime startDate, DateTime endDate) _calculateProjectTimeline() {
    if (_tasks.isEmpty) return (DateTime.now(), DateTime.now());

    DateTime earliestStart = _tasks.first.startDate;
    DateTime latestEnd = _tasks.first.endDate;

    for (var task in _tasks) {
      if (task.startDate.isBefore(earliestStart)) {
        earliestStart = task.startDate;
      }
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

  Widget _buildMonthHeaders(
    DateTime startDate,
    DateTime endDate,
    double scaledDayWidth,
  ) {
    List<Widget> monthHeaders = [];
    DateTime currentMonth = DateTime(startDate.year, startDate.month, 1);

    while (currentMonth.isBefore(endDate) ||
        currentMonth.isAtSameMomentAs(endDate)) {
      // Calculate days in this month that fall within project timeline
      DateTime monthEnd = DateTime(
        currentMonth.year,
        currentMonth.month + 1,
        0,
      );
      if (monthEnd.isAfter(endDate)) monthEnd = endDate;
      DateTime monthStart = currentMonth.isBefore(startDate)
          ? startDate
          : currentMonth;

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

  Widget _buildDayHeaders(
    DateTime startDate,
    int totalDays,
    double scaledDayWidth,
  ) {
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
    var mainTasks = _tasks.where((t) => t.taskType == 'Maintaskgroup').toList();
    mainTasks.sort((a, b) => a.startDate.compareTo(b.startDate));
    widget.logger.i('Main tasks: ${mainTasks.length}');

    for (var main in mainTasks) {
      sortedTasks.add(main);
      widget.logger.i('Added Maintaskgroup: ${main.title} (ID: ${main.id})');
      final subgroups = _tasks.where((t) => t.taskType == 'Maintasksubgroup' && t.parentId == main.id).toList();
      subgroups.sort((a, b) => a.startDate.compareTo(b.startDate));
      widget.logger.i('Subgroups for ${main.title}: ${subgroups.length}');
      sortedTasks.addAll(subgroups);
      for (var subgroup in subgroups) {
        final tasks = _tasks.where((t) => t.taskType == 'Task' && t.parentId == subgroup.id).toList();
        tasks.sort((a, b) => a.startDate.compareTo(b.startDate));
        widget.logger.i('Tasks for subgroup ${subgroup.title}: ${tasks.length}');
        sortedTasks.addAll(tasks);
      }
      final mainTasksDirect = _tasks.where((t) => t.taskType == 'Task' && t.parentId == main.id).toList();
      mainTasksDirect.sort((a, b) => a.startDate.compareTo(b.startDate));
      widget.logger.i('Tasks for ${main.title}: ${mainTasksDirect.length}');
      sortedTasks.addAll(mainTasksDirect);
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
          return _buildTaskRow(
            task,
            index + 1,
            projectStart,
            ganttWidth,
            scaledDayWidth,
          );
        }),

        // Add new task row if in edit mode
        if (_editModeEnabled && _showAddNewRow)
          _buildNewTaskRow(projectStart, ganttWidth, scaledDayWidth),

        // Add New Row Button
        if (_editModeEnabled && !_showAddNewRow)
          Container(
            height: 50,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
              color: Colors.green.shade50,
            ),
            child: Center(
              child: TextButton.icon(
                onPressed: () => setState(() => _showAddNewRow = true),
                icon: Icon(Icons.add, color: Colors.green.shade700),
                label: Text(
                  'Add New Task',
                  style: GoogleFonts.poppins(
                    color: Colors.green.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildNewTaskRow(
    DateTime projectStart,
    double ganttWidth,
    double scaledDayWidth,
  ) {
    final rowHeight = 50.0;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.green.shade400, width: 2),
        color: Colors.green.shade50,
      ),
      child: Row(
        children: [
          // Number
          _buildDataCell(
            '${_tasks.length + 1}',
            numberColumnWidth,
            rowHeight,
            alignment: Alignment.center,
            isEditable: false,
          ),

          // Task Name with Type Selection
          Container(
            width: taskNameColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: Column(
              children: [
                // Task Type Selector
                Container(
                  height: 25,
                  padding: EdgeInsets.symmetric(horizontal: 4),
                  child: DropdownButtonFormField<String>(
                    initialValue: _newTaskType,
                    decoration: InputDecoration.collapsed(hintText: 'Type'),
                    style: GoogleFonts.poppins(fontSize: 10),
                    items: ['Maintaskgroup', 'Task']
                        .map(
                          (type) =>
                              DropdownMenuItem(value: type, child: Text(type)),
                        )
                        .toList(),
                    onChanged: (value) => setState(() => _newTaskType = value!),
                  ),
                ),
                // Task Name Input
                Expanded(
                  child: TextField(
                    controller: _newTaskTitleController,
                    decoration: InputDecoration.collapsed(
                      hintText: 'Task name',
                    ),
                    style: GoogleFonts.poppins(fontSize: 11),
                  ),
                ),
              ],
            ),
          ),

          // Duration
          Container(
            width: durationColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: TextField(
              decoration: InputDecoration.collapsed(hintText: 'Days'),
              keyboardType: TextInputType.number,
              style: GoogleFonts.poppins(fontSize: 11),
              onChanged: (value) {
                final duration = int.tryParse(value);
                if (duration != null) {
                  setState(() => _newTaskDuration = duration);
                  if (_newTaskStartDate != null) {
                    setState(() {
                      _newTaskEndDate = _newTaskStartDate!.add(
                        Duration(days: duration - 1),
                      );
                    });
                  }
                }
              },
            ),
          ),

          // Start Date
          GestureDetector(
            onTap: () async {
              final date = await TaskDialogManager.showDatePickerDialog(
                context,
                _newTaskStartDate,
              );
              if (date != null) {
                setState(() {
                  _newTaskStartDate = date;
                  if (_newTaskDuration != null) {
                    _newTaskEndDate = date.add(
                      Duration(days: _newTaskDuration! - 1),
                    );
                  }
                });
              }
            },
            child: Container(
              width: dateColumnWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: Center(
                child: Text(
                  _newTaskStartDate != null
                      ? _dateFormat.format(_newTaskStartDate!)
                      : 'Select date',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
              ),
            ),
          ),

          // End Date
          GestureDetector(
            onTap: () async {
              final date = await TaskDialogManager.showDatePickerDialog(
                context,
                _newTaskEndDate,
              );
              if (date != null) {
                setState(() {
                  _newTaskEndDate = date;
                  if (_newTaskStartDate != null) {
                    _newTaskDuration = TaskDialogManager.calculateDuration(
                      _newTaskStartDate!,
                      date,
                    );
                  }
                });
              }
            },
            child: Container(
              width: dateColumnWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300, width: 0.5),
              ),
              child: Center(
                child: Text(
                  _newTaskEndDate != null
                      ? _dateFormat.format(_newTaskEndDate!)
                      : 'Select date',
                  style: GoogleFonts.poppins(fontSize: 11),
                ),
              ),
            ),
          ),

          // Gantt area with action buttons
          Container(
            width: ganttWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300, width: 0.5),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _addNewTaskInline,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    minimumSize: Size(60, 30),
                  ),
                  child: Text('Save', style: GoogleFonts.poppins(fontSize: 10)),
                ),
                SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _showAddNewRow = false;
                    _clearNewTaskInputs();
                  }),
                  child: Text(
                    'Cancel',
                    style: GoogleFonts.poppins(fontSize: 10),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
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
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  Widget _buildTaskRow(
    ScheduleModel task,
    int rowNumber,
    DateTime projectStart,
    double ganttWidth,
    double scaledDayWidth,
  ) {
    final isMainTask = task.taskType == 'Maintaskgroup';
    final isSubgroup = task.taskType == 'Maintasksubgroup';
    final rowHeight = 40.0;

    // Determine indentation based on task type
    final double indent;
    if (isMainTask) {
      indent = 8.0; // Minimal indent for top-level Maintaskgroup (title)
    } else if (isSubgroup) {
      indent = 16.0; // One tab for Maintasksubgroup (subtitle)
    } else {
      indent = 32.0; // Two tabs for Task (child/content)
    }

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        border: Border.all(
          color: _editModeEnabled ? Colors.orange.shade400 : Colors.grey.shade300,
          width: _editModeEnabled ? 2 : 0.5,
        ),
        color: _editModeEnabled
            ? ((isMainTask || isSubgroup) ? Colors.orange.shade50 : Colors.orange.shade50)
            : ((isMainTask || isSubgroup) ? Colors.blue.shade50 : Colors.white),
      ),
      child: Row(
        children: [
          // Number
          _buildDataCell(
            rowNumber.toString(),
            numberColumnWidth,
            rowHeight,
            alignment: Alignment.center,
            isEditable: false,
          ),

          // Task Name (with hierarchical indentation)
          _buildEditableDataCell(
            task.title,
            taskNameColumnWidth,
            rowHeight,
            alignment: Alignment.centerLeft,
            padding: EdgeInsets.only(left: indent),
            fontWeight: (isMainTask || isSubgroup) ? FontWeight.w600 : FontWeight.normal,
            onTap: _editModeEnabled ? () => _handleInlineTaskNameEdit(task) : null,
          ),

          // Duration
          _buildEditableDataCell(
            '${task.duration} days',
            durationColumnWidth,
            rowHeight,
            alignment: Alignment.center,
            onTap: _editModeEnabled ? () => _handleInlineDurationEdit(task) : null,
          ),

          // Start Date
          _buildEditableDataCell(
            _dateFormat.format(task.startDate),
            dateColumnWidth,
            rowHeight,
            alignment: Alignment.center,
            onTap: _editModeEnabled ? () => _handleInlineDateEdit(task, true) : null,
          ),

          // End Date
          _buildEditableDataCell(
            _dateFormat.format(task.endDate),
            dateColumnWidth,
            rowHeight,
            alignment: Alignment.center,
            onTap: _editModeEnabled ? () => _handleInlineDateEdit(task, false) : null,
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
        )
      );
    }

  Widget _buildDataCell(
    String text,
    double width,
    double height, {
    Alignment alignment = Alignment.center,
    EdgeInsets? padding,
    FontWeight fontWeight = FontWeight.normal,
    bool isEditable = true,
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
        style: GoogleFonts.poppins(fontSize: 11, fontWeight: fontWeight),
        overflow: TextOverflow.ellipsis,
        maxLines: 1,
      ),
    );
  }

  Widget _buildEditableDataCell(
    String text,
    double width,
    double height, {
    Alignment alignment = Alignment.center,
    EdgeInsets? padding,
    FontWeight fontWeight = FontWeight.normal,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300, width: 0.5),
          color: _editModeEnabled && onTap != null
              ? Colors.orange.shade100
              : null,
        ),
        alignment: alignment,
        padding: padding ?? const EdgeInsets.symmetric(horizontal: 4),
        child: Row(
          mainAxisAlignment: alignment == Alignment.centerLeft
              ? MainAxisAlignment.start
              : MainAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                text,
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: fontWeight,
                  color: _editModeEnabled && onTap != null
                      ? Colors.orange.shade800
                      : null,
                ),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            if (_editModeEnabled && onTap != null)
              Icon(Icons.edit, size: 12, color: Colors.orange.shade600),
          ],
        ),
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
              style: GoogleFonts.poppins(
                fontSize: 18,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _addTask,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${_tasks.length} tasks • ${_dateFormat.format(projectStart)} to ${_dateFormat.format(projectEnd)}',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  // Add Task Button
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _addTask,
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(
                        'Add Task',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0A2E5A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Edit Button
                  SizedBox(
                    height: 40,
                    child: ElevatedButton.icon(
                      onPressed: _toggleEditMode,
                      icon: Icon(
                        _editModeEnabled ? Icons.edit_off : Icons.edit,
                        size: 18,
                      ),
                      label: Text(
                        _editModeEnabled ? 'Exit Edit' : 'Edit',
                        style: GoogleFonts.poppins(fontSize: 14),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _editModeEnabled
                            ? Colors.orange
                            : const Color(0xFF0A2E5A),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Zoom In Button
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: IconButton(
                      icon: const Icon(Icons.zoom_in, size: 18),
                      onPressed: () => setState(
                        () => _scale = (_scale * 1.2).clamp(0.5, 3.0),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0A2E5A),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      tooltip: 'Zoom In',
                    ),
                  ),
                  const SizedBox(width: 4),
                  // Zoom Out Button
                  SizedBox(
                    height: 40,
                    width: 40,
                    child: IconButton(
                      icon: const Icon(Icons.zoom_out, size: 18),
                      onPressed: () => setState(
                        () => _scale = (_scale / 1.2).clamp(0.5, 3.0),
                      ),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF0A2E5A),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      tooltip: 'Zoom Out',
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

// Bottom sheet for advanced task editing
class _TaskEditBottomSheet extends StatefulWidget {
  final ScheduleModel task;
  final List<ScheduleModel> tasks;
  final Function(ScheduleModel) onSave;

  const _TaskEditBottomSheet({
    required this.task,
    required this.tasks,
    required this.onSave,
  });

  @override
  State<_TaskEditBottomSheet> createState() => _TaskEditBottomSheetState();
}

class _TaskEditBottomSheetState extends State<_TaskEditBottomSheet> {
  late TextEditingController _titleController;
  late String _selectedParentId;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _selectedParentId = widget.task.parentId ?? '';
  }

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mainTasks = widget.tasks
        .where((t) => t.taskType == 'Maintaskgroup' && t.id != widget.task.id)
        .toList();

    return Container(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Edit Task Details',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),

          // Task Name
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Task Name',
              border: OutlineInputBorder(),
            ),
            style: GoogleFonts.poppins(),
          ),
          const SizedBox(height: 16),

          // Parent Task Selection (only for subtasks)
          if (widget.task.taskType != 'Maintaskgroup')
            DropdownButtonFormField<String>(
              initialValue: _selectedParentId.isEmpty
                  ? null
                  : _selectedParentId,
              decoration: InputDecoration(
                labelText: 'Parent Task',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem<String>(
                  value: null,
                  child: Text('No Parent', style: GoogleFonts.poppins()),
                ),
                ...mainTasks.map(
                  (task) => DropdownMenuItem<String>(
                    value: task.id,
                    child: Text(task.title, style: GoogleFonts.poppins()),
                  ),
                ),
              ],
              onChanged: (value) {
                setState(() => _selectedParentId = value ?? '');
              },
            ),

          const SizedBox(height: 24),

          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              const SizedBox(width: 16),
              ElevatedButton(
                onPressed: () {
                  final updatedTask = ScheduleModel(
                    id: widget.task.id,
                    title: _titleController.text.trim(),
                    projectId: widget.task.projectId,
                    projectName: widget.task.projectName,
                    startDate: widget.task.startDate,
                    endDate: widget.task.endDate,
                    duration: widget.task.duration,
                    updatedAt: DateTime.now(),
                    taskType: widget.task.taskType,
                    parentId: _selectedParentId.isEmpty
                        ? null
                        : _selectedParentId,
                  );
                  widget.onSave(updatedTask);
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2E5A),
                  foregroundColor: Colors.white,
                ),
                child: Text('Save', style: GoogleFonts.poppins()),
              ),
            ],
          ),
          const SizedBox(height: 16),
        ],
      ),
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
    final startOffset =
        task.startDate.difference(projectStartDate).inDays * dayWidth;
    final duration = task.endDate.difference(task.startDate).inDays + 1;
    final width = duration * dayWidth;

    // Task bar
    final isMainTask = task.taskType == 'Maintaskgroup';
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
      final progressRect = Rect.fromLTWH(
        startOffset + 2,
        barTop + 2,
        progressWidth - 4,
        barHeight - 4,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(progressRect, Radius.circular(2.0)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
