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
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
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
                        return FutureBuilder<Widget>(
                          future: _buildPhotoTile(photo),
                          builder: (context, snapshot) {
                            if (snapshot.connectionState == ConnectionState.waiting) {
                              return const Center(child: CircularProgressIndicator());
                            } else if (snapshot.hasError) {
                              return _buildErrorWidget();
                            } else {
                              return snapshot.data!;
                            }
                          },
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

  Future<Widget> _buildPhotoTile(PhotoModel photo) async {
    final isSelected = _selectedPhotoIds.contains(photo.id);
    widget.logger.d('🖼️ Building photo tile for ID: ${photo.id}, URL: ${photo.url}, Selected: $isSelected');
    return GestureDetector(
      onTap: _multiSelectMode ? () => _toggleSelection(photo.id) : () => _viewPhotoFullScreen(photo),
      onLongPress: () => _startMultiSelect(photo.id),
      child: Stack(
        children: [
          Container(
            decoration: BoxDecoration(
              border: isSelected ? Border.all(color: Colors.blue, width: 2) : null,
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: await _buildUnifiedImage(photo.url, photo.id, photo),
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

  Future<Widget> _buildUnifiedImage(String imageUrl, String photoId, PhotoModel photo) async {
    widget.logger.d('🖼️ Initializing image load for ID: $photoId, URL: $imageUrl');
    
    try {
      // Use Firebase Storage reference instead of direct HTTP
      final ref = FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
          .refFromURL(imageUrl);
      
      return FutureBuilder<String>(
        future: ref.getDownloadURL(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            widget.logger.e('⛔ Failed to get download URL for ID: $photoId, Error: ${snapshot.error}');
            return _buildErrorWidget();
          } else {
            final downloadUrl = snapshot.data!;
            return Image.network(
              downloadUrl,
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              loadingBuilder: (context, child, loadingProgress) {
                if (loadingProgress == null) return child;
                return const Center(child: CircularProgressIndicator());
              },
              errorBuilder: (context, error, stackTrace) {
                widget.logger.e('⛔ Image display FAILED for ID: $photoId, URL: $downloadUrl, Error: $error');
                return _buildErrorWidget();
              },
            );
          }
        },
      );
    } catch (e, stackTrace) {
      widget.logger.e('⛔ Error creating storage reference for ID: $photoId, Error: $e', stackTrace: stackTrace);
      return _buildErrorWidget();
    }
  }

  Widget _buildErrorWidget() {
    return Container(
      color: Colors.grey[300],
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, color: Colors.red),
            Text('Load Error', style: TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
  }

  void _startMultiSelect(String photoId) {
    if (!_multiSelectMode) {
      widget.logger.i('🔄 Starting multi-select mode with initial photo: $photoId');
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
    widget.logger.i('✅ Selection toggled for photo: $photoId, Selected IDs: ${_selectedPhotoIds.join(', ')}, Multi-select: $_multiSelectMode');
  }

  Future<void> _handleMultiDelete() async {
    if (_selectedPhotoIds.isEmpty) {
      widget.logger.w('🗑️ Multi-delete attempted but no photos selected');
      return;
    }

    widget.logger.i('🗑️ Multi-delete requested for ${_selectedPhotoIds.length} photos: ${_selectedPhotoIds.join(', ')}');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Selected Photos?', style: GoogleFonts.poppins()),
        content: Text('This will remove ${_selectedPhotoIds.length} photos from view but can be restored later.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () {
              widget.logger.d('🗑️ Multi-delete cancelled');
              Navigator.pop(context, false);
            },
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              widget.logger.d('🗑️ Multi-delete confirmed');
              Navigator.pop(context, true);
            },
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      widget.logger.d('🗑️ Multi-delete aborted [Confirm: $confirm, Mounted: $mounted]');
      return;
    }

    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final id in _selectedPhotoIds) {
        final ref = FirebaseFirestore.instance
            .collection('projects')
            .doc(widget.project.id)
            .collection('photos')
            .doc(id);
        batch.update(ref, {'isDeleted': true});
        widget.logger.d('🗑️ Added photo $id to batch delete');
      }
      await batch.commit();
      widget.logger.i('🗑️ Multi-delete committed for ${_selectedPhotoIds.length} photos');
      if (mounted) {
        setState(() {
          _multiSelectMode = false;
          _selectedPhotoIds.clear();
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Selected photos deleted', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('🗑️ Error during multi-delete: $e', stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photos: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _handleMultiShare() async {
    if (_selectedPhotoIds.isEmpty) {
      widget.logger.w('📤 Multi-share attempted but no photos selected');
      return;
    }

    widget.logger.i('📤 Multi-share requested for ${_selectedPhotoIds.length} photos: ${_selectedPhotoIds.join(', ')}');
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
          .where(FieldPath.documentId, whereIn: _selectedPhotoIds.toList())
          .get();
      if (!mounted) return;

      final photos = snapshot.docs.map((doc) => PhotoModel.fromMap(doc.id, doc.data())).toList();
      widget.logger.i('📤 Fetched ${photos.length} photos for sharing: ${photos.map((p) => p.id).join(', ')}');

      List<XFile> xFiles = [];
      final dir = await getTemporaryDirectory();
      widget.logger.d('📤 Temporary directory for sharing: ${dir.path}');

      for (final photo in photos) {
        try {
          final path = '${dir.path}/${photo.name}';
          widget.logger.d('📤 Downloading photo ${photo.id} from URL: ${photo.url}');
          
          // Use Firebase Storage to download the file
          final ref = FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
              .refFromURL(photo.url);
          final file = File(path);
          await ref.writeToFile(file);
          
          xFiles.add(XFile(file.path));
          widget.logger.i('📤 Successfully downloaded photo ${photo.id} to $path');
        } catch (e, stackTrace) {
          widget.logger.e('📤 Error downloading photo ${photo.id} for share: $e', stackTrace: stackTrace);
        }
      }

      if (!mounted) return;

      if (xFiles.isEmpty) {
        widget.logger.w('📤 No files available for sharing');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No photos could be shared', style: GoogleFonts.poppins())),
        );
        return;
      }

      widget.logger.d('📤 Initiating share with ${xFiles.length} files');
      final params = ShareParams(files: xFiles);
      await SharePlus.instance.share(params);
      widget.logger.i('✅ Multi-share completed for ${xFiles.length} photos');

      if (mounted) {
        setState(() {
          _multiSelectMode = false;
          _selectedPhotoIds.clear();
        });
      }
    } catch (e, stackTrace) {
      widget.logger.e('📤 Error during multi-share: $e', stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sharing photos: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  void _viewPhotoFullScreen(PhotoModel photo) {
    widget.logger.i('🔍 Opening fullscreen view for photo: ${photo.id}, URL: ${photo.url}, Category: ${photo.category}, Phase: ${photo.phase}');
    
    // Get fresh download URL for the fullscreen view
    Future<String> getFreshDownloadUrl() async {
      try {
        final ref = FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
            .refFromURL(photo.url);
        return await ref.getDownloadURL();
      } catch (e) {
        widget.logger.e('🔍 Error getting fresh download URL: $e');
        return photo.url; // Fallback to original URL
      }
    }

    showDialog(
      context: context,
      builder: (context) => Dialog.fullscreen(
        child: FutureBuilder<String>(
          future: getFreshDownloadUrl(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            
            final imageUrl = snapshot.data ?? photo.url;
            
            return Stack(
              children: [
                Center(
                  child: PhotoView(
                    imageProvider: NetworkImage(imageUrl),
                    minScale: PhotoViewComputedScale.contained,
                    maxScale: PhotoViewComputedScale.covered * 3,
                    loadingBuilder: (context, event) {
                      final progress = event?.expectedTotalBytes != null
                          ? (event!.cumulativeBytesLoaded / event.expectedTotalBytes! * 100).toStringAsFixed(1)
                          : 'unknown';
                      widget.logger.d('🔍 Fullscreen image loading for ${photo.id}: $progress% [${event?.cumulativeBytesLoaded ?? 0}/${event?.expectedTotalBytes ?? 'unknown'} bytes]');
                      return const Center(child: CircularProgressIndicator());
                    },
                    errorBuilder: (context, error, stackTrace) {
                      widget.logger.e('⛔ Fullscreen image load FAILED for ${photo.id}, URL: $imageUrl, Error: $error, StackTrace: $stackTrace');
                      return const Center(child: Icon(Icons.error, color: Colors.red));
                    },
                  ),
                ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    color: const Color.fromRGBO(0, 0, 0, 0.7),
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
                            widget.logger.d('✏️ Edit button pressed for photo: ${photo.id} [Not implemented]');
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
                    onPressed: () {
                      widget.logger.d('🔍 Closing fullscreen view for photo: ${photo.id}');
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  void _showPhotoDetails(PhotoModel photo) {
    widget.logger.i('ℹ️ Showing details for photo: ${photo.id}, Name: ${photo.name}, Category: ${photo.category}, Phase: ${photo.phase}, Uploaded: ${_formatDate(photo.uploadedAt)}');
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
            onPressed: () {
              widget.logger.d('ℹ️ Closing photo details dialog for photo: ${photo.id}');
              Navigator.pop(context);
            },
            child: Text('Close', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Future<void> _rotatePhoto(PhotoModel photo) async {
    widget.logger.i('🔄 Initiating rotation for photo: ${photo.id}, URL: ${photo.url}, Bucket: gs://almaworks-b9a2e.firebasestorage.app');
    try {
      widget.logger.d('🔄 Downloading image for rotation: ${photo.url}');
      
      // Use Firebase Storage to download the file
      final ref = FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
          .refFromURL(photo.url);
      final bytes = await ref.getData();
      
      if (!mounted) {
        widget.logger.w('🔄 Rotation aborted: Widget not mounted');
        return;
      }
      
      if (bytes == null) {
        throw Exception('Failed to download image bytes');
      }
      
      widget.logger.d('🔄 Downloaded ${bytes.length} bytes for rotation');
      img.Image image = img.decodeImage(Uint8List.fromList(bytes))!;
      image = img.copyRotate(image, angle: 90);
      final newBytes = img.encodeJpg(image);
      widget.logger.d('🔄 Image rotated and encoded, new size: ${newBytes.length} bytes');

      widget.logger.d('🗑️ Deleting old image: ${photo.url}');
      await FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
          .refFromURL(photo.url)
          .delete();
      widget.logger.i('🗑️ Old image deleted successfully');
      if (!mounted) {
        widget.logger.w('🔄 Rotation aborted post-deletion: Widget not mounted');
        return;
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final newRef = FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
          .ref()
          .child('projects/${widget.project.id}/photos/${timestamp}_${photo.name}');
      widget.logger.d('📤 Uploading rotated image to: projects/${widget.project.id}/photos/${timestamp}_${photo.name}');
      final uploadTask = newRef.putData(newBytes, SettableMetadata(contentType: 'image/jpeg'));
      uploadTask.snapshotEvents.listen((snapshot) {
        final progress = (snapshot.bytesTransferred / snapshot.totalBytes * 100).toStringAsFixed(1);
        widget.logger.d('📤 Rotation upload progress for ${photo.id}: $progress% [${snapshot.bytesTransferred}/${snapshot.totalBytes} bytes]');
      });
      await uploadTask;
      if (!mounted) {
        widget.logger.w('🔄 Rotation aborted post-upload: Widget not mounted');
        return;
      }
      final newUrl = await newRef.getDownloadURL();
      widget.logger.i('📤 Rotated image uploaded, new URL: $newUrl');
      if (!mounted) return;

      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
          .doc(photo.id)
          .update({'url': newUrl});
      widget.logger.i('✅ Firestore updated with new URL for photo: ${photo.id}');
      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo rotated successfully', style: GoogleFonts.poppins())),
      );
    } catch (e, stackTrace) {
      widget.logger.e('🔄 Error rotating photo ${photo.id}: $e', stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rotating photo: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _deletePhoto(PhotoModel photo) async {
    widget.logger.i('🗑️ Initiating delete for photo: ${photo.id}, URL: ${photo.url}, Bucket: gs://almaworks-b9a2e.firebasestorage.app');
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Photo?', style: GoogleFonts.poppins()),
        content: Text('This will remove ${photo.name} from view but can be restored later.', style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () {
              widget.logger.d('🗑️ Delete cancelled for photo: ${photo.id}');
              Navigator.pop(context, false);
            },
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          TextButton(
            onPressed: () {
              widget.logger.d('🗑️ Delete confirmed for photo: ${photo.id}');
              Navigator.pop(context, true);
            },
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirm != true || !mounted) {
      widget.logger.d('🗑️ Delete aborted for photo: ${photo.id} [Confirm: $confirm, Mounted: $mounted]');
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('projects')
          .doc(widget.project.id)
          .collection('photos')
          .doc(photo.id)
          .update({'isDeleted': true});
      widget.logger.i('✅ Photo ${photo.id} marked as deleted in Firestore');
      if (!mounted) return;

      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Photo deleted', style: GoogleFonts.poppins())),
      );
    } catch (e, stackTrace) {
      widget.logger.e('🗑️ Error deleting photo ${photo.id}: $e, StackTrace: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting photo: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _sharePhoto(PhotoModel photo) async {
    widget.logger.i('📤 Initiating single photo share for: ${photo.id}, URL: ${photo.url}, Bucket: gs://almaworks-b9a2e.firebasestorage.app');
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/${photo.name}';
      widget.logger.d('📤 Downloading photo ${photo.id} to $path');
      
      // Use Firebase Storage to download the file
      final ref = FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
          .refFromURL(photo.url);
      final file = File(path);
      await ref.writeToFile(file);
      
      widget.logger.i('📤 Downloaded photo ${photo.id} to $path');
      if (!mounted) return;

      widget.logger.d('📤 Initiating share for photo ${photo.id}');
      final params = ShareParams(files: [XFile(file.path)]);
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

  Future<void> _startAddPhotoFlow() async {
    widget.logger.i('📸 Starting add photo flow for project: ${widget.project.id}, Bucket: gs://almaworks-b9a2e.firebasestorage.app');
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
      final storageRef = FirebaseStorage.instanceFor(bucket: 'gs://almaworks-b9a2e.firebasestorage.app')
          .ref()
          .child('projects/${widget.project.id}/photos/$fileName');
      widget.logger.i('📤 Initiating upload to Storage: projects/${widget.project.id}/photos/$fileName, Bucket: gs://almaworks-b9a2e.firebasestorage.app');

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