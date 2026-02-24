import 'dart:convert';
import 'dart:io' show Directory, File, Platform;
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:almaworks/models/project_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:pluto_grid/pluto_grid.dart';

// ══════════════════════════════════════════════════════════════════
// ACTIVITY ROW MODEL
// ══════════════════════════════════════════════════════════════════
class ActivityRow {
  String activity;
  String progress;
  String comment;
  ActivityRow({
    this.activity = '',
    this.progress = '',
    this.comment = '',
  });
  Map<String, dynamic> toMap() => {
        'activity': activity,
        'progress': progress,
        'comment': comment,
      };
  factory ActivityRow.fromMap(Map<String, dynamic> m) => ActivityRow(
        activity: m['activity'] ?? '',
        progress: m['progress'] ?? '',
        comment: m['comment'] ?? '',
      );
}
// ══════════════════════════════════════════════════════════════════
// DATA MODEL
// ══════════════════════════════════════════════════════════════════
class WeeklyReportData {
  final String id;
  final String projectId;
  final String projectName;
  String contractNumber;
  DateTime weekStart;
  DateTime weekEnd;
  String subContractor;
  String building;
  // Activities template — two roof sections
  List<ActivityRow> slopedRoofRows;
  List<ActivityRow> flatRoofRows;
  // Notes and percentage
  String notes;
  double percentageDone;
  List<String> imageUrls;
  List<Uint8List> localImages;
  bool isDraft;
  DateTime? savedAt;
  WeeklyReportData({
    required this.id,
    required this.projectId,
    required this.projectName,
    this.contractNumber = '',
    required this.weekStart,
    required this.weekEnd,
    this.subContractor = '',
    this.building = '',
    List<ActivityRow>? slopedRoofRows,
    List<ActivityRow>? flatRoofRows,
    this.notes = '',
    this.percentageDone = 0,
    this.imageUrls = const [],
    this.localImages = const [],
    this.isDraft = true,
    this.savedAt,
  }) : slopedRoofRows = slopedRoofRows ?? _defaultRows(),
        flatRoofRows = flatRoofRows ?? _defaultRows();
  static List<ActivityRow> _defaultRows() =>
      List.generate(5, (_) => ActivityRow());
  Map<String, dynamic> toMap() => {
        'id': id,
        'projectId': projectId,
        'projectName': projectName,
        'contractNumber': contractNumber,
        'weekStart': Timestamp.fromDate(weekStart),
        'weekEnd': Timestamp.fromDate(weekEnd),
        'subContractor': subContractor,
        'building': building,
        'slopedRoofRows': slopedRoofRows.map((r) => r.toMap()).toList(),
        'flatRoofRows': flatRoofRows.map((r) => r.toMap()).toList(),
        'notes': notes,
        'percentageDone': percentageDone,
        'imageUrls': imageUrls,
        'isDraft': isDraft,
        'savedAt': Timestamp.now(),
        'type': 'Weekly',
      };
  factory WeeklyReportData.fromMap(Map<String, dynamic> m) {
    List<ActivityRow> parseRows(dynamic raw) {
      if (raw == null) return WeeklyReportData._defaultRows();
      return (raw as List<dynamic>)
          .map((e) => ActivityRow.fromMap(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final ws = (m['weekStart'] as Timestamp).toDate();
    final we = (m['weekEnd'] as Timestamp).toDate();
    return WeeklyReportData(
      id: m['id'] ?? '',
      projectId: m['projectId'] ?? '',
      projectName: m['projectName'] ?? '',
      contractNumber: m['contractNumber'] ?? '',
      weekStart: ws,
      weekEnd: we,
      subContractor: m['subContractor'] ?? '',
      building: m['building'] ?? '',
      slopedRoofRows: parseRows(m['slopedRoofRows']),
      flatRoofRows: parseRows(m['flatRoofRows']),
      notes: m['notes'] ?? '',
      percentageDone: (m['percentageDone'] as num?)?.toDouble() ?? 0.0,
      imageUrls: List<String>.from(m['imageUrls'] ?? []),
      isDraft: m['isDraft'] ?? true,
    );
  }
}
// ══════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════
class WeeklyReportFormScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;
  final WeeklyReportData? existingReport;
  const WeeklyReportFormScreen({
    super.key,
    required this.project,
    required this.logger,
    this.existingReport,
  });
  @override
  State<WeeklyReportFormScreen> createState() => _WeeklyReportFormScreenState();
}
class _WeeklyReportFormScreenState extends State<WeeklyReportFormScreen> {
  // ── form key ──────────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _contractCtrl = TextEditingController();
  final _buildingCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _percentageCtrl = TextEditingController(text: '0');
  final _scrollCtrl = ScrollController();
  // ── state ─────────────────────────────────────────────────────
  late String _reportId;
  // Week range — default to current Mon–Sun
  late DateTime _weekStart;
  late DateTime _weekEnd;
  String _subContractor = '';
  List<String> _subcontractorNames = [];
  // Activity table rows — 5 default rows each, user can add more
  late List<ActivityRow> _slopedRows;
  late List<ActivityRow> _flatRows;
  PlutoGridStateManager? slopedGridManager;
  PlutoGridStateManager? flatGridManager;
  final List<Uint8List> _localImages = [];
  final List<String> _savedImageUrls = [];
  bool _isSaving = false;
  bool _isGeneratingPdf = false;
  // ── design constants ─────────────────────────────────────────
  static const _navy = Color(0xFF0A2E5A);
  static const _fieldBorder = Color(0xFFB0BEC5);
  // ── cache key ─────────────────────────────────────────────────
  String get _cacheKey =>
      'weekly_report_draft_${widget.project.id}_$_reportId';
  // ─────────────────────────────────────────────────────────────
  // LIFECYCLE
  // ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    widget.logger.i('📋 WeeklyForm: initState START project=${widget.project.name}');
    _reportId = widget.existingReport?.id ?? const Uuid().v4();
    _extractSubcontractors();
    // Default week: most recent Monday → Sunday
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(monday.year, monday.month, monday.day);
    _weekEnd = _weekStart.add(const Duration(days: 6));
    if (widget.existingReport != null) {
      _loadFromExisting(widget.existingReport!);
    } else {
      _slopedRows = WeeklyReportData._defaultRows();
      _flatRows = WeeklyReportData._defaultRows();
      _loadDraftFromCache();
    }
    widget.logger.i('📋 WeeklyForm: initState END reportId=$_reportId');
  }
  void _extractSubcontractors() {
    _subcontractorNames = widget.project.teamMembers
        .where((m) => m.role.toLowerCase() == 'subcontractor')
        .map((m) => m.name)
        .toList();
    widget.logger.d('📋 WeeklyForm: subcontractors → $_subcontractorNames');
  }
  void _loadFromExisting(WeeklyReportData r) {
    _contractCtrl.text = r.contractNumber;
    _buildingCtrl.text = r.building;
    _notesCtrl.text = r.notes;
    _percentageCtrl.text = r.percentageDone.toStringAsFixed(0);
    _weekStart = r.weekStart;
    _weekEnd = r.weekEnd;
    _subContractor = r.subContractor;
    _savedImageUrls.addAll(r.imageUrls);
    _slopedRows = r.slopedRoofRows;
    _flatRows = r.flatRoofRows;
    widget.logger.i('📋 WeeklyForm: loaded from existing report');
  }
  @override
  void dispose() {
    widget.logger.i('📋 WeeklyForm: dispose');
    _contractCtrl.dispose();
    _buildingCtrl.dispose();
    _notesCtrl.dispose();
    _percentageCtrl.dispose();
    _scrollCtrl.dispose();
    slopedGridManager?.dispose();
    flatGridManager?.dispose();
    super.dispose();
  }
  // ─────────────────────────────────────────────────────────────
  // CACHE
  // ─────────────────────────────────────────────────────────────
  Future<void> _saveDraftToCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'contractNumber': _contractCtrl.text,
        'building': _buildingCtrl.text,
        'weekStart': _weekStart.toIso8601String(),
        'weekEnd': _weekEnd.toIso8601String(),
        'subContractor': _subContractor,
        'slopedRoofRows': _slopedRows.map((r) => r.toMap()).toList(),
        'flatRoofRows': _flatRows.map((r) => r.toMap()).toList(),
        'notes': _notesCtrl.text,
        'percentage': _percentageCtrl.text,
        'imageUrls': _savedImageUrls,
      };
      await prefs.setString(_cacheKey, jsonEncode(data));
      widget.logger.d('📋 WeeklyForm: draft cached');
    } catch (e) {
      widget.logger.w('⚠️ WeeklyForm: cache save failed – $e');
    }
  }
  Future<void> _loadDraftFromCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return;
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _contractCtrl.text = data['contractNumber'] ?? '';
        _buildingCtrl.text = data['building'] ?? '';
        _notesCtrl.text = data['notes'] ?? '';
        _percentageCtrl.text = data['percentage'] ?? '0';
        if (data['weekStart'] != null) {
          _weekStart = DateTime.parse(data['weekStart']);
        }
        if (data['weekEnd'] != null) {
          _weekEnd = DateTime.parse(data['weekEnd']);
        }
        _subContractor = data['subContractor'] ?? '';
        _savedImageUrls.clear();
        _savedImageUrls.addAll(List<String>.from(data['imageUrls'] ?? []));
        // Restore table rows
        if (data['slopedRoofRows'] != null) {
          _slopedRows = (data['slopedRoofRows'] as List)
              .map((e) => ActivityRow.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
        if (data['flatRoofRows'] != null) {
          _flatRows = (data['flatRoofRows'] as List)
              .map((e) => ActivityRow.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList();
        }
      });
      widget.logger.i('📋 WeeklyForm: draft restored from cache');
    } catch (e, st) {
      widget.logger.e('❌ WeeklyForm: cache load failed', error: e, stackTrace: st);
    }
  }
  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
  }
  // ─────────────────────────────────────────────────────────────
  // TABLE ROW MANAGEMENT
  // ─────────────────────────────────────────────────────────────
  void _addRow(bool isSloped) {
    setState(() {
      final rows = isSloped ? _slopedRows : _flatRows;
      final manager = isSloped ? slopedGridManager : flatGridManager;
      if (manager == null) return;
      rows.add(ActivityRow());
      manager.appendRows([
        PlutoRow(
          cells: {
            'no': PlutoCell(value: '${rows.length}'),
            'activity': PlutoCell(value: ''),
            'progress': PlutoCell(value: ''),
            'comment': PlutoCell(value: ''),
          },
        )
      ]);
    });
    _saveDraftToCache();
  }
  void _removeRow(bool isSloped, int index) {
    setState(() {
      final rows = isSloped ? _slopedRows : _flatRows;
      final manager = isSloped ? slopedGridManager : flatGridManager;
      if (manager == null || rows.length <= 1) return;
      rows.removeAt(index);
      manager.removeRows([manager.rows[index]]);
      // Update No. for remaining rows
      for (int i = 0; i < manager.rows.length; i++) {
        manager.rows[i].cells['no']!.value = '${i + 1}';
      }
    });
    _saveDraftToCache();
  }
  // ─────────────────────────────────────────────────────────────
  // PICKERS
  // ─────────────────────────────────────────────────────────────
  Future<void> _pickWeekStart() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekStart,
      firstDate: DateTime(2020),
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
      _weekStart = picked;
      // Auto-set end to 6 days later if it's before start
      if (_weekEnd.isBefore(_weekStart)) {
        _weekEnd = _weekStart.add(const Duration(days: 6));
      }
    });
    _saveDraftToCache();
  }
  Future<void> _pickWeekEnd() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _weekEnd.isBefore(_weekStart)
          ? _weekStart.add(const Duration(days: 6))
          : _weekEnd,
      firstDate: _weekStart,
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
    setState(() => _weekEnd = picked);
    _saveDraftToCache();
  }
  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.poppins()),
      backgroundColor: Colors.red[700],
    ));
  }
  // ─────────────────────────────────────────────────────────────
  // IMAGES
  // ─────────────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;
    for (final xf in picked) {
      final bytes = await xf.readAsBytes();
      setState(() => _localImages.add(bytes));
    }
    widget.logger.i('📋 WeeklyForm: ${picked.length} image(s) added');
  }
  // ─────────────────────────────────────────────────────────────
  // SAVE
  // ─────────────────────────────────────────────────────────────
  Future<WeeklyReportData> _buildReportData() async {
    // Upload local images
    final List<String> allUrls = List.from(_savedImageUrls);
    for (int i = 0; i < _localImages.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child('Reports')
          .child('Weekly')
          .child('images')
          .child('${_reportId}_img_$i.jpg');
      await ref.putData(
          _localImages[i], SettableMetadata(contentType: 'image/jpeg'));
      allUrls.add(await ref.getDownloadURL());
    }
    return WeeklyReportData(
      id: _reportId,
      projectId: widget.project.id,
      projectName: widget.project.name,
      contractNumber: _contractCtrl.text.trim(),
      weekStart: _weekStart,
      weekEnd: _weekEnd,
      subContractor: _subContractor,
      building: _buildingCtrl.text.trim(),
      slopedRoofRows: _slopedRows,
      flatRoofRows: _flatRows,
      notes: _notesCtrl.text.trim(),
      percentageDone: double.tryParse(_percentageCtrl.text) ?? 0,
      imageUrls: allUrls,
      isDraft: false,
    );
  }
  Future<void> _saveReport({bool silent = false}) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      await _saveDraftToCache();
      final report = await _buildReportData();
      final map = report.toMap();
      if (widget.existingReport == null) {
        await FirebaseFirestore.instance
            .collection('Reports')
            .doc(_reportId)
            .set(map);
      } else {
        await FirebaseFirestore.instance
            .collection('Reports')
            .doc(_reportId)
            .update(map);
      }
      await _clearCache();
      _localImages.clear();
      widget.logger.i('✅ WeeklyForm: report saved id=$_reportId');
      if (!silent && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Weekly report saved successfully.',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e, st) {
      widget.logger.e('❌ WeeklyForm: save failed', error: e, stackTrace: st);
      if (mounted) _showError('Error saving report: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
  // ─────────────────────────────────────────────────────────────
  // PDF GENERATION
  // ─────────────────────────────────────────────────────────────
  // Ruled blank lines for empty printed sections
  List<pw.Widget> _writingLines(int count, {double spacing = 22}) =>
      List.generate(
        count,
        (_) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.SizedBox(height: spacing - 0.5),
            pw.Container(height: 0.5, color: PdfColors.grey400),
          ],
        ),
      );
  // Build a PDF table for one roof section
  pw.Widget _buildPdfTable(
    String label,
    List<ActivityRow> rows,
    pw.TextStyle headerStyle,
    pw.TextStyle cellStyle,
    PdfColor navyColor,
    PdfColor lightBlue,
  ) {
    final headers = ['No.', 'Activity', 'Progress', 'Comment'];
    final colWidths = [0.07, 0.28, 0.25, 0.40]; // fractions of table width
    // Header row
    pw.Widget headerRow = pw.Row(
      children: List.generate(headers.length, (ci) {
        return pw.Expanded(
          flex: (colWidths[ci] * 100).round(),
          child: pw.Container(
            color: navyColor,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 4, vertical: 4),
            child: pw.Text(headers[ci], style: headerStyle),
          ),
        );
      }),
    );
    // Data rows — if all rows are empty, render writing lines instead
    final hasData = rows.any((r) =>
        r.activity.isNotEmpty ||
        r.progress.isNotEmpty ||
        r.comment.isNotEmpty);
    List<pw.Widget> dataRows = [];
    if (hasData) {
      for (int i = 0; i < rows.length; i++) {
        final r = rows[i];
        final bg = i.isEven ? PdfColors.white : PdfColor.fromHex('#F5F7FA');
        dataRows.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // No.
              pw.Expanded(
                flex: (colWidths[0] * 100).round(),
                child: pw.Container(
                  color: bg,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 5),
                  child: pw.Text('${i + 1}', style: cellStyle),
                ),
              ),
              // Activity
              pw.Expanded(
                flex: (colWidths[1] * 100).round(),
                child: pw.Container(
                  color: bg,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 5),
                  child: pw.Text(r.activity, style: cellStyle),
                ),
              ),
              // Progress
              pw.Expanded(
                flex: (colWidths[2] * 100).round(),
                child: pw.Container(
                  color: bg,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 5),
                  child: pw.Text(r.progress, style: cellStyle),
                ),
              ),
              // Comment
              pw.Expanded(
                flex: (colWidths[3] * 100).round(),
                child: pw.Container(
                  color: bg,
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 5),
                  child: pw.Text(r.comment, style: cellStyle),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      // Blank printed form — writing lines inside each cell row
      for (int i = 0; i < rows.length; i++) {
        dataRows.add(
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Expanded(
                flex: (colWidths[0] * 100).round(),
                child: pw.Container(
                  padding: const pw.EdgeInsets.symmetric(
                      horizontal: 4, vertical: 10),
                  child: pw.Text('${i + 1}', style: cellStyle),
                ),
              ),
              ...List.generate(3, (ci) {
                return pw.Expanded(
                  flex: (colWidths[ci + 1] * 100).round(),
                  child: pw.Container(
                    padding: const pw.EdgeInsets.only(
                        left: 4, right: 4, bottom: 6, top: 6),
                    child: pw.Container(
                        height: 0.5, color: PdfColors.grey400),
                  ),
                );
              }),
            ],
          ),
        );
      }
    }
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        // Sub-section label (SLOPED ROOF / FLAT ROOF)
        pw.Container(
          width: double.infinity,
          color: lightBlue,
          padding: const pw.EdgeInsets.symmetric(
              horizontal: 8, vertical: 4),
          child: pw.Text(
            label,
            style: pw.TextStyle(
              font: pw.Font.helveticaBold(),
              fontSize: 8.5,
              color: PdfColor.fromHex('#0A2E5A'),
              letterSpacing: 0.3,
            ),
          ),
        ),
        pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(
                color: PdfColors.blueGrey300, width: 0.5),
          ),
          child: pw.Column(
            children: [
              headerRow,
              ...dataRows,
            ],
          ),
        ),
      ],
    );
  }
  Future<void> _savePdfBytes(Uint8List bytes, String fileName) async {
    widget.logger.i(
        '📋 WeeklyForm: _savePdfBytes platform=${kIsWeb ? "web" : defaultTargetPlatform.name}');
    if (kIsWeb) {
      await Printing.sharePdf(bytes: bytes, filename: fileName);
      return;
    }
    try {
      String dirPath;
      if (defaultTargetPlatform == TargetPlatform.android) {
        const androidDownloads = '/storage/emulated/0/Download';
        if (await Directory(androidDownloads).exists()) {
          dirPath = androidDownloads;
        } else {
          final ext = await getExternalStorageDirectory();
          if (ext != null) {
            final parts = ext.path.split('/');
            final idx = parts.indexOf('Android');
            final base = idx > 0
                ? parts.sublist(0, idx).join('/')
                : ext.path;
            dirPath = '$base/Download';
          } else {
            dirPath = (await getApplicationDocumentsDirectory()).path;
          }
        }
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        dirPath = (await getApplicationDocumentsDirectory()).path;
      } else {
        final homeDir = Platform.environment['USERPROFILE']
            ?? Platform.environment['HOME'];
        if (homeDir != null && homeDir.isNotEmpty) {
          dirPath = '$homeDir${Platform.pathSeparator}Downloads';
        } else {
          dirPath = (await getApplicationDocumentsDirectory()).path;
        }
      }
      final dir = Directory(dirPath);
      if (!await dir.exists()) await dir.create(recursive: true);
      final filePath = '$dirPath${Platform.pathSeparator}$fileName';
      await File(filePath).writeAsBytes(bytes);
      widget.logger.i('✅ WeeklyForm: PDF saved → $filePath');
      await OpenFile.open(filePath);
      final currentContext = context;
      if (!currentContext.mounted) return;
      ScaffoldMessenger.of(currentContext).showSnackBar(SnackBar(
        content: Text('PDF saved to Downloads: $fileName',
            style: GoogleFonts.poppins()),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 4),
      ));
    } catch (e, st) {
      widget.logger.e('❌ WeeklyForm: PDF save failed – falling back to share',
          error: e, stackTrace: st);
      await Printing.sharePdf(bytes: bytes, filename: fileName);
    }
  }
  Future<void> _downloadAsPdf() async {
    widget.logger.i('📋 WeeklyForm: _downloadAsPdf START');
    setState(() => _isGeneratingPdf = true);
    try {
      final report = await _buildReportData();
      final fileName =
          'Weekly_Report_${report.projectName.replaceAll(' ', '_')}_'
          '${DateFormat('yyyyMMdd').format(_weekStart)}.pdf';
      final List<pw.MemoryImage> pdfImages = [];
      for (final bytes in _localImages) {
        pdfImages.add(pw.MemoryImage(bytes));
      }
      // ── Styles ───────────────────────────────────────────────
      final navyColor = PdfColor.fromHex('#0A2E5A');
      final lightBlue = PdfColor.fromHex('#E8EEF6');
      final sectionHeaderStyle = pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 9.5,
        color: PdfColors.white,
        letterSpacing: 0.5,
      );
      final tableHeaderStyle = pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 8,
        color: PdfColors.white,
      );
      final cellStyle = pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: 8.5,
        color: PdfColors.black,
      );
      final fieldLabelStyle = pw.TextStyle(
        font: pw.Font.helveticaBold(),
        fontSize: 8,
        color: navyColor,
        letterSpacing: 0.3,
      );
      final fieldValueStyle = pw.TextStyle(
        font: pw.Font.helvetica(),
        fontSize: 9,
        color: PdfColors.black,
      );
      // ── Helpers ───────────────────────────────────────────────
      pw.Widget sectionBar(String label) => pw.Container(
            width: double.infinity,
            color: navyColor,
            padding: const pw.EdgeInsets.symmetric(
                horizontal: 8, vertical: 5),
            child: pw.Text(label, style: sectionHeaderStyle),
          );
      // Meta cell (week dates, building, etc.)
      pw.Widget metaCellFilled(String label, String value) =>
          pw.Expanded(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: PdfColors.blueGrey300, width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    color: lightBlue,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3),
                    child: pw.Text(label, style: fieldLabelStyle),
                  ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 5),
                    child: pw.Text(
                      value.isEmpty ? '' : value,
                      style: fieldValueStyle,
                    ),
                  ),
                ],
              ),
            ),
          );
      pw.Widget metaCellBlank(String label) => pw.Expanded(
            child: pw.Container(
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: PdfColors.blueGrey300, width: 0.5)),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Container(
                    width: double.infinity,
                    color: lightBlue,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 5, vertical: 3),
                    child: pw.Text(label, style: fieldLabelStyle),
                  ),
                  pw.SizedBox(height: 20),
                ],
              ),
            ),
          );
      final isFilled = report.building.isNotEmpty ||
          report.slopedRoofRows.any((r) => r.activity.isNotEmpty) ||
          report.flatRoofRows.any((r) => r.activity.isNotEmpty);
      final pdf = pw.Document();
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 48),
          // ── FOOTER — every page ───────────────────────────────
          footer: (ctx) => pw.Container(
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(
                    color: PdfColors.grey400, width: 0.5),
              ),
            ),
            padding: const pw.EdgeInsets.only(top: 4),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  '© JV Almacis Site Management System — Weekly Report',
                  style: pw.TextStyle(
                      font: pw.Font.helvetica(),
                      fontSize: 7,
                      color: PdfColors.grey600),
                ),
                pw.Text(
                  'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                  style: pw.TextStyle(
                      font: pw.Font.helvetica(),
                      fontSize: 7,
                      color: PdfColors.grey600),
                ),
              ],
            ),
          ),
          build: (ctx) => [
            // ══ TITLE BLOCK ══════════════════════════════════════
            pw.Container(
              width: double.infinity,
              color: navyColor,
              padding: const pw.EdgeInsets.fromLTRB(16, 14, 16, 2),
              child: pw.Text(
                report.projectName,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 14,
                  color: PdfColors.white,
                ),
              ),
            ),
            pw.Container(
              width: double.infinity,
              color: navyColor,
              padding: const pw.EdgeInsets.symmetric(
                  horizontal: 16, vertical: 4),
              child: pw.Text(
                'WEEKLY REPORT',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: pw.Font.helveticaBold(),
                  fontSize: 10,
                  color: PdfColors.white,
                  letterSpacing: 2.5,
                ),
              ),
            ),
            pw.Container(
              width: double.infinity,
              color: navyColor,
              padding: const pw.EdgeInsets.fromLTRB(16, 2, 16, 12),
              child: pw.Text(
                'Contract No: ${report.contractNumber.isEmpty ? '' : report.contractNumber}',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 8.5,
                  color: PdfColor.fromHex('#FFFFFFB3'),
                ),
              ),
            ),
            pw.SizedBox(height: 10),
            // ══ WEEK RANGE + BUILDING META ROW ═══════════════════
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                isFilled
                    ? metaCellFilled('WEEK START',
                        DateFormat('EEE, MMM d, yyyy').format(report.weekStart))
                    : metaCellBlank('WEEK START'),
                pw.SizedBox(width: 4),
                isFilled
                    ? metaCellFilled('WEEK END',
                        DateFormat('EEE, MMM d, yyyy').format(report.weekEnd))
                    : metaCellBlank('WEEK END'),
                pw.SizedBox(width: 4),
                isFilled
                    ? metaCellFilled('BUILDING', report.building)
                    : metaCellBlank('BUILDING'),
              ],
            ),
            pw.SizedBox(height: 6),
            // ══ SUB-CONTRACTOR ════════════════════════════════════
            ...[
              sectionBar('SUB-CONTRACTOR'),
              pw.Container(
                width: double.infinity,
                decoration: pw.BoxDecoration(
                    border: pw.Border.all(
                        color: PdfColors.blueGrey300, width: 0.5)),
                padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: report.subContractor.isEmpty
                    ? pw.Column(
                        children: _writingLines(2))
                    : pw.Text(report.subContractor,
                        style: fieldValueStyle),
              ),
              pw.SizedBox(height: 8),
            ],
            // ══ ACTIVITIES TEMPLATE ═══════════════════════════════
            sectionBar('ACTIVITIES TEMPLATE'),
            pw.SizedBox(height: 4),
            // SLOPED ROOF table
            _buildPdfTable(
              'SLOPED ROOF',
              report.slopedRoofRows,
              tableHeaderStyle,
              cellStyle,
              navyColor,
              lightBlue,
            ),
            pw.SizedBox(height: 8),
            // FLAT ROOF table
            _buildPdfTable(
              'FLAT ROOF',
              report.flatRoofRows,
              tableHeaderStyle,
              cellStyle,
              navyColor,
              lightBlue,
            ),
            pw.SizedBox(height: 8),
            // ══ NOTES ════════════════════════════════════════════
            sectionBar('NOTES'),
            pw.Container(
              width: double.infinity,
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: PdfColors.blueGrey300, width: 0.5)),
              padding: const pw.EdgeInsets.fromLTRB(8, 6, 8, 8),
              child: report.notes.isEmpty
                  ? pw.Column(children: _writingLines(5))
                  : pw.Text(report.notes, style: fieldValueStyle),
            ),
            pw.SizedBox(height: 8),
            // ══ PERCENTAGE OF WORK DONE ═══════════════════════════
            pw.Container(
              decoration: pw.BoxDecoration(
                  border: pw.Border.all(
                      color: PdfColors.blueGrey300, width: 0.5)),
              child: pw.Row(
                children: [
                  pw.Container(
                    color: lightBlue,
                    padding: const pw.EdgeInsets.symmetric(
                        horizontal: 8, vertical: 10),
                    child: pw.Text(
                      'PERCENTAGE OF WORK DONE',
                      style: pw.TextStyle(
                        font: pw.Font.helveticaBold(),
                        fontSize: 8.5,
                        color: navyColor,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Text(
                    report.percentageDone > 0
                        ? '${report.percentageDone.toStringAsFixed(0)}%'
                        : '',
                    style: pw.TextStyle(
                      font: pw.Font.helveticaBold(),
                      fontSize: 12,
                      color: navyColor,
                    ),
                  ),
                  pw.Expanded(child: pw.SizedBox()),
                ],
              ),
            ),
            pw.SizedBox(height: 8),
            // ══ ATTACHED IMAGES ══════════════════════════════════
            if (pdfImages.isNotEmpty) ...[
              sectionBar('ATTACHED IMAGES'),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pdfImages
                    .map((img) => pw.Image(img,
                        width: 155, height: 116, fit: pw.BoxFit.cover))
                    .toList(),
              ),
            ],
          ],
        ),
      );
      final bytes = await pdf.save();
      await _savePdfBytes(Uint8List.fromList(bytes), fileName);
      widget.logger.i('✅ WeeklyForm: PDF done $fileName');
    } catch (e, st) {
      widget.logger.e('❌ WeeklyForm: PDF failed', error: e, stackTrace: st);
      if (mounted) _showError('Error generating PDF: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }
  // ─────────────────────────────────────────────────────────────
  // NEW FORM
  // ─────────────────────────────────────────────────────────────
  Future<void> _addNewForm() async {
    await _saveReport(silent: true);
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16)),
        title: Text('New Weekly Report',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'Current form saved. Start a fresh weekly report?',
            style: GoogleFonts.poppins()),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins())),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: _navy, foregroundColor: Colors.white),
            child: Text('New Form', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => WeeklyReportFormScreen(
          project: widget.project,
          logger: widget.logger,
        ),
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.project.name} — Weekly Report',
          style:
              GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            await _saveDraftToCache();

            // This uses context.mounted (the exact guard the linter wants for BuildContext after await)
            if (!context.mounted) return;

            Navigator.of(context).pop();
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final aw = constraints.maxWidth;
          final contentW = aw.clamp(0.0, 860.0);
          final hPad = contentW * 0.04;
          const gap = 14.0;
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollCtrl,
              padding: const EdgeInsets.only(bottom: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── HEADER BAND ──────────────────────────────
                  _buildFormHeader(),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: gap),
                        // ── WEEKLY REPORT TITLE ──────────────
                        _buildReportTypeTitle(),
                        const SizedBox(height: gap),
                        // ── WEEK DATE RANGE (2 columns) ──────
                        _buildWeekDateRow(contentW),
                        const SizedBox(height: gap),
                        // ── BUILDING ─────────────────────────
                        _buildBuildingField(),
                        const SizedBox(height: gap),
                        // ── SUB-CONTRACTOR ───────────────────
                        _buildSubContractorSection(contentW),
                        const SizedBox(height: gap),
                        // ── ACTIVITIES TEMPLATE ──────────────
                        _buildActivitiesTemplate(contentW),
                        const SizedBox(height: gap),
                        // ── NOTES ────────────────────────────
                        _buildNotesSection(),
                        const SizedBox(height: gap),
                        // ── PERCENTAGE ───────────────────────
                        _buildPercentageSection(),
                        const SizedBox(height: gap),
                        // ── IMAGES ───────────────────────────
                        _buildImageSection(contentW),
                        const SizedBox(height: 20),
                        // ── ACTION BUTTONS ───────────────────
                        _buildActionButtons(),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  // ═══════════════════════════════════════════════════════════════
  // WIDGET BUILDERS
  // ═══════════════════════════════════════════════════════════════
  // ── Form header (full-width navy band) ───────────────────────
  Widget _buildFormHeader() {
    return Container(
      color: _navy,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            widget.project.name,
            textAlign: TextAlign.center,
            softWrap: true,
            overflow: TextOverflow.visible,
            style: GoogleFonts.poppins(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.bold,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Contract No: ',
                  style: GoogleFonts.poppins(
                      color: Colors.white70, fontSize: 13)),
              SizedBox(
                width: 180,
                child: TextFormField(
                  controller: _contractCtrl,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.poppins(
                      color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'e.g. CN-2024-001',
                    hintStyle: GoogleFonts.poppins(
                        color: Colors.white38, fontSize: 12),
                    isDense: true,
                    border: const UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white54, width: 1)),
                    enabledBorder: const UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white54, width: 1)),
                    focusedBorder: const UnderlineInputBorder(
                        borderSide:
                            BorderSide(color: Colors.white, width: 1.5)),
                    contentPadding: const EdgeInsets.symmetric(
                        vertical: 4, horizontal: 2),
                  ),
                  onChanged: (_) => _saveDraftToCache(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  // ── "WEEKLY REPORT" centred subtitle ─────────────────────────
  Widget _buildReportTypeTitle() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'WEEKLY REPORT',
          style: GoogleFonts.poppins(
            color: _navy,
            fontSize: 18,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
      ),
    );
  }
  // ── Week-start / Week-end date pickers (2 equal columns) ─────
  Widget _buildWeekDateRow(double aw) {
    const double labelFs = 10.0;
    const double valueFs = 12.5;
    const double iconSz = 15.0;
    const double cellRad = 6.0;
    Widget dateCell({
      required String label,
      required DateTime date,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            height: 58,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(cellRad),
              border: Border.all(color: _fieldBorder, width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 3,
                  offset: const Offset(0, 1),
                )
              ],
            ),
            padding: const EdgeInsets.symmetric(
                horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(children: [
                  const Icon(Icons.calendar_today_rounded,
                      color: _navy, size: iconSz),
                  const SizedBox(width: 4),
                  Text(label,
                      style: GoogleFonts.poppins(
                        fontSize: labelFs,
                        fontWeight: FontWeight.w600,
                        color: _navy.withValues(alpha: 0.7),
                        letterSpacing: 0.3,
                      )),
                ]),
                const SizedBox(height: 3),
                Text(
                  DateFormat('EEE, MMM d, yyyy').format(date),
                  style: GoogleFonts.poppins(
                    fontSize: valueFs,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      );
    }
    return Row(children: [
      dateCell(
          label: 'WEEK START',
          date: _weekStart,
          onTap: _pickWeekStart),
      const SizedBox(width: 8),
      dateCell(
          label: 'WEEK END',
          date: _weekEnd,
          onTap: _pickWeekEnd),
    ]);
  }
  // ── Building field ────────────────────────────────────────────
  Widget _buildBuildingField() {
    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _fieldBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 100,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EEF6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
            ),
            child: Text('BUILDING',
                style: GoogleFonts.poppins(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  letterSpacing: 0.5,
                )),
          ),
          Expanded(
            child: Center(
              child: TextFormField(
                controller: _buildingCtrl,
                textAlignVertical: TextAlignVertical.center,
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'[a-zA-Z0-9\s\-_/]'))
                ],
                style: GoogleFonts.poppins(
                    fontSize: 13, color: Colors.black87),
                decoration: InputDecoration(
                  hintText: 'Building number, ID, or name…',
                  hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400], fontSize: 12),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 14),
                ),
                onChanged: (_) => _saveDraftToCache(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ── Sub-contractor section ────────────────────────────────────
  Widget _buildSubContractorSection(double aw) {
    const double radius = 8.0;
    const double valueFs = 13.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _fieldBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitleBar('SUB-CONTRACTOR', radius),
          Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: _subcontractorNames.isEmpty
                ? Text('No sub-contractors added to this project.',
                    style: GoogleFonts.poppins(
                        color: Colors.grey[500], fontSize: valueFs))
                : DropdownButtonFormField<String>(
                    key: ValueKey(_subContractor),
                    // ignore: deprecated_member_use
                    value:
                        _subContractor.isEmpty ? null : _subContractor,
                    hint: Text('Select sub-contractor…',
                        style: GoogleFonts.poppins(
                            color: Colors.grey[400], fontSize: valueFs)),
                    isExpanded: true,
                    decoration: InputDecoration(
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: _fieldBorder, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            BorderSide(color: _fieldBorder, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(6),
                        borderSide:
                            const BorderSide(color: _navy, width: 1.5),
                      ),
                    ),
                    style: GoogleFonts.poppins(
                        fontSize: valueFs, color: Colors.black87),
                    items: _subcontractorNames
                        .map((n) => DropdownMenuItem(
                            value: n,
                            child: Text(n,
                                style: GoogleFonts.poppins(
                                    fontSize: valueFs))))
                        .toList(),
                    onChanged: (v) {
                      setState(() => _subContractor = v ?? '');
                      _saveDraftToCache();
                    },
                  ),
          ),
        ],
      ),
    );
  }
  // ── Activities Template (two roof tables) ─────────────────────
  Widget _buildActivitiesTemplate(double aw) {
    const double radius = 8.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _fieldBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title
          _sectionTitleBar('ACTIVITIES TEMPLATE', radius),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── SLOPED ROOF ──────────────────────────────
                _buildRoofSubHeader('SLOPED ROOF'),
                const SizedBox(height: 6),
                _buildActivityTable(isSloped: true),
                const SizedBox(height: 16),
                // ── FLAT ROOF ────────────────────────────────
                _buildRoofSubHeader('FLAT ROOF'),
                const SizedBox(height: 6),
                _buildActivityTable(isSloped: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
  // Sub-header chip for each roof section
  Widget _buildRoofSubHeader(String label) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFE8EEF6),
        borderRadius: BorderRadius.circular(4),
      ),
      padding:
          const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Text(
        label,
        style: GoogleFonts.poppins(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: _navy,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
  List<PlutoColumn> _buildColumns() => [
        PlutoColumn(
          title: 'No.',
          field: 'no',
          type: PlutoColumnType.text(),
          readOnly: true,
          width: 60,
        ),
        PlutoColumn(
          title: 'Activity',
          field: 'activity',
          type: PlutoColumnType.text(),
        ),
        PlutoColumn(
          title: 'Progress',
          field: 'progress',
          type: PlutoColumnType.text(),
        ),
        PlutoColumn(
          title: 'Comment',
          field: 'comment',
          type: PlutoColumnType.text(),
        ),
      ];
  List<PlutoRow> _buildPlutoRows(List<ActivityRow> rows) {
    return rows.asMap().entries.map((entry) {
      int index = entry.key;
      ActivityRow row = entry.value;
      return PlutoRow(
        cells: {
          'no': PlutoCell(value: '${index + 1}'),
          'activity': PlutoCell(value: row.activity),
          'progress': PlutoCell(value: row.progress),
          'comment': PlutoCell(value: row.comment),
        },
      );
    }).toList();
  }
  void _onGridChanged(PlutoGridOnChangedEvent event, bool isSloped) {
    final rows = isSloped ? _slopedRows : _flatRows;
    final rowIdx = event.rowIdx;
    final field = event.column.field;
    final value = event.value as String;
    if (field == 'activity') {
      rows[rowIdx].activity = value;
    } else if (field == 'progress') {
      rows[rowIdx].progress = value;
    } else if (field == 'comment') {
      rows[rowIdx].comment = value;
    }
    _saveDraftToCache();
  }
  // Activity table widget — using PlutoGrid
  Widget _buildActivityTable({
    required bool isSloped,
  }) {
    final rows = isSloped ? _slopedRows : _flatRows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border.all(color: _fieldBorder, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          height: 300, // Adjustable height for the grid
          child: PlutoGrid(
            columns: _buildColumns(),
            rows: _buildPlutoRows(rows),
            onLoaded: (PlutoGridOnLoadedEvent event) {
              if (isSloped) {
                slopedGridManager = event.stateManager;
              } else {
                flatGridManager = event.stateManager;
              }
            },
            onChanged: (event) => _onGridChanged(event, isSloped),
            configuration: PlutoGridConfiguration(
              style: PlutoGridStyleConfig(
                gridBackgroundColor: Colors.white,
                rowColor: Colors.white,
                activatedColor: _navy.withValues(alpha: 0.1),
                borderColor: _fieldBorder,
                activatedBorderColor: _navy,
                columnTextStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _navy,
                ),
                cellTextStyle: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.black87,
                ),
              ),
            ),
          ),
        ),
        // Row controls
        const SizedBox(height: 6),
        Row(
          children: [
            TextButton.icon(
              onPressed: () => _addRow(isSloped),
              icon: const Icon(Icons.add_rounded, size: 14),
              label: Text('Add Row',
                  style: GoogleFonts.poppins(fontSize: 11)),
              style: TextButton.styleFrom(
                foregroundColor: _navy,
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
              ),
            ),
            const SizedBox(width: 8),
            if (rows.length > 1)
              TextButton.icon(
                onPressed: () =>
                    _removeRow(isSloped, rows.length - 1),
                icon: const Icon(Icons.remove_rounded, size: 14),
                label: Text('Remove Last',
                    style: GoogleFonts.poppins(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red[700],
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                ),
              ),
          ],
        ),
      ],
    );
  }
  // ── Notes section (max 4–5 lines) ─────────────────────────────
  Widget _buildNotesSection() {
    const double radius = 8.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _fieldBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _sectionTitleBar('NOTES', radius),
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextFormField(
              controller: _notesCtrl,
              maxLines: 5,
              minLines: 3,
              maxLength: 800,
              style:
                  GoogleFonts.poppins(fontSize: 13, color: Colors.black87),
              decoration: InputDecoration(
                hintText: 'Enter any additional notes…',
                hintStyle: GoogleFonts.poppins(
                    color: Colors.grey[400], fontSize: 12),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _fieldBorder, width: 1),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: BorderSide(color: _fieldBorder, width: 1),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(6),
                  borderSide: const BorderSide(color: _navy, width: 1.5),
                ),
                counterStyle:
                    GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
              ),
              onChanged: (_) => _saveDraftToCache(),
            ),
          ),
        ],
      ),
    );
  }
  // ── Percentage of work done ────────────────────────────────────
  Widget _buildPercentageSection() {
    return Container(
      height: 58,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _fieldBorder, width: 1),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Label tab
          Container(
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Color(0xFFE8EEF6),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(6),
                bottomLeft: Radius.circular(6),
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Text(
              'PERCENTAGE OF WORK DONE',
              style: GoogleFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: _navy,
                letterSpacing: 0.3,
              ),
            ),
          ),
          // Value input
          SizedBox(
            width: 100,
            child: Center(
              child: TextFormField(
                controller: _percentageCtrl,
                textAlign: TextAlign.center,
                textAlignVertical: TextAlignVertical.center,
                keyboardType: const TextInputType.numberWithOptions(
                    decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(
                      RegExp(r'^\d{0,3}\.?\d{0,2}')),
                ],
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                ),
                decoration: InputDecoration(
                  hintText: '0',
                  hintStyle: GoogleFonts.poppins(
                      color: Colors.grey[400], fontSize: 20),
                  suffixText: '%',
                  suffixStyle: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _navy,
                  ),
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 14),
                ),
                validator: (v) {
                  final val = double.tryParse(v ?? '');
                  if (val == null) return 'Enter a number';
                  if (val < 0 || val > 100) return '0–100';
                  return null;
                },
                onChanged: (_) => _saveDraftToCache(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  // ── Image attachments ─────────────────────────────────────────
  Widget _buildImageSection(double aw) {
    final allImages = [
      ..._localImages.map((b) => _WImageItem(bytes: b)),
      ..._savedImageUrls.map((u) => _WImageItem(url: u)),
    ];
    final double thumbSz = (aw * 0.24).clamp(80.0, 130.0);
    const double radius = 8.0;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _fieldBorder, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
              ),
            ),
            child: Row(children: [
              Text('ATTACHED IMAGES',
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      letterSpacing: 0.8)),
              const Spacer(),
              if (allImages.isNotEmpty)
                Text('${allImages.length} image(s)',
                    style: GoogleFonts.poppins(
                        color: Colors.white70, fontSize: 11)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              if (allImages.isNotEmpty) ...[
                SizedBox(
                  height: thumbSz,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allImages.length,
                    separatorBuilder: (_, __) =>
                        const SizedBox(width: 8),
                    itemBuilder: (ctx, i) {
                      final item = allImages[i];
                      return Stack(children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: item.bytes != null
                              ? Image.memory(item.bytes!,
                                  width: thumbSz,
                                  height: thumbSz,
                                  fit: BoxFit.cover)
                              : Image.network(item.url!,
                                  width: thumbSz,
                                  height: thumbSz,
                                  fit: BoxFit.cover),
                        ),
                        Positioned(
                          top: 4, right: 4,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              if (i < _localImages.length) {
                                _localImages.removeAt(i);
                              } else {
                                _savedImageUrls.removeAt(
                                    i - _localImages.length);
                              }
                            }),
                            child: Container(
                              decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle),
                              padding: const EdgeInsets.all(3),
                              child: const Icon(Icons.close,
                                  size: 12, color: Colors.white),
                            ),
                          ),
                        ),
                      ]);
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],
              OutlinedButton.icon(
                onPressed: _pickImages,
                icon: const Icon(
                    Icons.add_photo_alternate_rounded, size: 18),
                label: Text(
                  allImages.isEmpty
                      ? 'Attach Image(s)'
                      : 'Add More Images',
                  style: GoogleFonts.poppins(fontSize: 13),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20, vertical: 10),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
  // ── Action buttons ────────────────────────────────────────────
  Widget _buildActionButtons() {
    Widget btn({
      required String label,
      required IconData icon,
      required Color color,
      required bool isLoading,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: SizedBox(
          height: 44,
          child: ElevatedButton.icon(
            onPressed: isLoading ? null : onTap,
            icon: isLoading
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white)))
                : Icon(icon, size: 16),
            label: Text(label,
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            style: ElevatedButton.styleFrom(
              backgroundColor: color,
              foregroundColor: Colors.white,
              disabledBackgroundColor: color.withValues(alpha: 0.5),
              disabledForegroundColor: Colors.white70,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6)),
              padding: const EdgeInsets.symmetric(
                  vertical: 0, horizontal: 12),
              elevation: 2,
            ),
          ),
        ),
      );
    }
    return Row(children: [
      btn(
        label: 'Save Report',
        icon: Icons.save_rounded,
        color: _navy,
        isLoading: _isSaving,
        onTap: _saveReport,
      ),
      const SizedBox(width: 10),
      btn(
        label: 'Download PDF',
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFF1B5E20),
        isLoading: _isGeneratingPdf,
        onTap: _downloadAsPdf,
      ),
      const SizedBox(width: 10),
      btn(
        label: '+ New Form',
        icon: Icons.add_circle_outline_rounded,
        color: const Color(0xFF6A1B9A),
        isLoading: false,
        onTap: _addNewForm,
      ),
    ]);
  }
  // ── Shared section title bar builder ──────────────────────────
  Widget _sectionTitleBar(String title, double radius) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(radius),
          topRight: Radius.circular(radius),
        ),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 12,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
// ══════════════════════════════════════════════════════════════════
// HELPERS
// ══════════════════════════════════════════════════════════════════
class _WImageItem {
  final Uint8List? bytes;
  final String? url;
  _WImageItem({this.bytes, this.url});
}