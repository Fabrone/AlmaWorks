import 'package:almaworks/models/photo_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:cached_network_image/cached_network_image.dart';

class PhotoGalleryScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const PhotoGalleryScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<PhotoGalleryScreen> createState() => _PhotoGalleryScreenState();
}

class _PhotoGalleryScreenState extends State<PhotoGalleryScreen> {
  bool _isLoading = false;
  double? _uploadProgress;
  bool _multiSelectMode = false;
  final Set<String> _selectedPhotoIds = {};

  @override
  void initState() {
    super.initState();
    widget.logger.i('📸 PhotoGalleryScreen: Initialized for project: ${widget.project.name} [Project ID: ${widget.project.id}]');
    widget.logger.d('🔧 Using Firebase Storage bucket: gs://almaworks-b9a2e.firebasestorage.app');
  }

  @override
  Widget build(BuildContext context) {
    widget.logger.d('🎨 PhotoGalleryScreen: Building UI for project: ${widget.project.name} [Multi-select: $_multiSelectMode, Selected: ${_selectedPhotoIds.length}]');

    return BaseLayout(
      title: '${widget.project.name} - Photo Gallery',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Photo Gallery',
      onMenuItemSelected: (_) {},
      floatingActionButton: FloatingActionButton(
        onPressed: _isLoading ? null : _startAddPhotoFlow,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
        child: const Icon(Icons.add_photo_alternate),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildPhotoGallery(),
                ],
              ),
            ),
          ),
          _buildFooter(context),
          if (_multiSelectMode)
            BottomAppBar(
              color: const Color(0xFF0A2E5A),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    icon: const Icon(Icons.share, color: Colors.white),
                    onPressed: _handleMultiShare,
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.white),
                    onPressed: _handleMultiDelete,
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel, color: Colors.white),
                    onPressed: () {
                      widget.logger.i('🔄 Exiting multi-select mode');
                      setState(() {
                        _multiSelectMode = false;
                        _selectedPhotoIds.clear();
                      });
                    },
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    widget.logger.d('🖌️ Building footer [Mobile: $isMobile]');
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: const Color(0xFF0A2E5A),
      child: Text(
        '© 2026 JV Alma C.I.S Site Management System',
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPhotoGallery() {
    widget.logger.d('📸 Building photo gallery stream for project: ${widget.project.id}');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('PhotoGallery')
          .where('projectId', isEqualTo: widget.project.id)
          .where('isDeleted', isEqualTo: false)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('Firestore error loading photos for project ${widget.project.id}: ${snapshot.error}', stackTrace: snapshot.stackTrace);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Error loading photos: ${snapshot.error}',
                  style: GoogleFonts.poppins(color: Colors.red[600]),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    widget.logger.i('🔄 Retrying Firestore query for photos');
                    setState(() {});
                  },
                  child: Text('Retry', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          widget.logger.d('📸 PhotoGalleryScreen: No snapshot data yet, showing loader');
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        final photos = docs.map((doc) => PhotoModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
        widget.logger.i('📸 Loaded ${photos.length} photos for project: ${widget.project.name} [IDs: ${photos.map((p) => p.id).join(', ')}]');

        if (photos.isEmpty) {
          widget.logger.d('📸 No photos available for project: ${widget.project.id}');
          return Padding(
            padding: const EdgeInsets.only(top: 84.0),
            child: Center(
              child: Text(
                'No photos yet. Add some!',
                style: GoogleFonts.poppins(color: Colors.grey[600]),
              ),
            ),
          );
        }

        // Group by date
        Map<String, List<PhotoModel>> dateGroups = {};
        for (var photo in photos) {
          final dateKey = DateFormat('yyyy-MM-dd').format(photo.uploadedAt);
          dateGroups.update(dateKey, (list) => list..add(photo), ifAbsent: () => [photo]);
        }
        widget.logger.d('📅 Grouped photos into ${dateGroups.length} date groups: ${dateGroups.keys.join(', ')}');

        // Sort dates descending
        final sortedDates = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));
        widget.logger.d('📅 Sorted dates: ${sortedDates.join(', ')}');

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateKey = sortedDates[index];
            final groupPhotos = dateGroups[dateKey]!;
            widget.logger.d('📅 Building gallery section for date: $dateKey, ${groupPhotos.length} photos');
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    _formatDate(DateTime.parse(dateKey)),
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 18),
                  ),
                ),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final width = constraints.maxWidth;
                    int crossAxisCount = width < 600 ? 2 : width < 1200 ? 4 : 6;
                    double spacing = width < 600 ? 8.0 : 16.0;
                    widget.logger.d('🖼️ Building grid with crossAxisCount: $crossAxisCount, width: $width, spacing: $spacing');
                    return Padding(
                      padding: EdgeInsets.symmetric(horizontal: spacing),
                      child: GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: crossAxisCount,
                          childAspectRatio: 1,
                          crossAxisSpacing: spacing,
                          mainAxisSpacing: spacing,
                        ),
                        itemCount: groupPhotos.length,
                        itemBuilder: (context, idx) {
                          final photo = groupPhotos[idx];
                          return GestureDetector(
                            onTap: () {
                              if (_multiSelectMode) {
                                _toggleSelection(photo.id);
                              } else {
                                _viewPhotoFullScreen(photo);
                              }
                            },
                            onLongPress: () => _startMultiSelect(photo.id),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: photo.url,
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Center(
                                    child: CircularProgressIndicator(
                                      color: const Color(0xFF0A2E5A),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) {
                                    widget.logger.e('🖼️ Image load error for ${photo.id}: $error');
                                    return _buildErrorWidget(error, photo);
                                  },
                                  fadeInDuration: const Duration(milliseconds: 300),
                                  fadeOutDuration: const Duration(milliseconds: 300),
                                  // Add retry mechanism
                                  maxHeightDiskCache: 1000,
                                  maxWidthDiskCache: 1000,
                                  // Force refresh on error
                                  cacheKey: photo.url,
                                  httpHeaders: {
                                    'Cache-Control': 'no-cache',
                                  },
                                ),
                                Positioned(
                                  bottom: 0,
                                  left: 0,
                                  right: 0,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    color: Colors.black.withValues(alpha: 0.5),
                                    child: Text(
                                      '${photo.category} - ${photo.phase}',
                                      style: GoogleFonts.poppins(color: Colors.white, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                                if (_multiSelectMode)
                                  Positioned(
                                    top: 8,
                                    right: 8,
                                    child: Checkbox(
                                      value: _selectedPhotoIds.contains(photo.id),
                                      onChanged: (value) => _toggleSelection(photo.id),
                                    ),
                                  ),
                              ],
                            ),
                          );
                        },
                      ),
                    );
                  },
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildErrorWidget(dynamic error, PhotoModel photo) {
    widget.logger.e('🖼️ Image load error: $error');
    return Container(
      color: Colors.grey[300],
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey[600], size: 32),
          const SizedBox(height: 8),
          Text(
            'Image unavailable',
            style: GoogleFonts.poppins(color: Colors.grey[700], fontSize: 10),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          ElevatedButton(
            onPressed: () {
              widget.logger.i('🔄 Retrying image load for ${photo.id}');
              // Force widget rebuild to retry image loading
              setState(() {});
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              minimumSize: const Size(50, 24),
            ),
            child: Text('Retry', style: GoogleFonts.poppins(fontSize: 10)),
          ),
        ],
      ),
    );
  }

  void _startMultiSelect(String photoId) {
    widget.logger.i('🖼️ Starting multi-select mode with photo $photoId');
    setState(() {
      _multiSelectMode = true;
      _selectedPhotoIds.add(photoId);
    });
  }

  void _toggleSelection(String photoId) {
    widget.logger.d('🖼️ Toggling selection for photo $photoId');
    setState(() {
      if (_selectedPhotoIds.contains(photoId)) {
        _selectedPhotoIds.remove(photoId);
        if (_selectedPhotoIds.isEmpty) {
          _multiSelectMode = false;
        }
      } else {
        _selectedPhotoIds.add(photoId);
      }
    });
  }

  Future<void> _handleMultiShare() async {
    widget.logger.i('📤 Starting multi-share for ${_selectedPhotoIds.length} photos');
    List<XFile> files = [];
    for (var id in _selectedPhotoIds) {
      final doc = await FirebaseFirestore.instance.collection('PhotoGallery').doc(id).get();
      if (doc.exists) {
        final photo = PhotoModel.fromMap(id, doc.data()!);
        final tempDir = await getTemporaryDirectory();
        final path = '${tempDir.path}/${photo.name}';
        await FirebaseStorage.instance.refFromURL(photo.url).writeToFile(File(path));
        files.add(XFile(path));
        widget.logger.d('📤 Added photo $id to share list: $path');
      }
    }
    if (files.isNotEmpty && mounted) {
      widget.logger.d('📤 Initiating multi-share');
      final params = ShareParams(files: files);
      await SharePlus.instance.share(params);
      widget.logger.i('✅ Multi-share completed');
    }
    setState(() {
      _multiSelectMode = false;
      _selectedPhotoIds.clear();
    });
  }

  Future<void> _handleMultiDelete() async {
    widget.logger.i('🗑️ Starting multi-delete for ${_selectedPhotoIds.length} photos');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Photos', style: GoogleFonts.poppins()),
        content: Text('Delete ${_selectedPhotoIds.length} selected photos?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      for (var id in _selectedPhotoIds) {
        await FirebaseFirestore.instance.collection('PhotoGallery').doc(id).update({'isDeleted': true});
        widget.logger.i('🗑️ Marked photo $id as deleted');
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photos deleted', style: GoogleFonts.poppins())),
        );
      }
    }
    setState(() {
      _multiSelectMode = false;
      _selectedPhotoIds.clear();
    });
  }

  void _viewPhotoFullScreen(PhotoModel photo) {
    widget.logger.i('🖼️ Viewing full screen: ${photo.id} - ${photo.url}');
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => Scaffold(
          appBar: AppBar(
            title: Text(photo.name, style: GoogleFonts.poppins()),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit),
                onPressed: () => _editPhotoDetails(photo),
              ),
              IconButton(
                icon: const Icon(Icons.share),
                onPressed: () => _sharePhoto(photo),
              ),
              IconButton(
                icon: const Icon(Icons.delete),
                onPressed: () => _deletePhoto(photo),
              ),
            ],
          ),
          body: PhotoView(
            imageProvider: CachedNetworkImageProvider(photo.url),
          ),
        ),
      ),
    );
  }

  Future<void> _editPhotoDetails(PhotoModel photo) async {
    final titleController = TextEditingController(text: photo.name);
    final categoryController = TextEditingController(text: photo.category);
    final phaseController = TextEditingController(text: photo.phase);

    final updated = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Edit Photo Details', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: titleController,
              decoration: InputDecoration(labelText: 'Title'),
            ),
            TextField(
              controller: categoryController,
              decoration: InputDecoration(labelText: 'Category'),
            ),
            TextField(
              controller: phaseController,
              decoration: InputDecoration(labelText: 'Phase'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              final newTitle = titleController.text.trim();
              final newCategory = categoryController.text.trim();
              final newPhase = phaseController.text.trim();
              if (newTitle.isNotEmpty || newCategory.isNotEmpty || newPhase.isNotEmpty) {
                Navigator.pop(ctx, true);
              } else {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  SnackBar(content: Text('At least one field must be filled')),
                );
              }
            },
            child: Text('Save'),
          ),
        ],
      ),
    );

    if (updated == true && mounted) {
      await FirebaseFirestore.instance.collection('PhotoGallery').doc(photo.id).update({
        if (titleController.text.trim().isNotEmpty) 'name': titleController.text.trim(),
        if (categoryController.text.trim().isNotEmpty) 'category': categoryController.text.trim(),
        if (phaseController.text.trim().isNotEmpty) 'phase': phaseController.text.trim(),
      });
      widget.logger.i('Updated photo details for ${photo.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo details updated')),
        );
      }
    }
  }

  Future<void> _sharePhoto(PhotoModel photo) async {
    widget.logger.i('📤 Starting single share for photo ${photo.id}');
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/${photo.name}';
      await FirebaseStorage.instance.refFromURL(photo.url).writeToFile(File(path));
      widget.logger.i('📤 Downloaded photo ${photo.id} to $path');
      if (!mounted) return;

      widget.logger.d('📤 Initiating share for photo ${photo.id}');
      final params = ShareParams(files: [XFile(path)]);
      await SharePlus.instance.share(params);
      widget.logger.i('✅ Single photo share completed for ${photo.id}');
    } catch (e, stackTrace) {
      widget.logger.e('📤 Error sharing photo ${photo.id}: $e', stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _deletePhoto(PhotoModel photo) async {
    widget.logger.i('🗑️ Starting delete for photo ${photo.id}');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Photo', style: GoogleFonts.poppins()),
        content: Text('Delete this photo?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Delete')),
        ],
      ),
    );
    if (confirmed == true) {
      await FirebaseFirestore.instance.collection('PhotoGallery').doc(photo.id).update({'isDeleted': true});
      widget.logger.i('🗑️ Marked photo ${photo.id} as deleted');
      if (mounted) {
        Navigator.pop(context); // Close viewer
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo deleted', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _startAddPhotoFlow() async {
    widget.logger.i('📸 Starting add photo flow for project: ${widget.project.id}');
    final uploadType = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Upload Photos', style: GoogleFonts.poppins()),
        content: Text('Select upload type', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'single'),
            child: Text('Single Photo'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'multiple'),
            child: Text('Multiple Photos'),
          ),
        ],
      ),
    );

    if (uploadType == null || !mounted) {
      widget.logger.d('📸 Add photo flow cancelled');
      return;
    }

    List<XFile> selectedFiles = [];
    if (uploadType == 'single') {
      final source = await showModalBottomSheet<String>(
        context: context,
        builder: (context) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text('Camera', style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text('Gallery', style: GoogleFonts.poppins()),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
          ],
        ),
      );

      if (source == null) return;

      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
      );
      if (file != null) {
        selectedFiles.add(file);
      }
    } else { // multiple
      final picker = ImagePicker();
      selectedFiles = await picker.pickMultiImage();
    }

    if (selectedFiles.isEmpty || !mounted) {
      widget.logger.d('📸 No photos selected');
      return;
    }

    // Confirm upload
    final confirmUpload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Upload', style: GoogleFonts.poppins()),
        content: Text('Upload ${selectedFiles.length} photo${selectedFiles.length > 1 ? 's' : ''}?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Confirm'),
          ),
        ],
      ),
    );

    if (confirmUpload != true || !mounted) {
      widget.logger.d('📸 Upload cancelled');
      return;
    }

    // Edit titles and enter details
    List<String> titles = selectedFiles.map((file) => file.name).toList();
    String category = '';
    String phase = '';

    final detailsConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Photo Details', style: GoogleFonts.poppins()),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (selectedFiles.length > 1)
                  ...List.generate(selectedFiles.length, (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: TextField(
                      onChanged: (value) {
                        titles[index] = value.trim().isEmpty ? selectedFiles[index].name : value.trim();
                      },
                      decoration: InputDecoration(
                        labelText: 'Title for Photo ${index + 1} (optional)',
                        hintText: selectedFiles[index].name,
                      ),
                    ),
                  )),
                if (selectedFiles.length == 1)
                  TextField(
                    onChanged: (value) {
                      titles[0] = value.trim().isEmpty ? selectedFiles[0].name : value.trim();
                    },
                    decoration: InputDecoration(
                      labelText: 'Title (optional)',
                      hintText: selectedFiles[0].name,
                    ),
                  ),
                TextField(
                  onChanged: (value) => category = value.trim(),
                  decoration: InputDecoration(labelText: 'Category (optional)'),
                ),
                TextField(
                  onChanged: (value) => phase = value.trim(),
                  decoration: InputDecoration(labelText: 'Phase (optional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                // Check if at least one detail is provided
                if (category.isNotEmpty || phase.isNotEmpty || titles.any((t) => t != selectedFiles[titles.indexOf(t)].name)) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('At least one detail must be provided')),
                  );
                }
              },
              child: Text('OK', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );

    if (detailsConfirmed != true || !mounted) {
      widget.logger.d('📸 Details input cancelled');
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Uploading', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: _uploadProgress),
            const SizedBox(height: 16),
            Text(
              '${(_uploadProgress! * 100).toStringAsFixed(0)}%',
              style: GoogleFonts.poppins(),
            ),
          ],
        ),
      ),
    );

    try {
      for (int i = 0; i < selectedFiles.length; i++) {
        final file = selectedFiles[i];
        final title = titles[i];
        Uint8List? bytes;
        
        if (!kIsWeb) {
          bytes = await File(file.path).readAsBytes();
        } else {
          bytes = await file.readAsBytes();
        }

        // Detect actual mime type from file extension
        String mimeType = 'image/jpeg';
        final extension = file.name.toLowerCase().split('.').last;
        if (extension == 'png') {
          mimeType = 'image/png';
        } else if (extension == 'jpg' || extension == 'jpeg') {
          mimeType = 'image/jpeg';
        } else if (extension == 'webp') {
          mimeType = 'image/webp';
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch + i;
        final fileName = title.contains('.') ? title : '${title}_$timestamp.$extension';
        final storageRef = FirebaseStorage.instance
            .ref()
            .child(widget.project.id)
            .child('PhotoGallery')
            .child(fileName);

        widget.logger.i('📤 Uploading image $i: $fileName with type $mimeType');

        final uploadTask = storageRef.putData(
          bytes,
          SettableMetadata(
            contentType: mimeType,
            cacheControl: 'public, max-age=31536000',
          ),
        );

        uploadTask.snapshotEvents.listen((snapshot) {
          if (mounted) {
            setState(() {
              _uploadProgress = (i / selectedFiles.length) + 
                  (snapshot.bytesTransferred / snapshot.totalBytes / selectedFiles.length);
            });
          }
        });

        await uploadTask;
        final url = await storageRef.getDownloadURL();
        
        widget.logger.i('✅ Image uploaded successfully: $fileName, URL: $url');

        await FirebaseFirestore.instance
            .collection('PhotoGallery')
            .add(PhotoModel(
              id: '',
              name: fileName,
              url: url,
              category: category,
              phase: phase,
              uploadedAt: DateTime.now(),
              projectId: widget.project.id,
            ).toMap());
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photos uploaded successfully!', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('📤 Error uploading photos: $e', stackTrace: stackTrace);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Upload error: $e', style: GoogleFonts.poppins()),
            action: SnackBarAction(
              label: 'Retry',
              onPressed: _startAddPhotoFlow,
            ),
          ),
        );
      }
    }
  }

  String _formatDate(DateTime date) {
    final formatted = DateFormat('MMMM dd, yyyy').format(date);
    widget.logger.d('📅 Formatted date: $date -> $formatted');
    return formatted;
  }
}