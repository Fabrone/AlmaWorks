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
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import 'package:photo_view/photo_view.dart';
import 'package:image/image.dart' as img; 

class PhotoModel {
  final String id;
  final String name;
  final String url;
  final String category;
  final String phase;
  final DateTime uploadedAt;
  final bool isDeleted;

  PhotoModel({
    required this.id,
    required this.name,
    required this.url,
    required this.category,
    required this.phase,
    required this.uploadedAt,
    this.isDeleted = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'url': url,
      'category': category,
      'phase': phase,
      'uploadedAt': Timestamp.fromDate(uploadedAt),
      'isDeleted': isDeleted,
    };
  }

  static PhotoModel fromMap(String id, Map<String, dynamic> data) {
    return PhotoModel(
      id: id,
      name: data['name'],
      url: data['url'],
      category: data['category'],
      phase: data['phase'],
      uploadedAt: (data['uploadedAt'] as Timestamp).toDate(),
      isDeleted: data['isDeleted'] ?? false,
    );
  }
}

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
  final Dio _dio = Dio();

  @override
  void initState() {
    super.initState();
    widget.logger.i('📸 PhotoGalleryScreen: Initialized for project: ${widget.project.name}');
  }

  @override
  Widget build(BuildContext context) {
    widget.logger.d('🎨 PhotoGalleryScreen: Building UI');

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

  Widget _buildPhotoGallery() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
          .where('isDeleted', isEqualTo: false)
          .orderBy('uploadedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('Firestore error: ${snapshot.error}');
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
                  onPressed: () => setState(() {}), // Trigger rebuild
                  child: Text('Retry', style: GoogleFonts.poppins()),
                ),
              ],
            ),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs;
        final photos = docs.map((doc) => PhotoModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();

        if (photos.isEmpty) {
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

        // Sort dates descending
        final sortedDates = dateGroups.keys.toList()..sort((a, b) => b.compareTo(a));

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: sortedDates.length,
          itemBuilder: (context, index) {
            final dateKey = sortedDates[index];
            final groupPhotos = dateGroups[dateKey]!;
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
                    return GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: crossAxisCount,
                        childAspectRatio: 1,
                        crossAxisSpacing: 4,
                        mainAxisSpacing: 4,
                      ),
                      itemCount: groupPhotos.length,
                      itemBuilder: (context, idx) {
                        final photo = groupPhotos[idx];
                        return _buildPhotoTile(photo);
                      },
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

  Widget _buildPhotoTile(PhotoModel photo) {
    final isSelected = _selectedPhotoIds.contains(photo.id);
    return GestureDetector(
      onTap: _multiSelectMode ? () => _toggleSelection(photo.id) : () => _viewPhotoFullScreen(photo),
      onLongPress: () => _startMultiSelect(photo.id),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: Image.network(
              photo.url,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                widget.logger.e('Image load error: $error');
                return Icon(Icons.error, color: Colors.red);
              },
            ),
          ),
          if (_multiSelectMode)
            Positioned(
              top: 8,
              right: 8,
              child: Checkbox(
                value: isSelected,
                onChanged: (_) => _toggleSelection(photo.id),
              ),
            ),
        ],
      ),
    );
  }

  void _startMultiSelect(String photoId) {
    if (!_multiSelectMode) {
      setState(() {
        _multiSelectMode = true;
        _selectedPhotoIds.add(photoId);
      });
    }
  }

  void _toggleSelection(String photoId) {
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

  Future<void> _handleMultiDelete() async {
    if (_selectedPhotoIds.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Selected Photos?', style: GoogleFonts.poppins()),
        content: Text('This will remove them from view but can be restored later.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    final batch = FirebaseFirestore.instance.batch();
    for (final id in _selectedPhotoIds) {
      final ref = FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
          .doc(id);
      batch.update(ref, {'isDeleted': true});
    }
    await batch.commit();

    if (mounted) {
      setState(() {
        _multiSelectMode = false;
        _selectedPhotoIds.clear();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected photos deleted', style: GoogleFonts.poppins())),
      );
    }
  }

  Future<void> _handleMultiShare() async {
    if (_selectedPhotoIds.isEmpty) return;

    // Fetch selected photos
    final snapshot = await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.project.id)
        .collection('photos')
        .where(FieldPath.documentId, whereIn: _selectedPhotoIds.toList())
        .get();

    if (!mounted) return;

    final photos = snapshot.docs.map((doc) => PhotoModel.fromMap(doc.id, doc.data())).toList();

    List<XFile> xFiles = [];
    final dir = await getTemporaryDirectory();

    for (final photo in photos) {
      final path = '${dir.path}/${photo.name}';
      final response = await _dio.get(photo.url, options: Options(responseType: ResponseType.bytes));
      if (!mounted) return;
      final bytes = response.data as List<int>;
      final file = await File(path).writeAsBytes(bytes);
      xFiles.add(XFile(file.path));
    }

    if (!mounted) return;

    final params = ShareParams(files: xFiles);
    await SharePlus.instance.share(params);

    setState(() {
      _multiSelectMode = false;
      _selectedPhotoIds.clear();
    });
  }

  void _viewPhotoFullScreen(PhotoModel photo) {
    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: Stack(
          children: [
            PhotoView(
              imageProvider: NetworkImage(photo.url),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 3,
              loadingBuilder: (context, event) => Center(child: CircularProgressIndicator()),
              errorBuilder: (context, error, stackTrace) {
                widget.logger.e('Full-screen image load error: $error');
                return Center(child: Icon(Icons.error, color: Colors.red));
              },
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                color: Colors.black.withValues(alpha: 0.7 * 255.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.info, color: Colors.white),
                      onPressed: () => _showPhotoDetails(photo),
                    ),
                    IconButton(
                      icon: const Icon(Icons.rotate_right, color: Colors.white),
                      onPressed: () => _rotatePhoto(photo),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete, color: Colors.white),
                      onPressed: () => _deletePhoto(photo),
                    ),
                    IconButton(
                      icon: const Icon(Icons.share, color: Colors.white),
                      onPressed: () => _sharePhoto(photo),
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, color: Colors.white),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Editing features coming soon', style: GoogleFonts.poppins())),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPhotoDetails(PhotoModel photo) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Photo Details', style: GoogleFonts.poppins()),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${photo.name}', style: GoogleFonts.poppins()),
            Text('Category: ${photo.category}', style: GoogleFonts.poppins()),
            Text('Phase: ${photo.phase}', style: GoogleFonts.poppins()),
            Text('Uploaded: ${_formatDate(photo.uploadedAt)}', style: GoogleFonts.poppins()),
          ],
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

  Future<void> _rotatePhoto(PhotoModel photo) async {
    try {
      final response = await _dio.get(photo.url, options: Options(responseType: ResponseType.bytes));
      if (!mounted) return;
      final bytes = response.data as List<int>;
      img.Image image = img.decodeImage(Uint8List.fromList(bytes))!;
      image = img.copyRotate(image, angle: 90);
      final newBytes = img.encodeJpg(image);

      // Delete old
      await FirebaseStorage.instance.refFromURL(photo.url).delete();
      if (!mounted) return;

      // Upload new
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.project.id}/photos/${timestamp}_${photo.name}');
      await newRef.putData(newBytes, SettableMetadata(contentType: 'image/jpeg'));
      if (!mounted) return;
      final newUrl = await newRef.getDownloadURL();
      if (!mounted) return;

      // Update Firestore
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
          .doc(photo.id)
          .update({'url': newUrl});
      if (!mounted) return;

      Navigator.pop(context); // Close full screen to refresh
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo rotated successfully', style: GoogleFonts.poppins())),
      );
    } catch (e) {
      widget.logger.e('Error rotating photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rotating photo: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _deletePhoto(PhotoModel photo) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Photo?', style: GoogleFonts.poppins()),
        content: Text('This will remove it from view but can be restored later.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) return;

    await FirebaseFirestore.instance
        .collection('projects')
        .doc(widget.project.id)
        .collection('photos')
        .doc(photo.id)
        .update({'isDeleted': true});
    if (!mounted) return;

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Photo deleted', style: GoogleFonts.poppins())),
    );
  }

  Future<void> _sharePhoto(PhotoModel photo) async {
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${photo.name}';
      final response = await _dio.get(photo.url, options: Options(responseType: ResponseType.bytes));
      if (!mounted) return;
      final bytes = response.data as List<int>;
      final file = await File(path).writeAsBytes(bytes);
      if (!mounted) return;

      final params = ShareParams(files: [XFile(file.path)]);
      await SharePlus.instance.share(params);
    } catch (e) {
      widget.logger.e('Error sharing photo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _startAddPhotoFlow() async {
    // Show bottom sheet for source selection
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

    if (source == null || !mounted) return;

    // Get details
    String? category;
    String? phase;
    final detailsConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Text('Photo Details', style: GoogleFonts.poppins()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(labelText: 'Category', labelStyle: GoogleFonts.poppins()),
                onChanged: (val) => category = val.trim(),
              ),
              TextField(
                decoration: InputDecoration(labelText: 'Phase', labelStyle: GoogleFonts.poppins()),
                onChanged: (val) => phase = val.trim(),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () {
                if (category != null && category!.isNotEmpty && phase != null && phase!.isNotEmpty) {
                  Navigator.pop(ctx, true);
                } else {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('Please fill all fields', style: GoogleFonts.poppins())),
                  );
                }
              },
              child: Text('OK', style: GoogleFonts.poppins()),
            ),
          ],
        );
      },
    );

    if (detailsConfirmed != true || !mounted) return;

    // Pick image
    final picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );

    if (imageFile == null || !mounted) return;

    Uint8List? bytes;
    if (!kIsWeb) {
      bytes = await File(imageFile.path).readAsBytes();
    } else {
      bytes = await imageFile.readAsBytes();
    }

    if (!mounted) return;

    // Confirm upload
    final confirmUpload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Upload', style: GoogleFonts.poppins()),
        content: Text('Upload photo?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text('Upload')),
        ],
      ),
    );

    if (confirmUpload != true || !mounted) return;

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    // Show progress dialog
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
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = 'photo_$timestamp.jpg';
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('projects/${widget.project.id}/photos/$fileName');

      final uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
        }
      });

      await uploadTask;
      if (!mounted) return;
      final url = await storageRef.getDownloadURL();
      if (!mounted) return;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
          .add(PhotoModel(
            id: '', // Will be set by Firestore
            name: fileName,
            url: url,
            category: category!,
            phase: phase!,
            uploadedAt: DateTime.now(),
          ).toMap());

      if (mounted) {
        Navigator.pop(context); // Close progress
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo uploaded successfully!', style: GoogleFonts.poppins())),
        );
      }
    } catch (e) {
      widget.logger.e('Error uploading photo: $e');
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e', style: GoogleFonts.poppins())),
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

  String _formatDate(DateTime date) {
    return DateFormat('MMMM dd, yyyy').format(date);
  }
}