import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/financial_document_model.dart'; // Import the new model
import 'package:almaworks/widgets/base_layout.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:typed_data';

class FinancialScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const FinancialScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = false; // Loading state

  final List<String> _tabs = ['Client', 'Subcontractor', 'Supplier'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    widget.logger.i('💰 FinancialScreen: Initialized for project: ${widget.project.name}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.logger.d('🎨 FinancialScreen: Building UI');

    return BaseLayout(
      title: '${widget.project.name} - Financials',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Financials',
      onMenuItemSelected: (_) {}, // Empty callback as navigation is handled by BaseLayout
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _uploadFinancialDocument,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.upload_file),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: constraints.maxHeight,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      TabBar(
                        controller: _tabController,
                        tabs: _tabs.map((tab) => Tab(text: tab)).toList(),
                        labelColor: const Color(0xFF0A2E5A),
                        unselectedLabelColor: Colors.grey,
                        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(
                        height: constraints.maxHeight - 48 - 48, // Subtract TabBar and footer height
                        child: TabBarView(
                          controller: _tabController,
                          children: _tabs.map((tab) => _buildFinancialSection(tab)).toList(),
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

  Widget _buildFinancialSection(String role) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('financials')
          .where('role', isEqualTo: role)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('Firestore error: ${snapshot.error}');
          return Center(
            child: Text(
              'Error loading financial documents',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        return ListView(
          children: [
            if (docs.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Center(
                  child: Text(
                    'No financial documents in this section',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...docs.map((doc) {
                final docData = doc.data() as Map<String, dynamic>;
                final financialDocument = FinancialDocumentModel.fromMap(doc.id, docData);
                return ListTile(
                  title: Text(financialDocument.title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '${financialDocument.fileName} - Uploaded: ${_formatDate(docData['uploadedAt'] as Timestamp)}',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.download),
                    onPressed: financialDocument.url != null
                        ? () => _downloadDocument(financialDocument.url!, financialDocument.fileName)
                        : null, // Disable the button if URL is null
                  ),
                );
              }),
          ],
        );
      },
    );
  }

  Future<void> _uploadFinancialDocument() async {
    widget.logger.i('📤 FinancialScreen: Initiating upload financial document');

    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'doc', 'ppt'],
      withData: true,
    );

    if (result == null || result.files.isEmpty) {
      widget.logger.w('📤 FinancialScreen: No document selected');
      return;
    }

    final platformFile = result.files.single;
    final fileName = platformFile.name;
    Uint8List? fileBytes;

    if (platformFile.bytes != null) {
      fileBytes = platformFile.bytes!;
      widget.logger.d('📤 FinancialScreen: File bytes available (web)');
    } else {
      widget.logger.w('📤 FinancialScreen: File bytes not available');
      return;
    }

    if (!mounted) return;
    final bool? confirmUpload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Upload', style: GoogleFonts.poppins()),
        content: Text('Upload: $fileName?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Upload', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmUpload != true) {
      widget.logger.d('📤 FinancialScreen: Upload cancelled by user');
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.project.id}/financials/${timestamp}_$fileName');

      final uploadTask = storageRef.putData(fileBytes);

      await uploadTask;
      final url = await storageRef.getDownloadURL();
      widget.logger.d('📤 FinancialScreen: Upload complete, URL obtained');

      // Create a FinancialDocumentModel instance
      FinancialDocumentModel financialDocument = FinancialDocumentModel(
        id: '', // ID will be generated by Firestore
        title: fileName,
        url: url,
        projectId: widget.project.id,
        projectName: widget.project.name,
        uploadedAt: DateTime.now(),
        role: 'Client', // Set the appropriate role here
        fileName: fileName, // Set the fileName here
      );

      // Save the financial document to Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('financials')
          .add(financialDocument.toMap());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "$fileName" uploaded successfully!', style: GoogleFonts.poppins()),
          ),
        );
        widget.logger.i('✅ FinancialScreen: Document uploaded successfully: $fileName');
      }
    } catch (e) {
      widget.logger.e('❌ FinancialScreen: Error adding document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading document: ${e.toString()}', style: GoogleFonts.poppins()),
          ),
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

  Future<void> _downloadDocument(String url, String name) async {
    widget.logger.i('⬇️ FinancialScreen: Downloading document: $name');
    try {
      final dir = await getDownloadsDirectory();
      final filePath = '${dir?.path}/$name';
      await Dio().download(url, filePath);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Downloaded to $filePath', style: GoogleFonts.poppins()),
          ),
        );
      }
    } catch (e) {
      widget.logger.e('❌ FinancialScreen: Error downloading document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
