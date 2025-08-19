import 'dart:convert';
import 'dart:io' show File, Platform;
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/report_model.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:universal_html/html.dart' as html;

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

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    widget.logger.i('📊 ReportsScreen: Initialized for project: ${widget.project.name} (ID: ${widget.project.id})');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: '${widget.project.name} - Reports',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Reports',
      onMenuItemSelected: (_) {},
      floatingActionButton: _buildFloatingActionButton(),
      child: Column(
        children: [
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
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF0A2E5A),
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: const Color(0xFF0A2E5A),
              labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
              tabs: const [
                Tab(text: 'Weekly'),
                Tab(text: 'Monthly'),
                Tab(text: 'Safety'),
                Tab(text: 'Quality'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyTab(),
                _buildMonthlyTab(),
                _buildSafetyTab(),
                _buildQualityTab(),
              ],
            ),
          ),
          _buildFooter(context),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: const Color(0xFF0A2E5A),
      child: Text(
        '© 2025 JV Alma C.I.S Site Management System',
        style: GoogleFonts.poppins(
          color: Colors.white,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildFloatingActionButton() {
    final BuildContext currentContext = context;
    return FloatingActionButton(
      onPressed: () {
        if (_tabController.index == 2) {
          if (mounted) {
            Navigator.push(
              currentContext,
              MaterialPageRoute(
                builder: (context) => SafetyFormScreen(
                  project: widget.project,
                  logger: widget.logger,
                ),
              ),
            );
          }
        } else {
          final type = _tabController.index == 0
              ? 'Weekly'
              : _tabController.index == 1
                  ? 'Monthly'
                  : 'Quality';
          _showUploadDialog(type);
        }
      },
      backgroundColor: const Color(0xFF0A2E5A),
      child: const Icon(Icons.add, color: Colors.white),
    );
  }

  Widget _buildWeeklyTab() {
    return _buildDocumentTab('Weekly');
  }

  Widget _buildMonthlyTab() {
    return _buildDocumentTab('Monthly');
  }

  Widget _buildQualityTab() {
    return _buildDocumentTab('Quality');
  }

  Widget _buildDocumentTab(String type) {
    widget.logger.d('📊 ReportsScreen: Fetching Reports (type: $type, projectId: ${widget.project.id})');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Reports')
          .where('projectId', isEqualTo: widget.project.id)
          .where('type', isEqualTo: type)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('❌ ReportsScreen: Error loading Reports ($type)', error: snapshot.error, stackTrace: snapshot.stackTrace);
          return Center(
            child: Text(
              'Error loading documents: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          widget.logger.d('📊 ReportsScreen: Waiting for Reports data ($type)');
          return const Center(child: CircularProgressIndicator());
        }
        final documents = snapshot.data!.docs;
        widget.logger.i('📊 ReportsScreen: Loaded ${documents.length} Reports ($type)');
        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No $type reports added yet', style: GoogleFonts.poppins(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _showUploadDialog(type),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Upload $type Report', style: GoogleFonts.poppins(fontSize: 16)),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      '$type Reports',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _showUploadDialog(type),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Upload $type Report', style: GoogleFonts.poppins(fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...documents.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final report = ReportModel.fromMap(doc.id, data);
                return _buildReportItem(report);
              } catch (e, stackTrace) {
                widget.logger.e('❌ ReportsScreen: Error parsing Report ${doc.id} ($type)', error: e, stackTrace: stackTrace);
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  Widget _buildSafetyTab() {
    widget.logger.d('📊 ReportsScreen: Fetching Safety Reports (projectId: ${widget.project.id})');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Reports')
          .where('projectId', isEqualTo: widget.project.id)
          .where('type', whereIn: ['SafetyWeekly', 'SafetyMonthly'])
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('❌ ReportsScreen: Error loading Safety Reports', error: snapshot.error, stackTrace: snapshot.stackTrace);
          return Center(
            child: Text(
              'Error loading safety reports: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          widget.logger.d('📊 ReportsScreen: Waiting for Safety Reports data');
          return const Center(child: CircularProgressIndicator());
        }
        final reports = snapshot.data!.docs;
        widget.logger.i('📊 ReportsScreen: Loaded ${reports.length} Safety Reports');
        if (reports.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No safety reports added yet', style: GoogleFonts.poppins(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
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
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Add Safety Report', style: GoogleFonts.poppins(fontSize: 16)),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 1),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Safety Reports',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () {
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
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    child: Text('Add Safety Report', style: GoogleFonts.poppins(fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...reports.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final report = ReportModel.fromMap(doc.id, data);
                return _buildReportItem(report);
              } catch (e, stackTrace) {
                widget.logger.e('❌ ReportsScreen: Error parsing Safety Report ${doc.id}', error: e, stackTrace: stackTrace);
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  Widget _buildReportItem(ReportModel report) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(
          report.type.contains('Safety') ? Icons.security : Icons.description,
          color: const Color(0xFF0A2E5A),
        ),
        title: Text(
          report.name,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Text(
          'Uploaded: ${_dateFormat.format(report.uploadedAt)}',
          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleReportAction(value, report),
          itemBuilder: (context) => [
            if (report.url != null)
              PopupMenuItem(value: 'view', child: Text('View', style: GoogleFonts.poppins())),
            if (report.safetyFormData != null)
              PopupMenuItem(value: 'view_form', child: Text('View Form', style: GoogleFonts.poppins())),
            PopupMenuItem(value: 'download', child: Text('Download', style: GoogleFonts.poppins())),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showUploadDialog(String type) async {
    final TextEditingController titleController = TextEditingController();
    final BuildContext dialogContext = context;
    final result = await showDialog<Map<String, dynamic>>(
      context: dialogContext,
      builder: (context) => AlertDialog(
        title: Text('Upload $type Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(
                labelText: 'Report Title',
                border: const OutlineInputBorder(),
                hintText: 'Enter report title',
              ),
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
              if (titleController.text.isNotEmpty) {
                Navigator.pop(context, {'title': titleController.text});
              } else {
                if (mounted && dialogContext.mounted) {
                  ScaffoldMessenger.of(dialogContext).showSnackBar(
                    SnackBar(content: Text('Please enter a title', style: GoogleFonts.poppins())),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
            ),
            child: Text('Select File', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    titleController.dispose();
    if (result != null && mounted) {
      await _uploadDocument(type, result['title']);
    }
  }

  Future<void> _uploadDocument(String type, String title) async {
    widget.logger.d('📊 ReportsScreen: Opening file picker for $type report');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) {
        widget.logger.d('📊 ReportsScreen: File picker cancelled');
        return;
      }

      final file = result.files.single;
      final fileName = file.name;
      final filePath = file.path;
      if (filePath == null) {
        widget.logger.w('📊 ReportsScreen: File path is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: Unable to access file', style: GoogleFonts.poppins())),
          );
        }
        return;
      }

      widget.logger.d('📊 ReportsScreen: Uploading $fileName to Firebase Storage ($type)');
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child('Reports')
          .child(type)
          .child(fileName);
      final uploadTask = await storageRef.putFile(File(filePath));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      widget.logger.d('📊 ReportsScreen: Saving report metadata to Firestore: $title');
      final docRef = await FirebaseFirestore.instance.collection('Reports').add({
        'name': title,
        'url': downloadUrl,
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'uploadedAt': Timestamp.now(),
        'type': type,
      });
      widget.logger.d('📊 ReportsScreen: Saved report with ID: ${docRef.id}');

      widget.logger.i('✅ ReportsScreen: Report uploaded successfully: $title');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report uploaded successfully', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('❌ ReportsScreen: Error uploading report', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading report: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _downloadSafetyReport(ReportModel report) async {
    if (report.safetyFormData == null) {
      widget.logger.w('📊 ReportsScreen: No safety form data for report: ${report.name}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No form data available for download', style: GoogleFonts.poppins())),
        );
      }
      return;
    }

    try {
      final buffer = StringBuffer();
      buffer.writeln(report.type == 'SafetyWeekly' ? 'Weekly Safety Meeting Form' : 'Monthly Safety Meeting Form');
      buffer.writeln('Date: ${_dateFormat.format(report.uploadedAt)}');
      buffer.writeln('\nItems:');
      for (var item in (report.safetyFormData!['items'] as Map<String, dynamic>).entries) {
        buffer.writeln('| ${item.key} | ${item.value ? 'X' : ' '} |');
      }
      buffer.writeln('\nObservations and Comments:');
      buffer.writeln(report.safetyFormData!['observations']);
      buffer.writeln('\nActions Taken:');
      buffer.writeln(report.safetyFormData!['actions']);
      buffer.writeln('\nAttendance:');
      buffer.writeln('JV Alma CIS:');
      buffer.writeln('| Name | Title | Signature |');
      buffer.writeln('|------|-------|-----------|');
      for (var row in report.safetyFormData!['jvAlmaAttendance']) {
        final signature = row['signature'].startsWith('http') ? '(Image)' : '[Signature: ${row['signature']}]';
        buffer.writeln('| ${row['name']} | ${row['title']} | $signature |');
      }
      if (report.type == 'SafetyWeekly') {
        buffer.writeln('\nSub-Contractors:');
        buffer.writeln('| Company Name | Name | Title | Signature |');
        buffer.writeln('|--------------|------|-------|-----------|');
        for (var row in report.safetyFormData!['subContractorAttendance']) {
          final signature = row['signature'].startsWith('http') ? '(Image)' : '[Signature: ${row['signature']}]';
          buffer.writeln('| ${row['companyName']} | ${row['name']} | ${row['title']} | $signature |');
        }
      }

      final fileName = '${report.type}_${_dateFormat.format(report.uploadedAt).replaceAll(' ', '_')}.docx';
      final text = buffer.toString();
      if (kIsWeb) {
        final bytes = utf8.encode(text);
        final blob = html.Blob([bytes], 'application/vnd.openxmlformats-officedocument.wordprocessingml.document');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor = html.document.createElement('a') as html.AnchorElement
          ..href = url
          ..download = fileName;
        html.document.body!.append(anchor);
        anchor.click();
        anchor.remove();
        html.Url.revokeObjectUrl(url);
        widget.logger.i('✅ ReportsScreen: Safety report downloaded via web to $fileName');
      } else if (Platform.isWindows) {
        final directory = await getApplicationDocumentsDirectory();
        final filePath = '${directory.path}/$fileName';
        await File(filePath).writeAsString(text);
        widget.logger.i('✅ ReportsScreen: Safety report downloaded to $filePath on Windows');
      } else {
        final directory = await getDownloadsDirectory() ?? await getTemporaryDirectory();
        final filePath = '${directory.path}/$fileName';
        await File(filePath).writeAsString(text);
        widget.logger.i('✅ ReportsScreen: Safety report downloaded to $filePath on mobile');
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report downloaded successfully', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('❌ ReportsScreen: Error downloading safety report', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error downloading report: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _viewSafetyReport(ReportModel report) async {
    if (report.safetyFormData == null) {
      widget.logger.w('📊 ReportsScreen: No safety form data for report: ${report.name}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No form data available to view', style: GoogleFonts.poppins())),
        );
      }
      return;
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(report.name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
            ),
            body: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: constraints.maxWidth * 0.05,
                  vertical: 24,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Text(
                        report.type == 'SafetyWeekly' ? 'Weekly Safety Meeting Form' : 'Monthly Safety Meeting Form',
                        style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 24),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text('Date: ${_dateFormat.format(report.uploadedAt)}', style: GoogleFonts.poppins(fontSize: 16)),
                    const SizedBox(height: 16),
                    Text('Items:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                    ...report.safetyFormData!['items'].entries.map((item) => CheckboxListTile(
                          title: Text(item.key, style: GoogleFonts.poppins()),
                          value: item.value,
                          enabled: false,
                          activeColor: const Color(0xFF228B22),
                          onChanged: null,
                        )),
                    const SizedBox(height: 16),
                    Text('Observations and Comments:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(report.safetyFormData!['observations'], style: GoogleFonts.poppins()),
                    const SizedBox(height: 16),
                    Text('Actions Taken:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text(report.safetyFormData!['actions'], style: GoogleFonts.poppins()),
                    const SizedBox(height: 16),
                    Text('Attendance:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
                    Text('JV Alma CIS', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.05),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.9),
                        child: SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: DataTable(
                            columnSpacing: 16,
                            dataRowMinHeight: 60,
                            dataRowMaxHeight: 60,
                            border: TableBorder(
                              horizontalInside: BorderSide(color: Colors.grey[400]!, width: 1),
                              verticalInside: BorderSide(color: Colors.grey[400]!, width: 1),
                              top: BorderSide(color: Colors.grey[400]!, width: 1),
                              bottom: BorderSide(color: Colors.grey[400]!, width: 1),
                              left: BorderSide(color: Colors.grey[400]!, width: 1),
                              right: BorderSide(color: Colors.grey[400]!, width: 1),
                            ),
                            columns: const [
                              DataColumn(
                                label: Expanded(child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              ),
                              DataColumn(
                                label: Expanded(child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                              ),
                              DataColumn(
                                label: Expanded(child: Text('Signature', style: TextStyle(fontWeight: FontWeight.bold))),
                              ),
                            ],
                            rows: (report.safetyFormData!['jvAlmaAttendance'] as List<dynamic>).map((row) {
                              return DataRow(cells: [
                                DataCell(
                                  SizedBox(
                                    width: (constraints.maxWidth * 0.9 - 32) / 3,
                                    child: Text(row['name'], style: GoogleFonts.poppins()),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: (constraints.maxWidth * 0.9 - 32) / 3,
                                    child: Text(row['title'], style: GoogleFonts.poppins()),
                                  ),
                                ),
                                DataCell(
                                  SizedBox(
                                    width: (constraints.maxWidth * 0.9 - 32) / 3,
                                    child: Text(
                                      row['signature'].startsWith('http') ? 'Image Signature' : row['signature'],
                                      style: row['signature'].startsWith('http')
                                          ? GoogleFonts.poppins()
                                          : GoogleFonts.caveat(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, fontSize: 18),
                                    ),
                                  ),
                                ),
                              ]);
                            }).toList(),
                          ),
                        ),
                      ),
                    ),
                    if (report.type == 'SafetyWeekly') ...[
                      const SizedBox(height: 16),
                      Text('Sub-Contractors', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: constraints.maxWidth * 0.05),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.9),
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: DataTable(
                              columnSpacing: 16,
                              dataRowMinHeight: 60,
                              dataRowMaxHeight: 60,
                              border: TableBorder(
                                horizontalInside: BorderSide(color: Colors.grey[400]!, width: 1),
                                verticalInside: BorderSide(color: Colors.grey[400]!, width: 1),
                                top: BorderSide(color: Colors.grey[400]!, width: 1),
                                bottom: BorderSide(color: Colors.grey[400]!, width: 1),
                                left: BorderSide(color: Colors.grey[400]!, width: 1),
                                right: BorderSide(color: Colors.grey[400]!, width: 1),
                              ),
                              columns: const [
                                DataColumn(
                                  label: Expanded(child: Text('Company Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                ),
                                DataColumn(
                                  label: Expanded(child: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                ),
                                DataColumn(
                                  label: Expanded(child: Text('Title', style: TextStyle(fontWeight: FontWeight.bold))),
                                ),
                                DataColumn(
                                  label: Expanded(child: Text('Signature', style: TextStyle(fontWeight: FontWeight.bold))),
                                ),
                              ],
                              rows: (report.safetyFormData!['subContractorAttendance'] as List<dynamic>).map((row) {
                                return DataRow(cells: [
                                  DataCell(
                                    SizedBox(
                                      width: (constraints.maxWidth * 0.9 - 48) / 4,
                                      child: Text(row['companyName'], style: GoogleFonts.poppins()),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: (constraints.maxWidth * 0.9 - 48) / 4,
                                      child: Text(row['name'], style: GoogleFonts.poppins()),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: (constraints.maxWidth * 0.9 - 48) / 4,
                                      child: Text(row['title'], style: GoogleFonts.poppins()),
                                    ),
                                  ),
                                  DataCell(
                                    SizedBox(
                                      width: (constraints.maxWidth * 0.9 - 48) / 4,
                                      child: Text(
                                        row['signature'].startsWith('http') ? 'Image Signature' : row['signature'],
                                        style: row['signature'].startsWith('http')
                                            ? GoogleFonts.poppins()
                                            : GoogleFonts.caveat(fontStyle: FontStyle.italic, fontWeight: FontWeight.w700, fontSize: 18),
                                      ),
                                    ),
                                  ),
                                ]);
                              }).toList(),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
  }

  Future<void> _handleReportAction(String action, ReportModel report) async {
    if (action == 'view' && report.url != null) {
      widget.logger.d('📊 ReportsScreen: Viewing report: ${report.name}');
      // Implement URL view logic (e.g., url_launcher)
    } else if (action == 'view_form') {
      widget.logger.d('📊 ReportsScreen: Viewing safety form: ${report.name}');
      await _viewSafetyReport(report);
    } else if (action == 'download') {
      widget.logger.d('📊 ReportsScreen: Downloading report: ${report.name}');
      if (report.safetyFormData != null) {
        await _downloadSafetyReport(report);
      } else if (report.url != null) {
        // Implement URL download logic (e.g., url_launcher or http)
        widget.logger.w('📊 ReportsScreen: URL download not implemented for ${report.name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('URL download not implemented', style: GoogleFonts.poppins())),
          );
        }
      }
    } else if (action == 'delete') {
      widget.logger.d('📊 ReportsScreen: Deleting report: ${report.name}');
      final BuildContext dialogContext = context;
      final confirmed = await showDialog<bool>(
        context: dialogContext,
        builder: (context) => AlertDialog(
          title: Text('Delete Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to delete "${report.name}"?', style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: Text('Delete', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        widget.logger.d('📊 ReportsScreen: Report deletion cancelled: ${report.name}');
        return;
      }

      try {
        await FirebaseFirestore.instance.collection('Reports').doc(report.id).delete();
        if (report.url != null) {
          await FirebaseStorage.instance.refFromURL(report.url!).delete();
        }
        widget.logger.i('✅ ReportsScreen: Report deleted successfully: ${report.name}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Report deleted successfully', style: GoogleFonts.poppins())),
          );
        }
      } catch (e, stackTrace) {
        widget.logger.e('❌ ReportsScreen: Error deleting report', error: e, stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting report: $e', style: GoogleFonts.poppins())),
          );
        }
      }
    }
  }
}

class SafetyFormScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const SafetyFormScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<SafetyFormScreen> createState() => _SafetyFormScreenState();
}

class _SafetyFormScreenState extends State<SafetyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _observationsController = TextEditingController();
  final TextEditingController _actionsController = TextEditingController();
  final Map<String, bool> _items = {
    'PPE': false,
    'Scaffold': false,
    'Harness': false,
    'Machinery/tools': false,
    'Safety Certification': false,
    'Site Plan Layout': false,
    'Evacuation Measures': false,
    'Fire Extinguishers': false,
    'First Aid Measures': false,
    'Update of Safety Plans': false,
  };
  final List<Map<String, dynamic>> _jvAlmaAttendance = List.generate(
    3,
    (_) => {'name': '', 'title': '', 'signature': ''},
  );
  final List<Map<String, dynamic>> _subContractorAttendance = List.generate(
    4,
    (_) => {'companyName': '', 'name': '', 'title': '', 'signature': ''},
  );
  late List<TextEditingController> _jvAlmaNameControllers;
  late List<TextEditingController> _jvAlmaTitleControllers;
  late List<TextEditingController> _jvAlmaSignatureControllers;
  late List<TextEditingController> _subContractorCompanyNameControllers;
  late List<TextEditingController> _subContractorNameControllers;
  late List<TextEditingController> _subContractorTitleControllers;
  late List<TextEditingController> _subContractorSignatureControllers;
  String _type = 'SafetyWeekly';
  DateTime? _selectedDateTime;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _jvAlmaNameControllers = List.generate(3, (_) => TextEditingController());
    _jvAlmaTitleControllers = List.generate(3, (_) => TextEditingController());
    _jvAlmaSignatureControllers = List.generate(3, (_) => TextEditingController());
    _subContractorCompanyNameControllers = List.generate(4, (_) => TextEditingController());
    _subContractorNameControllers = List.generate(4, (_) => TextEditingController());
    _subContractorTitleControllers = List.generate(4, (_) => TextEditingController());
    _subContractorSignatureControllers = List.generate(4, (_) => TextEditingController());
  }

  @override
  void dispose() {
    _observationsController.dispose();
    _actionsController.dispose();
    for (var controller in _jvAlmaNameControllers) {
      controller.dispose();
    }
    for (var controller in _jvAlmaTitleControllers) {
      controller.dispose();
    }
    for (var controller in _jvAlmaSignatureControllers) {
      controller.dispose();
    }
    for (var controller in _subContractorCompanyNameControllers) {
      controller.dispose();
    }
    for (var controller in _subContractorNameControllers) {
      controller.dispose();
    }
    for (var controller in _subContractorTitleControllers) {
      controller.dispose();
    }
    for (var controller in _subContractorSignatureControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _updateControllers() {
    if (_jvAlmaNameControllers.length < _jvAlmaAttendance.length) {
      _jvAlmaNameControllers.add(TextEditingController());
      _jvAlmaTitleControllers.add(TextEditingController());
      _jvAlmaSignatureControllers.add(TextEditingController());
    } else if (_jvAlmaNameControllers.length > _jvAlmaAttendance.length) {
      _jvAlmaNameControllers.removeLast().dispose();
      _jvAlmaTitleControllers.removeLast().dispose();
      _jvAlmaSignatureControllers.removeLast().dispose();
    }
    if (_subContractorCompanyNameControllers.length < _subContractorAttendance.length) {
      _subContractorCompanyNameControllers.add(TextEditingController());
      _subContractorNameControllers.add(TextEditingController());
      _subContractorTitleControllers.add(TextEditingController());
      _subContractorSignatureControllers.add(TextEditingController());
    } else if (_subContractorCompanyNameControllers.length > _subContractorAttendance.length) {
      _subContractorCompanyNameControllers.removeLast().dispose();
      _subContractorNameControllers.removeLast().dispose();
      _subContractorTitleControllers.removeLast().dispose();
      _subContractorSignatureControllers.removeLast().dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Add Safety Report', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: LayoutBuilder(
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: constraints.maxWidth * 0.05,
              vertical: 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Text(
                    _type == 'SafetyWeekly' ? 'Weekly Safety Meeting Form' : 'Monthly Safety Meeting Form',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 24),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                _buildSafetyForm(constraints),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final BuildContext currentContext = context;
          if (!_formKey.currentState!.validate() || !mounted) return;
          final formData = await _processFormData();
          if (formData == null || !mounted) return;
          await _saveSafetyForm(_type, formData);
          if (mounted && currentContext.mounted) {
            Navigator.of(currentContext).pop();
          }
        },
        backgroundColor: const Color(0xFF0A2E5A),
        child: const Icon(Icons.save, color: Colors.white),
      ),
    );
  }

  // Updated JV Alma Attendance Table Widget
  Widget _buildJvAlmaAttendanceTable(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JV Alma CIS Attendance:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey[400]!, width: 1),
              verticalInside: BorderSide(color: Colors.grey[400]!, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Title', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Signature', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows
              ..._jvAlmaAttendance.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _jvAlmaNameControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _jvAlmaAttendance[index]['name'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _jvAlmaTitleControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _jvAlmaAttendance[index]['title'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildSignatureField(row, index, false, _jvAlmaSignatureControllers[index]),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        // Remove buttons for rows beyond the first 3
        ..._jvAlmaAttendance.asMap().entries.where((entry) => entry.key >= 3).map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _jvAlmaAttendance.removeAt(index);
                  _updateControllers();
                });
              },
              child: Text(
                'Remove Row ${index + 1}',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _jvAlmaAttendance.add({'name': '', 'title': '', 'signature': ''});
              _updateControllers();
            });
          },
          child: Text(
            'Add Entry',
            style: GoogleFonts.poppins(
              color: const Color(0xFF0A2E5A),
              decoration: TextDecoration.underline,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // Updated Sub-Contractor Attendance Table Widget
  Widget _buildSubContractorAttendanceTable(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sub-Contractor Attendance:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey[400]!, width: 1),
              verticalInside: BorderSide(color: Colors.grey[400]!, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Company Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Title', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Signature', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows
              ..._subContractorAttendance.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _subContractorCompanyNameControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _subContractorAttendance[index]['companyName'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _subContractorNameControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _subContractorAttendance[index]['name'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _subContractorTitleControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _subContractorAttendance[index]['title'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildSignatureField(row, index, true, _subContractorSignatureControllers[index]),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        // Remove buttons for rows beyond the first 4
        ..._subContractorAttendance.asMap().entries.where((entry) => entry.key >= 4).map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _subContractorAttendance.removeAt(index);
                  _updateControllers();
                });
              },
              child: Text(
                'Remove Row ${index + 1}',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _subContractorAttendance.add({'companyName': '', 'name': '', 'title': '', 'signature': ''});
              _updateControllers();
            });
          },
          child: Text(
            'Add Entry',
            style: GoogleFonts.poppins(
              color: const Color(0xFF0A2E5A),
              decoration: TextDecoration.underline,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  // Updated _buildSafetyForm method
  Widget _buildSafetyForm(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text('Select Date and Time:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!mounted) return;
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (!mounted || date == null) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (!mounted || time == null) return;
                setState(() {
                  _selectedDateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5A),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _selectedDateTime != null ? _dateFormat.format(_selectedDateTime!) : 'Select Date',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Report Type:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        DropdownButton<String>(
          value: _type,
          items: ['SafetyWeekly', 'SafetyMonthly'].map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type == 'SafetyWeekly' ? 'Weekly' : 'Monthly', style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _type = value;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        Text('Items:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ..._items.keys.map((item) => CheckboxListTile(
              title: Text(item, style: GoogleFonts.poppins()),
              value: _items[item],
              activeColor: const Color(0xFF228B22),
              onChanged: (value) {
                setState(() {
                  _items[item] = value!;
                });
              },
            )),
        const SizedBox(height: 16),
        Text('Observations and Comments:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        TextFormField(
          controller: _observationsController,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter observations',
            hintStyle: GoogleFonts.poppins(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter observations';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text('Actions Taken:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        TextFormField(
          controller: _actionsController,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter actions taken',
            hintStyle: GoogleFonts.poppins(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter actions taken';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Use the new table widgets
        _buildJvAlmaAttendanceTable(constraints),
        if (_type == 'SafetyWeekly') ...[
          const SizedBox(height: 16),
          _buildSubContractorAttendanceTable(constraints),
        ],
      ],
    );
  }

  // Updated signature field widget with proper BuildContext handling
  Widget _buildSignatureField(Map<String, dynamic> row, int index, bool isSubContractor, TextEditingController signatureController) {
    signatureController.text = row['signature'].startsWith('http') ? '' : row['signature'];
    return TextFormField(
      controller: signatureController,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        suffixIcon: row['signature'].startsWith('http')
            ? Icon(Icons.image, color: Colors.green, size: 16)
            : null,
      ),
      style: GoogleFonts.poppins(fontSize: 14),
      readOnly: true,
      onTap: () async {
        final signature = await showDialog<String>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Signature Input', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final url = await _getSignature();
                    // Check if the dialog context is still valid before using it
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, url);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Upload Image', style: GoogleFonts.poppins()),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final url = await _getSignature(useCamera: true);
                    // Check if the dialog context is still valid before using it
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, url);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Take Photo', style: GoogleFonts.poppins()),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Enter Signature',
                    border: OutlineInputBorder(),
                    hintStyle: GoogleFonts.poppins(),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty && dialogContext.mounted) {
                      Navigator.pop(dialogContext, value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
        
        // Check if the widget is still mounted before updating state
        if (signature != null && mounted) {
          setState(() {
            if (isSubContractor) {
              _subContractorAttendance[index]['signature'] = signature;
            } else {
              _jvAlmaAttendance[index]['signature'] = signature;
            }
            signatureController.text = signature.startsWith('http') ? 'Image Selected' : signature;
          });
        }
      },
    );
  }

  Future<String?> _getSignature({bool useCamera = false}) async {
    final source = useCamera ? ImageSource.camera : ImageSource.gallery;
    final image = await ImagePicker().pickImage(source: source);
    if (image == null) {
      widget.logger.d('📊 SafetyFormScreen: Image picker cancelled for ${useCamera ? 'camera' : 'gallery'}');
      return null;
    }
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child('Signatures')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await storageRef.putFile(File(image.path));
      final url = await uploadTask.ref.getDownloadURL();
      widget.logger.i('✅ SafetyFormScreen: Uploaded signature from ${useCamera ? 'camera' : 'gallery'}');
      return url;
    } catch (e, stackTrace) {
      widget.logger.e('❌ SafetyFormScreen: Error uploading signature from ${useCamera ? 'camera' : 'gallery'}', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  // Updated validation method with proper row validation logic
  Future<Map<String, dynamic>?> _processFormData() async {
    // Validate basic form fields first
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all required fields', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }
    
    if (_selectedDateTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select date and time', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }

    // Validate JV Alma attendance rows
    String? jvAlmaError = _validateAttendanceRows(_jvAlmaAttendance, 'JV Alma CIS');
    if (jvAlmaError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jvAlmaError, style: GoogleFonts.poppins())),
        );
      }
      return null;
    }

    // Validate sub-contractor attendance rows (only for weekly reports)
    if (_type == 'SafetyWeekly') {
      String? subContractorError = _validateAttendanceRows(_subContractorAttendance, 'Sub-Contractor');
      if (subContractorError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(subContractorError, style: GoogleFonts.poppins())),
          );
        }
        return null;
      }
    }

    // Filter out completely empty rows before saving
    final filteredJvAlmaAttendance = _jvAlmaAttendance.where((row) {
      return row['name'].toString().isNotEmpty || 
            row['title'].toString().isNotEmpty || 
            row['signature'].toString().isNotEmpty;
    }).toList();

    final filteredSubContractorAttendance = _subContractorAttendance.where((row) {
      return row['companyName'].toString().isNotEmpty || 
            row['name'].toString().isNotEmpty || 
            row['title'].toString().isNotEmpty || 
            row['signature'].toString().isNotEmpty;
    }).toList();

    return {
      'items': _items,
      'observations': _observationsController.text,
      'actions': _actionsController.text,
      'jvAlmaAttendance': filteredJvAlmaAttendance,
      if (_type == 'SafetyWeekly') 'subContractorAttendance': filteredSubContractorAttendance,
    };
  }

  // New validation helper method
  String? _validateAttendanceRows(List<Map<String, dynamic>> attendance, String tableName) {
    for (int i = 0; i < attendance.length; i++) {
      final row = attendance[i];
      final name = row['name']?.toString() ?? '';
      final title = row['title']?.toString() ?? '';
      final signature = row['signature']?.toString() ?? '';
      final companyName = row['companyName']?.toString() ?? '';

      // Check if row has any content
      bool hasAnyContent = name.isNotEmpty || title.isNotEmpty || signature.isNotEmpty;
      if (tableName == 'Sub-Contractor') {
        hasAnyContent = hasAnyContent || companyName.isNotEmpty;
      }

      // If row has any content, all fields must be filled
      if (hasAnyContent) {
        if (tableName == 'Sub-Contractor') {
          if (companyName.isEmpty || name.isEmpty || title.isEmpty || signature.isEmpty) {
            return '$tableName attendance row ${i + 1}: All fields must be filled if any field is filled';
          }
        } else {
          if (name.isEmpty || title.isEmpty || signature.isEmpty) {
            return '$tableName attendance row ${i + 1}: All fields must be filled if any field is filled';
          }
        }
      }
    }
    return null; // No validation errors
  }

  Future<void> _saveSafetyForm(String type, Map<String, dynamic> formData) async {
    try {
      final docRef = await FirebaseFirestore.instance.collection('Reports').add({
        'name': '$type Safety Report - ${_dateFormat.format(_selectedDateTime!)}',
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'uploadedAt': Timestamp.fromDate(_selectedDateTime!),
        'type': type,
        'safetyFormData': formData,
      });
      widget.logger.i('✅ SafetyFormScreen: Saved safety report with ID: ${docRef.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Safety report saved successfully', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('❌ SafetyFormScreen: Error saving safety report', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving safety report: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }
}