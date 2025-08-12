import 'dart:io';
import 'package:almaworks/screens/projects/project_summary_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/project_model.dart';
import 'dart:typed_data';

class DocumentsScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;
  const DocumentsScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends State<DocumentsScreen> with TickerProviderStateMixin {
  late TabController _mainTabController;
  late TabController _clientSubTabController;
  late TabController _subContractorSubTabController;
  late TabController _supplierSubTabController;
  bool _isLoading = false; // Now used to disable FAB
  double? _uploadProgress;

  final List<String> _mainTabs = ['Client', 'Sub-Contractor', 'Supplier'];
  final List<String> _subSections = ['Contract', 'Communication'];

  @override
  void initState() {
    super.initState();
    _mainTabController = TabController(length: _mainTabs.length, vsync: this);
    _clientSubTabController = TabController(length: _subSections.length, vsync: this);
    _subContractorSubTabController = TabController(length: _subSections.length, vsync: this);
    _supplierSubTabController = TabController(length: _subSections.length, vsync: this);
    widget.logger.i('📂 DocumentsScreen: Initialized for project: ${widget.project.name}');
  }

  @override
  void dispose() {
    _mainTabController.dispose();
    _clientSubTabController.dispose();
    _subContractorSubTabController.dispose();
    _supplierSubTabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.logger.d('🎨 DocumentsScreen: Building UI');
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${widget.project.name} - Documents',
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(context, isTablet),
          Expanded(
            child: Column(
              children: [
                TabBar(
                  controller: _mainTabController,
                  tabs: _mainTabs.map((tab) => Tab(text: tab)).toList(),
                  labelColor: const Color(0xFF0A2E5A),
                  unselectedLabelColor: Colors.grey,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                ),
                Expanded(
                  child: TabBarView(
                    controller: _mainTabController,
                    children: [
                      _buildRoleSection('Client', _clientSubTabController),
                      _buildRoleSection('Sub-Contractor', _subContractorSubTabController),
                      _buildRoleSection('Supplier', _supplierSubTabController),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _addDocument, // Disable when loading
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.file_upload), // Changed icon to upload
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isTablet) {
    return Container(
      width: isTablet ? 280 : 300,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withAlpha((255 * 0.1).round()), // Replaced withAlpha
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0A2E5A),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    widget.project.name,
                    style: GoogleFonts.poppins(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Project Dashboard',
                    style: GoogleFonts.poppins(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: Text('Overview', style: GoogleFonts.poppins()),
                  onTap: () {
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectSummaryScreen(
                          project: widget.project,
                          logger: widget.logger,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: Text('Documents', style: GoogleFonts.poppins()),
                  selected: true,
                  selectedTileColor: Colors.blueGrey[50],
                ),
                ListTile(
                  leading: const Icon(Icons.architecture),
                  title: Text('Drawings', style: GoogleFonts.poppins()),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Drawings section coming soon', style: GoogleFonts.poppins())),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: Text('Schedule', style: GoogleFonts.poppins()),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Schedule section coming soon', style: GoogleFonts.poppins())),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: Text('Quality & Safety', style: GoogleFonts.poppins()),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Quality & Safety section coming soon', style: GoogleFonts.poppins())),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: Text('Reports', style: GoogleFonts.poppins()),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Reports section coming soon', style: GoogleFonts.poppins())),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: Text('Photo Gallery', style: GoogleFonts.poppins()),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Photo Gallery section coming soon', style: GoogleFonts.poppins())),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: Text('Financials', style: GoogleFonts.poppins()),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Financials section coming soon', style: GoogleFonts.poppins())),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleSection(String role, TabController subTabController) {
    return Column(
      children: [
        TabBar(
          controller: subTabController,
          tabs: _subSections.map((section) => Tab(text: section)).toList(),
          labelColor: const Color(0xFF0A2E5A),
          unselectedLabelColor: Colors.grey,
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        Expanded(
          child: TabBarView(
            controller: subTabController,
            children: _subSections.map((section) => _buildDocumentList(role, section)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentList(String role, String section) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('documents')
          .where('role', isEqualTo: role)
          .where('section', isEqualTo: section)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('Firestore error: ${snapshot.error}');
          return Center(
            child: Text(
              'Error loading documents',
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
                    'No documents in this section',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                ),
              )
            else
              ...docs.map((doc) {
                final docData = doc.data() as Map<String, dynamic>;
                final docId = doc.id;
                final title = docData['title'] as String;
                final fileName = docData['fileName'] as String;
                final url = docData['url'] as String;
                final type = docData['type'] as String;
                return ListTile(
                  leading: Icon(_getDocumentIcon(type), color: _getFileIconColor(type)),
                  title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    '$fileName - Uploaded: ${_formatDate(docData['uploadedAt'] as Timestamp)}',
                    style: GoogleFonts.poppins(color: Colors.grey[600]),
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) {
                      if (value == 'view') {
                        _viewDocument(url, type, title);
                      } else if (value == 'download') {
                        _downloadDocument(url, fileName);
                      } else if (value == 'delete') {
                        _deleteDocument(docId, url);
                      }
                    },
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'view', child: Text('View', style: GoogleFonts.poppins())),
                      PopupMenuItem(value: 'download', child: Text('Download', style: GoogleFonts.poppins())),
                      PopupMenuItem(value: 'delete', child: Text('Delete', style: GoogleFonts.poppins())),
                    ],
                  ),
                );
              }),
            _buildFooter(context, MediaQuery.of(context).size.width < 600),
          ],
        );
      },
    );
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

  Future<String?> _getDocumentTitle() async {
    String? title;
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Enter Document Title', style: GoogleFonts.poppins()),
          content: TextField(
            autofocus: true,
            decoration: InputDecoration(
              labelText: 'Title (e.g., RFI, Close Out doc)',
              border: const OutlineInputBorder(),
              labelStyle: GoogleFonts.poppins(),
            ),
            style: GoogleFonts.poppins(),
            onChanged: (val) => title = val.trim(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                if (title != null && title!.isNotEmpty) {
                  Navigator.pop(ctx, true);
                } else {
                  if (!mounted) return; // Added mounted check
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Please enter a title', style: GoogleFonts.poppins())),
                  );
                }
              },
              child: Text('OK', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );
    return result == true ? title : null;
  }

  Future<void> _addDocument() async {
    final roleIndex = _mainTabController.index;
    final role = _mainTabs[roleIndex];
    late int subIndex;
    if (roleIndex == 0) {
      subIndex = _clientSubTabController.index;
    } else if (roleIndex == 1) {
      subIndex = _subContractorSubTabController.index;
    } else {
      subIndex = _supplierSubTabController.index;
    }
    final section = _subSections[subIndex];

    widget.logger.i('📤 DocumentsScreen: Initiating add document to $role - $section');

    final title = await _getDocumentTitle();
    if (title == null) {
      widget.logger.d('📤 DocumentsScreen: Add document cancelled - no title provided');
      return;
    }

    widget.logger.d('📤 DocumentsScreen: Picking file...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'doc', 'ppt'],
      withData: true, // Ensure bytes are available for web
    );

    if (result == null || result.files.isEmpty) {
      widget.logger.w('📤 DocumentsScreen: No document selected');
      return;
    }

    final platformFile = result.files.single;
    final fileName = platformFile.name;
    final extension = path.extension(fileName).substring(1).toLowerCase();
    Uint8List? fileBytes;

    if (platformFile.bytes != null) {
      fileBytes = platformFile.bytes!;
      widget.logger.d('📤 DocumentsScreen: File bytes available (web)');
    } else if (!kIsWeb && platformFile.path != null) {
      final file = File(platformFile.path!);
      fileBytes = await file.readAsBytes();
      widget.logger.d('📤 DocumentsScreen: File read from path (mobile/desktop)');
    }

    if (fileBytes == null) {
      throw Exception('Could not read file data');
    }

    if (!mounted) return; // Added mounted check before showDialog
    final bool? confirmUpload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Upload', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _getDocumentIcon(extension),
              size: 48,
              color: _getFileIconColor(extension),
            ),
            const SizedBox(height: 16),
            Text(
              'Upload: $fileName?',
              style: GoogleFonts.poppins(),
              textAlign: TextAlign.center,
            ),
            Text(
              'Size: ${(fileBytes!.length / 1024 / 1024).toStringAsFixed(2)} MB',
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
            ),
          ],
        ),
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
      widget.logger.d('📤 DocumentsScreen: Upload cancelled by user');
      return;
    }

    if (!mounted) return;
    setState(() {
      _isLoading = true;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Text('Uploading $fileName', style: GoogleFonts.poppins()),
          content: StatefulBuilder(
            builder: (context, setDialogState) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: _uploadProgress,
                    backgroundColor: Colors.grey[300],
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.blueGrey),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _uploadProgress != null
                        ? '${(_uploadProgress! * 100).toStringAsFixed(0)}%'
                        : 'Starting upload...',
                    style: GoogleFonts.poppins(),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    try {
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.project.id}/documents/${timestamp}_$fileName');

      final metadata = SettableMetadata(
        contentType: _getContentType(extension),
        customMetadata: {
          'projectId': widget.project.id,
          'role': role,
          'section': section,
          'title': title,
          'platform': kIsWeb ? 'web' : Platform.operatingSystem,
        },
      );

      final uploadTask = storageRef.putData(fileBytes, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      }, onError: (e) {
        widget.logger.e('Upload progress error: $e');
        if (mounted) { // Added mounted check
          Navigator.pop(context); // Close progress dialog on error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload failed: ${e.toString()}', style: GoogleFonts.poppins()),
            ),
          );
        }
      });

      await uploadTask;
      final url = await storageRef.getDownloadURL();
      widget.logger.d('📤 DocumentsScreen: Upload complete, URL obtained');

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('documents')
          .add({
        'title': title,
        'fileName': fileName,
        'url': url,
        'type': extension,
        'role': role,
        'section': section,
        'uploadedAt': Timestamp.now(),
      });

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "$title" added successfully!', style: GoogleFonts.poppins()),
          ),
        );
        widget.logger.i('✅ DocumentsScreen: Document uploaded successfully: $fileName with title $title');
      }
    } catch (e) {
      widget.logger.e('❌ DocumentsScreen: Error adding document', error: e);
      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding document: ${e.toString()}', style: GoogleFonts.poppins()),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _uploadProgress = null;
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

  void _viewDocument(String url, String type, String name) async {
    widget.logger.i('👀 DocumentsScreen: Viewing document: $name ($type)');
    if (type == 'pdf') {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => Scaffold(
              appBar: AppBar(
                title: Text(name, style: GoogleFonts.poppins(color: Colors.white)),
                backgroundColor: const Color(0xFF0A2E5A),
              ),
              body: SfPdfViewer.network(
                url,
                onDocumentLoadFailed: (details) {
                  widget.logger.e('PDF load failed: ${details.error}');
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error loading PDF: ${details.error}', style: GoogleFonts.poppins()),
                      ),
                    );
                  }
                },
              ),
            ),
          ),
        );
      }
    } else if (type == 'txt') {
      widget.logger.d('👀 DocumentsScreen: Downloading TXT for viewing');
      try {
        final tempDir = await getTemporaryDirectory();
        final filePath = '${tempDir.path}/$name';
        await Dio().download(url, filePath);
        final content = await File(filePath).readAsString();
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(name, style: GoogleFonts.poppins()),
              content: SingleChildScrollView(
                child: Text(content, style: GoogleFonts.poppins()),
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
      } catch (e) {
        widget.logger.e('Error viewing TXT document: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error viewing document: $e', style: GoogleFonts.poppins()),
            ),
          );
        }
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Viewing for this file type is not implemented yet. Please download.',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _downloadDocument(String url, String name) async {
    widget.logger.i('⬇️ DocumentsScreen: Downloading document: $name');
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
      widget.logger.e('❌ DocumentsScreen: Error downloading document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading: $e', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }

  Future<void> _deleteDocument(String docId, String url) async {
    widget.logger.i('🗑️ DocumentsScreen: Deleting document: $docId');
    try {
      widget.logger.d('🗑️ DocumentsScreen: Deleting from storage');
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();
      widget.logger.d('🗑️ DocumentsScreen: Deleting from Firestore');
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('documents')
          .doc(docId)
          .delete();
      if (mounted) {
        widget.logger.i('✅ DocumentsScreen: Document deleted successfully');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document deleted successfully', style: GoogleFonts.poppins()),
          ),
        );
      }
    } catch (e) {
      widget.logger.e('❌ DocumentsScreen: Error deleting document', error: e);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting: $e', style: GoogleFonts.poppins()),
          ),
        );
      }
    }
  }

  Widget _buildFooter(BuildContext context, bool isMobile) {
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

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}
