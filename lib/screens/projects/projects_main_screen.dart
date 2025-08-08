import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'add_project_screen.dart';
import 'project_summary_screen.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../providers/selected_project_provider.dart';

class ProjectsMainScreen extends StatefulWidget {
  final Logger logger;
  final int initialTabIndex;
  
  const ProjectsMainScreen({
    super.key, 
    required this.logger,
    this.initialTabIndex = 0,
  });

  @override
  State<ProjectsMainScreen> createState() => _ProjectsMainScreenState();
}

class _ProjectsMainScreenState extends State<ProjectsMainScreen> 
    with SingleTickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  late TabController _tabController;
  late final ProjectService _projectService;
  late final Logger _logger;
  
  // Status filter variables - Only 3 tabs now
  String _statusFilter = 'All';
  bool _isLoading = true;
  
  // Status counts for tabs - Only 3 tabs: All, Active, Completed
  int _allCount = 0;
  int _activeCount = 0;
  int _completedCount = 0;
  
  // Cache for all projects to avoid repeated queries
  List<QueryDocumentSnapshot> _allProjects = [];

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger;
    _tabController = TabController(
      length: 3, // Changed to 3 tabs
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _projectService = ProjectService();
    
    _logger.i('🏗️ ProjectsMainScreen: Initialized with ${_tabController.length} tabs, initial index: ${widget.initialTabIndex}');
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    _logger.d('🎨 ProjectsMainScreen: Building UI, isLoading: $_isLoading');
    
    return Scaffold(
      body: Column(
        children: [
          // Navigation-style tab bar
          _buildNavigationTabBar(),
          // Projects list
          Expanded(
            child: _buildProjectsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _logger.i('➕ ProjectsMainScreen: Add project button pressed');
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AddProjectScreen(logger: _logger),
            ),
          );
          
          if (result == true) {
            _logger.d('🔄 ProjectsMainScreen: Project added successfully, stream will auto-update');
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildNavigationTabBar() {
    return Container(
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
        labelColor: Theme.of(context).primaryColor,
        unselectedLabelColor: Colors.grey[600],
        indicatorColor: Theme.of(context).primaryColor,
        indicatorWeight: 3,
        labelStyle: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
        unselectedLabelStyle: const TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 16,
        ),
        onTap: (index) {
          setState(() {
            switch (index) {
              case 0:
                _statusFilter = 'All';
                break;
              case 1:
                _statusFilter = 'active';
                break;
              case 2:
                _statusFilter = 'completed';
                break;
            }
          });
          _logger.d('📑 ProjectsMainScreen: Tab changed to index: $index, filter: $_statusFilter');
        },
        tabs: [
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('All Projects'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _allCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Active'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _activeCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Tab(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Completed'),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.orange[400],
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _completedCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // This is the key method - using StreamBuilder like your CMMS pattern
  Widget _buildProjectsList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('Projects')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && _isLoading) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          _logger.e('Firestore error: ${snapshot.error}');
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Error loading projects',
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.red[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Please check your connection and try again',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        if (!snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        // Cache all projects for better performance
        _allProjects = snapshot.data!.docs;
        _isLoading = false;
        
        // Update counts based on all projects (not filtered)
        _updateStatusCounts(_allProjects);
        
        // Get filtered projects
        final filteredProjects = _getFilteredProjects();
        
        if (filteredProjects.isEmpty) {
          final filterText = _statusFilter == 'All' 
              ? 'No projects found' 
              : 'No $_statusFilter projects';
          
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                children: [
                  Icon(
                    Icons.folder_open,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    filterText,
                    style: TextStyle(
                      fontSize: 18,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Tap the + button to create your first project',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          );
        }
        
        return RefreshIndicator(
          onRefresh: () async {
            _logger.i('🔄 ProjectsMainScreen: Pull to refresh triggered');
            // Force a rebuild to refresh streams
            setState(() {
              _isLoading = true;
            });
            await Future.delayed(const Duration(milliseconds: 500));
            setState(() {
              _isLoading = false;
            });
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredProjects.length,
            itemBuilder: (context, index) {
              final project = ProjectModel.fromFirestore(filteredProjects[index]);
              _logger.d('🏗️ ProjectsMainScreen: Building list item for project: ${project.name}');
              
              return _buildProjectCard(project, context);
            },
          ),
        );
      },
    );
  }

  // Fixed: Update status counts from all projects - Only 3 categories now
  void _updateStatusCounts(List<QueryDocumentSnapshot> allDocs) {
    final newAllCount = allDocs.length;
    int newActiveCount = 0;
    int newCompletedCount = 0;
    
    for (var doc in allDocs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = data['status'];
      
      switch (status) {
        case 'active':
          newActiveCount++;
          break;
        case 'completed':
          newCompletedCount++;
          break;
        // Projects with null status or other statuses are only counted in "All"
        // They don't get their own category
      }
    }
    
    // Only update if counts actually changed
    if (_allCount != newAllCount ||
        _activeCount != newActiveCount ||
        _completedCount != newCompletedCount) {
      
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _allCount = newAllCount;
            _activeCount = newActiveCount;
            _completedCount = newCompletedCount;
          });
        }
      });
    }
  }

  // Get filtered projects from cached data - Only 3 filters now
  List<QueryDocumentSnapshot> _getFilteredProjects() {
    if (_statusFilter == 'All') {
      return _allProjects;
    } else {
      return _allProjects.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        return data['status'] == _statusFilter;
      }).toList();
    }
  }

  Widget _buildProjectCard(ProjectModel project, BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: InkWell(
        onTap: () {
          _logger.i('👆 ProjectsMainScreen: Project tapped: ${project.name}');
          _navigateToProjectSummary(project, context);
        },
        onLongPress: () {
          _logger.i('👆 ProjectsMainScreen: Project long pressed: ${project.name}');
          _showProjectOptions(context, project);
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: _getStatusColor(project.status),
                    child: Text(
                      project.name.substring(0, 1).toUpperCase(),
                      style: const TextStyle(
                        color: Colors.white, 
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          project.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          project.location,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  _buildStatusChip(project.status),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                project.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (project.budget != null) ...[
                    Icon(Icons.attach_money, size: 14, color: Colors.grey[600]),
                    Text(
                      '\$${_formatBudget(project.budget!)}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                    ),
                    const SizedBox(width: 12),
                  ],
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  Expanded(
                    child: Text(
                      project.projectManager,
                      style: TextStyle(color: Colors.grey[600], fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (project.isActive) ...[
                    Icon(Icons.trending_up, size: 14, color: Colors.blue),
                    const SizedBox(width: 4),
                    Text(
                      '${project.progress.toStringAsFixed(0)}%',
                      style: const TextStyle(
                        color: Colors.blue,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    if (status == null) {
      return Chip(
        label: const Text('Untracked'),
        backgroundColor: Colors.grey.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: Colors.grey, fontSize: 10),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        visualDensity: VisualDensity.compact,
      );
    }
    
    return Chip(
      label: Text(_getStatusText(status)),
      backgroundColor: _getStatusColor(status).withValues(alpha: 0.1),
      labelStyle: TextStyle(
        color: _getStatusColor(status),
        fontSize: 10,
      ),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      visualDensity: VisualDensity.compact,
    );
  }

  void _navigateToProjectSummary(ProjectModel project, BuildContext context) {
    _logger.i('🧭 ProjectsMainScreen: Navigating to project summary: ${project.name}');
    
    // Set the selected project in the provider
    Provider.of<SelectedProjectProvider>(context, listen: false)
        .selectProject(project);
    
    // Navigate to project summary screen
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ProjectSummaryScreen(
          project: project,
          logger: _logger,
        ),
      ),
    ).then((_) {
      _logger.d('🔙 ProjectsMainScreen: Returned from project summary');
    });
  }

  void _showProjectOptions(BuildContext context, ProjectModel project) {
    _logger.i('📋 ProjectsMainScreen: Showing project options for: ${project.name}');
    
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.visibility),
                title: const Text('View Details'),
                onTap: () {
                  Navigator.pop(context);
                  _navigateToProjectSummary(project, context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit),
                title: const Text('Edit Project'),
                onTap: () {
                  Navigator.pop(context);
                  _logger.i('✏️ ProjectsMainScreen: Edit project selected');
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Edit functionality coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Project', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(context);
                  _confirmDeleteProject(context, project);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteProject(BuildContext context, ProjectModel project) {
    _logger.i('❓ ProjectsMainScreen: Confirming delete for project: ${project.name}');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Project'),
          content: Text(
            'Are you sure you want to delete "${project.name}"? This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                _logger.i('❌ ProjectsMainScreen: Delete cancelled');
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                _logger.i('✅ ProjectsMainScreen: Delete confirmed for: ${project.name}');
                
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                final navigator = Navigator.of(context);
                
                navigator.pop(); // Close dialog first
                
                try {
                  await _projectService.deleteProject(project.id);
                  _logger.i('✅ ProjectsMainScreen: Project deleted successfully');
                  
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Project "${project.name}" deleted successfully'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                } catch (e) {
                  _logger.e('❌ ProjectsMainScreen: Error deleting project: $e');
                  
                  if (mounted) {
                    scaffoldMessenger.showSnackBar(
                      SnackBar(
                        content: Text('Error deleting project: ${e.toString()}'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  String _formatBudget(double budget) {
    if (budget >= 1000000) {
      return '${(budget / 1000000).toStringAsFixed(1)}M';
    } else if (budget >= 1000) {
      return '${(budget / 1000).toStringAsFixed(0)}K';
    } else {
      return budget.toStringAsFixed(0);
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.orange;
      default:
        return Colors.grey; // Untracked
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'active':
        return 'Active';
      case 'completed':
        return 'Completed';
      default:
        return 'Untracked';
    }
  }

  @override
  void dispose() {
    _logger.i('🧹 ProjectsMainScreen: Disposing tab controller');
    _tabController.dispose();
    super.dispose();
  }
}
