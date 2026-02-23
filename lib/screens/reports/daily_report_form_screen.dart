import 'dart:convert';
import 'package:almaworks/models/project_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart' as quill;
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

// ══════════════════════════════════════════════════════════════════
//  DATA MODEL
// ══════════════════════════════════════════════════════════════════

class DailyReportData {
  final String id;
  final String projectId;
  final String projectName;
  String contractNumber;
  DateTime date;
  TimeOfDay? startTime;
  TimeOfDay? stopTime;
  String weather;
  String building;

  // Rich-text sections stored as Quill Delta JSON strings
  String visitorsJson;
  String subContractor;
  String personnelVehiclesJson;
  String activitiesJson;
  String remarksJson;

  List<String> imageUrls; // Firebase Storage URLs after upload
  List<Uint8List> localImages; // transient – picked but not yet uploaded
  bool isDraft;
  DateTime? savedAt;

  DailyReportData({
    required this.id,
    required this.projectId,
    required this.projectName,
    this.contractNumber = '',
    required this.date,
    this.startTime,
    this.stopTime,
    this.weather = '',
    this.building = '',
    this.visitorsJson = '',
    this.subContractor = '',
    this.personnelVehiclesJson = '',
    this.activitiesJson = '',
    this.remarksJson = '',
    this.imageUrls = const [],
    this.localImages = const [],
    this.isDraft = true,
    this.savedAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'projectId': projectId,
        'projectName': projectName,
        'contractNumber': contractNumber,
        'date': Timestamp.fromDate(date),
        'startTime': startTime != null
            ? '${startTime!.hour}:${startTime!.minute}'
            : null,
        'stopTime':
            stopTime != null ? '${stopTime!.hour}:${stopTime!.minute}' : null,
        'weather': weather,
        'building': building,
        'visitorsJson': visitorsJson,
        'subContractor': subContractor,
        'personnelVehiclesJson': personnelVehiclesJson,
        'activitiesJson': activitiesJson,
        'remarksJson': remarksJson,
        'imageUrls': imageUrls,
        'isDraft': isDraft,
        'savedAt': Timestamp.now(),
        'type': 'Daily',
      };

  static TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  factory DailyReportData.fromMap(Map<String, dynamic> m) => DailyReportData(
        id: m['id'] ?? '',
        projectId: m['projectId'] ?? '',
        projectName: m['projectName'] ?? '',
        contractNumber: m['contractNumber'] ?? '',
        date: (m['date'] as Timestamp).toDate(),
        startTime: _parseTime(m['startTime']),
        stopTime: _parseTime(m['stopTime']),
        weather: m['weather'] ?? '',
        building: m['building'] ?? '',
        visitorsJson: m['visitorsJson'] ?? '',
        subContractor: m['subContractor'] ?? '',
        personnelVehiclesJson: m['personnelVehiclesJson'] ?? '',
        activitiesJson: m['activitiesJson'] ?? '',
        remarksJson: m['remarksJson'] ?? '',
        imageUrls: List<String>.from(m['imageUrls'] ?? []),
        isDraft: m['isDraft'] ?? true,
        savedAt: m['savedAt'] != null ? (m['savedAt'] as Timestamp).toDate() : null,
      );
}

// ══════════════════════════════════════════════════════════════════
//  SCREEN
// ══════════════════════════════════════════════════════════════════

class DailyReportFormScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;
  /// Pass an existing report to open in edit mode; null = new form.
  final DailyReportData? existingReport;

  const DailyReportFormScreen({
    super.key,
    required this.project,
    required this.logger,
    this.existingReport,
  });

  @override
  State<DailyReportFormScreen> createState() => _DailyReportFormScreenState();
}

class _DailyReportFormScreenState extends State<DailyReportFormScreen> {
  // ── controllers ──────────────────────────────────────────────
  final _formKey = GlobalKey<FormState>();
  final _contractController = TextEditingController();
  final _buildingController = TextEditingController();
  final _scrollController = ScrollController();

  late quill.QuillController _visitorsCtrl;
  late quill.QuillController _personnelCtrl;
  late quill.QuillController _activitiesCtrl;
  late quill.QuillController _remarksCtrl;

  // ── state ─────────────────────────────────────────────────────
  late String _reportId;
  DateTime _date = DateTime.now();
  TimeOfDay? _startTime;
  TimeOfDay? _stopTime;
  String _weather = '';
  String _subContractor = '';
  final List<Uint8List> _localImages = [];
  final List<String> _savedImageUrls = [];
  bool _isSaving = false;
  bool _isGeneratingPdf = false;

  List<String> _subcontractorNames = [];

  static const List<String> _weatherOptions = [
    'Calm & Warm',
    'Chilly & Cold',
    'Hot',
    'Windy',
    'Rainy',
  ];

  // ── colours / constants ────────────────────────────────────────
  static const _navy = Color(0xFF0A2E5A);
  static const _fieldBorder = Color(0xFFB0BEC5);
  static const _sectionBg = Color(0xFFF5F7FA);

  // ── cache key ─────────────────────────────────────────────────
  String get _cacheKey =>
      'daily_report_draft_${widget.project.id}_$_reportId';

  @override
  void initState() {
    super.initState();
    widget.logger.i('📋 DailyForm: ── initState START ──');
    widget.logger.i('📋 DailyForm: project.id=${widget.project.id}  name=${widget.project.name}');
    widget.logger.i('📋 DailyForm: existingReport=${widget.existingReport?.id ?? 'null (new form)'}');

    _reportId = widget.existingReport?.id ?? const Uuid().v4();
    widget.logger.i('📋 DailyForm: reportId=$_reportId');

    _extractSubcontractors();

    if (widget.existingReport != null) {
      widget.logger.i('📋 DailyForm: initState: loading existing report data');
      _loadFromExisting(widget.existingReport!);
    } else {
      widget.logger.d('📋 DailyForm: initState: new form – creating blank Quill controllers');
      try {
        _visitorsCtrl   = quill.QuillController.basic();
        widget.logger.d('📋 DailyForm: _visitorsCtrl  OK');
        _personnelCtrl  = quill.QuillController.basic();
        widget.logger.d('📋 DailyForm: _personnelCtrl OK');
        _activitiesCtrl = quill.QuillController.basic();
        widget.logger.d('📋 DailyForm: _activitiesCtrl OK');
        _remarksCtrl    = quill.QuillController.basic();
        widget.logger.d('📋 DailyForm: _remarksCtrl  OK');
      } catch (e, st) {
        widget.logger.e('❌ DailyForm: ERROR creating blank Quill controllers', error: e, stackTrace: st);
      }
      widget.logger.d('📋 DailyForm: initState: calling _loadDraftFromCache');
      _loadDraftFromCache();
    }
    widget.logger.i('📋 DailyForm: ── initState END ──');
  }

