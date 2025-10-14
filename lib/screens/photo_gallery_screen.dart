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
                    widget.logger.d('🖼️ Building grid with crossAxisCount: $crossAxisCount, width: $width');
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
                                placeholder: (context, url) => Center(child: CircularProgressIndicator()),
                                errorWidget: (context, url, error) => _buildErrorWidget(error),
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

  Widget _buildErrorWidget(dynamic error) {
    widget.logger.e('🖼️ Image load error: $error');
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error, color: Colors.red),
          Text('Error loading image', style: GoogleFonts.poppins(color: Colors.red)),
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
    final source = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.camera_alt),
            title: Text('Camera', style: GoogleFonts.poppins()),
            onTap: () {
              widget.logger.d('📸 Selected camera as source');
              Navigator.pop(context, 'camera');
            },
          ),
          ListTile(
            leading: const Icon(Icons.photo_library),
            title: Text('Gallery', style: GoogleFonts.poppins()),
            onTap: () {
              widget.logger.d('📸 Selected gallery as source');
              Navigator.pop(context, 'gallery');
            },
          ),
        ],
      ),
    );

    if (source == null || !mounted) {
      widget.logger.d('📸 Add photo flow cancelled: Source = $source, Mounted = $mounted');
      return;
    }

    String? category;
    String? phase;
    widget.logger.d('📸 Prompting for photo details');
    final detailsConfirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final TextEditingController categoryController = TextEditingController();
        final TextEditingController phaseController = TextEditingController();
        return StatefulBuilder(
          builder: (ctx, setState) => AlertDialog(
            title: Text('Photo Details', style: GoogleFonts.poppins()),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: categoryController,
                  decoration: InputDecoration(labelText: 'Category', labelStyle: GoogleFonts.poppins()),
                ),
                TextField(
                  controller: phaseController,
                  decoration: InputDecoration(labelText: 'Phase', labelStyle: GoogleFonts.poppins()),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  widget.logger.d('📸 Photo details input cancelled');
                  Navigator.pop(ctx, false);
                },
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              TextButton(
                onPressed: () {
                  category = categoryController.text.trim();
                  phase = phaseController.text.trim();
                  if (category != null && category!.isNotEmpty && phase != null && phase!.isNotEmpty) {
                    widget.logger.d('📸 Photo details confirmed: Category = $category, Phase = $phase');
                    Navigator.pop(ctx, true);
                  } else {
                    widget.logger.w('📸 Invalid photo details: Category = $category, Phase = $phase');
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('Please fill all fields', style: GoogleFonts.poppins())),
                    );
                  }
                },
                child: Text('OK', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
      },
    );

    if (detailsConfirmed != true || !mounted) {
      widget.logger.d('📸 Add photo flow aborted: DetailsConfirmed = $detailsConfirmed, Mounted = $mounted');
      return;
    }

    widget.logger.d('📸 Picking image from source: $source');
    final picker = ImagePicker();
    final XFile? imageFile = await picker.pickImage(
      source: source == 'camera' ? ImageSource.camera : ImageSource.gallery,
    );

    if (imageFile == null || !mounted) {
      widget.logger.d('📸 Image picking cancelled or failed: ImageFile = $imageFile, Mounted = $mounted');
      return;
    }

    Uint8List? bytes;
    if (!kIsWeb) {
      bytes = await File(imageFile.path).readAsBytes();
    } else {
      bytes = await imageFile.readAsBytes();
    }
    widget.logger.i('📸 Image picked: ${bytes.length} bytes, Name: ${imageFile.name}');

    if (!mounted) {
      widget.logger.w('📸 Upload aborted: Widget not mounted');
      return;
    }

    widget.logger.d('📸 Prompting for upload confirmation');
    final confirmUpload = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Confirm Upload', style: GoogleFonts.poppins()),
        content: Text('Upload photo?', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () {
              widget.logger.d('📸 Upload cancelled');
              Navigator.pop(context, false);
            },
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              widget.logger.d('📸 Upload confirmed');
              Navigator.pop(context, true);
            },
            child: Text('Upload'),
          ),
        ],
      ),
    );

    if (confirmUpload != true || !mounted) {
      widget.logger.d('📸 Upload aborted: ConfirmUpload = $confirmUpload, Mounted = $mounted');
      return;
    }

    setState(() {
      _isLoading = true;
      _uploadProgress = 0.0;
    });

    widget.logger.d('📸 Showing upload progress dialog');
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
          .child(widget.project.id)
          .child('PhotoGallery')
          .child(fileName);
      widget.logger.i('📤 Initiating upload to Storage: ${widget.project.id}/PhotoGallery/$fileName, Bucket: gs://almaworks-b9a2e.firebasestorage.app');

      final uploadTask = storageRef.putData(bytes, SettableMetadata(contentType: 'image/jpeg'));

      uploadTask.snapshotEvents.listen((snapshot) {
        if (mounted) {
          setState(() {
            _uploadProgress = snapshot.bytesTransferred / snapshot.totalBytes;
          });
          widget.logger.d('📤 Upload progress for $fileName: ${(snapshot.bytesTransferred / snapshot.totalBytes * 100).toStringAsFixed(1)}% [${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes]');
        }
      });

      await uploadTask;
      if (!mounted) {
        widget.logger.w('📤 Upload aborted post-task: Widget not mounted');
        return;
      }
      final url = await storageRef.getDownloadURL();
      widget.logger.i('📤 Upload complete, URL: $url');
      if (!mounted) return;

      final photoDoc = await FirebaseFirestore.instance
          .collection('PhotoGallery')
          .add(PhotoModel(
            id: '', // Will be set by Firestore
            name: fileName,
            url: url,
            category: category!,
            phase: phase!,
            uploadedAt: DateTime.now(),
            projectId: widget.project.id,
          ).toMap());
      widget.logger.i('✅ Photo saved to Firestore with ID: ${photoDoc.id}');

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Photo uploaded successfully!', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('📤 Error uploading photo: $e, StackTrace: $stackTrace');
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
        widget.logger.d('📸 Upload process completed, reset loading state');
      }
    }
  }

  String _formatDate(DateTime date) {
    final formatted = DateFormat('MMMM dd, yyyy').format(date);
    widget.logger.d('📅 Formatted date: $date -> $formatted');
    return formatted;
  }
}