import 'dart:convert';
import 'dart:io' show File;
import 'dart:typed_data';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/report_model.dart';
import 'package:almaworks/screens/reports/safety_form_screen.dart';
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

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  bool _isLoading = false;

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
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : () {
          if (_tabController.index == 2) {
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
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
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
            child: Text('No $type reports added yet', style: GoogleFonts.poppins(color: Colors.grey[600])),
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
          report.fileType != null ? _getDocumentIcon(report.fileType!) : Icons.security,
          color: report.fileType != null ? _getFileIconColor(report.fileType!) : const Color(0xFF0A2E5A),
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
              PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    Text('View', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            if (report.safetyFormData != null)
              PopupMenuItem(
                value: 'view_form',
                child: Row(
                  children: [
                    Icon(Icons.visibility, color: Colors.blue[600]),
                    const SizedBox(width: 8),
                    Text('View Form', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.download, color: Colors.green[600]),
                  const SizedBox(width: 8),
                  Text('Download', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, color: Colors.red[600]),
                  const SizedBox(width: 8),
                  Text('Delete', style: GoogleFonts.poppins()),
                ],
              ),
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
      setState(() {
        _isLoading = true;
      });

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'doc', 'ppt'],
        withData: true,
      );
      if (result == null || result.files.isEmpty) {
        widget.logger.d('📊 ReportsScreen: File picker cancelled');
        return;
      }

      final platformFile = result.files.single;
      final fileName = platformFile.name;
      final extension = fileName.split('.').last.toLowerCase();
      Uint8List? fileBytes;

      if (platformFile.bytes != null) {
        fileBytes = platformFile.bytes!;
        widget.logger.d('📊 ReportsScreen: File bytes available (web)');
      } else if (platformFile.path != null) {
        final file = File(platformFile.path!);
        fileBytes = await file.readAsBytes();
        widget.logger.d('📊 ReportsScreen: File read from path (mobile/desktop)');
      }

      if (fileBytes == null) {
        throw Exception('Could not read file data');
      }

      widget.logger.d('📊 ReportsScreen: Uploading $fileName to Firebase Storage ($type)');
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child('Reports')
          .child(fileName);

      final uploadTask = storageRef.putData(
        fileBytes,
        SettableMetadata(contentType: _getContentType(extension)),
      );

      await uploadTask.whenComplete(() => null);

      final downloadUrl = await storageRef.getDownloadURL();

      widget.logger.d('📊 ReportsScreen: Saving report metadata to Firestore: $title');
      final docRef = await FirebaseFirestore.instance.collection('Reports').add({
        'name': title,
        'url': downloadUrl,
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'uploadedAt': Timestamp.now(),
        'type': type,
        'fileType': extension,
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
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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

  String _getViewerUrl(String url, String type) {
    final encodedUrl = Uri.encodeComponent(url);
    if (type.toLowerCase() == 'pdf') {
      return url;
    } else {
      return 'https://view.officeapps.live.com/op/view.aspx?src=$encodedUrl';
    }
  }

  Future<void> _viewDocument(String url, String type, String name) async {
    widget.logger.i('👀 ReportsScreen: Viewing document: $name ($type)');
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOnline = connectivityResult.any((r) => r != ConnectivityResult.none);

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
          // For TXT, read and show in dialog (works offline)
          final content = await File(localPath).readAsString();
          if (mounted) {
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(name, style: GoogleFonts.poppins()),
                content: SingleChildScrollView(
                  child: SelectableText(content, style: GoogleFonts.poppins()),
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
        } else if (kIsWeb) {
          // On web, always use launchUrl (can't open local files directly)
          final viewerUrl = _getViewerUrl(url, type);
          final uri = Uri.parse(viewerUrl);
          if (await canLaunchUrl(uri)) {
            await launchUrl(uri, mode: LaunchMode.externalApplication);
          } else {
            if (mounted) {
              widget.logger.e('Could not launch $viewerUrl');
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Could not open document viewer', style: GoogleFonts.poppins()),
                ),
              );
            }
          }
        } else {
          // On native, open local file with system viewer (prompts if multiple apps)
          final result = await OpenFile.open(localPath);
          if (result.type != ResultType.done && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open file: ${result.message}', style: GoogleFonts.poppins()),
                action: SnackBarAction(
                  label: 'Download instead',
                  onPressed: () => _downloadDocument(url, name),
                ),
              ),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No internet and no cache available', style: GoogleFonts.poppins()),
            ),
          );
        }
      }
    } catch (e) {
      widget.logger.e('Error viewing document: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error viewing document: $e', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(String url, String name) async {
    widget.logger.i('⬇️ ReportsScreen: Downloading: $name');
    try {
      // Fetch file bytes from URL
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final Uint8List bytes = response.data;

      // Use platform-specific download helper
      final result = await platformDownloadFile(bytes, name);

      if (!mounted) return;

      if (result != null) {
        // Success: result is either a path (mobile) or message (web)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded successfully!\nLocation: $result',  // Mobile: Full path
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                await OpenFile.open(result);
              },
            ),
          ),
        );
      } else {
        // User cancelled (shouldn't happen with new implementation)
        widget.logger.d('Download cancelled by user');
      }
    } catch (e) {
      widget.logger.e('❌ Error downloading', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
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
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(String docId, String url, String collection) async {
    widget.logger.i('🗑️ ReportsScreen: Deleting document: $docId');
    try {
      if (url.isNotEmpty) {
        widget.logger.d('🗑️ ReportsScreen: Deleting from storage');
        final ref = FirebaseStorage.instance.refFromURL(url);
        await ref.delete();
      }
      widget.logger.d('🗑️ ReportsScreen: Deleting from Firestore');
      await FirebaseFirestore.instance.collection(collection).doc(docId).delete();
      if (mounted) {
        widget.logger.i('✅ ReportsScreen: Document deleted successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document deleted successfully', style: GoogleFonts.poppins()),
          ),
        );
      }
    } catch (e) {
      widget.logger.e('❌ ReportsScreen: Error deleting document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }

  Future<void> _handleReportAction(String action, ReportModel report) async {
    if (action == 'view') {
      await _viewDocument(report.url!, report.fileType ?? 'pdf', report.name);
    } else if (action == 'view_form') {
      await _viewSafetyForm(report);
    } else if (action == 'download') {
      if (report.url != null) {
        await _downloadDocument(report.url!, report.name);
      } else {
        await _downloadSafetyReport(report);
      }
    } else if (action == 'delete') {
      final confirmed = await showDialog<bool>(
        context: context,
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

      if (confirmed == true) {
        await _deleteDocument(report.id, report.url ?? '', 'Reports');
      }
    }
  }

  Future<void> _viewSafetyForm(ReportModel report) async {
    final content = _generateSafetyReportContent(report);
    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(report.name, style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: SelectableText(content, style: GoogleFonts.poppins()),
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
    buffer.writeln(report.type == 'SafetyWeekly' ? 'Weekly Safety Meeting Form' : 'Monthly Safety Meeting Form');
    buffer.writeln('Date: ${_dateFormat.format(report.uploadedAt)}');
    buffer.writeln('\nItems:');
    for (var item in (report.safetyFormData!['items'] as Map<String, dynamic>).entries) {
      buffer.writeln('| ${item.key} | ${item.value ? 'X' : ' '} |');
    }
    buffer.writeln('\nObservations and Comments:');
    buffer.writeln(report.safetyFormData!['observations'] ?? '');
    buffer.writeln('\nActions Taken:');
    buffer.writeln(report.safetyFormData!['actions'] ?? '');
    buffer.writeln('\nJV Alma CIS Attendance:');
    for (var attendee in (report.safetyFormData!['jvAlmaAttendance'] ?? []) as List) {
      buffer.writeln('- Name: ${attendee['name']}, Title: ${attendee['title']}, Signature: ${attendee['signature']}');
    }
    if (report.type == 'SafetyWeekly') {
      buffer.writeln('\nSub-Contractor Attendance:');
      for (var attendee in (report.safetyFormData!['subContractorAttendance'] ?? []) as List) {
        buffer.writeln('- Company: ${attendee['companyName']}, Name: ${attendee['name']}, Title: ${attendee['title']}, Signature: ${attendee['signature']}');
      }
    }
    return buffer.toString();
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
      final content = _generateSafetyReportContent(report);
      final bytes = utf8.encode(content);
      final result = await platformDownloadFile(Uint8List.fromList(bytes), '${report.name}.txt');

      if (mounted && result != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Downloaded successfully!\nLocation: $result',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Open',
              textColor: Colors.white,
              onPressed: () async {
                await OpenFile.open(result);
              },
            ),
          ),
        );
      }
    } catch (e) {
      widget.logger.e('❌ Error downloading safety report', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }
}