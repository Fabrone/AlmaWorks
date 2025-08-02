import 'package:flutter/material.dart';
import 'project_detail_screen.dart';
import '../../models/project.dart';

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
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
                Tab(text: 'Planning'),
                Tab(text: 'Completed'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildProjectsList(Project.getMockProjects()),
                _buildProjectsList(Project.getMockProjects().where((p) => p.status == 'Active').toList()),
                _buildProjectsList(Project.getMockProjects().where((p) => p.status == 'Planning').toList()),
                _buildProjectsList(Project.getMockProjects().where((p) => p.status == 'Completed').toList()),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add new project
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildProjectsList(List<Project> projects) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: projects.length,
      itemBuilder: (context, index) {
        final project = projects[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: CircleAvatar(
              backgroundColor: _getStatusColor(project.status),
              child: Text(
                project.name.substring(0, 1),
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
                Row(
                  children: [
                    Icon(Icons.attach_money, size: 16, color: Colors.grey[600]),
                    Text('\$${project.budget}M', style: TextStyle(color: Colors.grey[600])),
                    const SizedBox(width: 16),
                    Icon(Icons.schedule, size: 16, color: Colors.grey[600]),
                    Text('${project.progress}%', style: TextStyle(color: Colors.grey[600])),
                  ],
                ),
              ],
            ),
            trailing: Chip(
              label: Text(project.status),
              backgroundColor: _getStatusColor(project.status).withAlpha(0.1 as int),
              labelStyle: TextStyle(color: _getStatusColor(project.status)),
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ProjectDetailScreen(project: project),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Active':
        return Colors.green;
      case 'Planning':
        return Colors.orange;
      case 'Completed':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }
}
