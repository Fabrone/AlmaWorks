import 'dart:io';
import 'dart:typed_data';
import 'package:almaworks/models/project_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:excel/excel.dart' hide Border;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════
// ENUMS
// ══════════════════════════════════════════════════════════════════

enum TaskRowType { project, category, phase, task }

enum DayStatus { none, started, ongoing, completed, holiday }

extension DayStatusX on DayStatus {
  String get code {
    switch (this) {
      case DayStatus.started:   return 'S';
      case DayStatus.ongoing:   return 'O';
      case DayStatus.completed: return 'C';
      case DayStatus.holiday:   return 'H';
      default:                  return '';
    }
  }

  String get label {
    switch (this) {
      case DayStatus.started:   return 'Started';
      case DayStatus.ongoing:   return 'Ongoing';
      case DayStatus.completed: return 'Completed';
      case DayStatus.holiday:   return 'Holiday';
      default:                  return 'Not Set';
    }
  }

  Color get color {
    switch (this) {
      case DayStatus.started:   return const Color(0xFF1565C0);
      case DayStatus.ongoing:   return const Color(0xFFE65100);
      case DayStatus.completed: return const Color(0xFF2E7D32);
      case DayStatus.holiday:   return const Color(0xFF6A1B9A);
      default:                  return Colors.grey;
    }
  }

  Color get bgColor {
    switch (this) {
      case DayStatus.started:   return const Color(0xFFE3F2FD);
      case DayStatus.ongoing:   return const Color(0xFFFFF3E0);
      case DayStatus.completed: return const Color(0xFFE8F5E9);
      case DayStatus.holiday:   return const Color(0xFFF3E5F5);
      default:                  return Colors.white;
    }
  }

  static DayStatus fromCode(String? code) {
    switch (code) {
      case 'S': return DayStatus.started;
      case 'O': return DayStatus.ongoing;
      case 'C': return DayStatus.completed;
      case 'H': return DayStatus.holiday;
      default:  return DayStatus.none;
    }
  }
}

// ══════════════════════════════════════════════════════════════════
// DATA MODEL
// ══════════════════════════════════════════════════════════════════

class TaskProgressRowData {
  String id;
  int rowIndex;
  String taskName;
  DateTime? startDate;
  DateTime? endDate;
  TaskRowType type;
  String? parentPhaseId; // for task rows, the id of their parent phase row
  int indentLevel;       // 0=project 1=category 2=phase 3+=task

  TaskProgressRowData({
    required this.id,
    required this.rowIndex,
    required this.taskName,
    this.startDate,
    this.endDate,
    required this.type,
    this.parentPhaseId,
    this.indentLevel = 0,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'rowIndex': rowIndex,
        'taskName': taskName,
        'startDate':
            startDate != null ? Timestamp.fromDate(startDate!) : null,
        'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
        'type': type.name,
        'parentPhaseId': parentPhaseId,
        'indentLevel': indentLevel,
      };

  factory TaskProgressRowData.fromMap(Map<String, dynamic> m) =>
      TaskProgressRowData(
        id: m['id'] as String? ?? const Uuid().v4(),
        rowIndex: (m['rowIndex'] as num?)?.toInt() ?? 0,
        taskName: m['taskName'] as String? ?? '',
        startDate: (m['startDate'] as Timestamp?)?.toDate(),
        endDate: (m['endDate'] as Timestamp?)?.toDate(),
        type: TaskRowType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => TaskRowType.task,
        ),
        parentPhaseId: m['parentPhaseId'] as String?,
        indentLevel: (m['indentLevel'] as num?)?.toInt() ?? 0,
      );
}

// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════

class TaskProgressMonitorScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const TaskProgressMonitorScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<TaskProgressMonitorScreen> createState() =>
      _TaskProgressMonitorScreenState();
}

