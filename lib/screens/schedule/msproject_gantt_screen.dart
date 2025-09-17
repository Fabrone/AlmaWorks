import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

//enum TaskType { mainTask, subTask, task }

class MSProjectGanttScreen extends StatefulWidget {
  final String projectId;
  final String projectName;
  final Logger logger;

  const MSProjectGanttScreen({
    super.key,
    required this.projectId,
    required this.projectName,
    required this.logger,
    required ProjectModel project,
  });

  @override
  State<MSProjectGanttScreen> createState() => _MSProjectGanttScreenState();
}

class _MSProjectGanttScreenState extends State<MSProjectGanttScreen> {
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();

  static const double rowHeight = 24.0;
  static const double headerHeight = 40.0;
  static const double dayWidth = 24.0;

  double _numberColumnWidth = 60.0;
  double _taskColumnWidth = 250.0;
  double _durationColumnWidth = 90.0;
  double _startColumnWidth = 120.0;
  double _finishColumnWidth = 120.0;

  List<GanttRowData> _rows = [];
  static const int defaultRowCount = 6;
  bool _isLoading = true;

  DateTime _projectStartDate = DateTime.now();
  DateTime _projectEndDate = DateTime.now().add(Duration(days: 30));

  // Temporary storage for edited row data
  final Map<int, GanttRowData> _editedRows = {};

