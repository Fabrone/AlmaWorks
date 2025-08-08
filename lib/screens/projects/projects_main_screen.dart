import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'add_project_screen.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';
import '../../providers/selected_project_provider.dart';

class ProjectsMainScreen extends StatefulWidget {
  final Logger logger;
  
  const ProjectsMainScreen({super.key, required this.logger});

  @override
  State<ProjectsMainScreen> createState() => _ProjectsMainScreenState();
}

class _ProjectsMainScreenState extends State<ProjectsMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late final ProjectService _projectService;
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger;
    _tabController = TabController(length: 3, vsync: this);
    _projectService = ProjectService();
    _logger.i('🏗️ ProjectsMainScreen: Initialized with ${_tabController.length} tabs');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('🎨 ProjectsMainScreen: Building UI');
    
    return Scaffold(
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: TabBar(
              controller: _tabController,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'All Projects'),
                Tab(text: 'Active'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAllProjectsTab(),
                _buildActiveProjectsTab(),
                _buildCompletedProjectsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          _logger.i('➕ ProjectsMainScreen: Add project button pressed');
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => AddProjectScreen(logger: _logger)),
          );
          _logger.d('🔄 ProjectsMainScreen: Returned from add project screen, result: $result');
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildAllProjectsTab() {
    _logger.d('📋 ProjectsMainScreen: Building all projects tab');
    
    return StreamBuilder<List<ProjectModel>>(
      stream: _projectService.getAllProjects(),
      builder: (context, snapshot) {
        _logger.d('📡 ProjectsMainScreen: All projects stream - ConnectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.d('⏳ ProjectsMainScreen: Showing loading indicator for all projects');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          _logger.e('❌ ProjectsMainScreen: Error in all projects stream: ${snapshot.error}');
          return _buildErrorWidget('Error loading projects', snapshot.error.toString());
        }

        final projects = snapshot.data ?? [];
        _logger.i('✅ ProjectsMainScreen: Received ${projects.length} projects');

        return _buildProjectsList(projects, 'all');
      },
    );
  }

  Widget _buildActiveProjectsTab() {
    _logger.d('📋 ProjectsMainScreen: Building active projects tab');
    
    return StreamBuilder<List<ProjectModel>>(
      stream: _projectService.getProjectsByStatus('active'),
      builder: (context, snapshot) {
        _logger.d('📡 ProjectsMainScreen: Active projects stream - ConnectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.d('⏳ ProjectsMainScreen: Showing loading indicator for active projects');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          _logger.e('❌ ProjectsMainScreen: Error in active projects stream: ${snapshot.error}');
          return _buildErrorWidget('Error loading active projects', snapshot.error.toString());
        }

        final projects = snapshot.data ?? [];
        _logger.i('✅ ProjectsMainScreen: Received ${projects.length} active projects');

        return _buildProjectsList(projects, 'active');
      },
    );
  }

  Widget _buildCompletedProjectsTab() {
    _logger.d('📋 ProjectsMainScreen: Building completed projects tab');
    
    return StreamBuilder<List<ProjectModel>>(
      stream: _projectService.getProjectsByStatus('completed'),
      builder: (context, snapshot) {
        _logger.d('📡 ProjectsMainScreen: Completed projects stream - ConnectionState: ${snapshot.connectionState}, hasData: ${snapshot.hasData}, hasError: ${snapshot.hasError}');
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          _logger.d('⏳ ProjectsMainScreen: Showing loading indicator for completed projects');
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          _logger.e('❌ ProjectsMainScreen: Error in completed projects stream: ${snapshot.error}');
          return _buildErrorWidget('Error loading completed projects', snapshot.error.toString());
        }

        final projects = snapshot.data ?? [];
        _logger.i('✅ ProjectsMainScreen: Received ${projects.length} completed projects');

        return _buildProjectsList(projects, 'completed');
      },
    );
  }

  Widget _buildErrorWidget(String title, String error) {
    _logger.w('⚠️ ProjectsMainScreen: Building error widget: $title');
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            error,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              _logger.i('🔄 ProjectsMainScreen: Retry button pressed');
              setState(() {}); // Trigger rebuild
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectsList(List<ProjectModel> projects, String tabType) {
    _logger.d('📋 ProjectsMainScreen: Building projects list for $tabType with ${projects.length} projects');
    
    if (projects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.folder_open, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              'No ${tabType == 'all' ? '' : '$tabType '}projects found',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tap the + button to add your first project',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        _logger.i('🔄 ProjectsMainScreen: Pull to refresh triggered');
        await Future.delayed(const Duration(milliseconds: 500));
      },
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: projects.length,
        itemBuilder: (context, index) {
          final project = projects[index];
          _logger.d('🏗️ ProjectsMainScreen: Building list item for project: ${project.name}');
          
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(
                backgroundColor: _getStatusColor(project.status),
                child: Text(
                  project.name.substring(0, 1).toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
              title: Text(
                project.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(project.location),
                  const SizedBox(height: 4),
                  Text(
                    project.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (project.budget != null) ...[
                        Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                        Text(
                          '\$${_formatBudget(project.budget!)}',
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Icon(Icons.person, size: 16, color: Colors.grey[600]),
                      Expanded(
                        child: Text(
                          project.projectManager,
                          style: TextStyle(color: Colors.grey[600]),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (project.status != null)
                    Chip(
                      label: Text(_getStatusText(project.status!)),
                      backgroundColor: _getStatusColor(project.status).withValues(alpha: 0.1),
                      labelStyle: TextStyle(color: _getStatusColor(project.status)),
                    )
                  else
                    Chip(
                      label: const Text('Untracked'),
                      backgroundColor: Colors.grey.withValues(alpha: 0.1),
                      labelStyle: const TextStyle(color: Colors.grey),
                    ),
                  const SizedBox(height: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              onTap: () {
                _logger.i('👆 ProjectsMainScreen: Project tapped: ${project.name}');
                
                // Select the project and navigate to dashboard
                Provider.of<SelectedProjectProvider>(context, listen: false)
                    .selectProject(project);
                
                // Show confirmation
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Selected project: ${project.name}'),
                    duration: const Duration(seconds: 2),
                  ),
                );
              },
              onLongPress: () {
                _logger.i('👆 ProjectsMainScreen: Project long pressed: ${project.name}');
                _showProjectOptions(context, project);
              },
            ),
          );
        },
      ),
    );
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
                  _logger.i('🗑️ ProjectsMainScreen: Delete project selected');
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
          content: Text('Are you sure you want to delete "${project.name}"? This action cannot be undone.'),
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
                
                // Store context references before async operation
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
        return Colors.blue;
      default:
        return Colors.grey;
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
