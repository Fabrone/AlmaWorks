import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/document_model.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class QualityAndSafetyScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const QualityAndSafetyScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<QualityAndSafetyScreen> createState() => _QualityAndSafetyScreenState();
}

class _QualityAndSafetyScreenState extends State<QualityAndSafetyScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.logger.i('📄 QualityAndSafetyScreen: Initialized for project: ${widget.project.name} (ID: ${widget.project.id})');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      widget.logger.d('📄 QualityAndSafetyScreen: Screen width: $width, isMobile: ${width < 600}');
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    widget.logger.d('📄 QualityAndSafetyScreen: Building UI, isMobile: $isMobile');
    return BaseLayout(
      title: '${widget.project.name} - Quality & Safety',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Quality & Safety',
      onMenuItemSelected: (_) {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
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
                            Tab(text: 'Quality'),
                            Tab(text: 'Safety'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: constraints.maxHeight - 48 - (isMobile ? 12 : 16) * 2,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildQualityTab(),
                            _buildSafetyTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildFooter(context),
                ],
              ),
            ),
          );
        },
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
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildQualityTab() {
    widget.logger.d('📄 QualityAndSafetyScreen: Fetching QualityDocuments (projectId: ${widget.project.id})');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('QualityDocuments')
          .where('projectId', isEqualTo: widget.project.id)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e(
            '❌ QualityAndSafetyScreen: Error loading QualityDocuments',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return Center(
            child: Text(
              'Error loading documents: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          widget.logger.d('📄 QualityAndSafetyScreen: Waiting for QualityDocuments data');
          return const Center(child: CircularProgressIndicator());
        }
        final documents = snapshot.data!.docs;
        widget.logger.i('📄 QualityAndSafetyScreen: Loaded ${documents.length} QualityDocuments');
        widget.logger.d('📄 QualityAndSafetyScreen: Rendering Quality tab with Upload Document button');
        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No documents added yet', style: GoogleFonts.poppins(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _uploadDocument('QualityDocuments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(100, 40),
                  ),
                  child: Text('Upload Document', style: GoogleFonts.poppins(fontSize: 16)),
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
                      'Quality Documents',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _uploadDocument('QualityDocuments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(100, 40),
                    ),
                    child: Text('Upload Document', style: GoogleFonts.poppins(fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...documents.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final document = DocumentModel.fromMap(doc.id, data);
                return _buildDocumentItem(
                  document.id,
                  document.name,
                  document.url,
                  document.uploadedAt,
                  'QualityDocuments',
                );
              } catch (e, stackTrace) {
                widget.logger.e(
                  '❌ QualityAndSafetyScreen: Error parsing QualityDocuments document ${doc.id}',
                  error: e,
                  stackTrace: stackTrace,
                );
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  Widget _buildSafetyTab() {
    widget.logger.d('📄 QualityAndSafetyScreen: Fetching SafetyDocuments (projectId: ${widget.project.id})');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('SafetyDocuments')
          .where('projectId', isEqualTo: widget.project.id)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e(
            '❌ QualityAndSafetyScreen: Error loading SafetyDocuments',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return Center(
            child: Text(
              'Error loading documents: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          widget.logger.d('📄 QualityAndSafetyScreen: Waiting for SafetyDocuments data');
          return const Center(child: CircularProgressIndicator());
        }
        final documents = snapshot.data!.docs;
        widget.logger.i('📄 QualityAndSafetyScreen: Loaded ${documents.length} SafetyDocuments');
        widget.logger.d('📄 QualityAndSafetyScreen: Rendering Safety tab with Upload Document button');
        if (documents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No documents added yet', style: GoogleFonts.poppins(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => _uploadDocument('SafetyDocuments'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    minimumSize: const Size(100, 40),
                  ),
                  child: Text('Upload Document', style: GoogleFonts.poppins(fontSize: 16)),
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
                      'Safety Documents',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: () => _uploadDocument('SafetyDocuments'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(100, 40),
                    ),
                    child: Text('Upload Document', style: GoogleFonts.poppins(fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...documents.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final document = DocumentModel.fromMap(doc.id, data);
                return _buildDocumentItem(
                  document.id,
                  document.name,
                  document.url,
                  document.uploadedAt,
                  'SafetyDocuments',
                );
              } catch (e, stackTrace) {
                widget.logger.e(
                  '❌ QualityAndSafetyScreen: Error parsing SafetyDocuments document ${doc.id}',
                  error: e,
                  stackTrace: stackTrace,
                );
                return const SizedBox.shrink();
              }
            }),
          ],
        );
      },
    );
  }

  Widget _buildDocumentItem(String id, String name, String url, DateTime uploadedAt, String collection) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.description, color: Color(0xFF0A2E5A)),
        title: Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Text(
          'Uploaded: ${_dateFormat.format(uploadedAt)}',
          style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleDocumentAction(value, id, name, url, collection),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'view', child: Text('View', style: GoogleFonts.poppins())),
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

  Future<void> _uploadDocument(String collection) async {
    widget.logger.d('📄 QualityAndSafetyScreen: Opening file picker for $collection');
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) {
        widget.logger.d('📄 QualityAndSafetyScreen: File picker cancelled');
        return;
      }

      final file = result.files.single;
      final fileName = file.name;
      final filePath = file.path;
      if (filePath == null) {
        widget.logger.w('📄 QualityAndSafetyScreen: File path is null');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: Unable to access file', style: GoogleFonts.poppins())),
          );
        }
        return;
      }

      widget.logger.d('📄 QualityAndSafetyScreen: Uploading $fileName to Firebase Storage');
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child(collection)
          .child(fileName);
      final uploadTask = await storageRef.putFile(File(filePath));
      final downloadUrl = await uploadTask.ref.getDownloadURL();

      widget.logger.d('📄 QualityAndSafetyScreen: Saving document metadata to Firestore: $fileName');
      await FirebaseFirestore.instance.collection(collection).add({
        'name': fileName,
        'url': downloadUrl,
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'uploadedAt': Timestamp.now(),
      });

      widget.logger.i('✅ QualityAndSafetyScreen: Document uploaded successfully: $fileName');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Document uploaded successfully', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('❌ QualityAndSafetyScreen: Error uploading document', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error uploading document: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _handleDocumentAction(String action, String id, String name, String url, String collection) async {
    if (action == 'view') {
      widget.logger.d('📄 QualityAndSafetyScreen: Viewing document: $name');
      try {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          widget.logger.i('✅ QualityAndSafetyScreen: Opened document: $name');
        } else {
          widget.logger.w('📄 QualityAndSafetyScreen: Cannot launch URL: $url');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Cannot open document', style: GoogleFonts.poppins())),
            );
          }
        }
      } catch (e, stackTrace) {
        widget.logger.e('❌ QualityAndSafetyScreen: Error viewing document', error: e, stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error viewing document: $e', style: GoogleFonts.poppins())),
          );
        }
      }
    } else if (action == 'download') {
      widget.logger.d('📄 QualityAndSafetyScreen: Downloading document: $name');
      try {
        final response = await http.get(Uri.parse(url));
        if (response.statusCode == 200) {
          final directory = await getApplicationDocumentsDirectory();
          final filePath = '${directory.path}/$name';
          final file = File(filePath);
          await file.writeAsBytes(response.bodyBytes);
          widget.logger.i('✅ QualityAndSafetyScreen: Downloaded document to $filePath');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Document downloaded to $filePath', style: GoogleFonts.poppins())),
            );
          }
        } else {
          widget.logger.w('📄 QualityAndSafetyScreen: Failed to download document, status: ${response.statusCode}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error downloading document', style: GoogleFonts.poppins())),
            );
          }
        }
      } catch (e, stackTrace) {
        widget.logger.e('❌ QualityAndSafetyScreen: Error downloading document', error: e, stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error downloading document: $e', style: GoogleFonts.poppins())),
          );
        }
      }
    } else if (action == 'delete') {
      widget.logger.d('📄 QualityAndSafetyScreen: Opening Delete Document dialog for document ID: $id');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Document', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
          content: Text('Are you sure you want to delete "$name"?', style: GoogleFonts.poppins()),
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
        widget.logger.d('📄 QualityAndSafetyScreen: Document deletion cancelled for document ID: $id');
        return;
      }

      try {
        widget.logger.d('📄 QualityAndSafetyScreen: Deleting document from Firestore: $id');
        await FirebaseFirestore.instance.collection(collection).doc(id).delete();
        widget.logger.d('📄 QualityAndSafetyScreen: Deleting document from Firebase Storage: $name');
        await FirebaseStorage.instance
            .ref()
            .child(widget.project.id)
            .child(collection)
            .child(name)
            .delete();
        widget.logger.i('✅ QualityAndSafetyScreen: Document deleted successfully: $id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Document deleted successfully', style: GoogleFonts.poppins())),
          );
        }
      } catch (e, stackTrace) {
        widget.logger.e('❌ QualityAndSafetyScreen: Error deleting document: $id', error: e, stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting document: $e', style: GoogleFonts.poppins())),
          );
        }
      }
    }
  }
}