  // New field for overlay management
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _loadTasksFromFirebase();
  }

  @override
  void dispose() {
    _removeOverlay(); 
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  Future<void> _loadTasksFromFirebase() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.projectId)
          .get();

      if (!mounted) return;

      List<GanttRowData> loadedRows = [];
      for (var doc in snapshot.docs) {
        final data = doc.data();
        loadedRows.add(GanttRowData.fromFirebaseMap(doc.id, data));
      }

      while (loadedRows.length < defaultRowCount) {
        loadedRows.add(GanttRowData(id: 'row_${loadedRows.length + 1}'));
      }

      _rows = loadedRows;
      _calculateProjectDates();
      _computeColumnWidths();
      widget.logger.i('📅 MSProjectGantt: Loaded ${_rows.length} rows');
    } catch (e) {
      widget.logger.e('❌ MSProjectGantt: Error loading tasks', error: e);
      if (mounted) {
        _initializeDefaultRows();
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeDefaultRows() {
    _rows = List.generate(defaultRowCount, (index) => GanttRowData(id: 'row_${index + 1}'));
    _computeColumnWidths();
  }

  void _calculateProjectDates() {
    // Combine original rows with edited rows for date calculation
    List<GanttRowData> allRows = [];
    for (int i = 0; i < _rows.length; i++) {
      allRows.add(_editedRows[i] ?? _rows[i]);
    }
    
    final activeTasks = allRows.where((row) => row.hasData).toList();
    if (activeTasks.isNotEmpty) {
      _projectStartDate = activeTasks
          .map((row) => row.startDate!)
          .reduce((a, b) => a.isBefore(b) ? a : b);
      _projectEndDate = activeTasks
          .map((row) => row.endDate!)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      _projectStartDate = _projectStartDate.subtract(Duration(days: 7));
      _projectEndDate = _projectEndDate.add(Duration(days: 7));
    } else {
      final now = DateTime.now();
      _projectStartDate = DateTime(now.year, now.month, 1);
      _projectEndDate = DateTime(now.year, now.month + 1, 0);
    }
  }

  void _addNewRow() {
    if (!mounted) return;
    setState(() {
      _rows.add(GanttRowData(id: 'new_row_${DateTime.now().millisecondsSinceEpoch}'));
      _computeColumnWidths();
    });
  }

  void _deleteRow(int index) {
    if (!mounted) return;
    if (_rows.length > defaultRowCount) {
      final rowToDelete = _rows[index];
      setState(() {
        _rows.removeAt(index);
        _editedRows.remove(index);
        _computeColumnWidths();
      });

      if (rowToDelete.firestoreId != null) {
        _deleteRowFromFirebase(rowToDelete.firestoreId!);
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot delete below minimum $defaultRowCount rows',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  Future<void> _saveRowToFirebase(GanttRowData row, int index) async {
    try {
      final rowData = row.toFirebaseMap(widget.projectId, widget.projectName, index);

      if (row.firestoreId != null) {
        await FirebaseFirestore.instance
            .collection('Schedule')
            .doc(row.firestoreId)
            .update(rowData);
        widget.logger.i('✅ Updated row: ${row.taskName}');
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('Schedule')
            .add(rowData);
        row.firestoreId = docRef.id;
        widget.logger.i('✅ Created new row: ${row.taskName}');
      }
    } catch (e) {
      widget.logger.e('❌ Error saving row to Firebase', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save task: $e', style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteRowFromFirebase(String firestoreId) async {
    try {
      await FirebaseFirestore.instance
          .collection('Schedule')
          .doc(firestoreId)
          .delete();
      widget.logger.i('✅ Deleted row from Firebase');
    } catch (e) {
      widget.logger.e('❌ Error deleting row from Firebase', error: e);
    }
  }

  // UPDATE this method to handle taskType
  void _updateRowData(int index, {
    String? taskName,
    int? duration,
    DateTime? startDate,
    DateTime? endDate,
    TaskType? taskType, // This parameter IS used now
  }) {
    if (!mounted) return;

    setState(() {
      final row = _editedRows[index] ?? GanttRowData.from(_rows[index]);
      _editedRows[index] = row;

      if (taskName != null) row.taskName = taskName;
      if (duration != null) row.duration = duration;
      if (startDate != null) row.startDate = startDate;
      if (endDate != null) row.endDate = endDate;
      if (taskType != null) row.taskType = taskType; 

      if (row.startDate != null && row.endDate != null && row.duration == null) {
        row.duration = row.endDate!.difference(row.startDate!).inDays + 1;
      } else if (row.startDate != null && row.duration != null && row.endDate == null) {
        row.endDate = row.startDate!.add(Duration(days: row.duration! - 1));
      } else if (row.endDate != null && row.duration != null && row.startDate == null) {
        row.startDate = row.endDate!.subtract(Duration(days: row.duration! - 1));
      }

      _calculateProjectDates();
      _computeColumnWidths();
    });
  }

  Future<void> _saveAllRows() async {
    if (!mounted) return;
    for (var entry in _editedRows.entries) {
      final index = entry.key;
      final row = entry.value;
      if (row.taskName?.isNotEmpty == true || row.startDate != null || row.endDate != null) {
        await _saveRowToFirebase(row, index);
        setState(() {
          _rows[index] = GanttRowData.from(row);
        });
      }
    }
    setState(() {
      _editedRows.clear();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Changes saved successfully', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  double _measureText(String text, TextStyle style) {
    final textPainter = TextPainter(
      text: TextSpan(text: text, style: style),
      maxLines: 1,
      textDirection: ui.TextDirection.ltr,
    )..layout(minWidth: 0, maxWidth: double.infinity);
    return textPainter.size.width;
  }

  void _computeColumnWidths() {
    final headerStyle = GoogleFonts.poppins(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      color: Colors.grey.shade700,
    );
    final cellStyle = GoogleFonts.poppins(fontSize: 11);

    // Number column
    double headerWidth = _measureText('No.', headerStyle) + 16;
    double maxCellWidth = 0;
    bool canDelete = _rows.length > defaultRowCount;
    for (int i = 0; i < _rows.length; i++) {
      String noText = '${i + 1}';
      double textW = _measureText(noText, cellStyle);
      double cellW = textW;
      if (canDelete) {
        cellW += 16 + 8; // Icon size + padding
      }
      if (cellW > maxCellWidth) maxCellWidth = cellW;
    }
    maxCellWidth += 32;
    _numberColumnWidth = math.max(headerWidth, maxCellWidth);

    // Task Name column - use edited data when available
    headerWidth = _measureText('Task Name', headerStyle) + 24;
    maxCellWidth = 0;
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      String text = row.taskName ?? 'Enter task name';
      double w = _measureText(text, cellStyle);
      if (w > maxCellWidth) maxCellWidth = w;
    }
    maxCellWidth += 48;
    _taskColumnWidth = math.max(headerWidth, maxCellWidth);

    // Duration column - use edited data when available
    headerWidth = _measureText('Duration', headerStyle) + 24;
    maxCellWidth = 0;
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      String text = row.duration?.toString() ?? 'days';
      double w = _measureText(text, cellStyle);
      if (w > maxCellWidth) maxCellWidth = w;
    }
    maxCellWidth += 32;
    _durationColumnWidth = math.max(headerWidth, maxCellWidth);

    // Start column - use edited data when available
    headerWidth = _measureText('Start', headerStyle) + 24;
    maxCellWidth = 0;
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      String text = row.startDate != null
          ? DateFormat('MM/dd/yyyy').format(row.startDate!)
          : 'MM/dd/yyyy';
      double w = _measureText(text, cellStyle);
      if (w > maxCellWidth) maxCellWidth = w;
    }
    maxCellWidth += 32;
    _startColumnWidth = math.max(headerWidth, maxCellWidth);

    // Finish column - use edited data when available
    headerWidth = _measureText('Finish', headerStyle) + 24;
    maxCellWidth = 0;
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      String text = row.endDate != null
          ? DateFormat('MM/dd/yyyy').format(row.endDate!)
          : 'MM/dd/yyyy';
      double w = _measureText(text, cellStyle);
      if (w > maxCellWidth) maxCellWidth = w;
    }
    maxCellWidth += 48;
    _finishColumnWidth = math.max(headerWidth, maxCellWidth);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    final totalDays = _projectEndDate.difference(_projectStartDate).inDays + 1;
    final ganttWidth = totalDays * dayWidth;

    return Column(
      children: [
        _buildToolbar(),
        Expanded(
          child: _buildUnifiedGanttLayout(ganttWidth),
        ),
      ],
    );
  }

  Widget _buildUnifiedGanttLayout(double ganttWidth) {
    final totalTableWidth = _numberColumnWidth +
        _taskColumnWidth +
        _durationColumnWidth +
        _startColumnWidth +
        _finishColumnWidth;

    return SingleChildScrollView(
      controller: _horizontalScrollController,
      scrollDirection: Axis.horizontal,
      child: SizedBox(
        width: totalTableWidth + ganttWidth,
        child: Column(
          children: [
            SizedBox(
              height: headerHeight,
              child: Row(
                children: [
                  _buildHeaderCell('No.', _numberColumnWidth),
                  _buildHeaderCell('Task Name', _taskColumnWidth),
                  _buildHeaderCell('Duration', _durationColumnWidth),
                  _buildHeaderCell('Start', _startColumnWidth),
                  _buildHeaderCell('Finish', _finishColumnWidth),
                  Container(
                    width: ganttWidth,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      border: Border.all(color: Colors.grey.shade400, width: 1),
                    ),
                    child: _buildTimelineHeader(),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: _verticalScrollController,
                itemCount: _rows.length,
                itemBuilder: (context, index) => _buildRow(index, ganttWidth),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderCell(String title, double width) {
    return Container(
      width: width,
      height: headerHeight,
      decoration: BoxDecoration(
        color: Colors.grey.shade200,
        border: Border(
          right: BorderSide(color: Colors.grey.shade400, width: 0.5),
          bottom: BorderSide(color: Colors.grey.shade400, width: 1),
        ),
      ),
      alignment: Alignment.center,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 8),
        child: Text(
          title,
          style: GoogleFonts.poppins(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade700,
          ),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildRow(int index, double ganttWidth) {
    // Use edited row data if available, otherwise use original row data
    final row = _editedRows[index] ?? _rows[index];
    final canDelete = _rows.length > defaultRowCount;
    final TaskType currentTaskType = row.taskType;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300, width: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            width: _numberColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: canDelete
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                          overflow: TextOverflow.ellipsis,
                        ),
                        InkWell(
                          onTap: () => _deleteRow(index),
                          child: Icon(Icons.close, size: 12, color: Colors.red.shade600),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500),
                      ),
                    ),
            ),
          ),
          Container(
            width: _taskColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: GestureDetector(
              onSecondaryTapDown: (details) {
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final position = renderBox.localToGlobal(details.localPosition);
                _showContextMenu(context, position, index);
              },
              onLongPress: () {
                // For mobile devices - long press to show context menu
                final RenderBox renderBox = context.findRenderObject() as RenderBox;
                final position = renderBox.localToGlobal(Offset(_taskColumnWidth / 2, rowHeight / 2));
                _showContextMenu(context, position, index);
                // Provide haptic feedback
                HapticFeedback.mediumImpact();
              },
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: _taskColumnWidth - 16),
                child: TextFormField(
                  initialValue: row.taskName ?? '',
                  onChanged: (value) => _updateRowData(index, taskName: value),
                  style: _getTaskNameStyle(currentTaskType),
                  decoration: InputDecoration(
                    hintText: 'Enter task name',
                    hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: _getTaskNamePadding(currentTaskType),
                    isDense: true,
                  ),
                  maxLines: 1,
                  textAlign: TextAlign.left,
                  textInputAction: TextInputAction.next,
                  enableInteractiveSelection: true,
                ),
              ),
            ),
          ),
          Container(
            width: _durationColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: _durationColumnWidth - 16),
              child: TextFormField(
                initialValue: row.duration?.toString() ?? '',
                onChanged: (value) {
                  final duration = int.tryParse(value);
                  if (duration != null) {
                    _updateRowData(index, duration: duration);
                  }
                },
                keyboardType: TextInputType.number,
                style: GoogleFonts.poppins(fontSize: 11),
                decoration: InputDecoration(
                  hintText: 'days',
                  hintStyle: GoogleFonts.poppins(fontSize: 11, color: Colors.grey.shade400),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  isDense: true,
                ),
                maxLines: 1,
              ),
            ),
          ),
          Container(
            width: _startColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: _buildDateCell(
              date: row.startDate,
              onDateSelected: (date) => _updateRowData(index, startDate: date),
            ),
          ),
          Container(
            width: _finishColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(right: BorderSide(color: Colors.grey.shade300, width: 0.5)),
            ),
            child: _buildDateCell(
              date: row.endDate,
              onDateSelected: (date) => _updateRowData(index, endDate: date),
            ),
          ),
          Container(
            width: ganttWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(left: BorderSide(color: Colors.grey.shade400, width: 1)),
            ),
            child: CustomPaint(
              painter: GanttRowPainter(
                row: row,
                projectStartDate: _projectStartDate,
                dayWidth: dayWidth,
                rowHeight: rowHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell({
    required DateTime? date,
    required Function(DateTime) onDateSelected,
  }) {
    return InkWell(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2020),
          lastDate: DateTime(2030),
        );
        if (selectedDate != null) {
          onDateSelected(selectedDate);
        }
      },
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        alignment: Alignment.centerLeft,
        child: Text(
          date != null ? DateFormat('MM/dd/yyyy').format(date) : '',
          style: GoogleFonts.poppins(fontSize: 11),
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
      ),
    );
  }

  Widget _buildToolbar() {
    return Container(
      height: 50,
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        border: Border(bottom: BorderSide(color: Colors.grey.shade300)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              widget.projectName,
              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            onPressed: _addNewRow,
            icon: Icon(Icons.add_circle_outline, color: Colors.green.shade700),
            tooltip: 'Add Row',
          ),
          IconButton(
            onPressed: _saveAllRows,
            icon: Icon(Icons.save, color: Colors.blue.shade700),
            tooltip: 'Save Changes',
          ),
        ],
      ),
    );
  }

  Widget _buildTimelineHeader() {
    return Stack(
      children: [
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: headerHeight / 2,
          child: _buildMonthHeaders(),
        ),
        Positioned(
          top: headerHeight / 2,
          left: 0,
          right: 0,
          height: headerHeight / 2,
          child: _buildDayHeaders(),
        ),
      ],
    );
  }

  Widget _buildMonthHeaders() {
    List<Widget> monthHeaders = [];
    DateTime currentMonth = DateTime(_projectStartDate.year, _projectStartDate.month, 1);
    final totalDays = _projectEndDate.difference(_projectStartDate).inDays + 1;
    final ganttWidth = totalDays * dayWidth;
    
    // Available width excluding parent container borders
    final availableWidth = ganttWidth - 2.0;

    while (currentMonth.isBefore(_projectEndDate) || currentMonth.isAtSameMomentAs(_projectEndDate)) {
      DateTime monthEnd = DateTime(currentMonth.year, currentMonth.month + 1, 0);
      if (monthEnd.isAfter(_projectEndDate)) monthEnd = _projectEndDate;

      DateTime monthStart = currentMonth.isBefore(_projectStartDate) ? _projectStartDate : currentMonth;
      int daysInMonth = monthEnd.difference(monthStart).inDays + 1;
      double monthWidth = daysInMonth * dayWidth;

      monthHeaders.add(
        Container(
          width: monthWidth,
          height: headerHeight / 2,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade400, width: 0.5),
            color: Colors.grey.shade100,
          ),
          child: Center(
            child: Text(
              DateFormat('MMM yyyy').format(currentMonth),
              style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      );

      currentMonth = DateTime(currentMonth.year, currentMonth.month + 1, 1);
    }

    return ClipRect(
      child: SizedBox(
        width: availableWidth,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          child: Row(children: monthHeaders),
        ),
      ),
    );
  }

  Widget _buildDayHeaders() {
    List<Widget> dayHeaders = [];
    final totalDays = _projectEndDate.difference(_projectStartDate).inDays + 1;
    final dayHeaderStyle = GoogleFonts.poppins(fontSize: 8, fontWeight: FontWeight.w400);
    final ganttWidth = totalDays * dayWidth;
    
    // Available width excluding parent container borders
    final availableWidth = ganttWidth - 2.0;

    for (int i = 0; i < totalDays; i++) {
      DateTime currentDate = _projectStartDate.add(Duration(days: i));
      dayHeaders.add(
        Container(
          width: dayWidth,
          height: headerHeight / 2,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey.shade300, width: 0.5),
            color: Colors.white,
          ),
          child: Center(
            child: Text(
              currentDate.day.toString(),
              style: dayHeaderStyle,
              overflow: TextOverflow.clip,
              maxLines: 1,
            ),
          ),
        ),
      );
    }

    return ClipRect(
      child: SizedBox(
        width: availableWidth,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          child: Row(children: dayHeaders),
        ),
      ),
    );
  }

  // New methods for context menu functionality
  void _showContextMenu(BuildContext context, Offset position, int rowIndex) {
    _removeOverlay();
    
    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _removeOverlay, // Dismiss when tapping outside
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            // Full screen overlay to capture taps
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            // Context menu
            Positioned(
              left: position.dx,
              top: position.dy,
              child: TaskContextMenu(
                onMakeMainTask: () => _setTaskType(rowIndex, TaskType.mainTask),
                onMakeSubtask: () => _setTaskType(rowIndex, TaskType.subTask),
                onAddNewRow: _addNewRow,
                onDeleteRow: () => _deleteRow(rowIndex),
                onDismiss: _removeOverlay,
              ),
            ),
          ],
        ),
      ),
    );
    
    Overlay.of(context).insert(_overlayEntry!);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  void _setTaskType(int index, TaskType taskType) {
    if (!mounted) return;
    
    setState(() {
      final row = _editedRows[index] ?? GanttRowData.from(_rows[index]);
      _editedRows[index] = row;
      row.taskType = taskType; 
      _computeColumnWidths();
    });
  }

  TextStyle _getTaskNameStyle(TaskType taskType) {
    switch (taskType) {
      case TaskType.mainTask:
        return GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade800,
        );
      case TaskType.subTask:
        return GoogleFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Colors.green.shade700,
        );
      case TaskType.task:
        return GoogleFonts.poppins(fontSize: 11);
    }
  }

  EdgeInsets _getTaskNamePadding(TaskType taskType) {
    switch (taskType) {
      case TaskType.mainTask:
        return EdgeInsets.symmetric(horizontal: 8, vertical: 4);
      case TaskType.subTask:
        return EdgeInsets.only(left: 24, right: 8, top: 4, bottom: 4);
      case TaskType.task:
        return EdgeInsets.symmetric(horizontal: 8, vertical: 4);
    }
  }
}

  class GanttRowPainter extends CustomPainter {
    final GanttRowData row;
    final DateTime projectStartDate;
    final double dayWidth;
    final double rowHeight;

    GanttRowPainter({
      required this.row,
      required this.projectStartDate,
      required this.dayWidth,
      required this.rowHeight,
    });

    @override
    void paint(Canvas canvas, Size size) {
      _drawGrid(canvas, size);

      if (row.hasData && row.startDate != null && row.endDate != null) {
        _drawGanttBar(canvas, size);
      }
    }

    void _drawGrid(Canvas canvas, Size size) {
      final gridPaint = Paint()
        ..color = Colors.grey.shade300
        ..strokeWidth = 0.5;

      final totalDays = (size.width / dayWidth).ceil();
      for (int i = 0; i <= totalDays; i++) {
        final x = i * dayWidth;
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
      }
    }

    void _drawGanttBar(Canvas canvas, Size size) {
      final startOffset = row.startDate!.difference(projectStartDate).inDays * dayWidth;
      final duration = row.endDate!.difference(row.startDate!).inDays + 1;
      final barWidth = duration * dayWidth;

      final barHeight = rowHeight * 0.6;
      final barTop = (rowHeight - barHeight) / 2;

      // Different colors based on task type
      Color barColor;
      Color borderColor;
      switch (row.taskType) {
        case TaskType.mainTask:
          barColor = Colors.blue.shade800;
          borderColor = Colors.blue.shade900;
          break;
        case TaskType.subTask:
          barColor = Colors.green.shade600;
          borderColor = Colors.green.shade800;
          break;
        case TaskType.task:
          barColor = Colors.blue.shade600;
          borderColor = Colors.blue.shade800;
          break;
      }

      final barPaint = Paint()
        ..color = barColor
        ..style = PaintingStyle.fill;

      final barRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startOffset + 2, barTop, barWidth - 4, barHeight),
        Radius.circular(2),
      );

      canvas.drawRRect(barRect, barPaint);

      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;

      canvas.drawRRect(barRect, borderPaint);

      final progressPaint = Paint()
        ..color = barColor.withValues(alpha: 0.5) 
        ..style = PaintingStyle.fill;

      final progressWidth = (barWidth - 4) * 0.6;
      final progressRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(startOffset + 2, barTop + 2, progressWidth, barHeight - 4),
        Radius.circular(1),
      );

      canvas.drawRRect(progressRect, progressPaint);
    }

    @override
    bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
  }

