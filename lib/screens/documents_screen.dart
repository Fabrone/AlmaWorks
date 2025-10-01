import 'dart:js_interop';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:path/path.dart' as path;
import 'dart:typed_data';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:web/web.dart' as web;

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
  bool _isLoading = false;
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

    return BaseLayout(
      title: '${widget.project.name} - Documents',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Documents',
      onMenuItemSelected: (_) {}, // Empty callback as navigation is handled by BaseLayout
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _addDocument,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.file_upload),
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
                        controller: _mainTabController,
                        tabs: _mainTabs.map((tab) => Tab(text: tab)).toList(),
                        labelColor: const Color(0xFF0A2E5A),
                        unselectedLabelColor: Colors.grey,
                        labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                      SizedBox(
                        height: constraints.maxHeight - 48 - 48, // Subtract TabBar and footer height
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
                );
              }),
          ],
        );
      },
    );
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

    widget.logger.d('📤 DocumentsScreen: Picking file...');
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'docx', 'pptx', 'txt', 'doc', 'ppt'],
      withData: true,
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

    final title = await _getDocumentTitle(fileName);
    if (title == null) {
      widget.logger.d('📤 DocumentsScreen: Add document cancelled - no title provided');
      return;
    }

    if (!mounted) return;
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

    UploadTask? uploadTask;
    final GlobalKey<State> dialogKey = GlobalKey<State>();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        key: dialogKey,
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
        actions: [
          TextButton(
            onPressed: () async {
              if (uploadTask != null) {
                await uploadTask.cancel();
                widget.logger.d('📤 DocumentsScreen: Upload cancelled by user');
              }
              if (context.mounted) {
                Navigator.pop(context);
              }
            },
            child: Text('Cancel', style: GoogleFonts.poppins(color: Colors.red)),
          ),
        ],
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

      uploadTask = storageRef.putData(fileBytes, metadata);

      uploadTask.snapshotEvents.listen((TaskSnapshot snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      }, onError: (e) {
        widget.logger.e('Upload progress error: $e');
        if (mounted) {
          Navigator.pop(context);
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
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document "$title" added successfully!', style: GoogleFonts.poppins()),
          ),
        );
        widget.logger.i('✅ DocumentsScreen: Document uploaded successfully: $fileName with title $title');
      }
    } on FirebaseException catch (e) {
      if (e.code == 'canceled') {
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Upload cancelled', style: GoogleFonts.poppins()),
            ),
          );
        }
      } else {
        widget.logger.e('❌ DocumentsScreen: Error adding document', error: e);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error adding document: ${e.message}', style: GoogleFonts.poppins()),
            ),
          );
        }
      }
    } catch (e) {
      widget.logger.e('❌ DocumentsScreen: Error adding document', error: e);
      if (mounted) {
        Navigator.pop(context);
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

  Future<String?> _getDocumentTitle(String prefilledName) async {
    String? title = prefilledName;
    final controller = TextEditingController(text: prefilledName);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Enter Document Title', style: GoogleFonts.poppins()),
          content: TextField(
            controller: controller,
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
                  if (!mounted) return;
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

  String _getViewerUrl(String url, String type) {
    final encodedUrl = Uri.encodeComponent(url);
    if (type.toLowerCase() == 'pdf') {
      return url;
    } else {
      return 'https://view.officeapps.live.com/op/view.aspx?src=$encodedUrl';
    }
  }

  Future<void> _viewDocument(String url, String type, String name) async {
    widget.logger.i('👀 DocumentsScreen: Viewing document: $name ($type)');
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
    widget.logger.i('⬇️ DocumentsScreen: Downloading document: $name');
    try {
      final response = await Dio().get(
        url,
        options: Options(responseType: ResponseType.bytes),
      );
      final Uint8List bytes = response.data;

      String? savePath;
      if (kIsWeb) {
        // On web, create Blob and trigger download
        // Convert Uint8List to JSUint8Array and wrap in JSArray
        final jsUint8Array = bytes.toJS;
        final jsArray = [jsUint8Array].toJS;
        final blob = web.Blob(jsArray);
        final objectUrl = web.URL.createObjectURL(blob);
        web.HTMLAnchorElement()
          ..href = objectUrl
          ..download = name
          ..click();
        web.URL.revokeObjectURL(objectUrl);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Download started. Check your browser downloads.', style: GoogleFonts.poppins()),
            ),
          );
        }
      } else {
        // On native, prompt for directory
        final String? selectedDir = await FilePicker.platform.getDirectoryPath();
        if (selectedDir == null) {
          widget.logger.d('Download cancelled by user');
          return;
        }
        savePath = path.join(selectedDir, name);
        final file = File(savePath);
        await file.writeAsBytes(bytes);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Downloaded to $savePath', style: GoogleFonts.poppins()),
            ),
          );
        }
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

  String _formatDate(Timestamp timestamp) {
    final date = timestamp.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }
}