class _TaskProgressMonitorScreenState
    extends State<TaskProgressMonitorScreen> {
  // ── Design constants ────────────────────────────────────────
  static const _navy       = Color(0xFF0A2E5A);
  static const _navyLight  = Color(0xFF1A3C6A);
  static const _navyMid    = Color(0xFF0D3060);
  static const _fieldBorder = Color(0xFFB0BEC5);
  static const _sectionBg  = Color(0xFFF5F7FA);

  // ── Fixed column widths ─────────────────────────────────────
  static const double _kNoW   = 38.0;
  static const double _kNameW = 234.0;
  static const double _kDateW = 86.0;
  static const double _kFixedW = _kNoW + _kNameW + _kDateW * 2; // 444

  // ── Day column width ────────────────────────────────────────
  static const double _kDayW  = 42.0;

  // ── Row heights ─────────────────────────────────────────────
  static const double _kHeaderH    = 84.0;
  static const double _kProjectH   = 46.0;
  static const double _kCategoryH  = 44.0;
  static const double _kPhaseH     = 52.0;
  static const double _kTaskH      = 46.0;

  // ── State ────────────────────────────────────────────────────
  final List<TaskProgressRowData> _rows = [];
  final Map<String, String> _dailyStatuses = {}; // key='rowId_YYYYMMDD' val='S/O/C/H'
  final Map<String, TextEditingController> _nameCtrlMap = {};

  bool _showRowNumbers = true;
  bool _isSaving       = false;
  bool _isLoading      = true;
  bool _isImporting    = false;

  // ── Scroll controllers ───────────────────────────────────────
  // Header horizontal / data horizontal (kept in sync)
  final _hScrollHeader = ScrollController();
  final _hScrollData   = ScrollController();
  bool _syncingH = false;

  // ── Date formatter ───────────────────────────────────────────
  final _dfDisplay = DateFormat('d MMM yy');
  final _dfKey     = DateFormat('yyyyMMdd');

  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _hScrollHeader.addListener(_syncHeaderToData);
    _hScrollData.addListener(_syncDataToHeader);
    _loadFromFirestore();
  }

  @override
  void dispose() {
    _hScrollHeader.removeListener(_syncHeaderToData);
    _hScrollData.removeListener(_syncDataToHeader);
    _hScrollHeader.dispose();
    _hScrollData.dispose();
    for (final c in _nameCtrlMap.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _syncHeaderToData() {
    if (_syncingH) return;
    _syncingH = true;
    if (_hScrollData.hasClients) {
      _hScrollData.jumpTo(_hScrollHeader.offset);
    }
    _syncingH = false;
  }

  void _syncDataToHeader() {
    if (_syncingH) return;
    _syncingH = true;
    if (_hScrollHeader.hasClients) {
      _hScrollHeader.jumpTo(_hScrollData.offset);
    }
    _syncingH = false;
  }

  // ─────────────────────────────────────────────────────────────
  // CONTROLLER HELPERS
  // ─────────────────────────────────────────────────────────────
  TextEditingController _nameCtrl(String id) =>
      _nameCtrlMap.putIfAbsent(id, () => TextEditingController());

  void _syncNameControllers() {
    for (final row in _rows) {
      _nameCtrl(row.id).text = row.taskName;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // FIRESTORE
  // ─────────────────────────────────────────────────────────────
  DocumentReference get _docRef => FirebaseFirestore.instance
      .collection('TaskProgressMonitor')
      .doc(widget.project.id);

  Future<void> _loadFromFirestore() async {
    try {
      final snap = await _docRef.get();
      if (!snap.exists) {
        setState(() => _isLoading = false);
        return;
      }
      final data = snap.data() as Map<String, dynamic>;
      final rawRows = data['rows'] as List<dynamic>? ?? [];
      final rawStatuses =
          Map<String, dynamic>.from(data['dailyStatuses'] as Map? ?? {});

      setState(() {
        _rows.clear();
        _rows.addAll(rawRows
            .map((e) =>
                TaskProgressRowData.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList());
        _rows.sort((a, b) => a.rowIndex.compareTo(b.rowIndex));
        _dailyStatuses.clear();
        rawStatuses.forEach((k, v) => _dailyStatuses[k] = v.toString());
        _isLoading = false;
      });
      _syncNameControllers();
    } catch (e, st) {
      widget.logger.e('TaskProgressMonitor: load failed', error: e, stackTrace: st);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveToFirestore() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);

    // Flush name controllers into row data
    for (final row in _rows) {
      row.taskName = _nameCtrl(row.id).text;
    }
    // Re-index rows
    for (int i = 0; i < _rows.length; i++) {
      _rows[i].rowIndex = i;
    }

    try {
      await _docRef.set({
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'updatedAt': Timestamp.now(),
        'rows': _rows.map((r) => r.toMap()).toList(),
        'dailyStatuses': _dailyStatuses,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Progress monitor saved!',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.green[700],
        ));
      }
    } catch (e) {
      widget.logger.e('TaskProgressMonitor: save failed', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[700],
        ));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // Individual cell auto-save
  Future<void> _autosaveStatus(String key, String? value) async {
    try {
      if (value == null) {
        await _docRef.update({'dailyStatuses.$key': FieldValue.delete()});
      } else {
        await _docRef.set(
          {'dailyStatuses': {key: value}},
          SetOptions(merge: true),
        );
      }
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────
  // EXCEL IMPORT
  // ─────────────────────────────────────────────────────────────
  Future<void> _importFromExcel() async {
    setState(() => _isImporting = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx', 'xls'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        setState(() => _isImporting = false);
        return;
      }

      Uint8List? bytes = result.files.first.bytes;
      if (bytes == null && result.files.first.path != null && !kIsWeb) {
        bytes = await File(result.files.first.path!).readAsBytes();
      }
      if (bytes == null) {
        setState(() => _isImporting = false);
        return;
      }

      final excel = Excel.decodeBytes(bytes);
      final sheetName = excel.tables.keys.first;
      final sheet = excel.tables[sheetName]!;

      final newRows = <TaskProgressRowData>[];
      String? currentPhaseId;
      int idx = 0;

      for (int r = 0; r < sheet.rows.length; r++) {
        final row = sheet.rows[r];
        if (row.isEmpty) continue;

        final rawName = _cellStr(row.elementAtOrNull(0));
        if (rawName.isEmpty) continue;

        // Skip header row
        if (r == 0 && rawName.trim().toLowerCase() == 'task name') continue;

        final startStr = _cellStr(row.elementAtOrNull(2));
        final endStr   = _cellStr(row.elementAtOrNull(3));

        final startDate = _parseExcelDate(startStr);
        final endDate   = _parseExcelDate(endStr);
        final type      = _detectType(rawName);

        final id = const Uuid().v4();

        if (type == TaskRowType.phase) {
          currentPhaseId = id;
        }

        newRows.add(TaskProgressRowData(
          id: id,
          rowIndex: idx++,
          taskName: rawName,
          startDate: startDate,
          endDate: endDate,
          type: type,
          parentPhaseId: type == TaskRowType.task ? currentPhaseId : null,
          indentLevel: _indentLevel(rawName),
        ));
      }

      // Confirm before replacing
      if (!mounted) return;
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text('Import from Excel',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
          content: Text(
            'Found ${newRows.length} rows.\nThis will replace the current table. Continue?',
            style: GoogleFonts.poppins(fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(
                  backgroundColor: _navy, foregroundColor: Colors.white),
              child: Text('Import', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );

      if (confirm != true || !mounted) {
        setState(() => _isImporting = false);
        return;
      }

      // Dispose old controllers
      for (final c in _nameCtrlMap.values) {
        c.dispose();
      }
      _nameCtrlMap.clear();

      setState(() {
        _rows.clear();
        _rows.addAll(newRows);
      });
      _syncNameControllers();
    } catch (e, st) {
      widget.logger.e('Excel import failed', error: e, stackTrace: st);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Import failed: $e', style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[700],
        ));
      }
    } finally {
      if (mounted) setState(() => _isImporting = false);
    }
  }

  // ── Excel helpers ─────────────────────────────────────────────
  String _cellStr(Data? cell) {
    if (cell == null || cell.value == null) return '';
    final v = cell.value!;
    if (v is TextCellValue)   return v.value.toString();
    if (v is IntCellValue)    return v.value.toString();
    if (v is DoubleCellValue) return v.value.toStringAsFixed(0);
    if (v is DateCellValue)   return '${v.month}/${v.day}/${v.year}';
    if (v is BoolCellValue)   return v.value.toString();
    return v.toString();
  }

  DateTime? _parseExcelDate(String s) {
    final t = s.trim();
    if (t.isEmpty) return null;
    for (final fmt in [
      'EEE M/d/yy', 'EEE M/d/yyyy',
      'M/d/yy', 'M/d/yyyy',
      'd/M/yy', 'd/M/yyyy',
    ]) {
      try { return DateFormat(fmt).parse(t); } catch (_) {}
    }
    return null;
  }

  int _countLeadingSpaces(String s) {
    int n = 0;
    for (final c in s.runes) {
      if (c == 32) {
        n++;
      } else {
        break;
      }
    }
    return n;
  }

  int _indentLevel(String rawName) =>
      (_countLeadingSpaces(rawName) / 3).floor().clamp(0, 5);

  TaskRowType _detectType(String rawName) {
    final spaces  = _countLeadingSpaces(rawName);
    final trimmed = rawName.trim().toLowerCase();
    if (spaces == 0) return TaskRowType.project;
    if (spaces < 6)  return TaskRowType.category;
    if (trimmed.startsWith('phase')) return TaskRowType.phase;
    if (spaces < 9)  return TaskRowType.category;
    return TaskRowType.task;
  }

  // ─────────────────────────────────────────────────────────────
  // ROW MANIPULATION
  // ─────────────────────────────────────────────────────────────
  void _addRow() {
    // Find last phase id to attach new task
    String? phaseId;
    for (int i = _rows.length - 1; i >= 0; i--) {
      if (_rows[i].type == TaskRowType.phase) {
        phaseId = _rows[i].id;
        break;
      }
    }
    final id = const Uuid().v4();
    setState(() {
      _rows.add(TaskProgressRowData(
        id: id,
        rowIndex: _rows.length,
        taskName: '         New Task',
        type: TaskRowType.task,
        parentPhaseId: phaseId,
        indentLevel: 3,
      ));
    });
    _nameCtrl(id).text = '         New Task';
  }

  void _removeLastRow() {
    if (_rows.isEmpty) return;
    // Only remove last task row
    for (int i = _rows.length - 1; i >= 0; i--) {
      if (_rows[i].type == TaskRowType.task) {
        final id = _rows[i].id;
        setState(() => _rows.removeAt(i));
        _nameCtrlMap.remove(id)?.dispose();
        return;
      }
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STATUS
  // ─────────────────────────────────────────────────────────────
  String _statusKey(String rowId, DateTime date) =>
      '${rowId}_${_dfKey.format(date)}';

  DayStatus _getStatus(String rowId, DateTime date) =>
      DayStatusX.fromCode(_dailyStatuses[_statusKey(rowId, date)]);

  void _setStatus(String rowId, DateTime date, DayStatus status) {
    final key = _statusKey(rowId, date);
    setState(() {
      if (status == DayStatus.none) {
        _dailyStatuses.remove(key);
      } else {
        _dailyStatuses[key] = status.code;
      }
    });
    _autosaveStatus(key, status == DayStatus.none ? null : status.code);
  }

  // ─────────────────────────────────────────────────────────────
  // WORKING DAYS & WEEKS
  // ─────────────────────────────────────────────────────────────
  /// Returns Mon–Sat working days between [start] and [end] (inclusive),
  /// excluding Sundays. Holidays are defined by the user via cell status.
  List<DateTime> _workingDays(DateTime start, DateTime end) {
    final days = <DateTime>[];
    DateTime cur = DateTime(start.year, start.month, start.day);
    final endN  = DateTime(end.year,   end.month,   end.day);
    while (!cur.isAfter(endN)) {
      if (cur.weekday != DateTime.sunday) days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  /// Groups a flat list of (working) days into week buckets (Mon–Sat).
  List<List<DateTime>> _groupWeeks(List<DateTime> days) {
    final weeks = <List<DateTime>>[];
    List<DateTime> cur = [];
    for (final d in days) {
      if (d.weekday == DateTime.monday && cur.isNotEmpty) {
        weeks.add(cur);
        cur = [];
      }
      cur.add(d);
      if (d.weekday == DateTime.saturday && cur.isNotEmpty) {
        weeks.add(cur);
        cur = [];
      }
    }
    if (cur.isNotEmpty) weeks.add(cur);
    return weeks;
  }

  // ── Phase column data ─────────────────────────────────────────
  List<_PhaseColumnData> get _phaseColumns {
    return _rows
        .where((r) =>
            r.type == TaskRowType.phase &&
            r.startDate != null &&
            r.endDate != null)
        .map((phase) {
          final days  = _workingDays(phase.startDate!, phase.endDate!);
          final weeks = _groupWeeks(days);
          return _PhaseColumnData(phase: phase, days: days, weeks: weeks);
        })
        .toList();
  }

  // ─────────────────────────────────────────────────────────────
  // PROGRESS
  // ─────────────────────────────────────────────────────────────
  bool _isTaskDone(TaskProgressRowData task, DateTime phaseEnd) {
    final checkDate = task.endDate != null && !task.endDate!.isAfter(phaseEnd)
        ? task.endDate!
        : phaseEnd;
    final d = DateTime(checkDate.year, checkDate.month, checkDate.day);
    return _getStatus(task.id, d) == DayStatus.completed;
  }

  double _phaseProgress(TaskProgressRowData phase) {
    if (phase.startDate == null || phase.endDate == null) return 0.0;
    final tasks = _rows
        .where((r) =>
            r.type == TaskRowType.task && r.parentPhaseId == phase.id)
        .toList();
    if (tasks.isEmpty) return 0.0;
    final done = tasks.where((t) => _isTaskDone(t, phase.endDate!)).length;
    return done / tasks.length;
  }

  double get _projectProgress {
    final phases = _rows.where((r) => r.type == TaskRowType.phase).toList();
    if (phases.isEmpty) {
      final tasks = _rows.where((r) => r.type == TaskRowType.task).toList();
      if (tasks.isEmpty) return 0.0;
      final done = tasks.where((t) {
        if (t.endDate == null) return false;
        return _getStatus(t.id,
                DateTime(t.endDate!.year, t.endDate!.month, t.endDate!.day)) ==
            DayStatus.completed;
      }).length;
      return done / tasks.length;
    }
    final total = phases.fold(0.0, (s, p) => s + _phaseProgress(p));
    return total / phases.length;
  }

  // ─────────────────────────────────────────────────────────────
  // ROW HEIGHT HELPER
  // ─────────────────────────────────────────────────────────────
  double _rowH(TaskRowType t) {
    switch (t) {
      case TaskRowType.project:  return _kProjectH;
      case TaskRowType.category: return _kCategoryH;
      case TaskRowType.phase:    return _kPhaseH;
      case TaskRowType.task:     return _kTaskH;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // STATUS PICKER
  // ─────────────────────────────────────────────────────────────
  Future<void> _showStatusPicker(
      TaskProgressRowData row, DateTime day) async {
    final current = _getStatus(row.id, day);
    if (!mounted) return;

    final selected = await showModalBottomSheet<DayStatus>(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 38, height: 4,
              margin: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Text(
                '${row.taskName.trim()}  ·  ${DateFormat('EEE d MMM yyyy').format(day)}',
                style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _navy),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(height: 1),
            ...DayStatus.values.map((s) => ListTile(
                  dense: true,
                  leading: _statusChip(s),
                  title: Text(s.label,
                      style: GoogleFonts.poppins(
                          fontSize: 13,
                          color: s == DayStatus.none
                              ? Colors.grey[500]
                              : Colors.black87)),
                  trailing: s == current
                      ? Icon(Icons.check_circle_rounded,
                          color: Colors.green[700], size: 16)
                      : null,
                  onTap: () => Navigator.pop(ctx, s),
                )),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (selected != null) _setStatus(row.id, day, selected);
  }

  Widget _statusChip(DayStatus s) {
    if (s == DayStatus.none) {
      return Container(
        width: 26, height: 26,
        decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!),
            borderRadius: BorderRadius.circular(6)),
        child: const Icon(Icons.remove_rounded, size: 12, color: Colors.grey),
      );
    }
    return Container(
      width: 26, height: 26,
      decoration: BoxDecoration(
          color: s.bgColor,
          border: Border.all(color: s.color.withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(6)),
      child: Center(
        child: Text(s.code,
            style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: s.color)),
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════
  // BUILD
  // ═════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: _buildAppBar(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Project header + progress ──────────────────
                _buildProjectHeader(),
                // ── Toolbar ───────────────────────────────────
                _buildToolbar(),
                // ── Table ─────────────────────────────────────
                Expanded(child: _buildTable()),
              ],
            ),
    );
  }

  // ── AppBar ────────────────────────────────────────────────────
  AppBar _buildAppBar() => AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.project.name} — Task Progress Monitor',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (_isSaving)
            const Padding(
              padding: EdgeInsets.only(right: 16),
              child: Center(
                child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white)),
              ),
            )
          else
            IconButton(
              onPressed: _saveToFirestore,
              icon: const Icon(Icons.save_rounded),
              tooltip: 'Save',
            ),
        ],
      );

  // ── Project header with progress ──────────────────────────────
  Widget _buildProjectHeader() {
    final progress = _projectProgress;
    return Container(
      color: _navy,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.project.name,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 15),
                ),
              ),
              // Project progress badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                      color: Colors.white.withValues(alpha: 0.3)),
                ),
                child: Text(
                  'Project: ${(progress * 100).toStringAsFixed(0)}%',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 11),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Project progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 5,
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0 ? Colors.greenAccent : Colors.cyanAccent,
              ),
            ),
          ),
          const SizedBox(height: 8),
          // Phase progress chips
          if (_phaseColumns.isNotEmpty)
            SizedBox(
              height: 26,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _phaseColumns.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final pc = _phaseColumns[i];
                  final pp = _phaseProgress(pc.phase);
                  return Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        pc.phase.taskName.trim(),
                        style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 9,
                            fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        '${(pp * 100).toStringAsFixed(0)}%',
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w800),
                      ),
                    ]),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  // ── Toolbar ───────────────────────────────────────────────────
  Widget _buildToolbar() {
    return Container(
      height: 44,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: _fieldBorder, width: 0.8)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      child: Row(children: [
        // Row numbers toggle
        _toolBtn(
          icon: Icons.format_list_numbered_rounded,
          label: '# Rows',
          active: _showRowNumbers,
          onTap: () => setState(() => _showRowNumbers = !_showRowNumbers),
        ),
        const SizedBox(width: 6),
        // Add row
        _toolBtn(
          icon: Icons.add_box_outlined,
          label: 'Add Row',
          color: Colors.green[700],
          onTap: _addRow,
        ),
        const SizedBox(width: 6),
        // Remove last row
        _toolBtn(
          icon: Icons.indeterminate_check_box_outlined,
          label: 'Remove Last',
          color: Colors.orange[700],
          onTap: _removeLastRow,
        ),
        const Spacer(),
        // Legend
        _legendChip('S', DayStatus.started),
        const SizedBox(width: 4),
        _legendChip('O', DayStatus.ongoing),
        const SizedBox(width: 4),
        _legendChip('C', DayStatus.completed),
        const SizedBox(width: 4),
        _legendChip('H', DayStatus.holiday),
        const SizedBox(width: 8),
        // Import Excel
        SizedBox(
          height: 32,
          child: ElevatedButton.icon(
            onPressed: _isImporting ? null : _importFromExcel,
            icon: _isImporting
                ? const SizedBox(
                    width: 12,
                    height: 12,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(Colors.white)))
                : const Icon(Icons.upload_file_rounded, size: 14),
            label: Text('Import Excel',
                style: GoogleFonts.poppins(
                    fontSize: 11, fontWeight: FontWeight.w600)),
            style: ElevatedButton.styleFrom(
              backgroundColor: _navy,
              foregroundColor: Colors.white,
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(7)),
              elevation: 1,
            ),
          ),
        ),
      ]),
    );
  }

  Widget _toolBtn({
    required IconData icon,
    required String label,
    Color? color,
    bool active = false,
    required VoidCallback onTap,
  }) {
    final c = color ?? _navy;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: active ? c.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
              color: active
                  ? c.withValues(alpha: 0.45)
                  : Colors.grey.withValues(alpha: 0.3),
              width: 0.9),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 14, color: active ? c : Colors.grey[600]),
          const SizedBox(width: 4),
          Text(label,
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: active ? c : Colors.grey[600])),
        ]),
      ),
    );
  }

  Widget _legendChip(String code, DayStatus s) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
        decoration: BoxDecoration(
            color: s.bgColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: s.color.withValues(alpha: 0.4))),
        child: Text(code,
            style: GoogleFonts.poppins(
                fontSize: 9,
                fontWeight: FontWeight.w800,
                color: s.color)),
      );

  // ═════════════════════════════════════════════════════════════
  // TABLE
  // ═════════════════════════════════════════════════════════════
  Widget _buildTable() {
    if (_rows.isEmpty) return _buildEmptyState();

    return Column(
      children: [
        // ── Sticky header row ──────────────────────────────────
        SizedBox(
          height: _kHeaderH,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Fixed header
              _buildFixedHeader(),
              // Period header (horizontally scrollable)
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  controller: _hScrollHeader,
                  physics: const ClampingScrollPhysics(),
                  child: _buildPeriodHeader(),
                ),
              ),
            ],
          ),
        ),
        // Thin divider
        Container(height: 1, color: _fieldBorder.withValues(alpha: 0.6)),
        // ── Data rows (vertically scrollable) ─────────────────
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final periodWidth = _phaseColumns.fold(
                  0.0, (acc, pc) => acc + pc.days.length * _kDayW);
              return SingleChildScrollView(
                scrollDirection: Axis.vertical,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Fixed data cells column
                    SizedBox(
                      width: _kFixedW,
                      child: Column(
                        children: _rows.map(_buildFixedRow).toList(),
                      ),
                    ),
                    // Period data cells column (horizontally scrollable)
                    SizedBox(
                      width: (constraints.maxWidth - _kFixedW)
                          .clamp(0.0, double.infinity),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        controller: _hScrollData,
                        physics: const ClampingScrollPhysics(),
                        child: SizedBox(
                          width: periodWidth,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _rows.map(_buildPeriodRow).toList(),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FIXED HEADER
  // ─────────────────────────────────────────────────────────────
  Widget _buildFixedHeader() {
    return Container(
      width: _kFixedW,
      height: _kHeaderH,
      decoration: const BoxDecoration(
        color: _navy,
        border: Border(
          right: BorderSide(color: Colors.white24, width: 1),
          bottom: BorderSide(color: Colors.white24, width: 1),
        ),
      ),
      child: Row(
        children: [
          if (_showRowNumbers) _fixedHdrCell('#', _kNoW, center: true),
          _fixedHdrCell('Task Name', _kNameW),
          _fixedHdrCell('Start Date', _kDateW, center: true),
          _fixedHdrCell('Finish Date', _kDateW, center: true),
        ],
      ),
    );
  }

  Widget _fixedHdrCell(String label, double w,
      {bool center = false}) =>
      Container(
        width: w,
        height: _kHeaderH,
        alignment: center ? Alignment.center : Alignment.centerLeft,
        padding: EdgeInsets.only(
            left: center ? 0 : 8, right: center ? 0 : 4),
        decoration: const BoxDecoration(
          border: Border(right: BorderSide(color: Colors.white24, width: 0.5)),
        ),
        child: Text(
          label,
          textAlign: center ? TextAlign.center : TextAlign.left,
          style: GoogleFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.w700,
              fontSize: 11,
              letterSpacing: 0.3),
        ),
      );

  // ─────────────────────────────────────────────────────────────
  // PERIOD HEADER (phase name → week ranges → day labels)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPeriodHeader() {
    final phaseData = _phaseColumns;
    if (phaseData.isEmpty) {
      return Container(
        width: 320,
        height: _kHeaderH,
        color: _navyMid,
        alignment: Alignment.center,
        child: Text(
          'No phases with start/end dates defined',
          style: GoogleFonts.poppins(
              color: Colors.white54, fontSize: 11),
        ),
      );
    }

    return SizedBox(
      height: _kHeaderH,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: phaseData.map((pc) {
          final phaseW = pc.days.length * _kDayW;
          return SizedBox(
            width: phaseW,
            child: Column(
              children: [
                // Row 1: Phase name (28px)
                Container(
                  height: 28,
                  width: double.infinity,
                  color: _navyMid,
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(3),
                      ),
                      child: Text(
                        'PHASE',
                        style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 7,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.5),
                      ),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        pc.phase.taskName.trim(),
                        style: GoogleFonts.poppins(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    // Phase progress %
                    Text(
                      '${(_phaseProgress(pc.phase) * 100).toStringAsFixed(0)}%',
                      style: GoogleFonts.poppins(
                          color: Colors.cyanAccent,
                          fontSize: 10,
                          fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(width: 6),
                  ]),
                ),
                // Row 2+3: Week groups (56px)
                Expanded(
                  child: Row(
                    children: pc.weeks.map((week) {
                      final weekW = week.length * _kDayW;
                      return SizedBox(
                        width: weekW,
                        child: Column(
                          children: [
                            // Week date range (26px)
                            Container(
                              height: 26,
                              alignment: Alignment.center,
                              decoration: const BoxDecoration(
                                color: _navyLight,
                                border: Border(
                                  right: BorderSide(
                                      color: Colors.white24, width: 0.5),
                                ),
                              ),
                              child: Text(
                                '${DateFormat('MMM d').format(week.first)} – '
                                '${DateFormat('MMM d').format(week.last)}',
                                style: GoogleFonts.poppins(
                                    color: Colors.white70,
                                    fontSize: 8,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                            // Day name cells (remaining height)
                            Expanded(
                              child: Row(
                                children: week.map((day) {
                                  return Container(
                                    width: _kDayW,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0B3070),
                                      border: Border(
                                        right: BorderSide(
                                            color: Colors.white24,
                                            width: 0.5),
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          DateFormat('EEE')
                                              .format(day)
                                              .substring(0, 2),
                                          style: GoogleFonts.poppins(
                                              color: Colors.white60,
                                              fontSize: 7.5,
                                              fontWeight: FontWeight.w600),
                                        ),
                                        Text(
                                          DateFormat('d').format(day),
                                          style: GoogleFonts.poppins(
                                              color: Colors.white,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // FIXED ROW (task name + dates – left sticky panel)
  // ─────────────────────────────────────────────────────────────
  Widget _buildFixedRow(TaskProgressRowData row) {
    final h = _rowH(row.type);

    // Row background + text colours by type
    final (bg, fg, accent) = _rowColors(row.type);

    return Container(
      width: _kFixedW,
      height: h,
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          bottom: BorderSide(
              color: _fieldBorder.withValues(alpha: 0.5), width: 0.5),
          right: BorderSide(
              color: _fieldBorder.withValues(alpha: 0.4), width: 0.7),
        ),
      ),
      child: Row(
        children: [
          // Row number
          if (_showRowNumbers)
            Container(
              width: _kNoW,
              height: h,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.08),
                border: Border(
                    right: BorderSide(
                        color: _fieldBorder.withValues(alpha: 0.4),
                        width: 0.5)),
              ),
              child: Text(
                '${_rows.indexOf(row) + 1}',
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: accent.withValues(alpha: 0.6)),
              ),
            ),

          // Task name cell (editable)
          _buildNameCell(row, h, fg, accent),

          // Start date
          _buildDateCell(row, isStart: true, h: h, fg: fg, accent: accent),

          // Finish date
          _buildDateCell(row, isStart: false, h: h, fg: fg, accent: accent),
        ],
      ),
    );
  }

  (Color, Color, Color) _rowColors(TaskRowType t) {
    switch (t) {
      case TaskRowType.project:
        return (
          const Color(0xFFE8EEF6),
          _navy,
          _navy,
        );
      case TaskRowType.category:
        return (
          const Color(0xFFF0F4F9),
          const Color(0xFF1A3C6A),
          const Color(0xFF1A3C6A),
        );
      case TaskRowType.phase:
        return (
          const Color(0xFFE3ECF8),
          _navy,
          _navy,
        );
      case TaskRowType.task:
        return (
          Colors.white,
          Colors.black87,
          _navy,
        );
    }
  }

  Widget _buildNameCell(
      TaskProgressRowData row, double h, Color fg, Color accent) {
    final indent = (row.indentLevel.clamp(0, 5) * 10.0);

    return Container(
      width: _kNameW,
      height: h,
      padding: EdgeInsets.only(left: indent + 6, right: 4),
      decoration: BoxDecoration(
        border: Border(
            right: BorderSide(
                color: _fieldBorder.withValues(alpha: 0.4), width: 0.5)),
      ),
      child: Row(
        children: [
          // Type badge
          if (row.type == TaskRowType.phase) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                  color: _navy, borderRadius: BorderRadius.circular(3)),
              child: Text('PH',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.3)),
            ),
          ] else if (row.type == TaskRowType.project) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF1565C0),
                  borderRadius: BorderRadius.circular(3)),
              child: Text('PRJ',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w800)),
            ),
          ] else if (row.type == TaskRowType.category) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                  color: const Color(0xFF37474F),
                  borderRadius: BorderRadius.circular(3)),
              child: Text('GRP',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 7,
                      fontWeight: FontWeight.w800)),
            ),
          ],

          // Editable task name
          Expanded(
            child: TextField(
              controller: _nameCtrl(row.id),
              onChanged: (v) => row.taskName = v,
              maxLines: 1,
              style: GoogleFonts.poppins(
                  fontSize: row.type == TaskRowType.task ? 11 : 11.5,
                  fontWeight: row.type == TaskRowType.task
                      ? FontWeight.w400
                      : FontWeight.w700,
                  color: fg),
              decoration: const InputDecoration(
                border: InputBorder.none,
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateCell(
      TaskProgressRowData row,
      {required bool isStart,
      required double h,
      required Color fg,
      required Color accent}) {
    final date = isStart ? row.startDate : row.endDate;
    return GestureDetector(
      onTap: row.type == TaskRowType.task || row.type == TaskRowType.phase
          ? () => _pickDate(row, isStart: isStart)
          : null,
      child: Container(
        width: _kDateW,
        height: h,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          border: Border(
              right: BorderSide(
                  color: _fieldBorder.withValues(alpha: 0.4), width: 0.5)),
        ),
        child: date != null
            ? Text(
                _dfDisplay.format(date),
                style: GoogleFonts.poppins(
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    color: fg),
                textAlign: TextAlign.center,
              )
            : Icon(Icons.edit_calendar_rounded,
                size: 13,
                color: Colors.grey[350]),
      ),
    );
  }

  Future<void> _pickDate(TaskProgressRowData row,
      {required bool isStart}) async {
    final initial = isStart
        ? (row.startDate ?? DateTime.now())
        : (row.endDate ?? (row.startDate ?? DateTime.now()));
    final first = isStart ? DateTime(2020) : (row.startDate ?? DateTime(2020));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.light(
              primary: _navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        row.startDate = picked;
        if (row.endDate != null && row.endDate!.isBefore(picked)) {
          row.endDate = picked;
        }
      } else {
        row.endDate = picked;
      }
    });
  }

  // ─────────────────────────────────────────────────────────────
  // PERIOD ROW (status cells – right scrollable panel)
  // ─────────────────────────────────────────────────────────────
  Widget _buildPeriodRow(TaskProgressRowData row) {
    final phaseData = _phaseColumns;
    final h = _rowH(row.type);

    if (phaseData.isEmpty) {
      return Container(
        width: 320,
        height: h,
        color: _sectionBg,
      );
    }

    return SizedBox(
      height: h,
      child: Row(
        children: phaseData.map((pc) {
          final phaseW = pc.days.length * _kDayW;

          // ── Project / Category rows – grey shade ─────────────
          if (row.type == TaskRowType.project ||
              row.type == TaskRowType.category) {
            return Container(
              width: phaseW,
              height: h,
              color: row.type == TaskRowType.project
                  ? const Color(0xFFE8EEF6)
                  : const Color(0xFFF0F4F9),
              child: const Divider(height: 1, thickness: 0.3),
            );
          }

          // ── Phase row – show progress bar for matching phase ─
          if (row.type == TaskRowType.phase) {
            if (row.id == pc.phase.id) {
              return _buildPhaseProgressRow(row, pc, phaseW, h);
            }
            return Container(
              width: phaseW,
              height: h,
              color: const Color(0xFFF5F7FA),
            );
          }

          // ── Task row – show day cells only for its parent phase
          final inPhase = row.parentPhaseId == pc.phase.id;
          if (!inPhase) {
            return Container(
              width: phaseW,
              height: h,
              color: const Color(0xFFF9FAFB),
              child: const Center(
                child: Divider(
                    color: Color(0xFFE0E4EA), thickness: 0.5, height: 1),
              ),
            );
          }

          return SizedBox(
            width: phaseW,
            height: h,
            child: Row(
              children: pc.days.map((day) {
                final status = _getStatus(row.id, day);
                // Determine if day falls within task's own date range
                final taskStart = row.startDate;
                final taskEnd   = row.endDate;
                final inRange = taskStart == null || taskEnd == null
                    ? true
                    : !day.isBefore(DateTime(taskStart.year, taskStart.month, taskStart.day)) &&
                      !day.isAfter(DateTime(taskEnd.year,   taskEnd.month,   taskEnd.day));

                return GestureDetector(
                  onTap: inRange
                      ? () => _showStatusPicker(row, day)
                      : null,
                  child: _buildDayCell(status, inRange, h),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildDayCell(DayStatus status, bool active, double h) {
    return Container(
      width: _kDayW,
      height: h,
      decoration: BoxDecoration(
        color: active ? status.bgColor : const Color(0xFFF3F5F7),
        border: Border(
          right: BorderSide(
              color: _fieldBorder.withValues(alpha: 0.35), width: 0.5),
          bottom: BorderSide(
              color: _fieldBorder.withValues(alpha: 0.25), width: 0.3),
        ),
      ),
      child: active
          ? Center(
              child: status == DayStatus.none
                  ? Icon(Icons.add_rounded,
                      size: 11,
                      color: Colors.grey[300])
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          status.code,
                          style: GoogleFonts.poppins(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: status.color),
                        ),
                      ],
                    ),
            )
          : null,
    );
  }

  Widget _buildPhaseProgressRow(TaskProgressRowData row,
      _PhaseColumnData pc, double phaseW, double h) {
    final progress = _phaseProgress(row);
    return Container(
      width: phaseW,
      height: h,
      color: const Color(0xFFE3ECF8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(children: [
            Text(
              '${pc.days.length} working days',
              style: GoogleFonts.poppins(
                  fontSize: 9, color: _navy.withValues(alpha: 0.6)),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).toStringAsFixed(0)}% complete',
              style: GoogleFonts.poppins(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: progress >= 1.0
                      ? Colors.green[700]
                      : _navy),
            ),
          ]),
          const SizedBox(height: 5),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: Colors.white.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation(
                progress >= 1.0
                    ? Colors.green[600]!
                    : const Color(0xFF1565C0),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────
  // EMPTY STATE
  // ─────────────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_chart_outlined,
              size: 56, color: Colors.grey[300]),
          const SizedBox(height: 14),
          Text('No tasks defined yet',
              style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[500])),
          const SizedBox(height: 6),
          Text(
            'Use "Import Excel" to load from a file,\nor "Add Row" to create tasks manually.',
            textAlign: TextAlign.center,
            style: GoogleFonts.poppins(
                fontSize: 12, color: Colors.grey[400]),
          ),
          const SizedBox(height: 20),
          Row(mainAxisSize: MainAxisSize.min, children: [
            ElevatedButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add_rounded, size: 15),
              label: Text('Add Row',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              style: ElevatedButton.styleFrom(
                backgroundColor: _navy,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _isImporting ? null : _importFromExcel,
              icon: const Icon(Icons.upload_file_rounded, size: 15),
              label: Text('Import Excel',
                  style: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 12)),
              style: OutlinedButton.styleFrom(
                foregroundColor: _navy,
                side: const BorderSide(color: _navy),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8)),
              ),
            ),
          ]),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════
// HELPER MODEL – phase column data (pre-computed)
// ══════════════════════════════════════════════════════════════════
class _PhaseColumnData {
  final TaskProgressRowData phase;
  final List<DateTime> days;
  final List<List<DateTime>> weeks;

  const _PhaseColumnData({
    required this.phase,
    required this.days,
    required this.weeks,
  });
}