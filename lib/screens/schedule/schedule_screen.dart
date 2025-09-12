import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/resource_model.dart';
//import 'package:almaworks/screens/schedule/gantt_chart_screen.dart';
import 'package:almaworks/screens/schedule/critical_path_screen.dart';
import 'package:almaworks/screens/schedule/gantt_chart_screen_refactored.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';

class ScheduleScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const ScheduleScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    widget.logger.i(
      '📅 ScheduleScreen: Initialized for project: ${widget.project.name} (ID: ${widget.project.id})',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      widget.logger.d(
        '📅 ScheduleScreen: Screen width: $width, isMobile: ${width < 600}',
      );
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
    widget.logger.d('📅 ScheduleScreen: Building UI, isMobile: $isMobile');
    return BaseLayout(
      title: '${widget.project.name} - Schedule',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Schedule',
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
                          labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: 'Gantt Chart'),
                            Tab(text: 'Critical Path'),
                            Tab(text: 'Purchasing Plan/Resources'),
                            Tab(text: 'Updates'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height:
                            constraints.maxHeight -
                            48 -
                            (isMobile ? 12 : 16) * 2,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            GanttChartScreen(
                              project: widget.project,
                              logger: widget.logger,
                            ),
                            CriticalPathScreen(
                              project: widget.project,
                              logger: widget.logger,
                            ),
                            _buildResourcesTab(),
                            _buildUpdatesTab(),
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

  Widget _buildResourcesTab() {
    widget.logger.d(
      '📅 ScheduleScreen: Fetching resources (projectId: ${widget.project.id})',
    );
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Resources')
          .where('projectId', isEqualTo: widget.project.id)
          .orderBy('updatedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e(
            '❌ ScheduleScreen: Error loading resources',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return Center(
            child: Text(
              'Error loading resources: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          widget.logger.d('📅 ScheduleScreen: Waiting for Resources data');
          return const Center(child: CircularProgressIndicator());
        }
        final resources = snapshot.data!.docs;
        widget.logger.i(
          '📅 ScheduleScreen: Loaded ${resources.length} resources',
        );
        widget.logger.d(
          '📅 ScheduleScreen: Rendering Resources with Add Resource button',
        );
        if (resources.isEmpty) {
          widget.logger.d(
            '📅 ScheduleScreen: No resources found for projectId: ${widget.project.id}',
          );
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inventory_2, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                Text(
                  'No resources added yet',
                  style: GoogleFonts.poppins(color: Colors.grey[600]),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _addResource,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Add Resource',
                    style: GoogleFonts.poppins(fontSize: 16),
                  ),
                ),
              ],
            ),
          );
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Resources & Purchasing Plan',
                        style: GoogleFonts.poppins(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${resources.length} resources configured',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                  ElevatedButton.icon(
                    onPressed: _addResource,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      'Add Resource',
                      style: GoogleFonts.poppins(fontSize: 14),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5A),
                      foregroundColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ...resources.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                final resource = ResourceModel.fromMap(doc.id, data);
                return _buildResourceItem(
                  resource.id,
                  resource.name,
                  resource.quantity,
                  resource.status,
                );
              } catch (e, stackTrace) {
                widget.logger.e(
                  '❌ ScheduleScreen: Error parsing resource document ${doc.id}',
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

  Widget _buildResourceItem(
    String id,
    String resource,
    String quantity,
    String status,
  ) {
    Color statusColor;
    IconData statusIcon;

    switch (status.toLowerCase()) {
      case 'available':
        statusColor = Colors.green;
        statusIcon = Icons.check_circle;
        break;
      case 'in use':
        statusColor = Colors.orange;
        statusIcon = Icons.work;
        break;
      case 'ordered':
        statusColor = Colors.blue;
        statusIcon = Icons.shopping_cart;
        break;
      case 'unavailable':
        statusColor = Colors.red;
        statusIcon = Icons.cancel;
        break;
      default:
        statusColor = Colors.grey;
        statusIcon = Icons.help;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF0A2E5A).withValues(alpha: 0.1),
          child: const Icon(Icons.inventory_2, color: Color(0xFF0A2E5A)),
        ),
        title: Text(
          resource,
          style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.numbers, size: 14, color: Colors.grey.shade600),
                const SizedBox(width: 4),
                Text(quantity, style: GoogleFonts.poppins(fontSize: 14)),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(statusIcon, size: 14, color: statusColor),
                const SizedBox(width: 4),
                Text(
                  status,
                  style: GoogleFonts.poppins(
                    color: statusColor,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) =>
              _handleResourceAction(value, id, resource, quantity, status),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'edit',
              child: Row(
                children: [
                  const Icon(Icons.edit, size: 18),
                  const SizedBox(width: 8),
                  Text('Edit', style: GoogleFonts.poppins()),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  const Icon(Icons.delete, size: 18, color: Colors.red),
                  const SizedBox(width: 8),
                  Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    widget.logger.d('📅 ScheduleScreen: Rendering Updates tab');
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.update, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Project Updates',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedule updates and notifications will appear here',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Coming Soon',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time project updates, notifications, and activity tracking will be available in future releases.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addResource() async {
    widget.logger.d('📅 ScheduleScreen: Opening Add Resource dialog');
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    String selectedStatus = 'Available';

    final statusOptions = ['Available', 'In use', 'Ordered', 'Unavailable'];

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(
            'Add Resource',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Resource Name',
                  hintText: 'e.g., Excavator, Steel Rebar, Workers',
                  border: const OutlineInputBorder(),
                  labelStyle: GoogleFonts.poppins(),
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: quantityController,
                decoration: InputDecoration(
                  labelText: 'Quantity',
                  hintText: 'e.g., 2 units, 500 kg, 8 workers',
                  border: const OutlineInputBorder(),
                  labelStyle: GoogleFonts.poppins(),
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: selectedStatus,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: const OutlineInputBorder(),
                  labelStyle: GoogleFonts.poppins(),
                ),
                items: statusOptions.map((status) {
                  return DropdownMenuItem(
                    value: status,
                    child: Text(status, style: GoogleFonts.poppins()),
                  );
                }).toList(),
                onChanged: (value) {
                  setState(() => selectedStatus = value!);
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: GoogleFonts.poppins()),
            ),
            ElevatedButton(
              onPressed: () {
                if (nameController.text.isNotEmpty &&
                    quantityController.text.isNotEmpty) {
                  Navigator.pop(context, true);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Please fill all required fields',
                        style: GoogleFonts.poppins(),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5A),
                foregroundColor: Colors.white,
              ),
              child: Text('Save', style: GoogleFonts.poppins()),
            ),
          ],
        ),
      ),
    );

    if (result != true) {
      widget.logger.d('📅 ScheduleScreen: Resource addition cancelled');
      return;
    }

    try {
      widget.logger.d(
        '📅 ScheduleScreen: Adding resource to Firestore: ${nameController.text}',
      );
      await FirebaseFirestore.instance.collection('Resources').add({
        'name': nameController.text.trim(),
        'quantity': quantityController.text.trim(),
        'status': selectedStatus,
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'updatedAt': Timestamp.now(),
      });
      widget.logger.i(
        '✅ ScheduleScreen: Resource added successfully: ${nameController.text}',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Resource added successfully',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e(
        '❌ ScheduleScreen: Error adding resource',
        error: e,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error adding resource: $e',
              style: GoogleFonts.poppins(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handleResourceAction(
    String action,
    String id,
    String name,
    String quantity,
    String status,
  ) async {
    if (action == 'edit') {
      widget.logger.d(
        '📅 ScheduleScreen: Opening Edit Resource dialog for resource ID: $id',
      );
      final nameController = TextEditingController(text: name);
      final quantityController = TextEditingController(text: quantity);
      String selectedStatus = status;

      final statusOptions = ['Available', 'In use', 'Ordered', 'Unavailable'];

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) => AlertDialog(
            title: Text(
              'Edit Resource',
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Resource Name',
                    border: const OutlineInputBorder(),
                    labelStyle: GoogleFonts.poppins(),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: quantityController,
                  decoration: InputDecoration(
                    labelText: 'Quantity',
                    border: const OutlineInputBorder(),
                    labelStyle: GoogleFonts.poppins(),
                  ),
                  style: GoogleFonts.poppins(),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: selectedStatus,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    border: const OutlineInputBorder(),
                    labelStyle: GoogleFonts.poppins(),
                  ),
                  items: statusOptions.map((statusOption) {
                    return DropdownMenuItem(
                      value: statusOption,
                      child: Text(statusOption, style: GoogleFonts.poppins()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() => selectedStatus = value!);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
              ElevatedButton(
                onPressed: () {
                  if (nameController.text.isNotEmpty &&
                      quantityController.text.isNotEmpty) {
                    Navigator.pop(context, true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Please fill all fields',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0A2E5A),
                  foregroundColor: Colors.white,
                ),
                child: Text('Save', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        ),
      );

      if (result != true) {
        widget.logger.d(
          '📅 ScheduleScreen: Resource edit cancelled for resource ID: $id',
        );
        return;
      }

      try {
        widget.logger.d(
          '📅 ScheduleScreen: Updating resource in Firestore: $id',
        );
        await FirebaseFirestore.instance
            .collection('Resources')
            .doc(id)
            .update({
              'name': nameController.text.trim(),
              'quantity': quantityController.text.trim(),
              'status': selectedStatus,
              'projectId': widget.project.id,
              'projectName': widget.project.name,
              'updatedAt': Timestamp.now(),
            });
        widget.logger.i('✅ ScheduleScreen: Resource updated successfully: $id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Resource updated successfully',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
      } catch (e, stackTrace) {
        widget.logger.e(
          '❌ ScheduleScreen: Error updating resource: $id',
          error: e,
          stackTrace: stackTrace,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Error updating resource: $e',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
      }
    } else if (action == 'delete') {
      widget.logger.d(
        '📅 ScheduleScreen: Opening Delete Resource dialog for resource ID: $id',
      );
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(
            'Delete Resource',
            style: GoogleFonts.poppins(fontWeight: FontWeight.w600),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.warning_amber, color: Colors.orange, size: 48),
              const SizedBox(height: 16),
              Text(
                'Are you sure you want to delete this resource?',
                style: GoogleFonts.poppins(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  name,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.red.shade700,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This action cannot be undone.',
                style: GoogleFonts.poppins(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
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
          widget.logger.d(
            '📅 ScheduleScreen: Deleting resource from Firestore: $id',
          );
          await FirebaseFirestore.instance
              .collection('Resources')
              .doc(id)
              .delete();
          widget.logger.i(
            '✅ ScheduleScreen: Resource deleted successfully: $id',
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Resource deleted successfully',
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
        } catch (e, stackTrace) {
          widget.logger.e(
            '❌ ScheduleScreen: Error deleting resource: $id',
            error: e,
            stackTrace: stackTrace,
          );
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error deleting resource: $e',
                  style: GoogleFonts.poppins(),
                ),
              ),
            );
          }
        }
      } else {
        widget.logger.d(
          '📅 ScheduleScreen: Resource deletion cancelled for resource ID: $id',
        );
      }
    }
  }
}
