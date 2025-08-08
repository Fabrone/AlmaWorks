import 'package:flutter/material.dart';
import '../../models/project_model.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/weather_widget.dart';
import '../../widgets/todo_widget.dart';

class ProjectDashboardScreen extends StatelessWidget {
  final ProjectModel project;

  const ProjectDashboardScreen({super.key, required this.project});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProjectHeader(),
          const SizedBox(height: 24),
          _buildProjectMetrics(context),
          const SizedBox(height: 24),
          _buildContentSection(context),
        ],
      ),
    );
  }

  Widget _buildProjectHeader() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: _getStatusColor(project.status),
                  child: Text(
                    project.name.substring(0, 1),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        project.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        project.location,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
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
              ],
            ),
            const SizedBox(height: 16),
            Text(
              project.description,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('Project Manager', project.projectManager),
                ),
                Expanded(
                  child: _buildInfoItem('Team Size', '${project.teamMembers.length} members'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildInfoItem('Start Date', _formatDate(project.startDate)),
                ),
                Expanded(
                  child: _buildInfoItem(
                    'End Date', 
                    project.endDate != null ? _formatDate(project.endDate!) : 'TBD'
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildProjectMetrics(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
    // Show different metrics based on project status
    List<Widget> cards = [];
    
    if (project.status == 'active' || project.status == 'completed') {
      if (project.budget != null) {
        cards.add(
          DashboardCard(
            title: 'Project Budget',
            value: '\$${(project.budget! / 1000000).toStringAsFixed(1)}M',
            icon: Icons.attach_money,
            color: Colors.green,
            onTap: () {
              // Navigate to financials
            },
          ),
        );
      }
      
      cards.addAll([
        DashboardCard(
          title: 'Progress',
          value: project.status == 'completed' ? '100%' : '65%',
          icon: Icons.trending_up,
          color: Colors.blue,
          onTap: () {
            // Navigate to schedule
          },
        ),
        DashboardCard(
          title: 'Team Members',
          value: '${project.teamMembers.length}',
          icon: Icons.people,
          color: Colors.purple,
          onTap: () {
            // Navigate to team
          },
        ),
        DashboardCard(
          title: 'Safety Score',
          value: project.status == 'completed' ? '9.8' : '9.2',
          icon: Icons.security,
          color: Colors.orange,
          onTap: () {
            // Navigate to quality & safety
          },
        ),
      ]);
    } else {
      // Untracked projects show empty or basic metrics
      cards.addAll([
        DashboardCard(
          title: 'Budget',
          value: project.budget != null ? '\$${(project.budget! / 1000000).toStringAsFixed(1)}M' : 'TBD',
          icon: Icons.attach_money,
          color: Colors.grey,
          onTap: () {
            // Navigate to financials
          },
        ),
        DashboardCard(
          title: 'Progress',
          value: '0%',
          icon: Icons.trending_up,
          color: Colors.grey,
          onTap: () {
            // Navigate to schedule
          },
        ),
        DashboardCard(
          title: 'Team Members',
          value: '${project.teamMembers.length}',
          icon: Icons.people,
          color: Colors.grey,
          onTap: () {
            // Navigate to team
          },
        ),
      ]);
    }
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isTablet ? 1.2 : 1.1,
      children: cards,
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 800;
    
    if (isTablet) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Column(
              children: [
                const ActivityFeed(),
                const SizedBox(height: 16),
                const TodoWidget(),
              ],
            ),
          ),
          const SizedBox(width: 16),
          const Expanded(
            child: WeatherWidget(),
          ),
        ],
      );
    } else {
      return const Column(
        children: [
          ActivityFeed(),
          SizedBox(height: 16),
          WeatherWidget(),
          SizedBox(height: 16),
          TodoWidget(),
        ],
      );
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
