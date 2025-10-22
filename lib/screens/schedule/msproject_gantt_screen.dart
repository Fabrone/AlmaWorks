import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/screens/projects/edit_project_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';
import 'dart:async';

class MSProjectGanttScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const MSProjectGanttScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<MSProjectGanttScreen> createState() => _MSProjectGanttScreenState();
}

class _MSProjectGanttScreenState extends State<MSProjectGanttScreen> {
  final Map<String, List<GanttRowData>> _cachedProjects = {};
  bool _isOfflineMode = false;
  final ScrollController _horizontalScrollController = ScrollController();
  final ScrollController _verticalScrollController = ScrollController();
  StreamSubscription<QuerySnapshot>? _firebaseListener;
  DateTime? _projectStartDate;
  DateTime? _projectEndDate;

  static const double rowHeight = 24.0;
  static const double headerHeight = 40.0;
  static const double dayWidth = 24.0;

  double _numberColumnWidth = 60.0;
  double _taskColumnWidth = 250.0;
  double _durationColumnWidth = 90.0;
  double _startColumnWidth = 120.0;
  double _finishColumnWidth = 120.0;
  double _resourcesColumnWidth = 120.0;
  double _actualDatesColumnWidth = 120.0;

  List<GanttRowData> _rows = [];
  static const int defaultRowCount = 6;
  bool _isLoading = true;

  // Temporary storage for edited row data
  final Map<int, GanttRowData> _editedRows = {};

  // Overlay management
  OverlayEntry? _overlayEntry;

  @override
  void initState() {
    super.initState();
    _initializeRealtimeClock();
    _setupFirebaseListener();
    _loadProjectDates();
    _loadTasksFromFirebase();
  }

  @override
  void dispose() {
    _firebaseListener?.cancel();
    _removeOverlay();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    super.dispose();
  }

  // Fetch project start and end dates from Firestore with detailed logging
  Future<void> _loadProjectDates() async {
    widget.logger.i(
      '📅 Attempting to load project dates for project ID: ${widget.project.id}',
    );
    try {
      final docRef = FirebaseFirestore.instance
          .collection('Projects')
          .doc(widget.project.id);
      widget.logger.d(
        'Querying Firestore at path: Projects/${widget.project.id}',
      );
      final doc = await docRef.get();

      if (doc.exists) {
        final data = doc.data();
        widget.logger.d('Document data: $data');

        if (data != null &&
            data.containsKey('startDate') &&
            data.containsKey('endDate')) {
          final startDate = (data['startDate'] as Timestamp?)?.toDate();
          final endDate = (data['endDate'] as Timestamp?)?.toDate();

          if (startDate != null && endDate != null) {
            if (mounted) {
              setState(() {
                _projectStartDate = startDate;
                _projectEndDate = endDate;
                _isLoading = false; // Only set to false if dates are valid
              });
              widget.logger.i(
                '✅ Successfully loaded project dates: $startDate to $endDate',
              );
            }
          } else {
            widget.logger.w(
              '⚠️ startDate or endDate is null in Firestore document',
            );
            _setDefaultDates();
          }
        } else {
          widget.logger.w('⚠️ Document missing startDate or endDate fields');
          _setDefaultDates();
        }
      } else {
        widget.logger.w(
          '⚠️ Project document does not exist for ID: ${widget.project.id}',
        );
        _setDefaultDates();
      }
    } catch (e, stackTrace) {
      widget.logger.e(
        '❌ Error loading project dates for project ID: ${widget.project.id}',
        error: e,
        stackTrace: stackTrace,
      );
      _setDefaultDates();
    }
  }

