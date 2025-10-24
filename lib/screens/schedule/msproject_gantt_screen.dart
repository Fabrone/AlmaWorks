import 'package:almaworks/models/gantt_row_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/purchase_resource_model.dart';
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
  int? _openDropdownIndex;

  List<PurchaseResourceModel> _resources = [];
  List<GanttRowData> _rows = [];
  static const int defaultRowCount = 6;
  bool _isLoading = true;

  final Map<int, TextEditingController> _quantityControllers = {}; 
  final Map<int, bool> _showQuantityInput = {}; 

  // Temporary storage for edited row data
  final Map<int, GanttRowData> _editedRows = {};

  // Overlay management
  OverlayEntry? _overlayEntry;
  GlobalKey? _activeResourceCellKey;
  OverlayEntry? _resourceDropdownOverlay;

  @override
  void initState() {
    super.initState();
    _initializeRealtimeClock();
    _setupFirebaseListener();
    _loadProjectDates();
    _loadTasksFromFirebase();
    _loadResources();
  }

  @override
  void dispose() {
    _firebaseListener?.cancel();
    _removeOverlay();
    _removeResourceDropdown();
    _horizontalScrollController.dispose();
    _verticalScrollController.dispose();
    for (final controller in _quantityControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _removeResourceDropdown() {
    _resourceDropdownOverlay?.remove();
    _resourceDropdownOverlay = null;
    _activeResourceCellKey = null;
    widget.logger.d('📅 Removed resource dropdown overlay');
  }

  void _toggleResourceDropdown(int index, BuildContext context, GlobalKey cellKey) {
    final row = _editedRows[index] ?? _rows[index];
    
    if (_openDropdownIndex == index) {
      // Close if already open
      setState(() {
        _openDropdownIndex = null;
      });
      _removeResourceDropdown();
    } else {
      // Close any existing dropdown first
      _removeResourceDropdown();
      
      // Capture the overlay before async gap
      final overlay = Overlay.of(context);
      
      // Small delay to ensure previous dropdown is fully removed
      Future.delayed(Duration(milliseconds: 50), () {
        if (!mounted) return;
        
        setState(() {
          _openDropdownIndex = index;
        });
        
        // Pass the overlay instead of context
        _showResourceDropdownWithOverlay(overlay, cellKey, row, index);
      });
    }
    
    widget.logger.d('📅 Toggled resource dropdown for row $index');
  }

  void _showResourceDropdownWithOverlay(OverlayState overlay, GlobalKey cellKey, GanttRowData row, int index) {
    _removeResourceDropdown();

    if (_activeResourceCellKey != null) {
      widget.logger.d('📅 Closing previous dropdown before opening new one');
    }

    final RenderBox? renderBox = cellKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final RenderBox overlayRenderBox = overlay.context.findRenderObject() as RenderBox;
    final RelativeRect position = RelativeRect.fromRect(
      Rect.fromPoints(
        renderBox.localToGlobal(Offset.zero, ancestor: overlayRenderBox),
        renderBox.localToGlobal(renderBox.size.bottomRight(Offset.zero), ancestor: overlayRenderBox),
      ),
      Offset.zero & overlayRenderBox.size,
    );

    _activeResourceCellKey = cellKey;

    // Initialize quantity controller if not exists
    if (!_quantityControllers.containsKey(index)) {
      _quantityControllers[index] = TextEditingController(
        text: row.resourceQuantity ?? '',
      );
    }

    // Initialize quantity input visibility
    if (!_showQuantityInput.containsKey(index)) {
      _showQuantityInput[index] = row.resourceId != null && (row.resourceQuantity?.isNotEmpty ?? false);
    }

    // Calculate optimal positioning
    final dropdownConstraints = _calculateDropdownConstraints(position, overlayRenderBox.size);

    _resourceDropdownOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () {
          setState(() {
            _openDropdownIndex = null;
            _showQuantityInput[index] = false;
          });
          _removeResourceDropdown();
        },
        behavior: HitTestBehavior.translucent,
        child: Stack(
          children: [
            Positioned.fill(
              child: Container(color: Colors.transparent),
            ),
            Positioned(
              left: dropdownConstraints['left'],
              top: dropdownConstraints['top'],
              right: dropdownConstraints['right'],
              child: GestureDetector(
                onTap: () {},
                child: Material(
                  elevation: 8,
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: dropdownConstraints['width'],
                    constraints: BoxConstraints(
                      maxHeight: dropdownConstraints['maxHeight']!,
                      minWidth: 280,
                      maxWidth: 400,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Search bar
                        Container(
                          padding: EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey.shade200, width: 1),
                            ),
                          ),
                          child: TextField(
                            decoration: InputDecoration(
                              hintText: 'Search resources...',
                              hintStyle: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey.shade400,
                              ),
                              prefixIcon: Icon(Icons.search, size: 18, color: Colors.grey.shade500),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(6),
                                borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                              ),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              isDense: true,
                            ),
                            style: GoogleFonts.poppins(fontSize: 12),
                            onChanged: (value) {
                              setState(() {});
                            },
                          ),
                        ),
                        // "None" option
                        InkWell(
                          onTap: () {
                            setState(() {
                              row.resourceId = null;
                              row.resourceQuantity = null;
                              _editedRows[index] = row;
                              _openDropdownIndex = null;
                              _showQuantityInput[index] = false;
                              _quantityControllers[index]?.clear();
                              _computeColumnWidths();
                            });
                            _removeResourceDropdown();
                            _showSuccessSnackbar('Resource cleared');
                          },
                          child: Container(
                            width: double.infinity,
                            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            decoration: BoxDecoration(
                              color: row.resourceId == null
                                  ? Colors.blue.shade50
                                  : Colors.transparent,
                              border: Border(
                                bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 20,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: row.resourceId == null
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade400,
                                      width: 2,
                                    ),
                                    color: row.resourceId == null
                                        ? Colors.blue.shade600
                                        : Colors.transparent,
                                  ),
                                  child: row.resourceId == null
                                      ? Icon(Icons.check, size: 14, color: Colors.white)
                                      : null,
                                ),
                                SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'None',
                                    style: GoogleFonts.poppins(
                                      fontSize: 13,
                                      fontWeight: row.resourceId == null
                                          ? FontWeight.w600
                                          : FontWeight.w400,
                                      color: row.resourceId == null
                                          ? Colors.blue.shade600
                                          : Colors.grey.shade700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Resource list with quantity input
                        Flexible(
                          child: _resources.isEmpty
                              ? _buildEmptyResourceState()
                              : StatefulBuilder(
                                  builder: (context, setDropdownState) {
                                    return ListView.builder(
                                      shrinkWrap: true,
                                      padding: EdgeInsets.zero,
                                      itemCount: _resources.length,
                                      itemBuilder: (context, resIndex) {
                                        final resource = _resources[resIndex];
                                        final isSelected = row.resourceId == resource.id;

                                        return _buildResourceItem(
                                          resource: resource,
                                          isSelected: isSelected,
                                          row: row,
                                          index: index,
                                          setDropdownState: setDropdownState,
                                        );
                                      },
                                    );
                                  },
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    overlay.insert(_resourceDropdownOverlay!);
    widget.logger.d('📅 Showing enhanced resource dropdown for row $index with optimal positioning');
  }

  // NEW METHOD: Calculate optimal dropdown positioning
  Map<String, double?> _calculateDropdownConstraints(RelativeRect position, Size overlaySize) {
    const double dropdownMinWidth = 280.0;
    const double dropdownMaxWidth = 400.0;
    const double dropdownMaxHeight = 350.0;
    const double dropdownMinHeight = 200.0;
    const double padding = 16.0; // Padding from screen edges

    double cellLeft = position.left;
    double cellTop = position.top;
    double cellBottom = position.bottom;
    double cellRight = position.right;
    double cellWidth = overlaySize.width - cellLeft - cellRight;
    double cellHeight = overlaySize.height - cellTop - cellBottom;

    // Calculate available space below and above the cell
    double spaceBelow = overlaySize.height - cellTop - cellHeight - padding;
    double spaceAbove = cellTop - padding;
    
    // Calculate available space on left and right
    double spaceRight = overlaySize.width - cellLeft - padding;
    double spaceLeft = cellLeft - padding;

    // Determine dropdown width (prefer cell width but respect min/max)
    double dropdownWidth = math.max(dropdownMinWidth, math.min(cellWidth, dropdownMaxWidth));
    
    // Adjust width if it exceeds available space
    if (cellLeft + dropdownWidth + padding > overlaySize.width) {
      dropdownWidth = spaceRight;
    }

    // Determine vertical position (prefer below, but show above if more space)
    double? top;
    double? bottom;
    double maxHeight = dropdownMaxHeight;

    if (spaceBelow >= dropdownMinHeight || spaceBelow >= spaceAbove) {
      // Position below the cell
      top = cellTop + cellHeight;
      maxHeight = math.min(dropdownMaxHeight, spaceBelow);
    } else {
      // Position above the cell
      bottom = overlaySize.height - cellTop;
      maxHeight = math.min(dropdownMaxHeight, spaceAbove);
    }

    // Determine horizontal position
    double? left;
    double? right;

    if (cellLeft + dropdownWidth + padding <= overlaySize.width) {
      // Align with left edge of cell
      left = cellLeft;
    } else if (spaceLeft >= dropdownMinWidth) {
      // Align with right edge of cell
      right = cellRight;
    } else {
      // Center on screen if cell is near edge
      left = math.max(padding, (overlaySize.width - dropdownWidth) / 2);
    }

    return {
      'left': left,
      'right': right,
      'top': top,
      'bottom': bottom,
      'width': dropdownWidth,
      'maxHeight': maxHeight,
    };
  }

  Future<void> _loadResources() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('PurchaseplanResources')
          .where('projectId', isEqualTo: widget.project.id)
          .get();
      if (mounted) {
        setState(() {
          _resources = snapshot.docs.map((doc) {
            final data = doc.data();
            return PurchaseResourceModel.fromFirebaseMap(doc.id, data);
          }).toList();
        });
        widget.logger.i(
          '🛒 Loaded ${_resources.length} resources for Gantt screen',
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e(
        '❌ Error loading resources for Gantt screen',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  String _getResourceDisplayText(GanttRowData row) {
    if (row.resourceId == null) return '';
    final resource = _resources.firstWhere(
      (res) => res.id == row.resourceId,
      orElse: () => PurchaseResourceModel(
        id: '',
        name: 'Unknown Resource',
        type: ResourceType.other,
        quantity: '',
        status: '',
        projectId: '',
        projectName: '',
        updatedAt: DateTime.now(),
      ),
    );
    
    String displayText = resource.name;
    if (row.resourceQuantity != null && row.resourceQuantity!.isNotEmpty) {
      displayText += ' (${row.resourceQuantity})';
    }
    return displayText;
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

  void _showSuccessSnackbar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  message,
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.green.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          duration: Duration(seconds: 2),
        ),
      );
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

  void _initializeRealtimeClock() {
    Timer.periodic(Duration(minutes: 1), (timer) {
      if (mounted) {
        setState(() {
          // Refresh UI to ensure date display is current, including current date indicator
          widget.logger.d('🔄 Realtime clock tick, refreshing UI for current date indicator');
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
    String dateType, {
    bool isActual = false,
  }) {
    final dateStr = DateFormat('MM/dd/yyyy').format(attemptedDate);
    final parentStartStr = parentRow.startDate != null 
        ? DateFormat('MM/dd/yyyy').format(parentRow.startDate!) 
        : 'Not set';
    final parentEndStr = parentRow.endDate != null 
        ? DateFormat('MM/dd/yyyy').format(parentRow.endDate!) 
        : 'Not set';

    String adjustedMessage = isActual ? message.replaceAll('selected', 'selected actual') : message;
    String fullMessage = '$adjustedMessage.\n\n';
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
                  isActual: isActual,
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

  void _adjustParentTaskDates(
    GanttRowData parentRow,
    GanttRowData childRow,
    int childIndex,
    DateTime attemptedDate,
    String dateType, {
    bool isActual = false,
  }) async {
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
            isActual: isActual,
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
        if (isActual) {
          childRow.actualStartDate = attemptedDate;
        } else {
          childRow.startDate = attemptedDate;
        }
      } else if (dateType == 'end' || dateType == 'calculated_end') {
        if (isActual) {
          childRow.actualEndDate = attemptedDate;
        } else {
          childRow.endDate = attemptedDate;
        }
      }

      // Ensure child row is in edited rows
      _editedRows[childIndex] = childRow;

      // CRITICAL FIX: Perform complete recalculation for the child row immediately if not actual
      if (!isActual) {
        _performImmediateRecalculation(childRow, childIndex);
      }
    });

    // Check if parent needs further adjustment (e.g., its own parent)
    _updateParentDatesIfNeeded(parentRow, _getRowIndex(parentRow.id));

    widget.logger.i(
      '✅ Successfully adjusted parent task dates and applied child task change${isActual ? ' (actual dates)' : ''} with${isActual ? 'out' : ''} recalculation',
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

    // Existing number column calculation
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

    // Existing task column calculation
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

    // Existing duration column calculation
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

    // Existing start column calculation
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

    // Existing finish column calculation
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

    // Existing resources column calculation
    headerWidth = _measureText('Resources', headerStyle) + 24;
    maxCellWidth = 0;
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      String text = _getResourceDisplayText(row);
      double w = _measureText(text, cellStyle);
      if (w > maxCellWidth) maxCellWidth = w;
    }
    maxCellWidth += 32;
    _resourcesColumnWidth = math.max(headerWidth, maxCellWidth);

    // Compute for Actual Dates column
    headerWidth = _measureText('Actual Dates', headerStyle) + 24;
    maxCellWidth = 0;
    for (int i = 0; i < _rows.length; i++) {
      final row = _editedRows[i] ?? _rows[i];
      if (row.canHaveActualDates) {
        String text = row.actualDatesDisplayText.isNotEmpty 
            ? row.actualDatesDisplayText 
            : 'Add dates';
        double w = _measureText(text, cellStyle);
        if (w > maxCellWidth) maxCellWidth = w;
      }
    }
    maxCellWidth += 32;
    _actualDatesColumnWidth = math.max(headerWidth, maxCellWidth);

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

  void _showProjectDateViolationDialog(
    String message,
    String boundaryType,
    DateTime attemptedDate, {
    bool isActual = false,
  }) {
    final dateStr = DateFormat('MM/dd/yyyy').format(attemptedDate);
    final projectStartStr = DateFormat('MM/dd/yyyy').format(_projectStartDate!);
    final projectEndStr = DateFormat('MM/dd/yyyy').format(_projectEndDate!);

    String adjustedMessage = isActual ? message.replaceAll('date', 'actual date') : message;

    String fullMessage = '$adjustedMessage.\n\n';
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

  Widget _buildResourceItem({
    required PurchaseResourceModel resource,
    required bool isSelected,
    required GanttRowData row,
    required int index,
    required StateSetter setDropdownState,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: () {
            setState(() {
              row.resourceId = resource.id;
              _editedRows[index] = row;
              _showQuantityInput[index] = true;
              _openDropdownIndex = index;
              _computeColumnWidths();
            });
            setDropdownState(() {});
            widget.logger.d('📅 Selected resource: ${resource.name}');
          },
          child: Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.blue.shade50 : Colors.transparent,
              border: Border(
                bottom: BorderSide(
                  color: Colors.grey.shade200,
                  width: (_showQuantityInput[index] == true && isSelected) ? 0 : 0.5,
                ),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.blue.shade600 : Colors.grey.shade400,
                      width: 2,
                    ),
                    color: isSelected ? Colors.blue.shade600 : Colors.transparent,
                  ),
                  child: isSelected
                      ? Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        resource.name,
                        style: GoogleFonts.poppins(
                          fontSize: 13,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                          color: isSelected ? Colors.blue.shade600 : Colors.grey.shade800,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (resource.type != ResourceType.other)
                        Text(
                          _getResourceTypeLabel(resource.type),
                          style: GoogleFonts.poppins(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                          ),
                        ),
                    ],
                  ),
                ),
                if (isSelected)
                  Icon(
                    Icons.keyboard_arrow_down,
                    size: 18,
                    color: Colors.blue.shade600,
                  ),
              ],
            ),
          ),
        ),
        // Quantity input section (expandable)
        if (isSelected && (_showQuantityInput[index] == true))
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(12, 8, 12, 12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade200, width: 0.5),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Quantity (optional)',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _quantityControllers[index],
                        decoration: InputDecoration(
                          hintText: 'e.g., 5, 10kg, 2 hours',
                          hintStyle: GoogleFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey.shade400,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(6),
                            borderSide: BorderSide(color: Colors.blue.shade400, width: 2),
                          ),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          isDense: true,
                          suffixIcon: _quantityControllers[index]?.text.isNotEmpty == true
                              ? IconButton(
                                  icon: Icon(Icons.clear, size: 16),
                                  onPressed: () {
                                    _quantityControllers[index]?.clear();
                                    setDropdownState(() {});
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                )
                              : null,
                        ),
                        style: GoogleFonts.poppins(fontSize: 12),
                        onChanged: (value) {
                          setDropdownState(() {});
                        },
                      ),
                    ),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          row.resourceQuantity = _quantityControllers[index]?.text.trim();
                          if (row.resourceQuantity?.isEmpty ?? true) {
                            row.resourceQuantity = null;
                          }
                          _editedRows[index] = row;
                          _openDropdownIndex = null;
                          _showQuantityInput[index] = false;
                          _computeColumnWidths();
                        });
                        _removeResourceDropdown();
                        _showSuccessSnackbar(
                          row.resourceQuantity != null
                              ? 'Resource assigned: ${resource.name} (${row.resourceQuantity})'
                              : 'Resource assigned: ${resource.name}',
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue.shade600,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: Text(
                        'Apply',
                        style: GoogleFonts.poppins(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildEmptyResourceState() {
    return Container(
      padding: EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 48,
            color: Colors.grey.shade300,
          ),
          SizedBox(height: 12),
          Text(
            'No resources available',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade600,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Add resources to your project first',
            style: GoogleFonts.poppins(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  String _getResourceTypeLabel(ResourceType type) {
    switch (type) {
      case ResourceType.material:
        return 'Material';
      case ResourceType.equipment:
        return 'Equipment';
      case ResourceType.labor:
        return 'Labor';
      case ResourceType.other:
        return 'Other';
    }
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
    final canDelete = row.isUnsaved;
    final TaskType currentTaskType = row.taskType;
    final isDropdownOpen = _openDropdownIndex == index;
    
    // Create a GlobalKey for the Resources cell
    final resourceCellKey = GlobalKey();

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
          // Number column
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
          // Task Name column
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
          // Duration column
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
          // Start date column
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
              rowData: row,
            ),
          ),
          // Finish date column
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
              rowData: row,
            ),
          ),
          // Resources column
          GestureDetector(
            key: resourceCellKey,
            onTap: () {
              if (row.taskType == TaskType.task) {
                _toggleResourceDropdown(index, context, resourceCellKey);
              }
            },
            child: Container(
              width: _resourcesColumnWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
                color: row.taskType == TaskType.task 
                    ? (isDropdownOpen ? Colors.blue.shade50 : Colors.transparent)
                    : Colors.grey.shade100,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (row.resourceId != null && row.taskType == TaskType.task)
                      Container(
                        width: 6,
                        height: 6,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.shade600,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        _getResourceDisplayText(row),
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: row.resourceId != null ? FontWeight.w500 : FontWeight.w400,
                          color: row.taskType == TaskType.task
                              ? (row.resourceId != null ? Colors.grey.shade800 : Colors.grey.shade500)
                              : Colors.grey.shade400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (row.taskType == TaskType.task)
                      Icon(
                        isDropdownOpen ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                        size: 18,
                        color: row.resourceId != null ? Colors.blue.shade600 : Colors.grey.shade500,
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Actual Dates column
          GestureDetector(
            onTap: row.taskType == TaskType.task
                ? () => _showActualDatesDialog(index)
                : null,
            child: Container(
              width: _actualDatesColumnWidth,
              height: rowHeight,
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(color: Colors.grey.shade300, width: 0.5),
                ),
                color: row.taskType == TaskType.task
                    ? Colors.transparent
                    : Colors.grey.shade100,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Row(
                  children: [
                    if (row.actualStartDate != null || row.actualEndDate != null)
                      Container(
                        width: 6,
                        height: 6,
                        margin: EdgeInsets.only(right: 6),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _getActualDatesStatusColor(row),
                        ),
                      ),
                    Expanded(
                      child: Text(
                        row.taskType == TaskType.task
                            ? (row.actualDatesDisplayText.isNotEmpty
                                ? row.actualDatesDisplayText
                                : 'Add dates')
                            : '',
                        style: GoogleFonts.poppins(
                          fontSize: 11,
                          fontWeight: (row.actualStartDate != null || row.actualEndDate != null)
                              ? FontWeight.w500
                              : FontWeight.w400,
                          color: row.taskType == TaskType.task
                              ? ((row.actualStartDate != null || row.actualEndDate != null)
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade500)
                              : Colors.grey.shade400,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (row.taskType == TaskType.task)
                      Icon(
                        Icons.calendar_today,
                        size: 14,
                        color: (row.actualStartDate != null || row.actualEndDate != null)
                            ? Colors.blue.shade600
                            : Colors.grey.shade400,
                      ),
                  ],
                ),
              ),
            ),
          ),
          // Gantt chart area
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

  Color _getActualDatesStatusColor(GanttRowData row) {
    // Both dates present
    if (row.actualStartDate != null && row.actualEndDate != null) {
      return Colors.green.shade600;
    }
    // Only one date present
    else if (row.actualStartDate != null || row.actualEndDate != null) {
      return Colors.orange.shade600;
    }
    // No dates
    return Colors.grey.shade400;
  }

  void _showActualDatesDialog(int index) {
    final row = _editedRows[index] ?? _rows[index];
    
    // Determine dialog state based on existing data
    bool hasActualStart = row.actualStartDate != null;
    bool hasActualEnd = row.actualEndDate != null;
    
    String dialogTitle;
    List<String> options;
    
    if (!hasActualStart && !hasActualEnd) {
      // No dates saved
      dialogTitle = 'Add Actual Dates';
      options = ['Actual Start Date', 'Actual Finish Date'];
    } else if (hasActualStart && !hasActualEnd) {
      // Only start date saved
      dialogTitle = 'Manage Actual Dates';
      options = ['Edit Actual Start Date', 'Add Actual Finish Date'];
    } else if (!hasActualStart && hasActualEnd) {
      // Only finish date saved
      dialogTitle = 'Manage Actual Dates';
      options = ['Add Actual Start Date', 'Edit Actual Finish Date'];
    } else {
      // Both dates saved
      dialogTitle = 'Edit Actual Dates';
      options = ['Edit Actual Start Date', 'Edit Actual Finish Date'];
    }

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.event_available,
                color: Colors.blue.shade600,
                size: 24,
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  dialogTitle,
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
            constraints: BoxConstraints(maxWidth: 350),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Task: ${row.taskName ?? "Unnamed Task"}',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade700,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Scheduled: ${row.startDate != null ? DateFormat('MM/dd/yyyy').format(row.startDate!) : "N/A"} - ${row.endDate != null ? DateFormat('MM/dd/yyyy').format(row.endDate!) : "N/A"}',
                  style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: Colors.grey.shade500,
                  ),
                ),
                if (hasActualStart || hasActualEnd) ...[
                  SizedBox(height: 4),
                  Text(
                    'Current Actual: ${row.actualDatesDisplayText}',
                    style: GoogleFonts.poppins(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: Colors.blue.shade600,
                    ),
                  ),
                ],
                SizedBox(height: 20),
                Text(
                  'Select action:',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey.shade600,
                  ),
                ),
                SizedBox(height: 12),
                ...options.map((option) => _buildDialogOption(
                  option: option,
                  onTap: () {
                    Navigator.of(context).pop();
                    _handleActualDateSelection(index, option, row);
                  },
                )),
                if (hasActualStart || hasActualEnd) ...[
                  SizedBox(height: 12),
                  Divider(height: 1, color: Colors.grey.shade300),
                  SizedBox(height: 12),
                  _buildDialogOption(
                    option: 'Clear All Actual Dates',
                    onTap: () {
                      Navigator.of(context).pop();
                      _clearActualDates(index);
                    },
                    isDestructive: true,
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade600,
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

    widget.logger.d(
      '📅 Showing actual dates dialog for row $index - hasStart: $hasActualStart, hasEnd: $hasActualEnd',
    );
  }

  Widget _buildDialogOption({
    required String option,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    IconData icon;
    if (option.contains('Start')) {
      icon = Icons.play_arrow;
    } else if (option.contains('Finish')) {
      icon = Icons.stop;
    } else {
      icon = Icons.delete_outline;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isDestructive ? Colors.red.shade200 : Colors.grey.shade300,
            width: 1,
          ),
          borderRadius: BorderRadius.circular(8),
          color: isDestructive ? Colors.red.shade50 : Colors.grey.shade50,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isDestructive ? Colors.red.shade600 : Colors.blue.shade600,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                option,
                style: GoogleFonts.poppins(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: isDestructive ? Colors.red.shade700 : Colors.grey.shade800,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 14,
              color: isDestructive ? Colors.red.shade400 : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  void _handleActualDateSelection(int index, String option, GanttRowData row) {
    widget.logger.d('📅 User selected: $option for row $index');

    if (option.contains('Start')) {
      _selectActualStartDate(index, row, isEdit: option.contains('Edit'));
    } else if (option.contains('Finish')) {
      _selectActualFinishDate(index, row, isEdit: option.contains('Edit'));
    }
  }

  Future<void> _selectActualStartDate(int index, GanttRowData row, {required bool isEdit}) async {
    // Set broad range for picker to allow selections outside current bounds
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime(2030);
    
    // Do not tighten to scheduled dates (loosened as per requirement)
    // Still apply parent if exists, but only as initial, since post-validation will handle violations
    final parentRow = _getParentRow(row);
    if (parentRow != null) {
      if (parentRow.startDate != null) {
        firstDate = parentRow.startDate!;
      }
      if (parentRow.endDate != null) {
        lastDate = parentRow.endDate!;
      }
    }

    // Apply project bounds as soft (picker uses parent, but broad if no)
    if (_projectStartDate != null) {
      firstDate = _projectStartDate!;
    }
    if (_projectEndDate != null) {
      lastDate = _projectEndDate!;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: isEdit && row.actualStartDate != null
          ? row.actualStartDate!
          : (row.startDate ?? DateTime.now()),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isEdit ? 'Edit Actual Start Date' : 'Add Actual Start Date',
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
      // 1. Internal consistency validation
      if (row.actualEndDate != null && selectedDate.isAfter(row.actualEndDate!)) {
        _showActualDateViolationDialog(
          'Actual start date cannot be after actual finish date',
          selectedDate,
          row.actualEndDate!,
          'start_after_end',
          index,
          allowOverride: false,
        );
        return;
      }

      // 2. Project bounds validation
      if (_projectStartDate != null && selectedDate.isBefore(_projectStartDate!)) {
        _showProjectDateViolationDialog(
          'The selected actual start date is before the project start date',
          'start',
          selectedDate,
        );
        return;
      }
      if (_projectEndDate != null && selectedDate.isAfter(_projectEndDate!)) {
        _showProjectDateViolationDialog(
          'The selected actual start date is after the project end date',
          'end',
          selectedDate,
        );
        return;
      }

      // 3. Parent bounds validation
      if (parentRow != null) {
        if (parentRow.startDate != null && selectedDate.isBefore(parentRow.startDate!)) {
          _showParentTaskDateViolationDialog(
            'Your selected actual start date is before the parent task start date',
            'start',
            selectedDate,
            parentRow,
            row,
            index,
            'start',
            isActual: true,
          );
          return;
        }
        if (parentRow.endDate != null && selectedDate.isAfter(parentRow.endDate!)) {
          _showParentTaskDateViolationDialog(
            'Your selected actual start date is after the parent task end date',
            'end',
            selectedDate,
            parentRow,
            row,
            index,
            'start',
            isActual: true,
          );
          return;
        }
      }

      // 4. Scheduled variance warning (allow override)
      if (row.startDate != null && selectedDate.isBefore(row.startDate!)) {
        _showActualDateViolationDialog(
          'Actual start date is before the scheduled start date',
          selectedDate,
          row.startDate!,
          'before_scheduled_start',
          index,
          allowOverride: true,
          onOverride: () => _applyActualStartDate(index, selectedDate),
        );
        return;
      }

      // If all validations pass, apply the date
      _applyActualStartDate(index, selectedDate);
    }
  }

  Future<void> _selectActualFinishDate(int index, GanttRowData row, {required bool isEdit}) async {
    // Set broad range for picker to allow selections outside current bounds
    DateTime firstDate = DateTime(2020);
    DateTime lastDate = DateTime(2030);
    
    // Still apply parent if exists, but only as initial, since post-validation will handle violations
    final parentRow = _getParentRow(row);
    if (parentRow != null) {
      if (parentRow.startDate != null) {
        firstDate = parentRow.startDate!;
      }
      if (parentRow.endDate != null) {
        lastDate = parentRow.endDate!;
      }
    }

    // Apply project bounds as soft
    if (_projectStartDate != null) {
      firstDate = _projectStartDate!;
    }
    if (_projectEndDate != null) {
      lastDate = _projectEndDate!;
    }

    final selectedDate = await showDatePicker(
      context: context,
      initialDate: isEdit && row.actualEndDate != null
          ? row.actualEndDate!
          : (row.endDate ?? DateTime.now()),
      firstDate: firstDate,
      lastDate: lastDate,
      helpText: isEdit ? 'Edit Actual Finish Date' : 'Add Actual Finish Date',
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
      // 1. Internal consistency validation
      if (row.actualStartDate != null && selectedDate.isBefore(row.actualStartDate!)) {
        _showActualDateViolationDialog(
          'Actual finish date cannot be before actual start date',
          selectedDate,
          row.actualStartDate!,
          'end_before_start',
          index,
          allowOverride: false,
        );
        return;
      }

      // 2. Project bounds validation
      if (_projectStartDate != null && selectedDate.isBefore(_projectStartDate!)) {
        _showProjectDateViolationDialog(
          'The selected actual finish date is before the project start date',
          'start',
          selectedDate,
        );
        return;
      }
      if (_projectEndDate != null && selectedDate.isAfter(_projectEndDate!)) {
        _showProjectDateViolationDialog(
          'The selected actual finish date is after the project end date',
          'end',
          selectedDate,
        );
        return;
      }

      // 3. Parent bounds validation
      if (parentRow != null) {
        if (parentRow.startDate != null && selectedDate.isBefore(parentRow.startDate!)) {
          _showParentTaskDateViolationDialog(
            'Your selected actual finish date is before the parent task start date',
            'start',
            selectedDate,
            parentRow,
            row,
            index,
            'end',
            isActual: true,
          );
          return;
        }
        if (parentRow.endDate != null && selectedDate.isAfter(parentRow.endDate!)) {
          _showParentTaskDateViolationDialog(
            'Your selected actual finish date is after the parent task end date',
            'end',
            selectedDate,
            parentRow,
            row,
            index,
            'end',
            isActual: true,
          );
          return;
        }
      }

      // 4. Scheduled variance warning (allow override)
      if (row.endDate != null && selectedDate.isAfter(row.endDate!)) {
        _showActualDateViolationDialog(
          'Actual finish date is after the scheduled finish date',
          selectedDate,
          row.endDate!,
          'after_scheduled_end',
          index,
          allowOverride: true,
          onOverride: () => _applyActualFinishDate(index, selectedDate),
        );
        return;
      }

      // If all validations pass, apply the date
      _applyActualFinishDate(index, selectedDate);
    }
  }

  void _applyActualStartDate(int index, DateTime date) {
    setState(() {
      final row = _editedRows[index] ?? GanttRowData.from(_rows[index]);
      row.actualStartDate = date;
      _editedRows[index] = row;
      _computeColumnWidths();
    });

    widget.logger.i(
      '✅ Applied actual start date: ${DateFormat('MM/dd/yyyy').format(date)} to row $index',
    );

    if (mounted) {
      _showSuccessSnackbar('Actual start date set to ${DateFormat('MM/dd/yyyy').format(date)}');
    }
  }

  void _applyActualFinishDate(int index, DateTime date) {
    setState(() {
      final row = _editedRows[index] ?? GanttRowData.from(_rows[index]);
      row.actualEndDate = date;
      _editedRows[index] = row;
      _computeColumnWidths();
    });

    widget.logger.i(
      '✅ Applied actual finish date: ${DateFormat('MM/dd/yyyy').format(date)} to row $index',
    );

    if (mounted) {
      _showSuccessSnackbar('Actual finish date set to ${DateFormat('MM/dd/yyyy').format(date)}');
    }
  }

  void _clearActualDates(int index) {
    setState(() {
      final row = _editedRows[index] ?? GanttRowData.from(_rows[index]);
      row.actualStartDate = null;
      row.actualEndDate = null;
      _editedRows[index] = row;
      _computeColumnWidths();
    });

    widget.logger.i(
      '🗑️ Cleared actual dates for row $index',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.white, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Actual dates cleared',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: Colors.blue.shade600,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  void _showActualDateViolationDialog(
    String message,
    DateTime attemptedDate,
    DateTime boundaryDate,
    String violationType,
    int index, {
    bool allowOverride = false,
    VoidCallback? onOverride,
  }) {
    final attemptedStr = DateFormat('MM/dd/yyyy').format(attemptedDate);
    final boundaryStr = DateFormat('MM/dd/yyyy').format(boundaryDate);

    String fullMessage = '$message.\n\n';
    fullMessage += 'Attempted date: $attemptedStr\n';
    fullMessage += 'Boundary date: $boundaryStr\n';

    if (allowOverride) {
      fullMessage += '\nThis may indicate a schedule variance. Continue anyway?';
    }

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
                  'Actual Date Constraint',
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
                  '📅 User canceled actual date selection due to violation: $violationType',
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
            if (allowOverride)
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  onOverride?.call();
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
                  'Continue Anyway',
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
      '⚠️ Actual date violation: $message for date $attemptedStr (type: $violationType)',
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

    // NEW: Draw actual dates bar if data present
    if (row.canHaveActualDates && (row.actualStartDate != null || row.actualEndDate != null)) {
      _drawActualGanttBar(canvas, size);
    }

    // NEW: Draw current date indicator
    _drawCurrentDateIndicator(canvas, size);
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

  // NEW METHOD: Draw actual dates bar with overlap handling
  void _drawActualGanttBar(Canvas canvas, Size size) {
    // Use scheduled dates as fallback if actual start/end missing
    final actualStart = row.actualStartDate ?? row.startDate!;
    final actualEnd = row.actualEndDate ?? row.endDate!;
    final scheduledStartOffset = row.startDate!.difference(projectStartDate).inDays * dayWidth;
    final scheduledEndOffset = row.endDate!.difference(projectStartDate).inDays * dayWidth + dayWidth; // End of last day
    
    final actualStartOffset = actualStart.difference(projectStartDate).inDays * dayWidth;
    final actualDuration = actualEnd.difference(actualStart).inDays + 1;
    final actualBarWidth = actualDuration * dayWidth;
    final actualEndOffset = actualStartOffset + actualBarWidth;

    // Only proceed if valid range
    if (actualStart.isAfter(actualEnd)) return;

    // Bar styling (light tint of scheduled color for tasks: green.shade100)
    final barHeight = rowHeight * 0.6;
    final barTop = (rowHeight - barHeight) / 2;
    final lightColor = Colors.green.shade100; // Light tint
    final darkColor = Colors.green.shade800;  // Dark shade for overlap
    final dottedBorderPaint = Paint()
      ..color = Colors.green.shade800
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;

    // Calculate segments
    // 1. Pre-scheduled extension (if actual start < scheduled start)
    if (actualStartOffset < scheduledStartOffset) {
      final preWidth = scheduledStartOffset - actualStartOffset;
      final preRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(actualStartOffset + 2, barTop, preWidth - 4, barHeight),
        Radius.circular(2),
      );
      final prePaint = Paint()..color = lightColor..style = PaintingStyle.fill;
      canvas.drawRRect(preRect, prePaint);
      _drawDashedRRect(canvas, preRect, dottedBorderPaint, [2, 2]);
    }

    // 2. Overlap section (max(actualStart, scheduledStart) to min(actualEnd, scheduledEnd))
    final overlapStart = math.max(actualStartOffset, scheduledStartOffset);
    final overlapEnd = math.min(actualEndOffset, scheduledEndOffset);
    if (overlapStart < overlapEnd) {
      final overlapWidth = overlapEnd - overlapStart;
      final overlapRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(overlapStart + 2, barTop, overlapWidth - 4, barHeight),
        Radius.circular(2),
      );
      final overlapPaint = Paint()..color = darkColor..style = PaintingStyle.fill;
      canvas.drawRRect(overlapRect, overlapPaint);
      _drawDashedRRect(canvas, overlapRect, dottedBorderPaint, [2, 2]);
    }

    // 3. Post-scheduled extension (if actual end > scheduled end, non-overlap parts)
    if (actualEndOffset > scheduledEndOffset) {
      final postWidth = actualEndOffset - scheduledEndOffset;
      final postRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(scheduledEndOffset + 2, barTop, postWidth - 4, barHeight),
        Radius.circular(2),
      );
      final postPaint = Paint()..color = lightColor..style = PaintingStyle.fill;
      canvas.drawRRect(postRect, postPaint);
      _drawDashedRRect(canvas, postRect, dottedBorderPaint, [2, 2]);
    }

    // 4. Non-overlapping actual in middle (if actual fully within scheduled, but since overlap is dark, and non-overlap light - but in this case, all is overlap)
    // Handled above as overlap is dark, extensions are light
  }

  // NEW HELPER METHOD: Draw dashed rounded rectangle
  void _drawDashedRRect(Canvas canvas, RRect rrect, Paint paint, List<double> dashPattern) {
    final path = Path()..addRRect(rrect);
    final dashWidth = dashPattern[0];
    final dashSpace = dashPattern[1];
    final metrics = path.computeMetrics();
    for (final metric in metrics) {
      double distance = 0.0;
      while (distance < metric.length) {
        final end = distance + dashWidth;
        if (end > metric.length) {
          canvas.drawPath(metric.extractPath(distance, metric.length), paint);
        } else {
          canvas.drawPath(metric.extractPath(distance, end), paint);
        }
        distance += dashWidth + dashSpace;
      }
    }
  }

  // NEW METHOD: Draw vertical current date indicator
  void _drawCurrentDateIndicator(Canvas canvas, Size size) {
    final now = DateTime.now();
    final currentOffset = now.difference(projectStartDate).inDays * dayWidth;
    
    // Only draw if within timeline
    if (currentOffset >= 0 && currentOffset <= size.width) {
      final indicatorPaint = Paint()
        ..color = Colors.red.shade600
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;

      canvas.drawLine(
        Offset(currentOffset, 0),
        Offset(currentOffset, rowHeight),
        indicatorPaint,
      );
    }
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