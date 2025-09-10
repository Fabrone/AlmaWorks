import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/models/resource_model.dart';
import 'package:almaworks/screens/schedule/gantt_chart_screen.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:intl/intl.dart';

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

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd');

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    widget.logger.i('📅 ScheduleScreen: Initialized for project: ${widget.project.name} (ID: ${widget.project.id})');
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      widget.logger.d('📅 ScheduleScreen: Screen width: $width, isMobile: ${width < 600}');
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
                          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
                          tabs: const [
                            Tab(text: 'Gantt Chart'),
                            Tab(text: 'Critical Path'),
                            Tab(text: 'Purchasing Plan/Resources'),
                            Tab(text: 'Updates'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height: constraints.maxHeight - 48 - (isMobile ? 12 : 16) * 2,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            GanttChartScreen(project: widget.project, logger: widget.logger), // Use new screen
                            _buildCriticalPathTab(),
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


  Widget _buildCriticalPathTab() {
    widget.logger.d('📅 ScheduleScreen: Fetching tasks for Critical Path (projectId: ${widget.project.id})');
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Schedule')
          .where('projectId', isEqualTo: widget.project.id)
          .orderBy('startDate', descending: false)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          widget.logger.e(
            '❌ ScheduleScreen: Error loading tasks for Critical Path',
            error: snapshot.error,
            stackTrace: snapshot.stackTrace,
          );
          return Center(
            child: Text(
              'Error loading tasks: ${snapshot.error}',
              style: GoogleFonts.poppins(color: Colors.red[600]),
            ),
          );
        }
        if (!snapshot.hasData) {
          widget.logger.d('📅 ScheduleScreen: Waiting for Critical Path data');
          return const Center(child: CircularProgressIndicator());
        }
        final tasks = snapshot.data!.docs;
        widget.logger.i('📅 ScheduleScreen: Loaded ${tasks.length} tasks for Critical Path');
        widget.logger.d('📅 ScheduleScreen: Rendering Critical Path with Add Task button');
        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No tasks added yet', style: GoogleFonts.poppins(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _addTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Add Task', style: GoogleFonts.poppins(fontSize: 16)),
                ),
              ],
            ),
          );
        }
        final totalDuration = tasks.isNotEmpty
            ? (tasks.last.data() as Map<String, dynamic>)['endDate']
                .toDate()
                .difference((tasks.first.data() as Map<String, dynamic>)['startDate'].toDate())
                .inDays
            : 0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!, width: 1), // Debug border
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Critical Path Analysis',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addTask,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(100, 40),
                    ),
                    child: Text('Add Task', style: GoogleFonts.poppins(fontSize: 16)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Total Project Duration: $totalDuration days', style: GoogleFonts.poppins()),
                    Text('Critical Path Duration: $totalDuration days', style: GoogleFonts.poppins()),
                    Text('Float Available: 0 days', style: GoogleFonts.poppins()),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            ...tasks.map((doc) {
              try {
                final data = doc.data() as Map<String, dynamic>;
                return _buildCriticalPathItem(data['title'] as String, 'Critical', Colors.red);
              } catch (e, stackTrace) {
                widget.logger.e(
                  '❌ ScheduleScreen: Error parsing critical path task document ${doc.id}',
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

  Widget _buildCriticalPathItem(String task, String status, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        title: Text(task, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        trailing: Chip(
          label: Text(status, style: GoogleFonts.poppins(color: Colors.white)),
          backgroundColor: color,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildResourcesTab() {
    widget.logger.d('📅 ScheduleScreen: Fetching resources (projectId: ${widget.project.id})');
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
        widget.logger.i('📅 ScheduleScreen: Loaded ${resources.length} resources');
        widget.logger.d('📅 ScheduleScreen: Rendering Resources with Add Resource button');
        if (resources.isEmpty) {
          widget.logger.d('📅 ScheduleScreen: No resources found for projectId: ${widget.project.id}');
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('No resources added yet', style: GoogleFonts.poppins(color: Colors.grey[600])),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _addResource,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    elevation: 4,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text('Add Resource', style: GoogleFonts.poppins(fontSize: 16)),
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
                border: Border.all(color: Colors.grey[300]!, width: 1), // Debug border
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      'Resources',
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ),
                  ElevatedButton(
                    onPressed: _addResource,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF0A2E5A),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      elevation: 4,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      minimumSize: const Size(100, 40),
                    ),
                    child: Text('Add Resource', style: GoogleFonts.poppins(fontSize: 16)),
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

  Widget _buildResourceItem(String id, String resource, String quantity, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: const Icon(Icons.build, color: Color(0xFF0A2E5A)),
        title: Text(resource, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quantity, style: GoogleFonts.poppins(fontSize: 14)),
            Text(status, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
          ],
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (value) => _handleResourceAction(value, id, resource, quantity, status),
          itemBuilder: (context) => [
            PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.poppins())),
            PopupMenuItem(
              value: 'delete',
              child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    widget.logger.d('📅 ScheduleScreen: Rendering Updates tab (placeholder)');
    return Center(
      child: Text(
        'No Updates at this time',
        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 16),
      ),
    );
  }

  Future<void> _addTask() async {
    widget.logger.d('📅 ScheduleScreen: Opening Add Task dialog');
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime? startDate;
    DateTime? endDate;
    double progress = 0.0;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Task', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Task Title',
                  border: const OutlineInputBorder(),
                  labelStyle: GoogleFonts.poppins(),
                ),
                style: GoogleFonts.poppins(),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: InputDecoration(
                  labelText: 'Description (optional)',
                  border: const OutlineInputBorder(),
                  labelStyle: GoogleFonts.poppins(),
                ),
                style: GoogleFonts.poppins(),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              ListTile(
                title: Text(
                  startDate == null ? 'Select Start Date' : _dateFormat.format(startDate!),
                  style: GoogleFonts.poppins(),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (selected != null) {
                    startDate = selected;
                    setState(() {});
                  }
                },
              ),
              ListTile(
                title: Text(
                  endDate == null ? 'Select End Date' : _dateFormat.format(endDate!),
                  style: GoogleFonts.poppins(),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: () async {
                  final selected = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (selected != null) {
                    endDate = selected;
                    setState(() {});
                  }
                },
              ),
              const SizedBox(height: 16),
              Text('Progress: ${(progress * 100).toInt()}%', style: GoogleFonts.poppins()),
              Slider(
                value: progress,
                onChanged: (value) => setState(() => progress = value),
                min: 0.0,
                max: 1.0,
                divisions: 100,
                label: '${(progress * 100).toInt()}%',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: GoogleFonts.poppins()),
          ),
          ElevatedButton(
            onPressed: () {
              if (titleController.text.isNotEmpty && startDate != null && endDate != null) {
                Navigator.pop(context, true);
              } else {
                widget.logger.w('📅 ScheduleScreen: Add Task failed - missing required fields');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill all fields except description', style: GoogleFonts.poppins())),
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
    );

    if (result != true || startDate == null || endDate == null) {
      widget.logger.d('📅 ScheduleScreen: Task addition cancelled');
      return;
    }

    try {
      widget.logger.d('📅 ScheduleScreen: Adding task to Firestore: ${titleController.text}');
      await FirebaseFirestore.instance.collection('Schedule').add({
        'title': titleController.text.trim(),
        'description': descriptionController.text.trim(),
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'startDate': Timestamp.fromDate(startDate!),
        'endDate': Timestamp.fromDate(endDate!),
        'progress': progress,
        'updatedAt': Timestamp.now(),
      });
      widget.logger.i('✅ ScheduleScreen: Task added successfully: ${titleController.text}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Task added successfully', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('❌ ScheduleScreen: Error adding task', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding task: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _addResource() async {
    widget.logger.d('📅 ScheduleScreen: Opening Add Resource dialog');
    final nameController = TextEditingController();
    final quantityController = TextEditingController();
    final statusController = TextEditingController();

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Resource', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
                labelText: 'Quantity (e.g., 8 workers, 2 units)',
                border: const OutlineInputBorder(),
                labelStyle: GoogleFonts.poppins(),
              ),
              style: GoogleFonts.poppins(),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: statusController,
              decoration: InputDecoration(
                labelText: 'Status (e.g., Available, In use)',
                border: const OutlineInputBorder(),
                labelStyle: GoogleFonts.poppins(),
              ),
              style: GoogleFonts.poppins(),
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
                  quantityController.text.isNotEmpty &&
                  statusController.text.isNotEmpty) {
                Navigator.pop(context, true);
              } else {
                widget.logger.w('📅 ScheduleScreen: Add Resource failed - missing required fields');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Please fill all fields', style: GoogleFonts.poppins())),
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
    );

    if (result != true) {
      widget.logger.d('📅 ScheduleScreen: Resource addition cancelled');
      return;
    }

    try {
      widget.logger.d('📅 ScheduleScreen: Adding resource to Firestore: ${nameController.text}');
      await FirebaseFirestore.instance.collection('Resources').add({
        'name': nameController.text.trim(),
        'quantity': quantityController.text.trim(),
        'status': statusController.text.trim(),
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'updatedAt': Timestamp.now(),
      });
      widget.logger.i('✅ ScheduleScreen: Resource added successfully: ${nameController.text}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Resource added successfully', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('❌ ScheduleScreen: Error adding resource', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error adding resource: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }

  Future<void> _handleResourceAction(String action, String id, String name, String quantity, String status) async {
    if (action == 'edit') {
      widget.logger.d('📅 ScheduleScreen: Opening Edit Resource dialog for resource ID: $id');
      final nameController = TextEditingController(text: name);
      final quantityController = TextEditingController(text: quantity);
      final statusController = TextEditingController(text: status);

      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Edit Resource', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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
              TextField(
                controller: statusController,
                decoration: InputDecoration(
                  labelText: 'Status',
                  border: const OutlineInputBorder(),
                  labelStyle: GoogleFonts.poppins(),
                ),
                style: GoogleFonts.poppins(),
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
                    quantityController.text.isNotEmpty &&
                    statusController.text.isNotEmpty) {
                  Navigator.pop(context, true);
                } else {
                  widget.logger.w('📅 ScheduleScreen: Edit Resource failed - missing required fields');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Please fill all fields', style: GoogleFonts.poppins())),
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
      );

      if (result != true) {
        widget.logger.d('📅 ScheduleScreen: Resource edit cancelled for resource ID: $id');
        return;
      }

      try {
        widget.logger.d('📅 ScheduleScreen: Updating resource in Firestore: $id');
        await FirebaseFirestore.instance.collection('Resources').doc(id).update({
          'name': nameController.text.trim(),
          'quantity': quantityController.text.trim(),
          'status': statusController.text.trim(),
          'projectId': widget.project.id,
          'projectName': widget.project.name,
          'updatedAt': Timestamp.now(),
        });
        widget.logger.i('✅ ScheduleScreen: Resource updated successfully: $id');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Resource updated successfully', style: GoogleFonts.poppins())),
          );
        }
      } catch (e, stackTrace) {
        widget.logger.e('❌ ScheduleScreen: Error updating resource: $id', error: e, stackTrace: stackTrace);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error updating resource: $e', style: GoogleFonts.poppins())),
          );
        }
      }
    } else if (action == 'delete') {
      widget.logger.d('📅 ScheduleScreen: Opening Delete Resource dialog for resource ID: $id');
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Delete Resource', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
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

      if (confirmed == true) {
        try {
          widget.logger.d('📅 ScheduleScreen: Deleting resource from Firestore: $id');
          await FirebaseFirestore.instance.collection('Resources').doc(id).delete();
          widget.logger.i('✅ ScheduleScreen: Resource deleted successfully: $id');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Resource deleted successfully', style: GoogleFonts.poppins())),
            );
          }
        } catch (e, stackTrace) {
          widget.logger.e('❌ ScheduleScreen: Error deleting resource: $id', error: e, stackTrace: stackTrace);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting resource: $e', style: GoogleFonts.poppins())),
            );
          }
        }
      } else {
        widget.logger.d('📅 ScheduleScreen: Resource deletion cancelled for resource ID: $id');
      }
    }
  }
}

class _GanttItemWidget extends StatefulWidget {
  final String id;
  final String task;
  final String description;
  final DateTime startDate;
  final DateTime endDate;
  final double progress;
  final DateFormat dateFormat;
  final Function(String, String, String, String, DateTime, DateTime, double) onAction;
  final Logger logger;

  const _GanttItemWidget({
    required this.id,
    required this.task,
    required this.description,
    required this.startDate,
    required this.endDate,
    required this.progress,
    required this.dateFormat,
    required this.onAction,
    required this.logger,
  });

  @override
  _GanttItemWidgetState createState() => _GanttItemWidgetState();
}

class _GanttItemWidgetState extends State<_GanttItemWidget> {
  bool isDescriptionVisible = false;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final totalDuration = widget.endDate.difference(widget.startDate).inDays;
    final elapsedDuration = now.isAfter(widget.startDate) ? now.difference(widget.startDate).inDays : 0;
    final calculatedProgress = totalDuration > 0 ? (elapsedDuration / totalDuration).clamp(0.0, 1.0) : 0.0;
    final displayProgress = widget.progress > 0.0 ? widget.progress : calculatedProgress;
    final color = displayProgress == 1.0
        ? Colors.green
        : now.isAfter(widget.endDate)
            ? Colors.red
            : Colors.blue;

    return GestureDetector(
      onTap: () {
        widget.logger.d('📅 ScheduleScreen: Toggled description visibility for task: ${widget.task}');
        setState(() {
          isDescriptionVisible = !isDescriptionVisible;
        });
      },
      child: Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.task, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '${widget.dateFormat.format(widget.startDate)} - ${widget.dateFormat.format(widget.endDate)}',
                    style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                  ),
                  const Spacer(),
                  Text(
                    '${(displayProgress * 100).toInt()}%',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              LinearProgressIndicator(
                value: displayProgress,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(color),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
              if (isDescriptionVisible && widget.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  widget.description,
                  style: GoogleFonts.poppins(color: Colors.grey[800], fontSize: 14),
                ),
              ],
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  PopupMenuButton<String>(
                    onSelected: (value) => widget.onAction(
                      value,
                      widget.id,
                      widget.task,
                      widget.description,
                      widget.startDate,
                      widget.endDate,
                      widget.progress,
                    ),
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'edit', child: Text('Edit', style: GoogleFonts.poppins())),
                      PopupMenuItem(
                        value: 'delete',
                        child: Text('Delete', style: GoogleFonts.poppins(color: Colors.red)),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}