  void _setDefaultDates() {
    if (mounted) {
      setState(() {
        final now = DateTime.now();
        _projectStartDate = DateTime(now.year, now.month, now.day);
        _projectEndDate = DateTime(now.year, now.month + 1, now.day);
        _isOfflineMode = true;
        _isLoading = false;
      });
      widget.logger.i(
        '📅 Set default dates: $_projectStartDate to $_projectEndDate',
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Failed to load project dates, using default timeline',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  // Initialize real-time clock for dynamic date updates
  void _initializeRealtimeClock() {
    Timer.periodic(Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          // Refresh UI to ensure date display is current
          widget.logger.d('🔄 Realtime clock tick, refreshing UI');
        });
      }
    });
  }

  // Updated _setupFirebaseListener method to handle orphaned tasks after loading
  void _setupFirebaseListener() {
    _firebaseListener = FirebaseFirestore.instance
        .collection('Schedule')
        .where('projectId', isEqualTo: widget.project.id)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .listen(
          (snapshot) {
            if (!mounted) return;

            widget.logger.d(
              '📅 Received Firebase snapshot with ${snapshot.docs.length} documents',
            );
            List<GanttRowData> loadedRows = [];
            for (var doc in snapshot.docs) {
              final data = doc.data();
              loadedRows.add(GanttRowData.fromFirebaseMap(doc.id, data));
            }

            loadedRows.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));
            _cachedProjects[widget.project.id] = List.from(loadedRows);

            if (loadedRows.isNotEmpty) {
              _rows = loadedRows;
              _sortRowsByHierarchy();

              // Handle orphaned tasks that may exist in loaded data
              _assignParentsToOrphanedTasks();
            }

            while (_rows.length < defaultRowCount) {
              _rows.add(GanttRowData(id: 'row_${_rows.length + 1}'));
            }

            setState(() {
              _isLoading = false;
              _isOfflineMode = false;
              _computeColumnWidths();
            });

            widget.logger.i(
              '📅 MSProjectGantt: Real-time update with ${_rows.length} rows',
            );
          },
          onError: (e, stackTrace) {
            widget.logger.e(
              '❌ Firebase listener error',
              error: e,
              stackTrace: stackTrace,
            );
            setState(() {
              _isOfflineMode = true;
            });
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Working offline - changes will sync when connection is restored',
                    style: GoogleFonts.poppins(),
                  ),
                  backgroundColor: Colors.orange,
                ),
              );
            }
          },
        );
  }

  // Updated _loadTasksFromFirebase method to handle orphaned tasks
  Future<void> _loadTasksFromFirebase() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      if (_cachedProjects.containsKey(widget.project.id)) {
        _rows = List.from(_cachedProjects[widget.project.id]!);
        _sortRowsByHierarchy();

        // Handle orphaned tasks in cached data
        _assignParentsToOrphanedTasks();

        while (_rows.length < defaultRowCount) {
          _rows.add(GanttRowData(id: 'row_${_rows.length + 1}'));
        }
        _computeColumnWidths();
        setState(() => _isLoading = false);
        widget.logger.i(
          '📅 MSProjectGantt: Loaded ${_rows.length} rows from cache with orphaned task handling',
        );
        return;
      }
    } catch (e, stackTrace) {
      widget.logger.e(
        '❌ MSProjectGantt: Error loading tasks',
        error: e,
        stackTrace: stackTrace,
      );
      _isOfflineMode = true;
      if (mounted) {
        _initializeDefaultRows();
        setState(() => _isLoading = false);
      }
    }
  }

  void _initializeDefaultRows() {
    _rows = List.generate(
      defaultRowCount,
      (index) => GanttRowData(id: 'row_${index + 1}'),
    );
    _computeColumnWidths();
  }

  // Updated _addNewRow method - ensures new rows are tracked properly
  void _addNewRow({int? insertAfterIndex}) {
    if (!mounted) return;
    setState(() {
      final newRow = GanttRowData(
        id: 'new_row_${DateTime.now().millisecondsSinceEpoch}',
        isUnsaved: true, // Mark new rows as unsaved
      );

      // Determine insertion index
      int insertIndex =
          insertAfterIndex != null &&
              insertAfterIndex >= 0 &&
              insertAfterIndex < _rows.length
          ? insertAfterIndex + 1
          : _rows.length;

      // Find the nearest parent (MainTask or SubTask) by scanning upward from insertion point
      GanttRowData? nearestParent;
      int parentHierarchyLevel = -1;

      // Scan upward from the insertion point to find the nearest MainTask or SubTask
      for (int i = insertIndex - 1; i >= 0; i--) {
        final candidateParent = _editedRows[i] ?? _rows[i];

        if (candidateParent.taskType == TaskType.mainTask) {
          nearestParent = candidateParent;
          parentHierarchyLevel = candidateParent.hierarchyLevel;
          break;
        } else if (candidateParent.taskType == TaskType.subTask) {
          if (nearestParent == null ||
              candidateParent.hierarchyLevel > parentHierarchyLevel) {
            nearestParent = candidateParent;
            parentHierarchyLevel = candidateParent.hierarchyLevel;
          }
        }
      }

      // Assign parent and hierarchy level to the new task
      if (nearestParent != null) {
        newRow.parentId = nearestParent.id;
        newRow.hierarchyLevel = nearestParent.hierarchyLevel + 1;
        newRow.taskType = TaskType.task;

        _safeAddChildId(nearestParent, newRow.id);

        for (int i = 0; i < _rows.length; i++) {
          final row = _editedRows[i] ?? _rows[i];
          if (row.id == nearestParent.id) {
            _editedRows[i] = nearestParent;
            break;
          }
        }

        widget.logger.i(
          '📅 Auto-assigned parent "${nearestParent.taskName}" (${nearestParent.taskType}) to new unsaved task at hierarchy level ${newRow.hierarchyLevel}',
        );
      } else {
        newRow.hierarchyLevel = 0;
        newRow.taskType = TaskType.task;
        widget.logger.i(
          '📅 New unsaved task created as top-level task (no parent found)',
        );
      }

      // Insert the new row
      if (insertAfterIndex != null &&
          insertAfterIndex >= 0 &&
          insertAfterIndex < _rows.length) {
        _rows.insert(insertAfterIndex + 1, newRow);
        // CRITICAL: Add the new row to _editedRows immediately to track it for saving
        _editedRows[insertAfterIndex + 1] = newRow;

        // Update indices for existing edited rows that come after the insertion point
        final updatedEditedRows = <int, GanttRowData>{};
        _editedRows.forEach((key, value) {
          if (key > insertAfterIndex) {
            updatedEditedRows[key + 1] = value;
          } else {
            updatedEditedRows[key] = value;
          }
        });
        _editedRows.clear();
        _editedRows.addAll(updatedEditedRows);
      } else {
        _rows.add(newRow);
        // CRITICAL: Add the new row to _editedRows immediately
        _editedRows[_rows.length - 1] = newRow;
      }

      // Recalculate hierarchy and update display orders
      _calculateHierarchy();
      _computeColumnWidths();
    });
    widget.logger.i(
      '📅 Added new unsaved row at index: ${insertAfterIndex ?? _rows.length - 1}',
    );
  }

  void _deleteRow(int index) {
    if (!mounted) return;

    final rowToDelete = _editedRows[index] ?? _rows[index];

    // Only allow deletion of unsaved rows or rows beyond default count
    if (!rowToDelete.isUnsaved && index < defaultRowCount) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Cannot delete saved rows within default range',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      widget.logger.w(
        '⚠️ Attempted to delete saved row within default range at index: $index',
      );
      return;
    }

    if (index >= 0 && index < _rows.length) {
      setState(() {
        _rows.removeAt(index);

        // Properly manage _editedRows indices after deletion
        final updatedEditedRows = <int, GanttRowData>{};
        _editedRows.forEach((key, value) {
          if (key < index) {
            // Rows before deletion point keep same index
            updatedEditedRows[key] = value;
          } else if (key > index) {
            // Rows after deletion point shift down by 1
            updatedEditedRows[key - 1] = value;
          }
          // Skip the deleted row (key == index)
        });
        _editedRows.clear();
        _editedRows.addAll(updatedEditedRows);

        _calculateHierarchy();
        _computeColumnWidths();
      });

      // Only delete from Firebase if it was previously saved
      if (rowToDelete.firestoreId != null) {
        _deleteRowFromFirebase(rowToDelete.firestoreId!);
      }
      widget.logger.i(
        '📅 Deleted row at index: $index, firestoreId: ${rowToDelete.firestoreId}, was unsaved: ${rowToDelete.isUnsaved}',
      );
    }
  }

  Future<void> _saveRowToFirebase(GanttRowData row, int index) async {
    try {
      final rowData = row.toFirebaseMap(
        widget.project.id,
        widget.project.name,
        index,
      );
      widget.logger.d('Saving row data to Firebase: $rowData');

      if (row.firestoreId != null) {
        await FirebaseFirestore.instance
            .collection('Schedule')
            .doc(row.firestoreId)
            .update(rowData);
        widget.logger.i(
          '✅ Updated row: ${row.taskName} for project ${widget.project.name} (${widget.project.id})',
        );
      } else {
        final docRef = await FirebaseFirestore.instance
            .collection('Schedule')
            .add(rowData);
        row.firestoreId = docRef.id;
        widget.logger.i(
          '✅ Created new row: ${row.taskName} for project ${widget.project.name} (${widget.project.id})',
        );
      }

      // Mark row as saved
      row.isUnsaved = false;

      if (_cachedProjects.containsKey(widget.project.id)) {
        final cachedRows = _cachedProjects[widget.project.id]!;
        final existingIndex = cachedRows.indexWhere((r) => r.id == row.id);
        if (existingIndex != -1) {
          cachedRows[existingIndex] = GanttRowData.from(row);
        } else {
          cachedRows.add(GanttRowData.from(row));
        }
      }
    } catch (e, stackTrace) {
      widget.logger.e(
        '❌ Error saving row to Firebase for project ${widget.project.name} (${widget.project.id})',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Failed to save task: $e',
              style: GoogleFonts.poppins(),
            ),
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
      widget.logger.i('✅ Deleted row from Firebase: $firestoreId');
    } catch (e, stackTrace) {
      widget.logger.e(
        '❌ Error deleting row from Firebase',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  // Updated _updateRowData method - enhanced for better date/duration handling
  void _updateRowData(
    int index, {
    String? taskName,
    int? duration,
    DateTime? startDate,
    DateTime? endDate,
    TaskType? taskType,
  }) {
    if (!mounted) return;
    if (index < 0 || index >= _rows.length) {
      widget.logger.w('⚠️ Attempted to update row at invalid index: $index');
      return;
    }

    setState(() {
      // CRITICAL FIX: Ensure we always have a row in _editedRows for tracking
      final row = _editedRows[index] ?? GanttRowData.from(_rows[index]);
      _editedRows[index] = row;

      if (taskName != null) {
        row.taskName = taskName;
        widget.logger.d('Updated task name for row $index: $taskName');
      }

      // Handle task type changes with hierarchy recalculation
      if (taskType != null) {
        final oldTaskType = row.taskType;
        row.taskType = taskType;

        if (oldTaskType != taskType) {
          _clearAffectedRelationships(index, oldTaskType, taskType);
          _calculateHierarchy();
          widget.logger.d(
            'Updated task type for row $index: $taskType with hierarchy recalculation',
          );
        }
      }

      // Enhanced date and duration handling with automatic recalculation
      bool needsRecalculation = false;

      // Handle duration changes first
      if (duration != null && duration != row.duration) {
        row.duration = duration;
        needsRecalculation = true;
        widget.logger.d('Updated duration for row $index: $duration');
      }

      // Handle date updates with parent-child constraints
      if (startDate != null && startDate != row.startDate) {
        if (_validateAndSetStartDate(row, startDate, index)) {
          needsRecalculation = true;
          _updateParentDatesIfNeeded(row, index);
        } else {
          // If validation failed, don't proceed with recalculation
          return;
        }
      }

      if (endDate != null && endDate != row.endDate) {
        if (_validateAndSetEndDate(row, endDate, index)) {
          needsRecalculation = true;
          _updateParentDatesIfNeeded(row, index);
        } else {
          // If validation failed, don't proceed with recalculation
          return;
        }
      }

      // Perform automatic recalculation if any date/duration field changed
      if (needsRecalculation) {
        _performSmartRecalculation(row, index);
      }

      _computeColumnWidths();
    });
  }

  void _performSmartRecalculation(GanttRowData row, int index) {
    // Count how many fields are populated
    bool hasStart = row.startDate != null;
    bool hasEnd = row.endDate != null;
    bool hasDuration = row.duration != null && row.duration! > 0;

    widget.logger.d(
      'Smart recalculation for row $index: start=$hasStart, end=$hasEnd, duration=$hasDuration',
    );

    if (hasStart && hasEnd && !hasDuration) {
      // Calculate duration from start and end dates
      row.duration = row.endDate!.difference(row.startDate!).inDays + 1;
      widget.logger.d('Calculated duration: ${row.duration}');
      
    } else if (hasStart && hasDuration && !hasEnd) {
      // Calculate end date from start date and duration
      final calculatedEndDate = row.startDate!.add(Duration(days: row.duration! - 1));
      if (_validateCalculatedEndDate(row, calculatedEndDate, index)) {
        row.endDate = calculatedEndDate;
        widget.logger.d('Calculated end date: ${row.endDate}');
      } else {
        // Clear duration if calculated end date is invalid
        row.duration = null;
        widget.logger.w('Cleared duration due to invalid calculated end date');
      }
      
    } else if (hasEnd && hasDuration && !hasStart) {
      // Calculate start date from end date and duration
      final calculatedStartDate = row.endDate!.subtract(Duration(days: row.duration! - 1));
      if (_validateCalculatedStartDate(row, calculatedStartDate, index)) {
        row.startDate = calculatedStartDate;
        widget.logger.d('Calculated start date: ${row.startDate}');
      } else {
        // Clear duration if calculated start date is invalid
        row.duration = null;
        widget.logger.w('Cleared duration due to invalid calculated start date');
      }
      
    } else if (hasStart && hasEnd && hasDuration) {
      // All three fields are populated - verify consistency and adjust if needed
      final calculatedDuration = row.endDate!.difference(row.startDate!).inDays + 1;
      if (calculatedDuration != row.duration) {
        // Prioritize the most recently changed field by recalculating end date from start + duration
        final recalculatedEndDate = row.startDate!.add(Duration(days: row.duration! - 1));
        if (_validateCalculatedEndDate(row, recalculatedEndDate, index)) {
          row.endDate = recalculatedEndDate;
          widget.logger.d('Recalculated end date for consistency: ${row.endDate}');
        } else {
          // Fall back to calculating duration from existing dates
          row.duration = calculatedDuration;
          widget.logger.d('Recalculated duration for consistency: ${row.duration}');
        }
      }
    }

    // Update parent dates if this row has a parent
    _updateParentDatesIfNeeded(row, index);
  }

  bool _validateCalculatedEndDate(GanttRowData row, DateTime calculatedEndDate, int index) {
    // Enhanced project-level constraints - MainTasks can be anywhere within project bounds
    if (_projectStartDate != null && _projectEndDate != null) {
      if (row.taskType == TaskType.mainTask) {
        // MainTask must be within project timeline but doesn't need to match exact dates
        if (calculatedEndDate.isBefore(_projectStartDate!) || calculatedEndDate.isAfter(_projectEndDate!)) {
          _showDateConstraintError(
            'Calculated end date would place MainTask outside project timeline. Please adjust duration or start date.',
          );
          return false;
        }
      } else {
        // Regular project boundary check for non-main tasks
        if (calculatedEndDate.isBefore(_projectStartDate!) ||
            calculatedEndDate.isAfter(_projectEndDate!)) {
          _showDateConstraintError(
            'Calculated end date would be outside project timeline. Please adjust duration or start date.',
          );
          return false;
        }
      }
    }

    // Check parent constraints with dialog option for calculated dates
    final parentRow = _getParentRow(row);
    if (parentRow != null && parentRow.endDate != null) {
      if (calculatedEndDate.isAfter(parentRow.endDate!)) {
        _showParentTaskDateViolationDialog(
          'The calculated end date would be after the parent task end date',
          'end',
          calculatedEndDate,
          parentRow,
          row,
          index,
          'calculated_end',
        );
        return false;
      }
      if (parentRow.startDate != null &&
          calculatedEndDate.isBefore(parentRow.startDate!)) {
        _showParentTaskDateViolationDialog(
          'The calculated end date would be before the parent task start date',
          'start',
          calculatedEndDate,
          parentRow,
          row,
          index,
          'calculated_end',
        );
        return false;
      }
    }

    // Check child constraints
    if (!_validateChildrenEndDates(row, calculatedEndDate)) {
      return false;
    }

    return true;
  }

  bool _validateCalculatedStartDate(GanttRowData row, DateTime calculatedStartDate, int index) {
    // Enhanced project-level constraints - MainTasks can be anywhere within project bounds
    if (_projectStartDate != null && _projectEndDate != null) {
      if (row.taskType == TaskType.mainTask) {
        // MainTask must be within project timeline but doesn't need to match exact dates
        if (calculatedStartDate.isBefore(_projectStartDate!) || calculatedStartDate.isAfter(_projectEndDate!)) {
          _showDateConstraintError(
            'Calculated start date would place MainTask outside project timeline. Please adjust duration or end date.',
          );
          return false;
        }
      } else {
        // Regular project boundary check for non-main tasks
        if (calculatedStartDate.isBefore(_projectStartDate!) ||
            calculatedStartDate.isAfter(_projectEndDate!)) {
          _showDateConstraintError(
            'Calculated start date would be outside project timeline. Please adjust duration or end date.',
          );
          return false;
        }
      }
    }

    // Check parent constraints with dialog option for calculated dates
    final parentRow = _getParentRow(row);
    if (parentRow != null && parentRow.startDate != null) {
      if (calculatedStartDate.isBefore(parentRow.startDate!)) {
        _showParentTaskDateViolationDialog(
          'The calculated start date would be before the parent task start date',
          'start',
          calculatedStartDate,
          parentRow,
          row,
          index,
          'calculated_start',
        );
        return false;
      }
      if (parentRow.endDate != null && calculatedStartDate.isAfter(parentRow.endDate!)) {
        _showParentTaskDateViolationDialog(
          'The calculated start date would be after the parent task end date',
          'end',
          calculatedStartDate,
          parentRow,
          row,
          index,
          'calculated_start',
        );
        return false;
      }
    }

    // Check child constraints
    if (!_validateChildrenStartDates(row, calculatedStartDate)) {
      return false;
    }

    return true;
  }

  bool _validateAndSetStartDate(
    GanttRowData row,
    DateTime startDate,
    int index,
  ) {
    // Enhanced project-level constraints - MainTasks can be anywhere within project bounds
    if (_projectStartDate != null && _projectEndDate != null) {
      if (row.taskType == TaskType.mainTask) {
        // MainTask must be within project timeline but doesn't need to match exact dates
        if (startDate.isBefore(_projectStartDate!) || startDate.isAfter(_projectEndDate!)) {
          _showProjectDateViolationDialog(
            'MainTask start date must be within the project timeline',
            'start',
            startDate,
          );
          return false;
        }
      } else {
        // Regular project boundary check for non-main tasks
        if (startDate.isBefore(_projectStartDate!) ||
            startDate.isAfter(_projectEndDate!)) {
          _showDateConstraintError(
            'Start date must be within project timeline (${DateFormat('MM/dd/yyyy').format(_projectStartDate!)} - ${DateFormat('MM/dd/yyyy').format(_projectEndDate!)})',
          );
          return false;
        }
      }
    }

    // Check parent constraints with dialog option
    final parentRow = _getParentRow(row);
    if (parentRow != null && parentRow.startDate != null) {
      if (startDate.isBefore(parentRow.startDate!)) {
        _showParentTaskDateViolationDialog(
          'Your selected start date is before the parent task start date',
          'start',
          startDate,
          parentRow,
          row,
          index,
          'start',
        );
        return false;
      }
      if (parentRow.endDate != null && startDate.isAfter(parentRow.endDate!)) {
        _showParentTaskDateViolationDialog(
          'Your selected start date is after the parent task end date',
          'end',
          startDate,
          parentRow,
          row,
          index,
          'start',
        );
        return false;
      }
    }

    // Check child constraints
    if (!_validateChildrenStartDates(row, startDate)) {
      return false;
    }

    row.startDate = startDate;
    widget.logger.d('Updated start date for row $index: $startDate');
    return true;
  }

  bool _validateAndSetEndDate(GanttRowData row, DateTime endDate, int index) {
    // Enhanced project-level constraints - MainTasks can be anywhere within project bounds
    if (_projectStartDate != null && _projectEndDate != null) {
      if (row.taskType == TaskType.mainTask) {
        // MainTask must be within project timeline but doesn't need to match exact dates
        if (endDate.isBefore(_projectStartDate!) || endDate.isAfter(_projectEndDate!)) {
          _showProjectDateViolationDialog(
            'MainTask end date must be within the project timeline',
            'end',
            endDate,
          );
          return false;
        }
      } else {
        // Regular project boundary check for non-main tasks
        if (endDate.isBefore(_projectStartDate!) ||
            endDate.isAfter(_projectEndDate!)) {
          _showDateConstraintError(
            'End date must be within project timeline (${DateFormat('MM/dd/yyyy').format(_projectStartDate!)} - ${DateFormat('MM/dd/yyyy').format(_projectEndDate!)})',
          );
          return false;
        }
      }
    }

    // Check parent constraints with dialog option
    final parentRow = _getParentRow(row);
    if (parentRow != null && parentRow.endDate != null) {
      if (endDate.isAfter(parentRow.endDate!)) {
        _showParentTaskDateViolationDialog(
          'Your selected end date is after the parent task end date',
          'end',
          endDate,
          parentRow,
          row,
          index,
          'end',
        );
        return false;
      }
      if (parentRow.startDate != null &&
          endDate.isBefore(parentRow.startDate!)) {
        _showParentTaskDateViolationDialog(
          'Your selected end date is before the parent task start date',
          'start',
          endDate,
          parentRow,
          row,
          index,
          'end',
        );
        return false;
      }
    }

    // Check child constraints
    if (!_validateChildrenEndDates(row, endDate)) {
      return false;
    }

    row.endDate = endDate;
    widget.logger.d('Updated end date for row $index: $endDate');
    return true;
  }

  // Show parent task date violation dialog
  void _showParentTaskDateViolationDialog(
    String message,
    String boundaryType,
    DateTime attemptedDate,
    GanttRowData parentRow,
    GanttRowData childRow,
    int childIndex,
    String dateType,
  ) {
    final dateStr = DateFormat('MM/dd/yyyy').format(attemptedDate);
    final parentStartStr = parentRow.startDate != null 
        ? DateFormat('MM/dd/yyyy').format(parentRow.startDate!) 
        : 'Not set';
    final parentEndStr = parentRow.endDate != null 
        ? DateFormat('MM/dd/yyyy').format(parentRow.endDate!) 
        : 'Not set';

    String fullMessage = '$message.\n\n';
    fullMessage += 'Attempted date: $dateStr\n';
    fullMessage += 'Parent task "${parentRow.taskName ?? 'Unnamed'}" timeline: $parentStartStr - $parentEndStr\n\n';
    fullMessage += 'Would you like to adjust the parent task dates to accommodate this change?';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade600,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Date Outside Parent Task Timeline',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.logger.i(
                  '📅 User canceled date selection due to parent task boundary violation',
                );
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _adjustParentTaskDates(
                  parentRow,
                  childRow,
                  childIndex,
                  attemptedDate,
                  dateType,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Continue',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        );
      },
    );

    widget.logger.w(
      '⚠️ Parent task date boundary violation: $message for date $dateStr',
    );
  }

  Future<void> _adjustParentTaskDates(
    GanttRowData parentRow,
    GanttRowData childRow,
    int childIndex,
    DateTime attemptedDate,
    String dateType,
  ) async {
    widget.logger.i(
      '📅 Attempting to adjust parent task "${parentRow.taskName}" dates for child task change',
    );

    DateTime? newParentStart = parentRow.startDate;
    DateTime? newParentEnd = parentRow.endDate;
    bool parentNeedsUpdate = false;

    // Determine which parent date needs adjustment
    if (dateType == 'start' || dateType == 'calculated_start') {
      if (parentRow.startDate == null || attemptedDate.isBefore(parentRow.startDate!)) {
        newParentStart = attemptedDate;
        parentNeedsUpdate = true;
      }
    }

    if (dateType == 'end' || dateType == 'calculated_end') {
      if (parentRow.endDate == null || attemptedDate.isAfter(parentRow.endDate!)) {
        newParentEnd = attemptedDate;
        parentNeedsUpdate = true;
      }
    }

    if (!parentNeedsUpdate) {
      widget.logger.w('No parent adjustment needed');
      return;
    }

    // Check if adjusted parent dates would violate project constraints
    if (_projectStartDate != null && _projectEndDate != null) {
      if (parentRow.taskType == TaskType.mainTask) {
        // For main tasks, check they remain within project bounds (not exact match)
        if ((newParentStart != null && (newParentStart.isBefore(_projectStartDate!) || newParentStart.isAfter(_projectEndDate!))) ||
            (newParentEnd != null && (newParentEnd.isBefore(_projectStartDate!) || newParentEnd.isAfter(_projectEndDate!)))) {
          
          String violationType = 'timeline';
          DateTime violatingDate = newParentStart != null && newParentStart.isBefore(_projectStartDate!) 
              ? newParentStart 
              : (newParentEnd != null && newParentEnd.isAfter(_projectEndDate!) ? newParentEnd : attemptedDate);
          
          _showProjectDateViolationDialog(
            'Adjusting the MainTask would place it outside the project timeline',
            violationType,
            violatingDate,
          );
          return;
        }
      } else {
        // For subtasks, check against project bounds
        if ((newParentStart != null && (newParentStart.isBefore(_projectStartDate!) || newParentStart.isAfter(_projectEndDate!))) ||
            (newParentEnd != null && (newParentEnd.isBefore(_projectStartDate!) || newParentEnd.isAfter(_projectEndDate!)))) {
          
          _showDateConstraintError(
            'Adjusting the parent task would place it outside the project timeline',
          );
          return;
        }
      }
    }

    // Apply the parent date adjustments and child date changes in single setState
    setState(() {
      // Update parent dates
      if (newParentStart != null) {
        parentRow.startDate = newParentStart;
      }
      if (newParentEnd != null) {
        parentRow.endDate = newParentEnd;
      }

      // Update parent duration if both dates are set
      if (parentRow.startDate != null && parentRow.endDate != null) {
        parentRow.duration = parentRow.endDate!.difference(parentRow.startDate!).inDays + 1;
      }

      // Find parent row index and mark it as edited
      final parentIndex = _getRowIndex(parentRow.id);
      if (parentIndex != -1) {
        _editedRows[parentIndex] = parentRow;
      }

      // CRITICAL FIX: Apply child date change AND perform full recalculation immediately
      if (dateType == 'start' || dateType == 'calculated_start') {
        childRow.startDate = attemptedDate;
      } else if (dateType == 'end' || dateType == 'calculated_end') {
        childRow.endDate = attemptedDate;
      }

      // Ensure child row is in edited rows
      _editedRows[childIndex] = childRow;

      // CRITICAL FIX: Perform complete recalculation for the child row immediately
      _performImmediateRecalculation(childRow, childIndex);
    });

    // Check if parent needs further adjustment (e.g., its own parent)
    _updateParentDatesIfNeeded(parentRow, _getRowIndex(parentRow.id));

    widget.logger.i(
      '✅ Successfully adjusted parent task dates and applied child task change with full recalculation',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Parent task "${parentRow.taskName ?? 'Unnamed'}" dates adjusted to accommodate the change',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.blue.shade600,
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  void _performImmediateRecalculation(GanttRowData row, int index) {
    // Count how many fields are populated
    bool hasStart = row.startDate != null;
    bool hasEnd = row.endDate != null;
    bool hasDuration = row.duration != null && row.duration! > 0;

    widget.logger.d(
      'Immediate recalculation for row $index: start=$hasStart, end=$hasEnd, duration=$hasDuration',
    );

    if (hasStart && hasEnd && !hasDuration) {
      // Calculate duration from start and end dates
      row.duration = row.endDate!.difference(row.startDate!).inDays + 1;
      widget.logger.d('Immediately calculated duration: ${row.duration}');
      
    } else if (hasStart && hasDuration && !hasEnd) {
      // Calculate end date from start date and duration
      final calculatedEndDate = row.startDate!.add(Duration(days: row.duration! - 1));
      
      // Validate without triggering dialogs (since we're in parent adjustment flow)
      if (_isDateWithinBounds(row, calculatedEndDate, 'end')) {
        row.endDate = calculatedEndDate;
        widget.logger.d('Immediately calculated end date: ${row.endDate}');
      }
      
    } else if (hasEnd && hasDuration && !hasStart) {
      // Calculate start date from end date and duration
      final calculatedStartDate = row.endDate!.subtract(Duration(days: row.duration! - 1));
      
      // Validate without triggering dialogs (since we're in parent adjustment flow)
      if (_isDateWithinBounds(row, calculatedStartDate, 'start')) {
        row.startDate = calculatedStartDate;
        widget.logger.d('Immediately calculated start date: ${row.startDate}');
      }
      
    } else if (hasStart && hasEnd && hasDuration) {
      // All three fields are populated - verify consistency and adjust if needed
      final calculatedDuration = row.endDate!.difference(row.startDate!).inDays + 1;
      if (calculatedDuration != row.duration) {
        // Prioritize dates over duration in parent adjustment scenarios
        row.duration = calculatedDuration;
        widget.logger.d('Immediately recalculated duration for consistency: ${row.duration}');
      }
    }

    // Update edited rows to ensure changes are tracked
    _editedRows[index] = row;
  }

  bool _isDateWithinBounds(GanttRowData row, DateTime date, String dateType) {
    // Check project bounds
    if (_projectStartDate != null && _projectEndDate != null) {
      if (row.taskType == TaskType.mainTask) {
        if (date.isBefore(_projectStartDate!) || date.isAfter(_projectEndDate!)) {
          return false;
        }
      } else {
        if (date.isBefore(_projectStartDate!) || date.isAfter(_projectEndDate!)) {
          return false;
        }
      }
    }

    // Check parent bounds (if any)
    final parentRow = _getParentRow(row);
    if (parentRow != null) {
      if (dateType == 'start' && parentRow.startDate != null) {
        if (date.isBefore(parentRow.startDate!)) return false;
      }
      if (dateType == 'end' && parentRow.endDate != null) {
        if (date.isAfter(parentRow.endDate!)) return false;
      }
      if (parentRow.startDate != null && parentRow.endDate != null) {
        if (date.isBefore(parentRow.startDate!) || date.isAfter(parentRow.endDate!)) {
          return false;
        }
      }
    }

    return true;
  }

  // New method to get parent row
  GanttRowData? _getParentRow(GanttRowData row) {
    if (row.parentId == null) return null;

    for (int i = 0; i < _rows.length; i++) {
      final parentRow = _editedRows[i] ?? _rows[i];
      if (parentRow.id == row.parentId) {
        return parentRow;
      }
    }
    return null;
  }

  // New method to get child rows
  List<GanttRowData> _getChildRows(GanttRowData row) {
    List<GanttRowData> children = [];

    for (String childId in row.childIds) {
      for (int i = 0; i < _rows.length; i++) {
        final childRow = _editedRows[i] ?? _rows[i];
        if (childRow.id == childId) {
          children.add(childRow);
          break;
        }
      }
    }
    return children;
  }

  // New method to validate children start dates
  bool _validateChildrenStartDates(
    GanttRowData parentRow,
    DateTime newStartDate,
  ) {
    final children = _getChildRows(parentRow);

    for (final child in children) {
      if (child.startDate != null && child.startDate!.isBefore(newStartDate)) {
        _showDateConstraintError(
          'Cannot set start date after child task "${child.taskName}" starts (${DateFormat('MM/dd/yyyy').format(child.startDate!)})',
        );
        return false;
      }
    }
    return true;
  }

  // New method to validate children end dates
  bool _validateChildrenEndDates(GanttRowData parentRow, DateTime newEndDate) {
    final children = _getChildRows(parentRow);

    for (final child in children) {
      if (child.endDate != null && child.endDate!.isAfter(newEndDate)) {
        _showDateConstraintError(
          'Cannot set end date before child task "${child.taskName}" ends (${DateFormat('MM/dd/yyyy').format(child.endDate!)})',
        );
        return false;
      }
    }
    return true;
  }

  // New method to automatically update parent dates when child dates change
  void _updateParentDatesIfNeeded(GanttRowData childRow, int childIndex) {
    final parentRow = _getParentRow(childRow);
    if (parentRow == null) return;

    final allChildren = _getChildRows(parentRow);
    if (allChildren.isEmpty) return;

    // Find the earliest start date among all children
    DateTime? earliestStart;
    DateTime? latestEnd;

    for (final child in allChildren) {
      if (child.startDate != null) {
        if (earliestStart == null || child.startDate!.isBefore(earliestStart)) {
          earliestStart = child.startDate;
        }
      }
      if (child.endDate != null) {
        if (latestEnd == null || child.endDate!.isAfter(latestEnd)) {
          latestEnd = child.endDate;
        }
      }
    }

    bool parentUpdated = false;

    // Update parent start date if necessary
    if (earliestStart != null &&
        (parentRow.startDate == null ||
            earliestStart.isBefore(parentRow.startDate!))) {
      // Check if the new start date is within project bounds
      if (_projectStartDate != null &&
          earliestStart.isBefore(_projectStartDate!)) {
        widget.logger.w(
          'Cannot auto-adjust parent start date - would exceed project start date',
        );
      } else {
        parentRow.startDate = earliestStart;
        parentUpdated = true;
        widget.logger.i(
          'Auto-updated parent task "${parentRow.taskName}" start date to: $earliestStart',
        );
      }
    }

    // Update parent end date if necessary
    if (latestEnd != null &&
        (parentRow.endDate == null || latestEnd.isAfter(parentRow.endDate!))) {
      // Check if the new end date is within project bounds
      if (_projectEndDate != null && latestEnd.isAfter(_projectEndDate!)) {
        widget.logger.w(
          'Cannot auto-adjust parent end date - would exceed project end date',
        );
      } else {
        parentRow.endDate = latestEnd;
        parentUpdated = true;
        widget.logger.i(
          'Auto-updated parent task "${parentRow.taskName}" end date to: $latestEnd',
        );
      }
    }

    if (parentRow.startDate != null && parentRow.endDate != null) {
      parentRow.duration =
          parentRow.endDate!.difference(parentRow.startDate!).inDays + 1;
    }

    // If parent was updated, recursively update its parent
    if (parentUpdated) {
      final parentIndex = _getRowIndex(parentRow.id);
      if (parentIndex != -1) {
        _editedRows[parentIndex] = parentRow;
        _updateParentDatesIfNeeded(parentRow, parentIndex);
      }
    }
  }

  // Helper method to get row index by ID
  int _getRowIndex(String rowId) {
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      if (row.id == rowId) return i;
    }
    return -1;
  }

  void _showDateConstraintError(String message) {
    widget.logger.w('Date constraint violation: $message');
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _saveAllRows() async {
    if (!mounted) return;

    _calculateHierarchy();

    if (_isOfflineMode) {
      // In offline mode, save all rows with data to local state
      for (int i = 0; i < _rows.length; i++) {
        final row = _editedRows[i] ?? _rows[i];
        if (_shouldSaveRow(row)) {
          setState(() {
            _rows[i] = GanttRowData.from(row);
          });
          widget.logger.i(
            '📅 Saved row $i locally in offline mode: ${row.taskName}',
          );
        }
      }
      setState(() {
        _editedRows.clear();
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Changes saved locally - will sync when online',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    List<Future<void>> saveFutures = [];

    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];

      if (_shouldSaveRow(row)) {
        widget.logger.d(
          '📅 Preparing to save row $i: ${row.taskName} (firestoreId: ${row.firestoreId})',
        );
        saveFutures.add(_saveRowToFirebase(row, i));
      }
    }

    try {
      await Future.wait(saveFutures);

      // Update local state after successful saves
      for (int i = 0; i < _rows.length; i++) {
        final row = _editedRows[i] ?? _rows[i];
        if (_shouldSaveRow(row)) {
          setState(() {
            _rows[i] = GanttRowData.from(row);
          });
        }
      }

      setState(() {
        _editedRows.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'All changes saved successfully (${saveFutures.length} rows)',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }
      widget.logger.i(
        '📅 Successfully saved ${saveFutures.length} rows to Firebase',
      );
    } catch (e, stackTrace) {
      widget.logger.e('❌ Error saving rows', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error saving some changes: $e',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  bool _shouldSaveRow(GanttRowData row) {
    return (row.taskName?.trim().isNotEmpty == true) ||
        (row.startDate != null) ||
        (row.endDate != null) ||
        (row.duration != null && row.duration! > 0) ||
        (row.taskType !=
            TaskType.task) || 
        (row.parentId != null) || 
        (row.childIds.isNotEmpty); 
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

    double headerWidth = _measureText('No.', headerStyle) + 16;
    double maxCellWidth = 0;
    for (int i = 0; i < _rows.length; i++) {
      String noText = '${i + 1}';
      double textW = _measureText(noText, cellStyle);
      double cellW = textW;
      if (i >= defaultRowCount) {
        cellW += 16 + 8;
      }
      if (cellW > maxCellWidth) maxCellWidth = cellW;
    }
    maxCellWidth += 32;
    _numberColumnWidth = math.max(headerWidth, maxCellWidth);

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

    // Compute width for Resources column
    headerWidth = _measureText('Resources', headerStyle) + 24;
    _resourcesColumnWidth = math.max(headerWidth, 120.0);

    // Compute width for Actual Dates column
    headerWidth = _measureText('Actual Dates', headerStyle) + 24;
    _actualDatesColumnWidth = math.max(headerWidth, 120.0);

    widget.logger.d(
      '📅 Computed column widths: number=$_numberColumnWidth, task=$_taskColumnWidth, duration=$_durationColumnWidth, start=$_startColumnWidth, finish=$_finishColumnWidth, resources=$_resourcesColumnWidth, actualDates=$_actualDatesColumnWidth',
    );
  }

  // Updated _calculateHierarchy method with orphaned task assignment
  void _calculateHierarchy() {
    // First pass: Reset all hierarchy data
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      row.parentId = null;
      row.hierarchyLevel = 0;
      row.displayOrder = i;

      try {
        row.childIds.clear();
      } catch (e, stackTrace) {
        row.childIds = <String>[];
        widget.logger.w(
          '⚠️ Had to recreate childIds list for row ${row.id}',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    // Second pass: Establish parent-child relationships dynamically
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];

      if (row.taskType == TaskType.mainTask) {
        row.hierarchyLevel = 0;
        row.displayOrder = i;

        // Scan forward to find children for this MainTask
        for (int j = i + 1; j < _rows.length; j++) {
          final candidateChild = _editedRows[j] ?? _rows[j];

          // Stop if we hit another MainTask
          if (candidateChild.taskType == TaskType.mainTask) break;

          // Assign SubTasks and regular Tasks as direct children of MainTask
          if (candidateChild.parentId == null) {
            if (candidateChild.taskType == TaskType.subTask) {
              candidateChild.parentId = row.id;
              candidateChild.hierarchyLevel = 1;
              _safeAddChildId(row, candidateChild.id);

              // Now find children for this SubTask
              for (int k = j + 1; k < _rows.length; k++) {
                final subCandidate = _editedRows[k] ?? _rows[k];

                // Stop if we hit MainTask or another SubTask
                if (subCandidate.taskType == TaskType.mainTask ||
                    subCandidate.taskType == TaskType.subTask) {
                  break;
                }

                // Assign regular Tasks as children of SubTask
                if (subCandidate.taskType == TaskType.task &&
                    subCandidate.parentId == null) {
                  subCandidate.parentId = candidateChild.id;
                  subCandidate.hierarchyLevel = 2;
                  _safeAddChildId(candidateChild, subCandidate.id);
                }
              }
            } else if (candidateChild.taskType == TaskType.task) {
              candidateChild.parentId = row.id;
              candidateChild.hierarchyLevel = 1;
              _safeAddChildId(row, candidateChild.id);
            }
          }
        }
      }
    }

    // Third pass: Handle any remaining orphaned tasks
    _assignParentsToOrphanedTasks();

    // Update _editedRows to reflect hierarchy changes
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      if (row.parentId != null || row.childIds.isNotEmpty) {
        _editedRows[i] = row;
      }
    }

    widget.logger.d(
      '📅 Enhanced hierarchy calculation completed for ${_rows.length} rows',
    );
  }

  void _safeAddChildId(GanttRowData parentRow, String childId) {
    try {
      parentRow.childIds.add(childId);
    } catch (e, stackTrace) {
      List<String> newList = List<String>.from(parentRow.childIds);
      newList.add(childId);
      parentRow.childIds = newList;
      widget.logger.w(
        '⚠️ Had to recreate childIds list for parent ${parentRow.id}',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void _sortRowsByHierarchy() {
    List<GanttRowData> sortedRows = [];
    Map<String, GanttRowData> rowMap = {};

    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      rowMap[row.id] = row;
    }

    void addRowAndChildren(GanttRowData row) {
      sortedRows.add(row);
      List<String> sortedChildIds = List.from(row.childIds);
      sortedChildIds.sort((a, b) {
        final rowA = rowMap[a];
        final rowB = rowMap[b];
        if (rowA == null || rowB == null) return 0;
        return rowA.displayOrder.compareTo(rowB.displayOrder);
      });

      for (String childId in sortedChildIds) {
        final childRow = rowMap[childId];
        if (childRow != null) {
          addRowAndChildren(childRow);
        }
      }
    }

    List<GanttRowData> topLevelRows = rowMap.values
        .where((row) => row.hierarchyLevel == 0 || row.parentId == null)
        .toList();

    topLevelRows.sort((a, b) => a.displayOrder.compareTo(b.displayOrder));

    for (GanttRowData topRow in topLevelRows) {
      addRowAndChildren(topRow);
    }

    setState(() {
      _rows = sortedRows;
    });
    widget.logger.d('📅 Sorted rows by hierarchy, total rows: ${_rows.length}');
  }

  // NEW METHOD: Show project date violation dialog
  void _showProjectDateViolationDialog(
    String message,
    String boundaryType,
    DateTime attemptedDate,
  ) {
    final dateStr = DateFormat('MM/dd/yyyy').format(attemptedDate);
    final projectStartStr = DateFormat('MM/dd/yyyy').format(_projectStartDate!);
    final projectEndStr = DateFormat('MM/dd/yyyy').format(_projectEndDate!);

    String fullMessage = '$message.\n\n';
    fullMessage += 'Attempted date: $dateStr\n';
    fullMessage += 'Project timeline: $projectStartStr - $projectEndStr\n\n';
    fullMessage +=
        'Would you like to edit the project dates to accommodate this task?';

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_amber_rounded,
                color: Colors.orange.shade600,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Date Outside Project Timeline',
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
              ),
            ],
          ),
          content: Container(
            constraints: BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fullMessage,
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    height: 1.4,
                    color: Colors.grey.shade700,
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                widget.logger.i(
                  '📅 User canceled date selection due to project boundary violation',
                );
              },
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).pop();
                _navigateToEditProjectScreen();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade600,
                foregroundColor: Colors.white,
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              child: Text(
                'Edit Project Dates',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 8,
        );
      },
    );

    widget.logger.w(
      '⚠️ Project date boundary violation: $message for date $dateStr',
    );
  }

  // NEW METHOD: Navigate to edit project screen
  void _navigateToEditProjectScreen() {
    widget.logger.i(
      '📅 Navigating to edit project screen for project: ${widget.project.name}',
    );

    Navigator.of(context)
        .push(
          MaterialPageRoute(
            builder: (context) => EditProjectScreen(
              project: widget.project,
              logger: widget.logger,
            ),
          ),
        )
        .then((_) {
          // Refresh project dates when returning from edit screen
          _loadProjectDates();
          widget.logger.i(
            '📅 Returned from edit project screen, refreshing project dates',
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _projectStartDate == null || _projectEndDate == null) {
      return Center(child: CircularProgressIndicator());
    }

    final totalDays =
        _projectEndDate!.difference(_projectStartDate!).inDays + 1;
    final ganttWidth = totalDays * dayWidth;

    return Column(
      children: [
        _buildToolbar(),
        Expanded(child: _buildUnifiedGanttLayout(ganttWidth)),
      ],
    );
  }

  Widget _buildUnifiedGanttLayout(double ganttWidth) {
    final totalTableWidth =
        _numberColumnWidth +
        _taskColumnWidth +
        _durationColumnWidth +
        _startColumnWidth +
        _finishColumnWidth +
        _resourcesColumnWidth +
        _actualDatesColumnWidth;

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
                  _buildHeaderCell('Resources', _resourcesColumnWidth),
                  _buildHeaderCell('Actual Dates', _actualDatesColumnWidth),
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

  EdgeInsets _getHierarchicalPadding(int index, TaskType taskType) {
    final row = _editedRows[index] ?? _rows[index];
    double leftPadding = 8.0 + (row.hierarchyLevel * 16.0);
    return EdgeInsets.only(left: leftPadding, right: 8, top: 4, bottom: 4);
  }

  Widget _buildRow(int index, double ganttWidth) {
    final row = _editedRows[index] ?? _rows[index];
    final canDelete = row.isUnsaved; // Only show delete button for unsaved rows
    final TaskType currentTaskType = row.taskType;

    return Container(
      height: rowHeight,
      decoration: BoxDecoration(
        color: index % 2 == 0 ? Colors.white : Colors.grey.shade50,
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: _numberColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: canDelete
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${index + 1}',
                          style: GoogleFonts.poppins(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        InkWell(
                          onTap: () => _deleteRow(index),
                          child: Icon(
                            Icons.close,
                            size: 12,
                            color: Colors.red.shade600,
                          ),
                        ),
                      ],
                    )
                  : Center(
                      child: Text(
                        '${index + 1}',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
            ),
          ),
          Container(
            width: _taskColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: GestureDetector(
              onSecondaryTapDown: (details) {
                final RenderBox renderBox =
                    context.findRenderObject() as RenderBox;
                final position = renderBox.localToGlobal(details.localPosition);
                _showContextMenu(context, position, index);
              },
              onLongPress: () {
                final RenderBox renderBox =
                    context.findRenderObject() as RenderBox;
                final position = renderBox.localToGlobal(
                  Offset(_taskColumnWidth / 2, rowHeight / 2),
                );
                _showContextMenu(context, position, index);
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
                    hintStyle: GoogleFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey.shade400,
                    ),
                    border: InputBorder.none,
                    contentPadding: _getHierarchicalPadding(
                      index,
                      currentTaskType,
                    ),
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
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
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
                  hintStyle: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade400,
                  ),
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
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
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: _buildDateCell(
              date: row.startDate,
              onDateSelected: (date) => _updateRowData(index, startDate: date),
              rowData: row, // Pass row data for validation context
            ),
          ),
          Container(
            width: _finishColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: _buildDateCell(
              date: row.endDate,
              onDateSelected: (date) => _updateRowData(index, endDate: date),
              rowData: row, // Pass row data for validation context
            ),
          ),
          Container(
            width: _resourcesColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Container(), // Empty for now
          ),
          Container(
            width: _actualDatesColumnWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: Colors.grey.shade300, width: 0.5),
              ),
            ),
            child: Container(), // Empty for now
          ),
          Container(
            width: ganttWidth,
            height: rowHeight,
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(color: Colors.grey.shade400, width: 1),
              ),
            ),
            child: CustomPaint(
              painter: GanttRowPainter(
                row: row,
                projectStartDate: _projectStartDate!,
                dayWidth: dayWidth,
                rowHeight: rowHeight,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Updated _buildDateCell method with enhanced date picker constraints
  Widget _buildDateCell({
    required DateTime? date,
    required Function(DateTime) onDateSelected,
    GanttRowData? rowData,
  }) {
    return InkWell(
      onTap: () async {
        // Determine date picker bounds based on task type
        DateTime firstDate = _projectStartDate ?? DateTime(2020);
        DateTime lastDate = _projectEndDate ?? DateTime(2030);

        // For main tasks, we still allow selection outside project bounds to trigger validation dialog
        if (rowData != null && rowData.taskType == TaskType.mainTask) {
          firstDate = DateTime(
            2020,
          ); // Allow broader selection to catch violations
          lastDate = DateTime(2030);
        }

        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date ?? _projectStartDate ?? DateTime.now(),
          firstDate: firstDate,
          lastDate: lastDate,
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: ColorScheme.light(
                  primary: Colors.blue.shade600,
                  onPrimary: Colors.white,
                ),
              ),
              child: child!,
            );
          },
        );

        if (selectedDate != null) {
          onDateSelected(selectedDate);
          widget.logger.d(
            'Selected date: $selectedDate for task type: ${rowData?.taskType}',
          );
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
            child: Container(
              constraints: BoxConstraints(maxHeight: 34),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      widget.project.name,
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Flexible(
                    child: Text(
                      _projectStartDate != null && _projectEndDate != null
                          ? '${DateFormat('MMM d, yyyy').format(_projectStartDate!)} - ${DateFormat('MMM d, yyyy').format(_projectEndDate!)}'
                          : 'Failed to load project dates',
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w400,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (_isOfflineMode)
                    Flexible(
                      child: Text(
                        'Offline Mode',
                        style: GoogleFonts.poppins(
                          fontSize: 10,
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (_isOfflineMode)
            Padding(
              padding: EdgeInsets.only(right: 8),
              child: Icon(
                Icons.wifi_off,
                size: 16,
                color: Colors.orange.shade700,
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
    DateTime currentMonth = DateTime(
      _projectStartDate!.year,
      _projectStartDate!.month,
      1,
    );
    final totalDays =
        _projectEndDate!.difference(_projectStartDate!).inDays + 1;
    final ganttWidth = totalDays * dayWidth;

    while (currentMonth.isBefore(_projectEndDate!) ||
        currentMonth.isAtSameMomentAs(_projectEndDate!)) {
      DateTime monthEnd = DateTime(
        currentMonth.year,
        currentMonth.month + 1,
        0,
      );
      if (monthEnd.isAfter(_projectEndDate!)) monthEnd = _projectEndDate!;
      DateTime monthStart = currentMonth.isBefore(_projectStartDate!)
          ? _projectStartDate!
          : currentMonth;
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
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
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
        width: ganttWidth,
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
    final totalDays =
        _projectEndDate!.difference(_projectStartDate!).inDays + 1;
    final dayHeaderStyle = GoogleFonts.poppins(
      fontSize: 8,
      fontWeight: FontWeight.w400,
    );
    final ganttWidth = totalDays * dayWidth;

    for (int i = 0; i < totalDays; i++) {
      DateTime currentDate = _projectStartDate!.add(Duration(days: i));
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
        width: ganttWidth,
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: NeverScrollableScrollPhysics(),
          child: Row(children: dayHeaders),
        ),
      ),
    );
  }

  void _showContextMenu(BuildContext context, Offset position, int rowIndex) {
    _removeOverlay();

    final row = _editedRows[rowIndex] ?? _rows[rowIndex];
    final canDelete = row.isUnsaved;

    _overlayEntry = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: _removeOverlay,
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(child: Container(color: Colors.transparent)),
            Positioned(
              left: position.dx,
              top: position.dy,
              child: TaskContextMenu(
                onMakeMainTask: () => _setTaskType(rowIndex, TaskType.mainTask),
                onMakeSubtask: () => _setTaskType(rowIndex, TaskType.subTask),
                onAddNewRow: () => _addNewRow(insertAfterIndex: rowIndex),
                onDeleteRow: () => _deleteRow(rowIndex),
                onDismiss: _removeOverlay,
                canDelete: canDelete, // Pass the canDelete parameter
              ),
            ),
          ],
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    widget.logger.d(
      '📅 Showing context menu for row $rowIndex at position $position, canDelete: $canDelete',
    );
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    widget.logger.d('📅 Removed context menu overlay');
  }

  // Updated _setTaskType method with orphaned task handling
  void _setTaskType(int index, TaskType taskType) {
    if (!mounted) return;

    setState(() {
      final row = _editedRows[index] ?? GanttRowData.from(_rows[index]);
      _editedRows[index] = row;

      final oldTaskType = row.taskType;
      row.taskType = taskType;

      // If task type changed significantly, recalculate all relationships
      if (oldTaskType != taskType) {
        // Clear existing relationships for this row
        row.parentId = null;
        row.childIds.clear();

        // Also clear any existing parent-child relationships that might be affected
        _clearAffectedRelationships(index, oldTaskType, taskType);

        // Recalculate entire hierarchy
        _calculateHierarchy(); // This now includes _assignParentsToOrphanedTasks()
        _computeColumnWidths();

        widget.logger.i(
          '📅 Task type changed from $oldTaskType to $taskType for row $index - hierarchy recalculated with orphaned task handling',
        );
      }
    });
  }

  // Helper method to clear relationships affected by task type changes
  void _clearAffectedRelationships(
    int changedIndex,
    TaskType oldType,
    TaskType newType,
  ) {
    final changedRow = _editedRows[changedIndex] ?? _rows[changedIndex];

    // If changing from MainTask or SubTask to regular Task, clear all children
    if ((oldType == TaskType.mainTask || oldType == TaskType.subTask) &&
        newType == TaskType.task) {
      for (int i = 0; i < _rows.length; i++) {
        final row = _editedRows[i] ?? _rows[i];
        if (row.parentId == changedRow.id) {
          row.parentId = null;
          row.hierarchyLevel = 0;
          _editedRows[i] = row;
        }
      }
      changedRow.childIds.clear();
    }

    // If changing to MainTask or SubTask, clear existing parent relationship
    if (newType == TaskType.mainTask || newType == TaskType.subTask) {
      if (changedRow.parentId != null) {
        // Remove this row from its current parent's children
        for (int i = 0; i < _rows.length; i++) {
          final potentialParent = _editedRows[i] ?? _rows[i];
          if (potentialParent.id == changedRow.parentId) {
            potentialParent.childIds.remove(changedRow.id);
            _editedRows[i] = potentialParent;
            break;
          }
        }
        changedRow.parentId = null;
      }
    }
  }

  // New method to automatically assign parents to orphaned tasks
  void _assignParentsToOrphanedTasks() {
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];

      // Skip if already has parent or is a MainTask
      if (row.parentId != null || row.taskType == TaskType.mainTask) continue;

      // Find nearest parent by scanning upward
      GanttRowData? nearestParent;
      int parentHierarchyLevel = -1;

      for (int j = i - 1; j >= 0; j--) {
        final candidateParent = _editedRows[j] ?? _rows[j];

        if (candidateParent.taskType == TaskType.mainTask) {
          nearestParent = candidateParent;
          parentHierarchyLevel = candidateParent.hierarchyLevel;
          break;
        } else if (candidateParent.taskType == TaskType.subTask) {
          if (nearestParent == null ||
              candidateParent.hierarchyLevel > parentHierarchyLevel) {
            nearestParent = candidateParent;
            parentHierarchyLevel = candidateParent.hierarchyLevel;
          }
        }
      }

      // Assign parent if found
      if (nearestParent != null) {
        row.parentId = nearestParent.id;
        row.hierarchyLevel = nearestParent.hierarchyLevel + 1;
        _safeAddChildId(nearestParent, row.id);

        // Update in _editedRows
        _editedRows[i] = row;
        for (int k = 0; k < _rows.length; k++) {
          final checkRow = _editedRows[k] ?? _rows[k];
          if (checkRow.id == nearestParent.id) {
            _editedRows[k] = nearestParent;
            break;
          }
        }

        widget.logger.i(
          '📅 Auto-assigned parent "${nearestParent.taskName}" to orphaned task "${row.taskName}"',
        );
      }
    }
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
    final startOffset =
        row.startDate!.difference(projectStartDate).inDays * dayWidth;
    final duration = row.endDate!.difference(row.startDate!).inDays + 1;
    final barWidth = duration * dayWidth;

    // Determine bar height based on task type
    double barHeight;
    switch (row.taskType) {
      case TaskType.mainTask:
      case TaskType.subTask:
        barHeight = rowHeight * 0.15; 
        break;
      case TaskType.task:
        barHeight = rowHeight * 0.6; 
        break;
    }
    
    final barTop = (rowHeight - barHeight) / 2;

    Color barColor;
    Color borderColor;
    switch (row.taskType) {
      case TaskType.mainTask:
        barColor = Colors.grey[600]!;
        borderColor = Colors.black;
        break;
      case TaskType.subTask:
        barColor = Colors.blue.shade600;
        borderColor = Colors.blue.shade800;
        break;
      case TaskType.task:
        barColor = Colors.green.shade600;
        borderColor = Colors.green.shade800;
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

    // Only draw progress indicator for regular tasks (not for slim MainTask/SubTask bars)
    if (row.taskType == TaskType.task) {
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

    final startOffset =
        row.startDate!.difference(projectStartDate).inDays * dayWidth;
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
  final bool canDelete; // Add this parameter

  const TaskContextMenu({
    super.key,
    required this.onMakeMainTask,
    required this.onMakeSubtask,
    required this.onAddNewRow,
    required this.onDeleteRow,
    required this.onDismiss,
    required this.canDelete, // Add this parameter
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
              text: 'Insert Row Below',
              onTap: () {
                onDismiss();
                onAddNewRow();
              },
            ),
            if (canDelete)
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
            Icon(icon, size: 16, color: textColor ?? Colors.grey.shade700),
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