import 'dart:io';
import 'package:almaworks/models/drawing_model.dart';
import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/screens/documents_screen.dart';
import 'package:almaworks/screens/projects/project_summary_screen.dart';
import 'package:almaworks/screens/projects/projects_main_screen.dart';
import 'package:almaworks/services/drawing_service.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:logger/logger.dart';
import 'package:google_fonts/google_fonts.dart';

class DrawingsScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const DrawingsScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<DrawingsScreen> createState() => _DrawingsScreenState();
}

class _DrawingsScreenState extends State<DrawingsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DrawingService _drawingService = DrawingService();
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    widget.logger.i('🏗️ DrawingsScreen: Initialized for project: ${widget.project.name}');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BaseLayout(
      title: '${widget.project.name} - Drawings',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Drawings',
      onMenuItemSelected: _handleMenuNavigation, // Updated to use proper navigation method
      floatingActionButton: _tabController.index == 0
          ? FloatingActionButton(
              onPressed: _isUploading ? null : _uploadDrawing,
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
              child: _isUploading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Icon(Icons.upload_file),
            )
          : null,
      child: Column(
        children: [
          // Tab Bar
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
              indicatorWeight: 3,
              labelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              unselectedLabelStyle: GoogleFonts.poppins(
                fontWeight: FontWeight.w500,
                fontSize: 16,
              ),
              tabs: const [
                Tab(text: 'Revisions'),
                Tab(text: 'As Built'),
              ],
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRevisionsTab(),
                _buildAsBuiltTab(),
              ],
            ),
          ),
          
          _buildFooter(context),
        ],
      ),
    );
  }

  void _handleMenuNavigation(String menuItem) {
    widget.logger.d('🧭 DrawingsScreen: Navigation to: $menuItem');
    
    switch (menuItem) {
      case 'Switch Project':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectsMainScreen(logger: widget.logger),
          ),
        );
        break;
      case 'Overview':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ProjectSummaryScreen(
              project: widget.project,
              logger: widget.logger,
            ),
          ),
        );
        break;
      case 'Documents':
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DocumentsScreen(
              project: widget.project,
              logger: widget.logger,
            ),
          ),
        );
        break;
      case 'Drawings':
        // Already on drawings screen
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$menuItem section coming soon',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
        break;
    }
  }

  Widget _buildFooter(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border(
          top: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Column(
        children: [
          Text(
            'AlmaWorks Construction Management',
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF0A2E5A),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'End of Drawings Section',
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRevisionsTab() {
    return StreamBuilder<List<DrawingModel>>(
      stream: _drawingService.getRevisionDrawings(widget.project.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e('❌ DrawingsScreen: Error loading revisions', error: snapshot.error);
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading drawings',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final drawings = snapshot.data!;
        final groupedDrawings = _drawingService.groupDrawingsByTitle(drawings);

        if (groupedDrawings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.architecture, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No drawings uploaded yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Tap the upload button to add your first drawing',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: groupedDrawings.length,
          itemBuilder: (context, index) {
            final group = groupedDrawings[index];
            return _buildDrawingGroup(group);
          },
        );
      },
    );
  }

  Widget _buildAsBuiltTab() {
    return StreamBuilder<List<DrawingModel>>(
      stream: _drawingService.getAsBuiltDrawings(widget.project.id),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                const SizedBox(height: 16),
                Text(
                  'Error loading as-built drawings',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          );
        }

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final drawings = snapshot.data!;

        if (drawings.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.check_circle_outline, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No as-built drawings yet',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Mark revisions as final to move them here',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: drawings.length,
          itemBuilder: (context, index) {
            final drawing = drawings[index];
            return _buildAsBuiltDrawingCard(drawing);
          },
        );
      },
    );
  }

  Widget _buildDrawingGroup(DrawingGroup group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ExpansionTile(
        title: Text(
          group.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          'Rev ${group.latestRevision?.revisionNumber ?? 0} (Latest) • ${group.revisions.length} revision${group.revisions.length != 1 ? 's' : ''}',
          style: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: const Color(0xFF0A2E5A).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getDrawingIcon(group.latestRevision?.type ?? ''),
            color: const Color(0xFF0A2E5A),
          ),
        ),
        children: group.revisions.map((drawing) => _buildRevisionTile(drawing, group)).toList(),
      ),
    );
  }

  Widget _buildRevisionTile(DrawingModel drawing, DrawingGroup group) {
    final isLatest = drawing.revisionNumber == group.latestRevision?.revisionNumber;
    
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: isLatest 
              ? Colors.green.withValues(alpha: 0.1)
              : Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            'R${drawing.revisionNumber}',
            style: GoogleFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: isLatest ? Colors.green[700] : Colors.grey[600],
            ),
          ),
        ),
      ),
      title: Text(
        drawing.fileName,
        style: GoogleFonts.poppins(fontSize: 14),
      ),
      subtitle: Text(
        'Uploaded ${_formatDate(drawing.uploadedAt)}',
        style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isLatest) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Latest',
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 8),
          ],
          PopupMenuButton<String>(
            onSelected: (value) => _handleRevisionAction(value, drawing),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'view',
                child: Row(
                  children: [
                    Icon(Icons.visibility, size: 16),
                    SizedBox(width: 8),
                    Text('View'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'download',
                child: Row(
                  children: [
                    Icon(Icons.download, size: 16),
                    SizedBox(width: 8),
                    Text('Download'),
                  ],
                ),
              ),
              if (!drawing.isFinal)
                const PopupMenuItem(
                  value: 'mark_final',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle, size: 16),
                      SizedBox(width: 8),
                      Text('Mark as Final'),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'delete',
                child: Row(
                  children: [
                    Icon(Icons.delete, size: 16, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Delete', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAsBuiltDrawingCard(DrawingModel drawing) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            _getDrawingIcon(drawing.type),
            color: Colors.green[700],
            size: 24,
          ),
        ),
        title: Text(
          drawing.title,
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              drawing.fileName,
              style: GoogleFonts.poppins(fontSize: 14),
            ),
            const SizedBox(height: 4),
            Text(
              'Finalized ${_formatDate(drawing.finalizedAt!)} • Rev ${drawing.revisionNumber}',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleAsBuiltAction(value, drawing),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'view',
              child: Row(
                children: [
                  Icon(Icons.visibility, size: 16),
                  SizedBox(width: 8),
                  Text('View'),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'download',
              child: Row(
                children: [
                  Icon(Icons.download, size: 16),
                  SizedBox(width: 8),
                  Text('Download'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadDrawing() async {
    try {
      widget.logger.i('📤 DrawingsScreen: Starting drawing upload');

      // Pick file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'dwg', 'dxf', 'jpg', 'jpeg', 'png'],
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        widget.logger.d('📤 DrawingsScreen: File selection cancelled');
        return;
      }

      final file = result.files.first;
      final fileName = file.name;
      final fileExtension = fileName.split('.').last.toLowerCase();

      // Get file bytes
      List<int> fileBytes;
      if (kIsWeb) {
        fileBytes = file.bytes!;
      } else {
        fileBytes = await File(file.path!).readAsBytes();
      }

      // Show title input dialog
      final title = await _showTitleInputDialog(fileName);
      if (title == null || title.trim().isEmpty) {
        return;
      }

      setState(() {
        _isUploading = true;
      });

      // Show upload progress dialog
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            title: Text(
              'Uploading Drawing',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(
                  'Uploading $fileName...',
                  style: GoogleFonts.poppins(),
                ),
              ],
            ),
          ),
        );
      }

      // Upload drawing
      await _drawingService.uploadDrawing(
        projectId: widget.project.id,
        title: title.trim(),
        fileName: fileName,
        fileBytes: fileBytes,
        fileExtension: fileExtension,
      );

      if (mounted) {
        Navigator.pop(context); // Close progress dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Drawing "$title" uploaded successfully!',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.green,
          ),
        );
      }

      widget.logger.i('✅ DrawingsScreen: Drawing uploaded successfully');
    } catch (e) {
      widget.logger.e('❌ DrawingsScreen: Upload failed', error: e);
      
      if (mounted) {
        Navigator.pop(context); // Close progress dialog if open
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Upload failed: ${e.toString()}',
              style: GoogleFonts.poppins(),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  Future<String?> _showTitleInputDialog(String fileName) async {
    final controller = TextEditingController(
      text: fileName.split('.').first, // Remove extension
    );

    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Drawing Title',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter a title for this drawing:',
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'e.g., Floor Plan Level 1',
                border: const OutlineInputBorder(),
                hintStyle: GoogleFonts.poppins(),
              ),
              style: GoogleFonts.poppins(),
              autofocus: true,
            ),
            const SizedBox(height: 8),
            Text(
              'File: $fileName',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.poppins(),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, controller.text),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0A2E5A),
              foregroundColor: Colors.white,
            ),
            child: Text(
              'Upload',
              style: GoogleFonts.poppins(),
            ),
          ),
        ],
      ),
    );
  }

  void _handleRevisionAction(String action, DrawingModel drawing) async {
    switch (action) {
      case 'view':
        // Implement view functionality
        widget.logger.d('👁️ DrawingsScreen: View drawing: ${drawing.fileName}');
        break;
      case 'download':
        // Implement download functionality
        widget.logger.d('⬇️ DrawingsScreen: Download drawing: ${drawing.fileName}');
        break;
      case 'mark_final':
        await _markDrawingAsFinal(drawing);
        break;
      case 'delete':
        await _deleteDrawing(drawing);
        break;
    }
  }

  void _handleAsBuiltAction(String action, DrawingModel drawing) async {
    switch (action) {
      case 'view':
        // Implement view functionality
        widget.logger.d('👁️ DrawingsScreen: View as-built: ${drawing.fileName}');
        break;
      case 'download':
        // Implement download functionality
        widget.logger.d('⬇️ DrawingsScreen: Download as-built: ${drawing.fileName}');
        break;
    }
  }

  Future<void> _markDrawingAsFinal(DrawingModel drawing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Mark as Final',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to mark "${drawing.title} Rev ${drawing.revisionNumber}" as final? This will move it to the As Built section.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: Text('Mark as Final', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _drawingService.markAsFinal(drawing.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Drawing marked as final and moved to As Built',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to mark as final: ${e.toString()}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _deleteDrawing(DrawingModel drawing) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Delete Drawing',
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
        content: Text(
          'Are you sure you want to delete "${drawing.fileName}"? This action cannot be undone.',
          style: GoogleFonts.poppins(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete', style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _drawingService.deleteDrawing(drawing.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Drawing deleted successfully',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Failed to delete: ${e.toString()}',
                style: GoogleFonts.poppins(),
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  IconData _getDrawingIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'dwg':
      case 'dxf':
        return Icons.architecture;
      case 'jpg':
      case 'jpeg':
      case 'png':
        return Icons.image;
      default:
        return Icons.description;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
