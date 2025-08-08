import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/project_model.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/weather_widget.dart';
import '../../widgets/todo_widget.dart';

class ProjectSummaryScreen extends StatelessWidget {
  final ProjectModel project;
  final Logger logger;

  const ProjectSummaryScreen({
    super.key, 
    required this.project,
    required this.logger,
  });

  @override
  Widget build(BuildContext context) {
    logger.d('🎨 ProjectSummaryScreen: Building project summary for: ${project.name}');
    
    return Scaffold(
      appBar: AppBar(
        title: Text(project.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              logger.i('✏️ ProjectSummaryScreen: Edit button pressed');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Project metrics cards at the top - FIXED SIZING
            _buildProjectMetrics(context),
            const SizedBox(height: 24),
            // Project header info
            _buildProjectHeader(),
            const SizedBox(height: 24),
            // Content section
            _buildContentSection(context),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectMetrics(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 600 && screenWidth <= 1200;
    final isMobile = screenWidth <= 600;
    
    logger.d('📊 ProjectSummaryScreen: Building project metrics, isDesktop: $isDesktop, isTablet: $isTablet, isMobile: $isMobile');
    
    List<Widget> cards = [];
    
    // Budget card
    if (project.budget != null) {
      cards.add(
        DashboardCard(
          title: 'Project Budget',
          value: '\$${(project.budget! / 1000000).toStringAsFixed(1)}M',
          icon: Icons.attach_money,
          color: Colors.green,
          onTap: () {
            logger.i('👆 ProjectSummaryScreen: Budget card tapped');
          },
        ),
      );
    } else {
      cards.add(
        DashboardCard(
          title: 'Budget',
          value: 'TBD',
          icon: Icons.attach_money,
          color: Colors.grey,
          onTap: () {
            logger.i('👆 ProjectSummaryScreen: Budget (TBD) card tapped');
          },
        ),
      );
    }
    
    // Progress card
    cards.add(
      DashboardCard(
        title: 'Progress',
        value: '${project.progress.toStringAsFixed(0)}%',
        icon: Icons.trending_up,
        color: project.isActive ? Colors.blue : Colors.grey,
        onTap: () {
          logger.i('👆 ProjectSummaryScreen: Progress card tapped');
        },
      ),
    );
    
    // Team members card
    cards.add(
      DashboardCard(
        title: 'Team Members',
        value: '${project.teamMembers.length}',
        icon: Icons.people,
        color: Colors.purple,
        onTap: () {
          logger.i('👆 ProjectSummaryScreen: Team members card tapped');
          _showTeamMembers(context);
        },
      ),
    );
    
    // Safety score card
    cards.add(
      DashboardCard(
        title: 'Safety Score',
        value: project.safetyScore.toStringAsFixed(1),
        icon: Icons.security,
        color: Colors.orange,
        onTap: () {
          logger.i('👆 ProjectSummaryScreen: Safety score card tapped');
        },
      ),
    );
    
    // FIXED: Proper responsive grid layout
    if (isDesktop) {
      // Desktop: 4 columns in a single row
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.3, // Reduced height for desktop
        children: cards,
      );
    } else if (isTablet) {
      // Tablet: 2 columns, 2 rows
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 1.5, // Slightly taller for tablet
        children: cards,
      );
    } else {
      // Mobile: 2 columns, 2 rows, more compact
      return GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.1, // More compact for mobile but readable
        children: cards,
      );
    }
  }

  Widget _buildProjectHeader() {
    logger.d('🏗️ ProjectSummaryScreen: Building project header');
    
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: _getStatusColor(project.status),
                  child: Text(
                    project.name.substring(0, 1),
                    style: const TextStyle(
                      color: Colors.white, 
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
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
                      const SizedBox(height: 4),
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
            if (project.daysRemaining != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem(
                      'Days Remaining', 
                      '${project.daysRemaining} days'
                    ),
                  ),
                  Expanded(
                    child: _buildInfoItem('Health Status', project.healthStatus),
                  ),
                ],
              ),
            ],
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

  void _showTeamMembers(BuildContext context) {
    logger.i('👥 ProjectSummaryScreen: Showing team members dialog');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Team Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: project.teamMembers.length,
              itemBuilder: (context, index) {
                final member = project.teamMembers[index];
                final isManager = member == project.projectManager;
                
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(member.substring(0, 1).toUpperCase()),
                  ),
                  title: Text(member),
                  subtitle: isManager ? const Text('Project Manager') : null,
                  trailing: isManager ? const Icon(Icons.star, color: Colors.amber) : null,
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 800;
    final isMobile = screenWidth < 600;
    
    logger.d('🏗️ ProjectSummaryScreen: Building content section, isTablet: $isTablet, isMobile: $isMobile');
    
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
          Expanded(
            child: const WeatherWidget(), // Removed container constraints
          ),
        ],
      );
    } else {
      return Column(
        children: [
          const ActivityFeed(),
          const SizedBox(height: 16),
          const WeatherWidget(), // Removed container constraints
          const SizedBox(height: 16),
          const TodoWidget(),
        ],
      );
    }
  }

  Color _getStatusColor(String? status) {
    switch (status) {
      case 'active':
        return Colors.green;
      case 'completed':
        return Colors.orange;
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
