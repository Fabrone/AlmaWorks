import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/report_model.dart';
import 'package:almaworks/screens/reports/safety_form_screen.dart';
import 'package:almaworks/screens/reports/daily_report_form_screen.dart';
import 'package:almaworks/screens/reports/weekly_report_form_screen.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:almaworks/helpers/download_helper.dart';

class ReportsScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const ReportsScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  bool _isLoading = false;

  // Tab definitions: label, report type key
  static const _tabs = [
    {'label': 'Daily', 'type': 'Daily'},
    {'label': 'Weekly', 'type': 'Weekly'},
    {'label': 'Monthly', 'type': 'Monthly'},
    {'label': 'Safety Meetings', 'type': 'Safety'},
    {'label': 'Quality', 'type': 'Quality'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    widget.logger.i(
        '📊 ReportsScreen: Initialized for project: ${widget.project.name} (ID: ${widget.project.id})');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  // ─────────────────────────── BUILD ───────────────────────────

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: '${widget.project.name} - Reports',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Reports',
      onMenuItemSelected: (_) {},
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _handleUploadAction,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : const Icon(Icons.upload_file),
      ),
      child: Column(
        children: [
          // ── Tab Bar: fills evenly on wide screens, scrollable on mobile ──
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.1),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                // Breakpoint: ≥600 px → desktop/tablet mode (fill evenly)
                //             <600 px → mobile (scroll, show ~4 tabs at a time)
                final isMobile = constraints.maxWidth < 600;
                return TabBar(
                  controller: _tabController,
                  isScrollable: isMobile,
                  tabAlignment: isMobile
                      ? TabAlignment.start
                      : TabAlignment.fill,
                  labelColor: const Color(0xFF0A2E5A),
                  unselectedLabelColor: Colors.grey[600],
                  indicatorColor: const Color(0xFF0A2E5A),
                  labelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w600, fontSize: 13),
                  unselectedLabelStyle: GoogleFonts.poppins(
                      fontWeight: FontWeight.w400, fontSize: 13),
                  tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
                );
              },
            ),
          ),

          // ── Tab Views ──
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDocumentTab('Daily'),      // tab 0
                _buildDocumentTab('Weekly'),     // tab 1
                _buildDocumentTab('Monthly'),    // tab 2
                _buildSafetyTab(),               // tab 3 – Safety Meetings
                _buildDocumentTab('Quality'),    // tab 4
              ],
            ),
          ),

          _buildFooter(context),
        ],
      ),
    );
  }

  // ─────────────────────────── FOOTER ───────────────────────────

  Widget _buildFooter(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: const Color(0xFF0A2E5A),
      child: Text(
        '© 2026 JV Alma C.I.S Site Management System',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  // ─────────────────────── DOCUMENT TAB (Daily / Weekly / Monthly / Quality) ───

  Widget _buildDocumentTab(String type) {
    widget.logger.d(
        '📊 ReportsScreen: Fetching Reports (type: $type, projectId: ${widget.project.id})');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Reports')
          .where('projectId', isEqualTo: widget.project.id)
          .where('type', isEqualTo: type)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e(
              '❌ ReportsScreen: Error loading Reports ($type)',
              error: snapshot.error,
              stackTrace: snapshot.stackTrace);
          return Center(
            child: Text(
              'Error loading documents: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final documents = snapshot.data!.docs;
        widget.logger
            .i('📊 ReportsScreen: Loaded ${documents.length} Reports ($type)');

        if (documents.isEmpty) {
          return _buildEmptyState(type);
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('$type Reports'),
            const SizedBox(height: 16),
            ...documents.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final report = ReportModel.fromMap(doc.id, data);
                return _buildReportItem(report);
              } catch (e, st) {
                widget.logger.e(
                    '❌ ReportsScreen: Error parsing Report ${doc.id} ($type)',
                    error: e,
                    stackTrace: st);
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  // ─────────────────────── SAFETY MEETINGS TAB ───────────────────

  Widget _buildSafetyTab() {
    widget.logger.d(
        '📊 ReportsScreen: Fetching Safety Reports (projectId: ${widget.project.id})');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Reports')
          .where('projectId', isEqualTo: widget.project.id)
          .where('type', whereIn: ['SafetyWeekly', 'SafetyMonthly', 'Safety'])
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e(
              '❌ ReportsScreen: Error loading Safety Reports',
              error: snapshot.error,
              stackTrace: snapshot.stackTrace);
          return Center(
            child: Text(
              'Error loading safety reports: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final reports = snapshot.data!.docs;
        widget.logger
            .i('📊 ReportsScreen: Loaded ${reports.length} Safety Reports');

        if (reports.isEmpty) {
          return _buildEmptyState('Safety Meeting');
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildSectionHeader('Safety Meeting Reports'),
            const SizedBox(height: 16),
            ...reports.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final report = ReportModel.fromMap(doc.id, data);
                return _buildReportItem(report);
              } catch (e, st) {
                widget.logger.e(
                    '❌ ReportsScreen: Error parsing Safety Report ${doc.id}',
                    error: e,
                    stackTrace: st);
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  // ─────────────────────── SHARED UI HELPERS ───────────────────

  Widget _buildEmptyState(String type) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.folder_open_outlined,
              size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No $type reports added yet',
            style: GoogleFonts.poppins(
                color: Colors.grey[600], fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the upload button to add one',
            style: GoogleFonts.poppins(
                color: Colors.grey[400], fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0A2E5A).withValues(alpha: 0.05),
        border: Border.all(color: Colors.grey[300]!, width: 1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        title,
        style: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0A2E5A)),
      ),
    );
  }

  Widget _buildReportItem(ReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          backgroundColor:
              (report.fileType != null
                      ? _getFileIconColor(report.fileType!)
                      : const Color(0xFF0A2E5A))
                  .withValues(alpha: 0.12),
          child: Icon(
            report.fileType != null
                ? _getDocumentIcon(report.fileType!)
                : Icons.security,
            color: report.fileType != null
                ? _getFileIconColor(report.fileType!)
                : const Color(0xFF0A2E5A),
            size: 22,
          ),
        ),
        title: Text(
          report.name,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600, fontSize: 15),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              'Uploaded: ${_dateFormat.format(report.uploadedAt)}',
              style: GoogleFonts.poppins(
                  color: Colors.grey[600], fontSize: 13),
            ),
            ...[
            const SizedBox(height: 2),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color:
                    const Color(0xFF0A2E5A).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                report.type,
                style: GoogleFonts.poppins(
                    fontSize: 11,
                    color: const Color(0xFF0A2E5A),
                    fontWeight: FontWeight.w500),
              ),
            ),
          ],
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleReportAction(value, report),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          itemBuilder: (context) => [
            if (report.url != null)
              _popupItem('view', Icons.visibility, Colors.blue[600]!, 'View'),
            if (report.safetyFormData != null)
              _popupItem('view_form', Icons.visibility,
                  Colors.blue[600]!, 'View Form'),
            _popupItem(
                'download', Icons.download, Colors.green[600]!, 'Download'),
            _popupItem('delete', Icons.delete, Colors.red[600]!, 'Delete'),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _popupItem(
      String value, IconData icon, Color color, String label) {
    return PopupMenuItem(
      value: value,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label, style: GoogleFonts.poppins()),
        ],
      ),
    );
  }

  // ─────────────────────── FAB LOGIC ───────────────────────────

  void _handleUploadAction() {
    // Map tab index → report type
    const typeMap = {
      0: 'Daily',
      1: 'Weekly',
      2: 'Monthly',
      3: 'Safety',
      4: 'Quality',
    };
    final type = typeMap[_tabController.index] ?? 'Daily';

    if (type == 'Daily') {
      _showDailyOptions();
    } else if (type == 'Weekly') {
      _showWeeklyOptions();        // ← NEW
    } else if (type == 'Safety') {
      _showSafetyOptions();
    } else {
      _uploadReport(type);
    }
  }

  void _showDailyOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Daily Report',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF0A2E5A)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FB),
                child: Icon(Icons.edit_note_rounded, color: Color(0xFF0A2E5A)),
              ),
              title: Text('Fill Daily Report Form', style: GoogleFonts.poppins()),
              subtitle: Text(
                'Complete the structured form within the app',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                Navigator.pop(context);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DailyReportFormScreen(
                        project: widget.project,
                        logger: widget.logger,
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.upload_file_rounded, color: Colors.green),
              ),
              title: Text('Upload Daily Report File', style: GoogleFonts.poppins()),
              subtitle: Text(
                'PDF, DOCX, PPTX, or TXT file from your device',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                Navigator.pop(context);
                _uploadReport('Daily');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showWeeklyOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // drag handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Weekly Report',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF0A2E5A)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FB),
                child: Icon(Icons.edit_note_rounded, color: Color(0xFF0A2E5A)),
              ),
              title: Text('Fill Weekly Report Form', style: GoogleFonts.poppins()),
              subtitle: Text(
                'Complete the structured form within the app',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                Navigator.pop(context);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => WeeklyReportFormScreen(
                        project: widget.project,
                        logger: widget.logger,
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.upload_file_rounded, color: Colors.green),
              ),
              title: Text('Upload Weekly Report File', style: GoogleFonts.poppins()),
              subtitle: Text(
                'PDF, DOCX, PPTX, or TXT file from your device',
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
              ),
              onTap: () {
                Navigator.pop(context);
                _uploadReport('Weekly');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  void _showSafetyOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(
                'Safety Meeting Report',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: const Color(0xFF0A2E5A)),
              ),
            ),
            const Divider(),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F0FB),
                child:
                    Icon(Icons.edit_note, color: Color(0xFF0A2E5A)),
              ),
              title:
                  Text('Fill Safety Form', style: GoogleFonts.poppins()),
              subtitle: Text('Complete the form within the app',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600])),
              onTap: () {
                Navigator.pop(context);
                if (mounted) {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => SafetyFormScreen(
                        project: widget.project,
                        logger: widget.logger,
                      ),
                    ),
                  );
                }
              },
            ),
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Color(0xFFE8F5E9),
                child: Icon(Icons.upload_file, color: Colors.green),
              ),
              title: Text('Upload Safety File',
                  style: GoogleFonts.poppins()),
              subtitle: Text('PDF, DOCX, PPTX, or TXT file',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600])),
              onTap: () {
                Navigator.pop(context);
                _uploadReport('Safety');
              },
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  // ─────────────────────── UPLOAD ──────────────────────────────

  Future<void> _uploadReport(String type) async {
    try {
      // 1. Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'pptx', 'ppt', 'txt'],
      );
      if (result == null || result.files.isEmpty) {
        widget.logger.d('📤 ReportsScreen: File selection cancelled');
        return;
      }

      final pickedFile = result.files.first;
      final originalFileName = pickedFile.name;
      final extension = originalFileName.split('.').last.toLowerCase();
      widget.logger
          .i('📤 ReportsScreen: File selected: $originalFileName');

      // 2. Ask for title (pre-filled)
      final title = await _showTextInputDialog(
        dialogTitle: 'Enter Report Title',
        contentText: 'Enter a title for this report:',
        hintText: 'Enter report title',
        prefill: originalFileName.split('.').first,
        fileName: originalFileName,
        showFileName: true,
      );
      if (title == null || title.trim().isEmpty) {
        widget.logger.d('📤 ReportsScreen: Title input cancelled');
        return;
      }

      final finalFileName = '$title.$extension';

      // 3. Read bytes
      Uint8List fileBytes;
      if (kIsWeb) {
        fileBytes = pickedFile.bytes!;
      } else {
        fileBytes = await File(pickedFile.path!).readAsBytes();
      }

      setState(() => _isLoading = true);

      // 4. Progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Uploading Report',
                style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text('Uploading $finalFileName...',
                    style: GoogleFonts.poppins()),
              ],
            ),
          ),
        );
      }

      // 5. Upload to Firebase Storage
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child('Reports')
          .child(type) // organise by type in storage too
          .child(finalFileName);

      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: _getContentType(extension)),
      );
      final snapshot = await uploadTask.whenComplete(() {});
      final downloadUrl = await snapshot.ref.getDownloadURL();

      // 6. Save to Firestore
      final docRef =
          await FirebaseFirestore.instance.collection('Reports').add({
        'name': title.trim(),
        'url': downloadUrl,
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'uploadedAt': Timestamp.now(),
        'type': type,
        'fileType': extension,
      });
      widget.logger
          .i('✅ ReportsScreen: Report saved (ID: ${docRef.id})');

      if (mounted) {
        Navigator.pop(context); // close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Report uploaded successfully',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
        ));
      }
    } catch (e, st) {
      widget.logger.e('❌ ReportsScreen: Error uploading report',
          error: e, stackTrace: st);
      if (mounted) {
        if (Navigator.canPop(context)) Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error uploading report: $e',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ─────────────────────── DIALOGS ─────────────────────────────

  Future<String?> _showTextInputDialog({
    required String dialogTitle,
    required String contentText,
    required String hintText,
    String? prefill,
    String? fileName,
    bool showFileName = true,
  }) async {
    final controller = TextEditingController(text: prefill ?? '');
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          dialogTitle,
          style: GoogleFonts.poppins(
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0A2E5A)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contentText,
                style: GoogleFonts.poppins(color: Colors.grey[700])),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              style: GoogleFonts.poppins(),
              decoration: InputDecoration(
                hintText: hintText,
                hintStyle:
                    GoogleFonts.poppins(color: Colors.grey[500]),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                focusedBorder: OutlineInputBorder(
                  borderSide:
                      const BorderSide(color: Color(0xFF0A2E5A)),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            if (showFileName && fileName != null) ...[
              const SizedBox(height: 8),
              Text('File: $fileName',
                  style: GoogleFonts.poppins(
                      fontSize: 12, color: Colors.grey[600])),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel',
                style:
                    GoogleFonts.poppins(color: const Color(0xFF800000))),
          ),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                Navigator.pop(context, controller.text.trim());
              } else {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text('Title cannot be empty',
                      style: GoogleFonts.poppins()),
                ));
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: Text('Confirm', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  // ─────────────────────── ACTIONS ─────────────────────────────

  Future<void> _handleReportAction(
      String action, ReportModel report) async {
    switch (action) {
      case 'view':
        await _viewDocument(
            report.url!, report.fileType ?? 'pdf', report.name);
        break;
      case 'view_form':
        await _viewSafetyForm(report);
        break;
      case 'download':
        if (report.url != null) {
          await _downloadDocument(report.url!, report.name);
        } else {
          await _downloadSafetyReport(report);
        }
        break;
      case 'delete':
        final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16)),
            title: Text('Delete Report',
                style: GoogleFonts.poppins(
                    fontWeight: FontWeight.w600)),
            content: Text(
                'Are you sure you want to delete "${report.name}"?',
                style: GoogleFonts.poppins()),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context, true),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white),
                child: Text('Delete', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
        if (confirmed == true) {
          await _deleteDocument(report.id, report.url ?? '', 'Reports');
        }
        break;
    }
  }

  // ─────────────────────── VIEW ────────────────────────────────

  Future<void> _viewDocument(
      String url, String type, String name) async {
    widget.logger.i('👀 ReportsScreen: Viewing document: $name ($type)');
    final connectivityResult =
        await Connectivity().checkConnectivity();
    final isOnline =
        connectivityResult.any((r) => r != ConnectivityResult.none);

    try {
      final cacheManager = DefaultCacheManager();
      FileInfo? cachedFile;
      if (isOnline) {
        cachedFile = await cacheManager.downloadFile(url);
      } else {
        cachedFile = await cacheManager.getFileFromCache(url);
      }

      if (cachedFile != null) {
        final localPath = cachedFile.file.path;
        if (type.toLowerCase() == 'txt') {
          final content = await File(localPath).readAsString();
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(name, style: GoogleFonts.poppins()),
                content: SingleChildScrollView(
                  child: SelectableText(content,
                      style: GoogleFonts.poppins()),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child:
                        Text('Close', style: GoogleFonts.poppins()),
                  ),
                ],
              ),
            );
          }
        } else if (kIsWeb) {
          final viewerUrl = _getViewerUrl(url, type);
          final uri = Uri.parse(viewerUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri,
                mode: LaunchMode.externalApplication);
          } else if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not open document viewer',
                  style: GoogleFonts.poppins()),
            ));
          }
        } else {
          final result = await OpenFile.open(localPath);
          if (result.type != ResultType.done && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Could not open file: ${result.message}',
                  style: GoogleFonts.poppins()),
              action: SnackBarAction(
                label: 'Download instead',
                onPressed: () => _downloadDocument(url, name),
              ),
            ));
          }
        }
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No internet and no cache available',
              style: GoogleFonts.poppins()),
        ));
      }
    } catch (e) {
      widget.logger.e('Error viewing document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Error viewing document: $e', style: GoogleFonts.poppins()),
        ));
      }
    }
  }

  // ─────────────────────── DOWNLOAD ────────────────────────────

  Future<void> _downloadDocument(String url, String name) async {
    widget.logger.i('⬇️ ReportsScreen: Downloading: $name');
    try {
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final Uint8List bytes = response.data;
      final result = await platformDownloadFile(bytes, name);

      if (!mounted) return;
      if (result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            'Downloaded successfully!\nLocation: $result',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async => await OpenFile.open(result),
          ),
        ));
      }
    } catch (e) {
      widget.logger.e('❌ Error downloading', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
            e.toString().contains('permission')
                ? 'Storage permission denied. Please enable it in Settings.'
                : 'Error downloading: $e',
            style: GoogleFonts.poppins(),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
          action: e.toString().contains('permission')
              ? SnackBarAction(
                  label: 'Settings',
                  textColor: Colors.white,
                  onPressed: () => openAppSettings(),
                )
              : null,
        ));
      }
    }
  }

  // ─────────────────────── DELETE ──────────────────────────────

  Future<void> _deleteDocument(
      String docId, String url, String collection) async {
    widget.logger.i('🗑️ ReportsScreen: Deleting document: $docId');
    try {
      if (url.isNotEmpty) {
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      }
      await FirebaseFirestore.instance
          .collection(collection)
          .doc(docId)
          .delete();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Document deleted successfully',
              style: GoogleFonts.poppins()),
        ));
      }
    } catch (e) {
      widget.logger.e('❌ ReportsScreen: Error deleting document',
          error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error deleting: $e',
              style: GoogleFonts.poppins()),
        ));
      }
    }
  }

  // ─────────────────────── SAFETY FORM HELPERS ─────────────────

  Future<void> _viewSafetyForm(ReportModel report) async {
    final content = _generateSafetyReportContent(report);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(report.name, style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child:
                SelectableText(content, style: GoogleFonts.poppins()),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Close', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );
    }
  }

  String _generateSafetyReportContent(ReportModel report) {
    final buffer = StringBuffer();
    buffer.writeln(report.type == 'SafetyWeekly'
        ? 'Weekly Safety Meeting Form'
        : 'Monthly Safety Meeting Form');
    buffer.writeln('Date: ${_dateFormat.format(report.uploadedAt)}');
    buffer.writeln('\nItems:');
    for (var item in (report.safetyFormData!['items']
            as Map<String, dynamic>)
        .entries) {
      buffer.writeln('| ${item.key} | ${item.value ? 'X' : ' '} |');
    }
    buffer.writeln('\nObservations and Comments:');
    buffer.writeln(report.safetyFormData!['observations'] ?? '');
    buffer.writeln('\nActions Taken:');
    buffer.writeln(report.safetyFormData!['actions'] ?? '');
    buffer.writeln('\nJV Alma CIS Attendance:');
    for (var attendee
        in (report.safetyFormData!['jvAlmaAttendance'] ?? []) as List) {
      buffer.writeln(
          '- Name: ${attendee['name']}, Title: ${attendee['title']}, Signature: ${attendee['signature']}');
    }
    if (report.type == 'SafetyWeekly') {
      buffer.writeln('\nSub-Contractor Attendance:');
      for (var attendee in (report.safetyFormData![
              'subContractorAttendance'] ??
          []) as List) {
        buffer.writeln(
            '- Company: ${attendee['companyName']}, Name: ${attendee['name']}, Title: ${attendee['title']}, Signature: ${attendee['signature']}');
      }
    }
    return buffer.toString();
  }

  Future<void> _downloadSafetyReport(ReportModel report) async {
    if (report.safetyFormData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('No form data available for download',
              style: GoogleFonts.poppins()),
        ));
      }
      return;
    }
    try {
      final content = _generateSafetyReportContent(report);
      final bytes = utf8.encode(content);
      final result = await platformDownloadFile(
          Uint8List.fromList(bytes), '${report.name}.txt');
      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Downloaded successfully!\nLocation: $result',
              style: GoogleFonts.poppins()),
          backgroundColor: Colors.green,
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Open',
            textColor: Colors.white,
            onPressed: () async => await OpenFile.open(result),
          ),
        ));
      }
    } catch (e) {
      widget.logger.e('❌ Error downloading safety report', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error downloading: $e',
              style: GoogleFonts.poppins()),
        ));
      }
    }
  }

  // ─────────────────────── UTILITIES ───────────────────────────

  String _getViewerUrl(String url, String type) {
    final encodedUrl = Uri.encodeComponent(url);
    return type.toLowerCase() == 'pdf'
        ? url
        : 'https://view.officeapps.live.com/op/view.aspx?src=$encodedUrl';
  }

  String _getContentType(String extension) {
    switch (extension.toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      case 'doc':
        return 'application/msword';
      case 'pptx':
        return 'application/vnd.openxmlformats-officedocument.presentationml.presentation';
      case 'ppt':
        return 'application/vnd.ms-powerpoint';
      case 'txt':
        return 'text/plain';
      default:
        return 'application/octet-stream';
    }
  }

  IconData _getDocumentIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'docx':
      case 'doc':
        return Icons.description;
      case 'pptx':
      case 'ppt':
        return Icons.slideshow;
      case 'txt':
        return Icons.text_snippet;
      default:
        return Icons.insert_drive_file;
    }
  }

  Color _getFileIconColor(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Colors.red[600]!;
      case 'docx':
      case 'doc':
        return Colors.blueGrey[600]!;
      case 'pptx':
      case 'ppt':
        return Colors.orange[600]!;
      case 'txt':
        return Colors.grey[600]!;
      default:
        return Colors.grey[600]!;
    }
  }
}