  void _extractSubcontractors() {
    widget.logger.d('📋 DailyForm: _extractSubcontractors: teamMembers.length=${widget.project.teamMembers.length}');
    _subcontractorNames = widget.project.teamMembers
        .where((m) => m.role.toLowerCase() == 'subcontractor')
        .map((m) => m.name)
        .toList();
    widget.logger.i('📋 DailyForm: _extractSubcontractors: found ${_subcontractorNames.length} → $_subcontractorNames');
  }

  void _loadFromExisting(DailyReportData r) {
    widget.logger.i('📋 DailyForm: _loadFromExisting: id=${r.id}');
    _contractController.text = r.contractNumber;
    _buildingController.text = r.building;
    _date = r.date;
    _startTime = r.startTime;
    _stopTime = r.stopTime;
    _weather = r.weather;
    _subContractor = r.subContractor;
    _savedImageUrls.addAll(r.imageUrls);
    widget.logger.i('📋 DailyForm: _loadFromExisting: basic fields loaded. imageUrls.count=${r.imageUrls.length}');

    widget.logger.d('📋 DailyForm: _loadFromExisting: creating visitorsCtrl from visitorsJson (len=${r.visitorsJson.length})');
    _visitorsCtrl   = _quillFromJson('visitors',  r.visitorsJson);
    widget.logger.d('📋 DailyForm: _loadFromExisting: creating personnelCtrl from personnelVehiclesJson (len=${r.personnelVehiclesJson.length})');
    _personnelCtrl  = _quillFromJson('personnel', r.personnelVehiclesJson);
    widget.logger.d('📋 DailyForm: _loadFromExisting: creating activitiesCtrl from activitiesJson (len=${r.activitiesJson.length})');
    _activitiesCtrl = _quillFromJson('activities', r.activitiesJson);
    widget.logger.d('📋 DailyForm: _loadFromExisting: creating remarksCtrl from remarksJson (len=${r.remarksJson.length})');
    _remarksCtrl    = _quillFromJson('remarks',   r.remarksJson);
    widget.logger.i('📋 DailyForm: _loadFromExisting: all Quill controllers ready');
  }

  quill.QuillController _quillFromJson(String fieldKey, String json) {
    widget.logger.d('📋 DailyForm: _quillFromJson [$fieldKey]: json.length=${json.length}');
    if (json.isEmpty) {
      widget.logger.d('📋 DailyForm: _quillFromJson [$fieldKey]: empty JSON → returning basic controller');
      return quill.QuillController.basic();
    }
    try {
      final decoded = jsonDecode(json);
      widget.logger.d('📋 DailyForm: _quillFromJson [$fieldKey]: decoded type=${decoded.runtimeType}');
      if (decoded is! List) {
        widget.logger.w('⚠️ DailyForm: _quillFromJson [$fieldKey]: decoded is NOT a List – returning basic controller');
        return quill.QuillController.basic();
      }
      final doc = quill.Document.fromJson(decoded);
      widget.logger.d('📋 DailyForm: _quillFromJson [$fieldKey]: Document.fromJson OK');
      final ctrl = quill.QuillController(
        document: doc,
        selection: const TextSelection.collapsed(offset: 0),
      );
      widget.logger.d('📋 DailyForm: _quillFromJson [$fieldKey]: QuillController created OK');
      return ctrl;
    } catch (e, st) {
      widget.logger.e('❌ DailyForm: _quillFromJson [$fieldKey]: EXCEPTION – falling back to basic', error: e, stackTrace: st);
      return quill.QuillController.basic();
    }
  }

  // ── local cache ───────────────────────────────────────────────
  Future<void> _saveDraftToCache() async {
    widget.logger.d('📋 DailyForm: _saveDraftToCache: cacheKey=$_cacheKey');
    try {
      final prefs = await SharedPreferences.getInstance();
      final data = {
        'contractNumber': _contractController.text,
        'building': _buildingController.text,
        'date': _date.toIso8601String(),
        'startTime': _startTime != null
            ? '${_startTime!.hour}:${_startTime!.minute}'
            : null,
        'stopTime': _stopTime != null
            ? '${_stopTime!.hour}:${_stopTime!.minute}'
            : null,
        'weather': _weather,
        'subContractor': _subContractor,
        'visitorsJson': jsonEncode(_visitorsCtrl.document.toDelta().toJson()),
        'personnelVehiclesJson':
            jsonEncode(_personnelCtrl.document.toDelta().toJson()),
        'activitiesJson':
            jsonEncode(_activitiesCtrl.document.toDelta().toJson()),
        'remarksJson': jsonEncode(_remarksCtrl.document.toDelta().toJson()),
        'imageUrls': _savedImageUrls,
      };
      await prefs.setString(_cacheKey, jsonEncode(data));
      widget.logger.d('📋 DailyForm: _saveDraftToCache: saved OK');
    } catch (e) {
      widget.logger.w('⚠️ DailyForm: _saveDraftToCache: FAILED – $e');
    }
  }

