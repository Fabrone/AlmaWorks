import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/schedule_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

class TaskDialogManager {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  static Future<bool> _saveTask({
    required BuildContext context,
    required ScheduleModel task,
    required Logger logger,
    required VoidCallback onSuccess,
    required bool isUpdate,
  }) async {
    try {
      if (isUpdate) {
        await FirebaseFirestore.instance
            .collection('Schedule')
            .doc(task.id)
            .update(task.toMap());
        logger.i('✅ Task updated successfully: ${task.title} (Type: ${task.taskType}, ParentId: ${task.parentId}, Dependency: ${task.dependency})');
      } else {
        await FirebaseFirestore.instance.collection('Schedule').add(task.toMap());
        logger.i('✅ Task added successfully: ${task.title} (Type: ${task.taskType}, ParentId: ${task.parentId}, Dependency: ${task.dependency})');
      }
      onSuccess();
      return true;
    } catch (e) {
      logger.e('❌ Error ${isUpdate ? 'updating' : 'adding'} task', error: e);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error ${isUpdate ? 'updating' : 'adding'} task: $e', style: GoogleFonts.poppins())),
        );
      }
      return false;
    }
  }

  static Future<void> showAddTaskDialog({
    required BuildContext context,
    required ProjectModel project,
    required List<ScheduleModel> tasks,
    required Logger logger,
    required VoidCallback onTaskAdded,
  }) async {
    final titleController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    int? duration;
    String? selectedParentId;
    String? taskType = 'Maintaskgroup';

    final existingMainTasks = tasks.where((task) => task.taskType == 'Maintaskgroup' || task.taskType == 'Maintasksubgroup').toList();

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => _AddTaskDialog(
        titleController: titleController,
        existingMainTasks: existingMainTasks,
        onStartDateChanged: (date) => startDate = date,
        onEndDateChanged: (date) => endDate = date,
        onDurationChanged: (dur) => duration = dur,
        onParentIdChanged: (id) => selectedParentId = id,
        onTaskTypeChanged: (type) {
          logger.i('Task type changed to: $type');
          taskType = type;
        },
        startDate: startDate,
        endDate: endDate,
        dateFormat: _dateFormat,
      ),
    );

    logger.i('AddTaskDialog result: $result, taskType: $taskType');
    if (result == null || !result['result'] || startDate == null || endDate == null || duration == null || taskType == null) {
      logger.w('AddTaskDialog failed: result=$result, startDate=$startDate, endDate=$endDate, duration=$duration, taskType=$taskType');
      return;
    }

    final newTask = ScheduleModel(
      id: '',
      title: titleController.text.trim(),
      projectId: project.id,
      projectName: project.name,
      startDate: startDate!,
      endDate: endDate!,
      duration: duration!,
      updatedAt: DateTime.now(),
      taskType: taskType!,
      parentId: taskType == 'Maintaskgroup' ? null : selectedParentId,
      dependency: null,
    );

    if (context.mounted) {
      await _saveTask(
        context: context,
        task: newTask,
        logger: logger,
        onSuccess: onTaskAdded,
        isUpdate: false,
      );
    }
  }

  static Future<void> showEditTaskDialog({
    required BuildContext context,
    required ProjectModel project,
    required List<ScheduleModel> tasks,
    required ScheduleModel taskToEdit,
    required Logger logger,
    required VoidCallback onTaskEdited,
  }) async {
    final titleController = TextEditingController(text: taskToEdit.title);
    DateTime? startDate = taskToEdit.startDate;
    DateTime? endDate = taskToEdit.endDate;
    int? duration = taskToEdit.duration;
    String? selectedParentId = taskToEdit.parentId;

    final existingMainTasks = tasks
        .where((task) =>
            (task.taskType == 'Maintaskgroup' ||
                task.taskType == 'Maintasksubgroup') &&
            task.id != taskToEdit.id)
        .toList();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => _EditTaskDialog(
        titleController: titleController,
        existingMainTasks: existingMainTasks,
        taskToEdit: taskToEdit,
        onStartDateChanged: (date) => startDate = date,
        onEndDateChanged: (date) => endDate = date,
        onDurationChanged: (dur) => duration = dur,
        onParentIdChanged: (id) => selectedParentId = id,
        startDate: startDate,
        endDate: endDate,
        duration: duration,
        selectedParentId: selectedParentId,
        dateFormat: _dateFormat,
      ),
    );

    logger.i('EditTaskDialog result: $result');
    if (result != true || startDate == null || endDate == null || duration == null) {
      logger.w(
          'EditTaskDialog failed: result=$result, startDate=$startDate, endDate=$endDate, duration=$duration');
      return;
    }

    final updatedTask = ScheduleModel(
      id: taskToEdit.id,
      title: titleController.text.trim(),
      projectId: project.id,
      projectName: project.name,
      startDate: startDate!,
      endDate: endDate!,
      duration: duration!,
      updatedAt: DateTime.now(),
      taskType: taskToEdit.taskType,
      parentId: taskToEdit.taskType == 'Maintaskgroup' ? null : selectedParentId,
      dependency: taskToEdit.dependency,
    );

    if (context.mounted) {
      await _saveTask(
        context: context,
        task: updatedTask,
        logger: logger,
        onSuccess: onTaskEdited,
        isUpdate: true,
      );
    }
  }

  static Future<Map<String, dynamic>?> showLinkTaskDialog({
    required BuildContext context,
    required ScheduleModel sourceTask,
    required List<ScheduleModel> tasks,
    required String dependencyType,
    required Logger logger,
  }) async {
    String? selectedTaskId;

    final eligibleTasks = tasks
        .where((task) =>
            task.taskType == 'Task' &&
            task.parentId == sourceTask.parentId &&
            task.id != sourceTask.id)
        .toList();

    if (eligibleTasks.isEmpty) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No eligible tasks to link with the same parent', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
      logger.w('No eligible tasks for linking with source task: ${sourceTask.title}');
      return null;
    }

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Link Task: ${sourceTask.title}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dependency Type: $dependencyType', style: GoogleFonts.poppins(fontSize: 14)),
            SizedBox(height: 16.0),
            DropdownButtonFormField<String>(
              hint: Text('Select Target Task', style: GoogleFonts.poppins()),
              items: eligibleTasks.map((task) {
                return DropdownMenuItem(
                  value: task.id,
                  child: SizedBox(
                    width: 300.0,
                    child: Text(
                      task.title,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.poppins(),
                    ),
                  ),
                );
              }).toList(),
              onChanged: (value) {
                selectedTaskId = value;
              },
              decoration: InputDecoration(
                labelText: 'Target Task',
                border: OutlineInputBorder(),
              ),
              validator: (value) => value == null ? 'Please select a target task' : null,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (selectedTaskId != null) {
                Navigator.pop(context, {
                  'type': dependencyType,
                  'targetTaskId': selectedTaskId,
                });
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Please select a target task', style: GoogleFonts.poppins()),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
            ),
            child: Text('Link', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    logger.i('LinkTaskDialog result: $result');
    return result;
  }

  static Future<String?> showTaskTypeDialog(BuildContext context) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Task Type', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text('Maintaskgroup', style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context, 'Maintaskgroup'),
            ),
            ListTile(
              title: Text('Maintasksubgroup', style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context, 'Maintasksubgroup'),
            ),
            ListTile(
              title: Text('Task', style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context, 'Task'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  static Future<String?> showParentTaskDialog(BuildContext context, List<ScheduleModel> mainTasks) async {
    return await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Select Parent Task', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: mainTasks.length,
            itemBuilder: (context, index) {
              final task = mainTasks[index];
              return ListTile(
                title: Text(task.title, style: GoogleFonts.poppins()),
                subtitle: Text('Type: ${task.taskType}', style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () => Navigator.pop(context, task.id),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  static Future<DateTime?> showDatePickerDialog(BuildContext context, DateTime? initialDate) async {
    return await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
  }

  static int calculateDuration(DateTime startDate, DateTime endDate) {
    return endDate.difference(startDate).inDays + 1;
  }

  static Future<bool> saveInlineEdit({
    required BuildContext context,
    required ProjectModel project,
    required ScheduleModel task,
    required Logger logger,
    required VoidCallback onTaskUpdated,
  }) async {
    return await _saveTask(
      context: context,
      task: task,
      logger: logger,
      onSuccess: onTaskUpdated,
      isUpdate: true,
    );
  }

  static Future<bool> addInlineTask({
    required BuildContext context,
    required ProjectModel project,
    required ScheduleModel newTask,
    required Logger logger,
    required VoidCallback onTaskAdded,
  }) async {
    return await _saveTask(
      context: context,
      task: newTask,
      logger: logger,
      onSuccess: onTaskAdded,
      isUpdate: false,
    );
  }
}

class _AddTaskDialog extends StatefulWidget {
  final TextEditingController titleController;
  final List<ScheduleModel> existingMainTasks;
  final Function(DateTime) onStartDateChanged;
  final Function(DateTime) onEndDateChanged;
  final Function(int) onDurationChanged;
  final Function(String?) onParentIdChanged;
  final Function(String?) onTaskTypeChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateFormat dateFormat;

  const _AddTaskDialog({
    required this.titleController,
    required this.existingMainTasks,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onDurationChanged,
    required this.onParentIdChanged,
    required this.onTaskTypeChanged,
    required this.startDate,
    required this.endDate,
    required this.dateFormat,
  });

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> with SingleTickerProviderStateMixin {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedParentId;
  int? _duration;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _tabController = TabController(length: 3, vsync: this);
    widget.onTaskTypeChanged('Maintaskgroup');
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        final taskType = _tabController.index == 0
            ? 'Maintaskgroup'
            : _tabController.index == 1
                ? 'Maintasksubgroup'
                : 'Task';
        widget.onTaskTypeChanged(taskType);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Add Task', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.all(16.0),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TabBar(
              controller: _tabController,
              tabs: [
                Tab(text: 'Maintaskgroup'),
                Tab(text: 'Maintasksubgroup'),
                Tab(text: 'Task'),
              ],
              labelStyle: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600),
              unselectedLabelStyle: GoogleFonts.poppins(fontSize: 14),
              indicatorColor: const Color(0xFF0A2E5A),
              labelColor: const Color(0xFF0A2E5A),
              unselectedLabelColor: Colors.grey.shade600,
            ),
            Flexible(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildMainTaskForm(),
                  _buildSubgroupTaskForm(),
                  _buildActualTaskForm(),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: _onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A2E5A),
            foregroundColor: Colors.white,
          ),
          child: Text('Save', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }

  Widget _buildMainTaskForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: widget.titleController,
            decoration: InputDecoration(labelText: 'Task Name', border: OutlineInputBorder()),
            style: GoogleFonts.poppins(),
          ),
          SizedBox(height: 16.0),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Duration (days)', border: OutlineInputBorder()),
            onChanged: (value) {
              final duration = int.tryParse(value);
              if (duration != null && duration > 0) {
                _duration = duration;
                widget.onDurationChanged(duration);
                if (_startDate != null) {
                  setState(() {
                    _endDate = _startDate!.add(Duration(days: duration - 1));
                    widget.onEndDateChanged(_endDate!);
                  });
                }
              }
            },
          ),
          SizedBox(height: 16.0),
          _buildDateSelector('Select Start Date', _startDate, (date) {
            setState(() {
              _startDate = date;
              if (_duration != null) {
                _endDate = date.add(Duration(days: _duration! - 1));
                widget.onEndDateChanged(_endDate!);
              }
            });
            widget.onStartDateChanged(date);
          }),
          SizedBox(height: 16.0),
          _buildDateSelector('Select End Date', _endDate, (date) {
            setState(() {
              _endDate = date;
              if (_startDate != null) {
                _duration = TaskDialogManager.calculateDuration(_startDate!, date);
                widget.onDurationChanged(_duration!);
              }
            });
            widget.onEndDateChanged(date);
          }),
        ],
      ),
    );
  }

  Widget _buildSubgroupTaskForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedParentId,
            hint: Text('Select Parent Task (Group or Subgroup)', style: GoogleFonts.poppins()),
            items: widget.existingMainTasks.map((task) {
              return DropdownMenuItem(
                value: task.id,
                child: SizedBox(
                  width: 300.0,
                  child: Text(
                    '${task.title} (${task.taskType})',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedParentId = value);
              widget.onParentIdChanged(value);
            },
            decoration: InputDecoration(
              labelText: 'Parent Task (Group or Subgroup)',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null ? 'Please select a parent task' : null,
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: widget.titleController,
            decoration: InputDecoration(labelText: 'Task Name', border: OutlineInputBorder()),
            style: GoogleFonts.poppins(),
          ),
          SizedBox(height: 16.0),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Duration (days)', border: OutlineInputBorder()),
            onChanged: (value) {
              final duration = int.tryParse(value);
              if (duration != null && duration > 0) {
                _duration = duration;
                widget.onDurationChanged(duration);
                if (_startDate != null) {
                  setState(() {
                    _endDate = _startDate!.add(Duration(days: duration - 1));
                    widget.onEndDateChanged(_endDate!);
                  });
                }
              }
            },
          ),
          SizedBox(height: 16.0),
          _buildDateSelector('Select Start Date', _startDate, (date) {
            setState(() {
              _startDate = date;
              if (_duration != null) {
                _endDate = date.add(Duration(days: _duration! - 1));
                widget.onEndDateChanged(_endDate!);
              }
            });
            widget.onStartDateChanged(date);
          }),
          SizedBox(height: 16.0),
          _buildDateSelector('Select End Date', _endDate, (date) {
            setState(() {
              _endDate = date;
              if (_startDate != null) {
                _duration = TaskDialogManager.calculateDuration(_startDate!, date);
                widget.onDurationChanged(_duration!);
              }
            });
            widget.onEndDateChanged(date);
          }),
        ],
      ),
    );
  }

  Widget _buildActualTaskForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(top: 8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedParentId,
            hint: Text('Select Parent Task (Group or Subgroup)', style: GoogleFonts.poppins()),
            items: widget.existingMainTasks.map((task) {
              return DropdownMenuItem(
                value: task.id,
                child: SizedBox(
                  width: 300.0,
                  child: Text(
                    '${task.title} (${task.taskType})',
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(),
                  ),
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedParentId = value);
              widget.onParentIdChanged(value);
            },
            decoration: InputDecoration(
              labelText: 'Parent Task (Group or Subgroup)',
              border: OutlineInputBorder(),
            ),
            validator: (value) => value == null ? 'Please select a parent task' : null,
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: widget.titleController,
            decoration: InputDecoration(labelText: 'Task Name', border: OutlineInputBorder()),
            style: GoogleFonts.poppins(),
          ),
          SizedBox(height: 16.0),
          TextField(
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: 'Duration (days)', border: OutlineInputBorder()),
            onChanged: (value) {
              final duration = int.tryParse(value);
              if (duration != null && duration > 0) {
                _duration = duration;
                widget.onDurationChanged(duration);
                if (_startDate != null) {
                  setState(() {
                    _endDate = _startDate!.add(Duration(days: duration - 1));
                    widget.onEndDateChanged(_endDate!);
                  });
                }
              }
            },
          ),
          SizedBox(height: 16.0),
          _buildDateSelector('Select Start Date', _startDate, (date) {
            setState(() {
              _startDate = date;
              if (_duration != null) {
                _endDate = date.add(Duration(days: _duration! - 1));
                widget.onEndDateChanged(_endDate!);
              }
            });
            widget.onStartDateChanged(date);
          }),
          SizedBox(height: 16.0),
          _buildDateSelector('Select End Date', _endDate, (date) {
            setState(() {
              _endDate = date;
              if (_startDate != null) {
                _duration = TaskDialogManager.calculateDuration(_startDate!, date);
                widget.onDurationChanged(_duration!);
              }
            });
            widget.onEndDateChanged(date);
          }),
        ],
      ),
    );
  }

  Widget _buildDateSelector(String label, DateTime? selectedDate, Function(DateTime) onDateSelected) {
    return InkWell(
      onTap: () async {
        final date = await TaskDialogManager.showDatePickerDialog(context, selectedDate);
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        child: Text(
          selectedDate != null ? widget.dateFormat.format(selectedDate) : 'Select Date',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }

  void _onSave() {
    if (widget.titleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Task name cannot be empty', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_startDate == null || _endDate == null || _duration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select start and end dates', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_tabController.index != 0 && _selectedParentId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please select a parent task for non-main tasks', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    if (_startDate!.isAfter(_endDate!)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Start date must be before end date', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.pop(context, {
      'result': true,
    });
  }
}

class _EditTaskDialog extends StatefulWidget {
  final TextEditingController titleController;
  final List<ScheduleModel> existingMainTasks;
  final ScheduleModel taskToEdit;
  final Function(DateTime) onStartDateChanged;
  final Function(DateTime) onEndDateChanged;
  final Function(int) onDurationChanged;
  final Function(String?) onParentIdChanged;
  final DateTime? startDate;
  final DateTime? endDate;
  final int? duration;
  final String? selectedParentId;
  final DateFormat dateFormat;

  const _EditTaskDialog({
    required this.titleController,
    required this.existingMainTasks,
    required this.taskToEdit,
    required this.onStartDateChanged,
    required this.onEndDateChanged,
    required this.onDurationChanged,
    required this.onParentIdChanged,
    required this.startDate,
    required this.endDate,
    required this.duration,
    required this.selectedParentId,
    required this.dateFormat,
  });

  @override
  State<_EditTaskDialog> createState() => _EditTaskDialogState();
}

class _EditTaskDialogState extends State<_EditTaskDialog> {
  DateTime? _startDate;
  DateTime? _endDate;
  String? _selectedParentId;
  int? _duration;

  @override
  void initState() {
    super.initState();
    _startDate = widget.startDate;
    _endDate = widget.endDate;
    _duration = widget.duration;
    _selectedParentId = widget.selectedParentId;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Edit Task: ${widget.taskToEdit.title}', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: widget.titleController,
              decoration: InputDecoration(labelText: 'Task Name', border: OutlineInputBorder()),
              style: GoogleFonts.poppins(),
            ),
            SizedBox(height: 16.0),
            if (widget.taskToEdit.taskType != 'Maintaskgroup')
              DropdownButtonFormField<String>(
                initialValue: _selectedParentId,
                hint: Text('Select Parent Task (Group or Subgroup)', style: GoogleFonts.poppins()),
                items: widget.existingMainTasks.map((task) {
                  return DropdownMenuItem(
                    value: task.id,
                    child: SizedBox(
                      width: 300.0,
                      child: Text(
                        '${task.title} (${task.taskType})',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => _selectedParentId = value);
                  widget.onParentIdChanged(value);
                },
                decoration: InputDecoration(
                  labelText: 'Parent Task (Group or Subgroup)',
                  border: OutlineInputBorder(),
                ),
                validator: (value) => value == null ? 'Please select a parent task' : null,
              ),
            SizedBox(height: 16.0),
            TextField(
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: 'Duration (days)', border: OutlineInputBorder()),
              controller: TextEditingController(text: _duration?.toString()),
              onChanged: (value) {
                final duration = int.tryParse(value);
                if (duration != null && duration > 0) {
                  _duration = duration;
                  widget.onDurationChanged(duration);
                  if (_startDate != null) {
                    setState(() {
                      _endDate = _startDate!.add(Duration(days: duration - 1));
                      widget.onEndDateChanged(_endDate!);
                    });
                  }
                }
              },
            ),
            SizedBox(height: 16.0),
            _buildDateSelector('Select Start Date', _startDate, (date) {
              setState(() {
                _startDate = date;
                if (_duration != null) {
                  _endDate = date.add(Duration(days: _duration! - 1));
                  widget.onEndDateChanged(_endDate!);
                }
              });
              widget.onStartDateChanged(date);
            }),
            SizedBox(height: 16.0),
            _buildDateSelector('Select End Date', _endDate, (date) {
              setState(() {
                _endDate = date;
                if (_startDate != null) {
                  _duration = TaskDialogManager.calculateDuration(_startDate!, date);
                  widget.onDurationChanged(_duration!);
                }
              });
              widget.onEndDateChanged(date);
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Cancel', style: GoogleFonts.poppins()),
        ),
        ElevatedButton(
          onPressed: () {
            if (widget.titleController.text.trim().isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Task name cannot be empty', style: GoogleFonts.poppins()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (_startDate == null || _endDate == null || _duration == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please select start and end dates', style: GoogleFonts.poppins()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (widget.taskToEdit.taskType != 'Maintaskgroup' && _selectedParentId == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Please select a parent task for non-main tasks', style: GoogleFonts.poppins()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (_startDate!.isAfter(_endDate!)) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Start date must be before end date', style: GoogleFonts.poppins()),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.pop(context, true);
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF0A2E5A),
            foregroundColor: Colors.white,
          ),
          child: Text('Save', style: GoogleFonts.poppins()),
        ),
      ],
    );
  }

  Widget _buildDateSelector(String label, DateTime? selectedDate, Function(DateTime) onDateSelected) {
    return InkWell(
      onTap: () async {
        final date = await TaskDialogManager.showDatePickerDialog(context, selectedDate);
        if (date != null) {
          onDateSelected(date);
        }
      },
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(),
        ),
        child: Text(
          selectedDate != null ? widget.dateFormat.format(selectedDate) : 'Select Date',
          style: GoogleFonts.poppins(),
        ),
      ),
    );
  }
}