class GanttChartPainter extends CustomPainter {
  final List<GanttRowData> rows;
  final DateTime projectStartDate;
  final double dayWidth;
  final double rowHeight;

  GanttChartPainter({
    required this.rows,
    required this.projectStartDate,
    required this.dayWidth,
    required this.rowHeight,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawGrid(canvas, size);

    for (int i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.hasData) {
        _drawGanttBar(canvas, row, i);
      }
    }
  }

  void _drawGrid(Canvas canvas, Size size) {
    final gridPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 0.5;

    for (int i = 0; i <= rows.length; i++) {
      final y = i * rowHeight;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final totalDays = (size.width / dayWidth).ceil();
    for (int i = 0; i <= totalDays; i++) {
      final x = i * dayWidth;
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  void _drawGanttBar(Canvas canvas, GanttRowData row, int rowIndex) {
    if (row.startDate == null || row.endDate == null) return;

    final startOffset = row.startDate!.difference(projectStartDate).inDays * dayWidth;
    final duration = row.endDate!.difference(row.startDate!).inDays + 1;
    final barWidth = duration * dayWidth;

    final barHeight = rowHeight * 0.6;
    final barTop = (rowIndex * rowHeight) + (rowHeight - barHeight) / 2;

    final barPaint = Paint()
      ..color = Colors.blue.shade600
      ..style = PaintingStyle.fill;

    final barRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(startOffset + 2, barTop, barWidth - 4, barHeight),
      Radius.circular(2),
    );

    canvas.drawRRect(barRect, barPaint);

    final borderPaint = Paint()
      ..color = Colors.blue.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawRRect(barRect, borderPaint);

    final progressPaint = Paint()
      ..color = Colors.blue.shade300
      ..style = PaintingStyle.fill;

    final progressWidth = (barWidth - 4) * 0.6;
    final progressRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(startOffset + 2, barTop + 2, progressWidth, barHeight - 4),
      Radius.circular(1),
    );

    canvas.drawRRect(progressRect, progressPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class TaskContextMenu extends StatelessWidget {
  final VoidCallback onMakeMainTask;
  final VoidCallback onMakeSubtask;
  final VoidCallback onAddNewRow;
  final VoidCallback onDeleteRow;
  final VoidCallback onDismiss;

  const TaskContextMenu({
    super.key,
    required this.onMakeMainTask,
    required this.onMakeSubtask,
    required this.onAddNewRow,
    required this.onDeleteRow,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 180,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildMenuItem(
              icon: Icons.star_outline,
              text: 'Make Main Task',
              onTap: () {
                onDismiss();
                onMakeMainTask();
              },
            ),
            _buildMenuItem(
              icon: Icons.subdirectory_arrow_right,
              text: 'Make Subtask',
              onTap: () {
                onDismiss();
                onMakeSubtask();
              },
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.add,
              text: 'Add New Row',
              onTap: () {
                onDismiss();
                onAddNewRow();
              },
            ),
            _buildMenuItem(
              icon: Icons.delete_outline,
              text: 'Delete Row',
              onTap: () {
                onDismiss();
                onDeleteRow();
              },
              textColor: Colors.red.shade600,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String text,
    required VoidCallback onTap,
    Color? textColor,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              size: 16,
              color: textColor ?? Colors.grey.shade700,
            ),
            const SizedBox(width: 12),
            Text(
              text,
              style: GoogleFonts.poppins(
                fontSize: 13,
                color: textColor ?? Colors.grey.shade800,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}