  Future<void> _loadDraftFromCache() async {
    widget.logger.d('📋 DailyForm: _loadDraftFromCache: cacheKey=$_cacheKey');
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) {
        widget.logger.d('📋 DailyForm: _loadDraftFromCache: no cached data found');
        return;
      }
      widget.logger.i('📋 DailyForm: _loadDraftFromCache: cache hit – raw.length=${raw.length}');
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _contractController.text = data['contractNumber'] ?? '';
        _buildingController.text = data['building'] ?? '';
        if (data['date'] != null) _date = DateTime.parse(data['date']);
        _startTime = _parseTime(data['startTime']);
        _stopTime = _parseTime(data['stopTime']);
        _weather = data['weather'] ?? '';
        _subContractor = data['subContractor'] ?? '';
        _savedImageUrls.clear();
        _savedImageUrls.addAll(List<String>.from(data['imageUrls'] ?? []));
      });
      widget.logger.i('📋 DailyForm: _loadDraftFromCache: basic fields restored');
      // Re-build Quill controllers from cached JSON AFTER setState
      _visitorsCtrl   = _quillFromJson('visitors_cache',  data['visitorsJson'] ?? '');
      _personnelCtrl  = _quillFromJson('personnel_cache', data['personnelVehiclesJson'] ?? '');
      _activitiesCtrl = _quillFromJson('activities_cache', data['activitiesJson'] ?? '');
      _remarksCtrl    = _quillFromJson('remarks_cache',   data['remarksJson'] ?? '');
      widget.logger.i('📋 DailyForm: _loadDraftFromCache: Quill controllers restored from cache');
    } catch (e, st) {
      widget.logger.e('❌ DailyForm: _loadDraftFromCache: FAILED', error: e, stackTrace: st);
    }
  }

  Future<void> _clearCache() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_cacheKey);
    widget.logger.d('📋 DailyForm: _clearCache: cache cleared for key=$_cacheKey');
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // ── time validation ───────────────────────────────────────────
  /// Working hours: 06:00 – 19:00
  bool _isWithinWorkingHours(TimeOfDay t) =>
      (t.hour > 5) && (t.hour < 19 || (t.hour == 19 && t.minute == 0));

  // ── pickers ───────────────────────────────────────────────────
  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      widget.logger.i('📋 DailyForm: date picked → ${picked.toIso8601String()}');
      setState(() => _date = picked);
    }
  }

  Future<void> _pickTime({required bool isStart}) async {
    final initial = isStart
        ? (_startTime ?? const TimeOfDay(hour: 7, minute: 0))
        : (_stopTime ?? const TimeOfDay(hour: 16, minute: 0));

    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              const ColorScheme.light(primary: _navy, onPrimary: Colors.white),
        ),
        child: child!,
      ),
    );
    if (picked == null) return;

    if (!_isWithinWorkingHours(picked)) {
      widget.logger.w('⚠️ DailyForm: time out of working hours → ${picked.hour}:${picked.minute}');
      _showError(
          'Time must be between 06:00 AM and 07:00 PM (working hours only).');
      return;
    }
    if (!isStart && _startTime != null) {
      final s = _startTime!.hour * 60 + _startTime!.minute;
      final e = picked.hour * 60 + picked.minute;
      if (e <= s) {
        widget.logger.w('⚠️ DailyForm: stop time not after start time');
        _showError('Stop time must be after start time.');
        return;
      }
    }
    if (isStart && _stopTime != null) {
      final s = picked.hour * 60 + picked.minute;
      final e = _stopTime!.hour * 60 + _stopTime!.minute;
      if (s >= e) {
        widget.logger.w('⚠️ DailyForm: start time not before stop time');
        _showError('Start time must be before stop time.');
        return;
      }
    }
    widget.logger.i('📋 DailyForm: ${isStart ? 'startTime' : 'stopTime'} set → ${picked.hour}:${picked.minute}');
    setState(() => isStart ? _startTime = picked : _stopTime = picked);
  }

  void _showError(String msg) => ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg, style: GoogleFonts.poppins()),
          backgroundColor: Colors.red[700],
        ),
      );

  // ── images ────────────────────────────────────────────────────
  Future<void> _pickImages() async {
    widget.logger.d('📋 DailyForm: _pickImages: opening image picker');
    final picker = ImagePicker();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) {
      widget.logger.d('📋 DailyForm: _pickImages: no images selected');
      return;
    }
    widget.logger.i('📋 DailyForm: _pickImages: ${picked.length} image(s) selected');
    for (final xfile in picked) {
      final bytes = await xfile.readAsBytes();
      setState(() => _localImages.add(bytes));
    }
    widget.logger.i('📋 DailyForm: _pickImages: total local images now=${_localImages.length}');
  }

  // ── save to Firestore ─────────────────────────────────────────
  Future<DailyReportData> _buildReportData() async {
    widget.logger.d('📋 DailyForm: _buildReportData: uploading ${_localImages.length} local image(s)');
    // Upload any local images first
    final List<String> allUrls = List.from(_savedImageUrls);
    for (int i = 0; i < _localImages.length; i++) {
      final ref = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child('Reports')
          .child('Daily')
          .child('images')
          .child('${_reportId}_img_$i.jpg');
      await ref.putData(_localImages[i],
          SettableMetadata(contentType: 'image/jpeg'));
      final url = await ref.getDownloadURL();
      widget.logger.d('📋 DailyForm: _buildReportData: image[$i] uploaded → $url');
      allUrls.add(url);
    }
    widget.logger.i('📋 DailyForm: _buildReportData: all images uploaded, total urls=${allUrls.length}');

    return DailyReportData(
      id: _reportId,
      projectId: widget.project.id,
      projectName: widget.project.name,
      contractNumber: _contractController.text.trim(),
      date: _date,
      startTime: _startTime,
      stopTime: _stopTime,
      weather: _weather,
      building: _buildingController.text.trim(),
      visitorsJson: jsonEncode(_visitorsCtrl.document.toDelta().toJson()),
      subContractor: _subContractor,
      personnelVehiclesJson:
          jsonEncode(_personnelCtrl.document.toDelta().toJson()),
      activitiesJson: jsonEncode(_activitiesCtrl.document.toDelta().toJson()),
      remarksJson: jsonEncode(_remarksCtrl.document.toDelta().toJson()),
      imageUrls: allUrls,
      isDraft: false,
      savedAt: DateTime.now(),
    );
  }

  Future<void> _saveReport({bool silent = false}) async {
    if (_isSaving) return;
    widget.logger.i('📋 DailyForm: _saveReport: START (silent=$silent, reportId=$_reportId)');
    setState(() => _isSaving = true);
    try {
      await _saveDraftToCache();
      final report = await _buildReportData();
      final map = report.toMap();
      if (widget.existingReport == null) {
        widget.logger.i('📋 DailyForm: _saveReport: creating new Firestore doc');
        await FirebaseFirestore.instance
            .collection('Reports')
            .doc(_reportId)
            .set(map);
      } else {
        widget.logger.i('📋 DailyForm: _saveReport: updating existing Firestore doc');
        await FirebaseFirestore.instance
            .collection('Reports')
            .doc(_reportId)
            .update(map);
      }
      await _clearCache();
      _localImages.clear();
      widget.logger.i('✅ DailyForm: _saveReport: saved successfully (id=$_reportId)');
      if (!silent && mounted) {
        // ignore: use_build_context_synchronously
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Daily report saved successfully.', style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e, st) {
      widget.logger.e('❌ DailyForm: _saveReport: FAILED', error: e, stackTrace: st);
      if (mounted) _showError('Error saving report: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── PDF generation ────────────────────────────────────────────
  String _quillToPlainText(quill.QuillController ctrl) {
    return ctrl.document.toPlainText().trim();
  }

  Future<void> _downloadAsPdf() async {
    widget.logger.i('📋 DailyForm: _downloadAsPdf: START');
    setState(() => _isGeneratingPdf = true);
    try {
      final report = await _buildReportData();
      widget.logger.d('📋 DailyForm: _downloadAsPdf: report data built, generating PDF');
      final pdf = pw.Document();
      final dateStr = DateFormat('MMMM d, yyyy').format(report.date);

      // ── local helper: format TimeOfDay for PDF display ──
      String fmtTime(TimeOfDay? t) {
        if (t == null) return '—';
        final h = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
        final m = t.minute.toString().padLeft(2, '0');
        final period = t.period == DayPeriod.am ? 'AM' : 'PM';
        return '$h:$m $period';
      }

      // Load images for PDF
      final List<pw.MemoryImage> pdfImages = [];
      for (final bytes in _localImages) {
        pdfImages.add(pw.MemoryImage(bytes));
      }
      widget.logger.d('📋 DailyForm: _downloadAsPdf: ${pdfImages.length} image(s) added to PDF');

      // ── PDF styles ──
      final headerStyle = pw.TextStyle(
        fontSize: 11,
        fontWeight: pw.FontWeight.bold,
        color: PdfColors.white,
      );
      final labelStyle = pw.TextStyle(
        fontSize: 9,
        fontWeight: pw.FontWeight.bold,
        color: PdfColor.fromHex('#0A2E5A'),
      );
      final valueStyle = pw.TextStyle(fontSize: 9, color: PdfColors.black);

      // ── PDF helper functions (no leading underscores) ──
      pw.Widget labeledBox(String label, String value, {double height = 40}) {
        return pw.Container(
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                color: PdfColor.fromHex('#E8EEF6'),
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                child: pw.Text(label, style: labelStyle),
              ),
              pw.Container(
                height: height,
                width: double.infinity,
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text(value, style: valueStyle),
              ),
            ],
          ),
        );
      }

      pw.Widget richBox(String label, String plainText, {double height = 70}) {
        return pw.Container(
          margin: const pw.EdgeInsets.only(bottom: 8),
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.5),
          ),
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Container(
                width: double.infinity,
                color: PdfColor.fromHex('#0A2E5A'),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text(label, style: headerStyle),
              ),
              pw.Container(
                width: double.infinity,
                constraints: pw.BoxConstraints(minHeight: height),
                padding: const pw.EdgeInsets.all(8),
                child: pw.Text(
                  plainText.isEmpty ? ' ' : plainText,
                  style: valueStyle,
                ),
              ),
            ],
          ),
        );
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(28),
          header: (ctx) => pw.Container(
            decoration: pw.BoxDecoration(
              color: PdfColor.fromHex('#0A2E5A'),
              borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
            ),
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        report.projectName,
                        style: pw.TextStyle(
                          color: PdfColors.white,
                          fontSize: 12,
                          fontWeight: pw.FontWeight.bold,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'Contract No: ${report.contractNumber.isEmpty ? '—' : report.contractNumber}',
                        style: pw.TextStyle(
                          color: PdfColor.fromHex('#FFFFFFB3'),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: pw.BoxDecoration(
                    color: PdfColors.white,
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Text(
                    'DAILY REPORT',
                    style: pw.TextStyle(
                      color: PdfColor.fromHex('#0A2E5A'),
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          footer: (ctx) => pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text(
                '© JV Alma C.I.S Site Management System',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
              ),
              pw.Text(
                'Page ${ctx.pageNumber} of ${ctx.pagesCount}',
                style: pw.TextStyle(fontSize: 7, color: PdfColors.grey),
              ),
            ],
          ),
          build: (ctx) => [
            pw.SizedBox(height: 12),

            // ── Date / Time / Weather row ──
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(flex: 3, child: labeledBox('DATE', dateStr, height: 40)),
                pw.SizedBox(width: 6),
                pw.Expanded(
                  flex: 2,
                  child: pw.Column(children: [
                    labeledBox('START TIME', fmtTime(_startTime), height: 16),
                    labeledBox('STOP TIME', fmtTime(_stopTime), height: 16),
                  ]),
                ),
                pw.SizedBox(width: 6),
                pw.Expanded(flex: 3, child: labeledBox('WEATHER', report.weather, height: 40)),
              ],
            ),
            pw.SizedBox(height: 8),

            // ── Building ──
            pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blueGrey300, width: 0.5),
              ),
              child: pw.Row(children: [
                pw.Container(
                  color: PdfColor.fromHex('#E8EEF6'),
                  padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  child: pw.Text('BUILDING', style: labelStyle),
                ),
                pw.Expanded(
                  child: pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                    child: pw.Text(
                      report.building.isEmpty ? '—' : report.building,
                      style: valueStyle,
                    ),
                  ),
                ),
              ]),
            ),
            pw.SizedBox(height: 8),

            // ── Rich sections ──
            richBox('VISITORS', _quillToPlainText(_visitorsCtrl)),
            richBox('SUB-CONTRACTOR', report.subContractor.isEmpty ? '—' : report.subContractor),
            richBox('PERSONNEL AND VEHICLES', _quillToPlainText(_personnelCtrl)),
            richBox('ACTIVITIES', _quillToPlainText(_activitiesCtrl)),
            richBox('REMARKS', _quillToPlainText(_remarksCtrl)),

            // ── Images ──
            if (pdfImages.isNotEmpty) ...[
              pw.Container(
                width: double.infinity,
                color: PdfColor.fromHex('#0A2E5A'),
                padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                child: pw.Text('ATTACHED IMAGES', style: headerStyle),
              ),
              pw.SizedBox(height: 6),
              pw.Wrap(
                spacing: 8,
                runSpacing: 8,
                children: pdfImages
                    .map((img) => pw.Image(img, width: 160, height: 120, fit: pw.BoxFit.cover))
                    .toList(),
              ),
            ],
          ],
        ),
      );

      widget.logger.d('📋 DailyForm: _downloadAsPdf: PDF pages built, calling Printing.layoutPdf');
      await Printing.layoutPdf(
        onLayout: (_) async => pdf.save(),
        name:
            'Daily_Report_${widget.project.name}_${DateFormat('yyyyMMdd').format(_date)}.pdf',
      );
      widget.logger.i('✅ DailyForm: _downloadAsPdf: PDF export complete');
    } catch (e, st) {
      widget.logger.e('❌ DailyForm: _downloadAsPdf: FAILED', error: e, stackTrace: st);
      if (mounted) _showError('Error generating PDF: $e');
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // ── new form (save current + reset) ──────────────────────────
  Future<void> _addNewForm() async {
    widget.logger.i('📋 DailyForm: _addNewForm: saving current form before reset');
    await _saveReport(silent: true);
    if (!mounted) return;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('New Daily Report',
            style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(
            'Your current form has been saved. Start a fresh daily report?',
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
    if (confirm != true || !mounted) {
      widget.logger.d('📋 DailyForm: _addNewForm: user cancelled new form dialog');
      return;
    }

    widget.logger.i('📋 DailyForm: _addNewForm: user confirmed – pushing fresh form screen');
    // Push a fresh screen instance
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => DailyReportFormScreen(
          project: widget.project,
          logger: widget.logger,
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    widget.logger.d('📋 DailyForm: build()');
    return Scaffold(
      backgroundColor: const Color(0xFFF0F4F8),
      appBar: AppBar(
        backgroundColor: _navy,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(
          '${widget.project.name} — Daily Report',
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 16),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () async {
            final nav = Navigator.of(context);
            widget.logger.d('📋 DailyForm: back pressed – saving draft');
            await _saveDraftToCache();
            nav.pop();
          },
        ),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final aw = constraints.maxWidth;
          final hPad = aw * 0.045;
          final gap  = aw * 0.032;
          widget.logger.d('📋 DailyForm: LayoutBuilder: availableWidth=$aw  hPad=$hPad  gap=$gap');

          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              controller: _scrollController,
              padding: EdgeInsets.symmetric(horizontal: hPad, vertical: aw * 0.04),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── FORM HEADER ──────────────────────────────
                  _buildFormHeader(aw),
                  SizedBox(height: gap),

                  // ── REPORT TYPE SUBTITLE ─────────────────────
                  _buildReportTypeTitle(aw),
                  SizedBox(height: gap),

                  // ── DATE / TIME / WEATHER ────────────────────
                  _buildDateTimeWeatherRow(aw),
                  SizedBox(height: gap),

                  // ── BUILDING ─────────────────────────────────
                  _buildBuildingField(aw),
                  SizedBox(height: gap),

                  // ── VISITORS ─────────────────────────────────
                  _buildRichSection(
                    title: 'VISITORS',
                    fieldKey: 'visitors',
                    hint: 'Enter visitor names (press Enter for auto-numbering)…',
                    controller: _visitorsCtrl,
                    aw: aw,
                  ),
                  SizedBox(height: gap),

                  // ── SUB-CONTRACTOR ───────────────────────────
                  _buildSubContractorSection(aw),
                  SizedBox(height: gap),

                  // ── PERSONNEL AND VEHICLES ───────────────────
                  _buildRichSection(
                    title: 'PERSONNEL AND VEHICLES',
                    fieldKey: 'personnel',
                    hint: 'Enter personnel and vehicle details…',
                    controller: _personnelCtrl,
                    aw: aw,
                  ),
                  SizedBox(height: gap),

                  // ── ACTIVITIES ───────────────────────────────
                  _buildRichSection(
                    title: 'ACTIVITIES',
                    fieldKey: 'activities',
                    hint: 'Describe site activities for the day…',
                    controller: _activitiesCtrl,
                    aw: aw,
                  ),
                  SizedBox(height: gap),

                  // ── REMARKS ──────────────────────────────────
                  _buildRichSection(
                    title: 'REMARKS',
                    fieldKey: 'remarks',
                    hint: 'Add any remarks or observations…',
                    controller: _remarksCtrl,
                    aw: aw,
                  ),
                  SizedBox(height: gap),

                  // ── IMAGE ATTACHMENTS ─────────────────────────
                  _buildImageSection(aw),
                  SizedBox(height: gap * 1.4),

                  // ── ACTION BUTTONS ────────────────────────────
                  _buildActionButtons(aw),
                  SizedBox(height: gap * 2),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  //  WIDGET BUILDERS
  // ══════════════════════════════════════════════════════════════

  // ── Form header ───────────────────────────────────────────────
  Widget _buildFormHeader(double aw) {
    widget.logger.d('📋 DailyForm: _buildFormHeader → aw=$aw');
    final double titleFs = (aw * 0.048).clamp(15.0, 22.0);
    final double labelFs = (aw * 0.034).clamp(11.0, 15.0);
    final double padH    = aw * 0.050;
    final double padV    = aw * 0.038;
    final double radius  = aw * 0.025;
    return Container(
      decoration: BoxDecoration(
        color: _navy,
        borderRadius: BorderRadius.circular(radius),
      ),
      padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.project.name,
              style: GoogleFonts.poppins(
                  color: Colors.white,
                  fontSize: titleFs,
                  fontWeight: FontWeight.bold)),
          SizedBox(height: aw * 0.018),
          Row(children: [
            Text('Contract No: ',
                style: GoogleFonts.poppins(
                    color: Colors.white70, fontSize: labelFs)),
            Expanded(
              child: TextFormField(
                controller: _contractController,
                style: GoogleFonts.poppins(
                    color: Colors.white, fontSize: labelFs),
                decoration: InputDecoration(
                  hintText: 'Enter contract number',
                  hintStyle: GoogleFonts.poppins(
                      color: Colors.white38, fontSize: labelFs),
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
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                ),
                onChanged: (v) {
                  widget.logger.d('📋 DailyForm: contractNumber changed → "$v"');
                  _saveDraftToCache();
                },
              ),
            ),
          ]),
        ],
      ),
    );
  }

  // ── Report type title ─────────────────────────────────────────
  Widget _buildReportTypeTitle(double aw) {
    widget.logger.d('📋 DailyForm: _buildReportTypeTitle → aw=$aw');
    return Center(
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: aw * 0.08, vertical: aw * 0.025),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(
              color: _navy.withValues(alpha: 0.3), width: 1.5),
          borderRadius: BorderRadius.circular(aw * 0.020),
        ),
        child: Text('DAILY REPORT',
            style: GoogleFonts.poppins(
              color: _navy,
              fontSize: (aw * 0.048).clamp(14.0, 22.0),
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            )),
      ),
    );
  }

  // ── Date / Time / Weather row ─────────────────────────────────
  Widget _buildDateTimeWeatherRow(double aw) {
    widget.logger.d('📋 DailyForm: _buildDateTimeWeatherRow → aw=$aw');

    final double labelFs = (aw * 0.024).clamp(8.0, 11.0);
    final double valueFs = (aw * 0.032).clamp(10.0, 14.0);
    final double iconSz  = (aw * 0.044).clamp(14.0, 22.0);
    final double cellRad = aw * 0.022;
    final double cellPH  = aw * 0.028;
    final double cellPV  = aw * 0.026;

    final String dateStr = DateFormat('EEE, MMM d, yyyy').format(_date);
    String fmtTime(TimeOfDay? t) => t == null
        ? 'Tap to set'
        : '${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:'
            '${t.minute.toString().padLeft(2, '0')} '
            '${t.period == DayPeriod.am ? 'AM' : 'PM'}';

    widget.logger.d('📋 DailyForm: _buildDateTimeWeatherRow: '
        'date=$dateStr  start=${fmtTime(_startTime)}  '
        'stop=${fmtTime(_stopTime)}  weather="$_weather"');

    // ── reusable inline cell builder ──
    Widget cell({
      required String label,
      required String value,
      required IconData icon,
      required VoidCallback onTap,
    }) {
      return GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(cellRad),
            border: Border.all(color: _fieldBorder, width: 1),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 4,
                  offset: const Offset(0, 2))
            ],
          ),
          padding:
              EdgeInsets.symmetric(horizontal: cellPH, vertical: cellPV),
          child: Row(children: [
            Icon(icon, color: _navy, size: iconSz),
            SizedBox(width: aw * 0.018),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(label,
                      style: GoogleFonts.poppins(
                          fontSize: labelFs,
                          fontWeight: FontWeight.w600,
                          color: _navy.withValues(alpha: 0.7),
                          letterSpacing: 0.5)),
                  Text(value,
                      style: GoogleFonts.poppins(
                          fontSize: valueFs,
                          fontWeight: FontWeight.w500,
                          color: value == 'Tap to set'
                              ? Colors.grey[400]
                              : Colors.black87)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                color: Colors.grey[400], size: iconSz * 0.75),
          ]),
        ),
      );
    }

    final dateCell = cell(
        label: 'DATE',
        value: dateStr,
        icon: Icons.calendar_today_rounded,
        onTap: _pickDate);

    final timesCell = Column(children: [
      cell(
          label: 'START TIME',
          value: fmtTime(_startTime),
          icon: Icons.access_time_rounded,
          onTap: () => _pickTime(isStart: true)),
      SizedBox(height: aw * 0.015),
      cell(
          label: 'STOP TIME',
          value: fmtTime(_stopTime),
          icon: Icons.timer_off_rounded,
          onTap: () => _pickTime(isStart: false)),
    ]);

    final weatherCell = Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(cellRad),
        border: Border.all(color: _fieldBorder, width: 1),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2))
        ],
      ),
      padding: EdgeInsets.symmetric(horizontal: cellPH, vertical: cellPV),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('WEATHER',
              style: GoogleFonts.poppins(
                  fontSize: labelFs,
                  fontWeight: FontWeight.w600,
                  color: _navy.withValues(alpha: 0.7),
                  letterSpacing: 0.5)),
          SizedBox(height: aw * 0.010),
          DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: _weather.isEmpty ? null : _weather,
              hint: Text('Select…',
                  style: GoogleFonts.poppins(
                      color: Colors.grey[400], fontSize: valueFs)),
              isExpanded: true,
              icon: Icon(Icons.wb_sunny_rounded,
                  color: _navy, size: iconSz),
              style: GoogleFonts.poppins(
                  fontSize: valueFs, color: Colors.black87),
              items: _weatherOptions
                  .map((w) => DropdownMenuItem(
                      value: w,
                      child: Text(w,
                          style: GoogleFonts.poppins(fontSize: valueFs))))
                  .toList(),
              onChanged: (v) {
                widget.logger.i('📋 DailyForm: weather selected → "$v"');
                setState(() => _weather = v ?? '');
                _saveDraftToCache();
              },
            ),
          ),
        ],
      ),
    );

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 3, child: dateCell),
          SizedBox(width: aw * 0.020),
          Expanded(flex: 2, child: timesCell),
          SizedBox(width: aw * 0.020),
          Expanded(flex: 3, child: weatherCell),
        ],
      ),
    );
  }

  // ── Building field ────────────────────────────────────────────
  Widget _buildBuildingField(double aw) {
    widget.logger.d('📋 DailyForm: _buildBuildingField → aw=$aw');
    final double labelFs = (aw * 0.028).clamp(10.0, 13.0);
    final double valueFs = (aw * 0.034).clamp(11.0, 15.0);
    final double radius  = aw * 0.022;
    final double padH    = aw * 0.035;
    final double padV    = aw * 0.038;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: _fieldBorder, width: 1),
      ),
      child: Row(children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
          decoration: BoxDecoration(
            color: _navy.withValues(alpha: 0.07),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(radius),
              bottomLeft: Radius.circular(radius),
            ),
          ),
          child: Text('BUILDING',
              style: GoogleFonts.poppins(
                  fontSize: labelFs,
                  fontWeight: FontWeight.w700,
                  color: _navy,
                  letterSpacing: 0.5)),
        ),
        Expanded(
          child: TextFormField(
            controller: _buildingController,
            inputFormatters: [
              FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9\s\-_/]'))
            ],
            style: GoogleFonts.poppins(fontSize: valueFs),
            decoration: InputDecoration(
              hintText: 'Enter building number, ID, or name…',
              hintStyle: GoogleFonts.poppins(
                  color: Colors.grey[400], fontSize: valueFs * 0.93),
              border: InputBorder.none,
              contentPadding: EdgeInsets.symmetric(
                  horizontal: padH, vertical: padV),
            ),
            onChanged: (v) {
              widget.logger.d('📋 DailyForm: building changed → "$v"');
              _saveDraftToCache();
            },
          ),
        ),
      ]),
    );
  }

  // ── Rich-text section ─────────────────────────────────────────
  Widget _buildRichSection({
    required String fieldKey,
    required String title,
    required String hint,
    required quill.QuillController controller,
    required double aw,
  }) {
    widget.logger.d('📋 DailyForm: _buildRichSection[$fieldKey] → aw=$aw  controller.hashCode=${controller.hashCode}');

    final double titleFs   = (aw * 0.030).clamp(10.0, 14.0);
    final double editorFs  = (aw * 0.032).clamp(11.0, 14.0);
    final double minH      = (aw * 0.38).clamp(120.0, 300.0);
    final double radius    = aw * 0.022;
    final double titlePH   = aw * 0.035;
    final double titlePV   = aw * 0.025;
    final double editorPad = aw * 0.030;
    final double toolbarSz = (aw * 0.088).clamp(32.0, 44.0);

    try {
      // ── Toolbar ──────────────────────────────────────────────
      Widget toolbarWidget;
      try {
        widget.logger.d('📋 DailyForm: [$fieldKey] building QuillSimpleToolbar (toolbarSize=$toolbarSz)');
        toolbarWidget = quill.QuillSimpleToolbar(
          controller: controller,
          config: quill.QuillSimpleToolbarConfig(
            showBoldButton: true,
            showItalicButton: true,
            showUnderLineButton: true,
            showListBullets: true,
            showListNumbers: true,
            showIndent: true,
            showClearFormat: true,
            showFontSize: false,
            showFontFamily: false,
            showColorButton: false,
            showBackgroundColorButton: false,
            showSubscript: false,
            showSuperscript: false,
            showInlineCode: false,
            showCodeBlock: false,
            showQuote: false,
            showLink: false,
            showSearchButton: false,
            showAlignmentButtons: false,
            showHeaderStyle: false,
            showDividers: true,
            toolbarIconAlignment: WrapAlignment.start,
            toolbarSize: toolbarSz,
          ),
        );
        widget.logger.d('📋 DailyForm: [$fieldKey] QuillSimpleToolbar built OK');
      } catch (e, st) {
        widget.logger.e('❌ DailyForm: [$fieldKey] QuillSimpleToolbar FAILED', error: e, stackTrace: st);
        toolbarWidget = Container(
          color: Colors.amber[100],
          padding: EdgeInsets.all(editorPad),
          child: Text(
            '⚠ Toolbar error [$fieldKey] — see logs\n$e',
            style: GoogleFonts.poppins(
                color: Colors.red[800], fontSize: 11),
          ),
        );
      }

      // ── Editor ───────────────────────────────────────────────
      Widget editorWidget;
      try {
        widget.logger.d('📋 DailyForm: [$fieldKey] building QuillEditor (minH=$minH  fontSize=$editorFs)');
        editorWidget = Container(
          constraints: BoxConstraints(minHeight: minH),
          padding: EdgeInsets.all(editorPad),
          child: quill.QuillEditor.basic(
            controller: controller,
            config: quill.QuillEditorConfig(
              placeholder: hint,
              minHeight: minH,
              expands: false,
              scrollable: true,
              autoFocus: false,
              enableInteractiveSelection: true,
              customStyles: quill.DefaultStyles(
                placeHolder: quill.DefaultTextBlockStyle(
                  GoogleFonts.poppins(
                      color: Colors.grey[400], fontSize: editorFs),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(0, 0),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
                paragraph: quill.DefaultTextBlockStyle(
                  GoogleFonts.poppins(
                      color: Colors.black87, fontSize: editorFs),
                  const quill.HorizontalSpacing(0, 0),
                  const quill.VerticalSpacing(2, 2),
                  const quill.VerticalSpacing(0, 0),
                  null,
                ),
              ),
            ),
          ),
        );
        widget.logger.d('📋 DailyForm: [$fieldKey] QuillEditor built OK');
      } catch (e, st) {
        widget.logger.e('❌ DailyForm: [$fieldKey] QuillEditor FAILED', error: e, stackTrace: st);
        editorWidget = Container(
          constraints: BoxConstraints(minHeight: minH),
          color: Colors.red[50],
          padding: EdgeInsets.all(editorPad),
          child: Text(
            '⚠ Editor error [$fieldKey] — see logs\n$e',
            style: GoogleFonts.poppins(
                color: Colors.red[800], fontSize: 11),
          ),
        );
      }

      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
          border: Border.all(color: _fieldBorder, width: 1),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 4,
                offset: const Offset(0, 2))
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(
                  horizontal: titlePH, vertical: titlePV),
              decoration: BoxDecoration(
                color: _navy,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(radius),
                  topRight: Radius.circular(radius),
                ),
              ),
              child: Text(title,
                  style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: titleFs,
                      letterSpacing: 0.8)),
            ),
            Container(
              decoration: BoxDecoration(
                color: _sectionBg,
                border: Border(
                    bottom: BorderSide(color: _fieldBorder, width: 0.5)),
              ),
              child: toolbarWidget,
            ),
            editorWidget,
          ],
        ),
      );
    } catch (e, st) {
      widget.logger.e('❌ DailyForm: [$fieldKey] section container FAILED', error: e, stackTrace: st);
      return Container(
        padding: EdgeInsets.all(aw * 0.04),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.red, width: 1.5),
          borderRadius: BorderRadius.circular(aw * 0.022),
          color: Colors.red[50],
        ),
        child: Text(
          '⚠ Section "$title" failed to render — see logs\n$e',
          style: GoogleFonts.poppins(color: Colors.red[800], fontSize: 11),
        ),
      );
    }
  }

  // ── Sub-contractor section ────────────────────────────────────
  Widget _buildSubContractorSection(double aw) {
    widget.logger.d('📋 DailyForm: _buildSubContractorSection → aw=$aw  names=${_subcontractorNames.length}');
    final double titleFs = (aw * 0.030).clamp(10.0, 14.0);
    final double valueFs = (aw * 0.032).clamp(11.0, 14.0);
    final double radius  = aw * 0.022;
    final double padH    = aw * 0.035;
    final double padV    = aw * 0.025;

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
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
              color: _navy,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(radius),
                topRight: Radius.circular(radius),
              ),
            ),
            child: Text('SUB-CONTRACTOR',
                style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: titleFs,
                    letterSpacing: 0.8)),
          ),
          Padding(
            padding: EdgeInsets.symmetric(
                horizontal: padH, vertical: aw * 0.030),
            child: _subcontractorNames.isEmpty
                ? Text(
                    'No sub-contractors added to this project.',
                    style: GoogleFonts.poppins(
                        color: Colors.grey[500], fontSize: valueFs),
                  )
                : DropdownButtonFormField<String>(
                    key: ValueKey(_subContractor),
                    initialValue:
                        _subContractor.isEmpty ? null : _subContractor,
                    hint: Text('Select sub-contractor…',
                        style: GoogleFonts.poppins(
                            color: Colors.grey[400], fontSize: valueFs)),
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: EdgeInsets.symmetric(
                          horizontal: aw * 0.030, vertical: aw * 0.025),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(aw * 0.018),
                        borderSide:
                            BorderSide(color: _fieldBorder, width: 1),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(aw * 0.018),
                        borderSide:
                            BorderSide(color: _fieldBorder, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(aw * 0.018),
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
                                style:
                                    GoogleFonts.poppins(fontSize: valueFs))))
                        .toList(),
                    onChanged: (v) {
                      widget.logger.i('📋 DailyForm: subContractor selected → "$v"');
                      setState(() => _subContractor = v ?? '');
                      _saveDraftToCache();
                    },
                  ),
          ),
        ],
      ),
    );
  }

  // ── Image attachments section ─────────────────────────────────
  Widget _buildImageSection(double aw) {
    final allImages = [
      ..._localImages.map((b) => _ImageItem(bytes: b)),
      ..._savedImageUrls.map((u) => _ImageItem(url: u)),
    ];
    widget.logger.d('📋 DailyForm: _buildImageSection → aw=$aw  local=${_localImages.length}  saved=${_savedImageUrls.length}');

    final double thumbSz = (aw * 0.24).clamp(80.0, 130.0);
    final double titleFs = (aw * 0.030).clamp(10.0, 14.0);
    final double radius  = aw * 0.022;
    final double padH    = aw * 0.035;
    final double padV    = aw * 0.025;

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
            padding: EdgeInsets.symmetric(horizontal: padH, vertical: padV),
            decoration: BoxDecoration(
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
                      fontSize: titleFs,
                      letterSpacing: 0.8)),
              const Spacer(),
              if (allImages.isNotEmpty)
                Text('${allImages.length} image(s)',
                    style: GoogleFonts.poppins(
                        color: Colors.white70,
                        fontSize: titleFs * 0.85)),
            ]),
          ),
          Padding(
            padding: EdgeInsets.all(padH),
            child: Column(children: [
              if (allImages.isNotEmpty) ...[
                SizedBox(
                  height: thumbSz,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: allImages.length,
                    separatorBuilder: (_, __) =>
                        SizedBox(width: aw * 0.020),
                    itemBuilder: (ctx, i) {
                      final item = allImages[i];
                      widget.logger.d('📋 DailyForm: image[$i] ${item.bytes != null ? "local" : "url"}');
                      return Stack(children: [
                        ClipRRect(
                          borderRadius:
                              BorderRadius.circular(radius * 0.6),
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
                            onTap: () {
                              widget.logger.i('📋 DailyForm: removing image[$i]');
                              setState(() {
                                if (i < _localImages.length) {
                                  _localImages.removeAt(i);
                                } else {
                                  _savedImageUrls.removeAt(
                                      i - _localImages.length);
                                }
                              });
                            },
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
                SizedBox(height: aw * 0.025),
              ],
              OutlinedButton.icon(
                onPressed: () {
                  widget.logger.d('📋 DailyForm: pick images tapped');
                  _pickImages();
                },
                icon: const Icon(
                    Icons.add_photo_alternate_rounded, size: 18),
                label: Text(
                  allImages.isEmpty ? 'Attach Image(s)' : 'Add More Images',
                  style: GoogleFonts.poppins(
                      fontSize: (aw * 0.032).clamp(11.0, 14.0)),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: _navy,
                  side: const BorderSide(color: _navy, width: 1.5),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(aw * 0.018)),
                  padding: EdgeInsets.symmetric(
                      horizontal: aw * 0.045, vertical: aw * 0.030),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }

  // ── Action buttons ────────────────────────────────────────────
  Widget _buildActionButtons(double aw) {
    widget.logger.d('📋 DailyForm: _buildActionButtons → aw=$aw');
    final double fs     = (aw * 0.032).clamp(11.0, 14.0);
    final double padV   = aw * 0.035;
    final double padH   = aw * 0.020;
    final double radius = aw * 0.022;
    final double iconSz = (aw * 0.040).clamp(14.0, 20.0);
    final double gap    = aw * 0.020;

    Widget btn({
      required String label,
      required IconData icon,
      required Color color,
      required bool isLoading,
      required VoidCallback onTap,
    }) {
      return Expanded(
        child: ElevatedButton.icon(
          onPressed: isLoading ? null : onTap,
          icon: isLoading
              ? SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          Colors.white)))
              : Icon(icon, size: iconSz),
          label: Text(label,
              style: GoogleFonts.poppins(
                  fontWeight: FontWeight.w600, fontSize: fs)),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            foregroundColor: Colors.white,
            disabledBackgroundColor: color.withValues(alpha: 0.5),
            disabledForegroundColor: Colors.white70,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(radius)),
            padding:
                EdgeInsets.symmetric(vertical: padV, horizontal: padH),
            elevation: 2,
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
        onTap: () {
          widget.logger.i('📋 DailyForm: Save Report tapped');
          _saveReport();
        },
      ),
      SizedBox(width: gap),
      btn(
        label: 'Download PDF',
        icon: Icons.picture_as_pdf_rounded,
        color: const Color(0xFF1B5E20),
        isLoading: _isGeneratingPdf,
        onTap: () {
          widget.logger.i('📋 DailyForm: Download PDF tapped');
          _downloadAsPdf();
        },
      ),
      SizedBox(width: gap),
      btn(
        label: '+ New Form',
        icon: Icons.add_circle_outline_rounded,
        color: const Color(0xFF6A1B9A),
        isLoading: false,
        onTap: () {
          widget.logger.i('📋 DailyForm: New Form tapped');
          _addNewForm();
        },
      ),
    ]);
  }

  @override
  void dispose() {
    widget.logger.i('📋 DailyForm: dispose()');
    _contractController.dispose();
    _buildingController.dispose();
    _scrollController.dispose();
    _visitorsCtrl.dispose();
    _personnelCtrl.dispose();
    _activitiesCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }
}

// ══════════════════════════════════════════════════════════════════
//  SMALL HELPERS
// ══════════════════════════════════════════════════════════════════

class _ImageItem {
  final Uint8List? bytes;
  final String? url;
  _ImageItem({this.bytes, this.url});
}