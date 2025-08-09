import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import '../../models/project_model.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/weather_widget.dart';
import '../../widgets/todo_widget.dart';

class ProjectSummaryScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const ProjectSummaryScreen({
    super.key, 
    required this.project,
    required this.logger,
  });

  @override
  State<ProjectSummaryScreen> createState() => _ProjectSummaryScreenState();
}

class _ProjectSummaryScreenState extends State<ProjectSummaryScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.logger.d('🎨 ProjectSummaryScreen: Building project summary for: ${widget.project.name}');
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;
    
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.project.name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              widget.logger.i('✏️ ProjectSummaryScreen: Edit button pressed');
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Edit functionality coming soon')),
              );
            },
          ),
        ],
      ),
      body: Row(
        children: [
          // Sidebar for tablet and desktop
          if (!isMobile) _buildSidebar(context, isTablet),
          // Main content
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: EdgeInsets.all(isMobile ? 12 : 16),
                          child: Text(
                            'Project Overview',
                            style: TextStyle(
                              fontSize: isMobile ? 20 : 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        _buildProjectMetrics(context, isMobile, isTablet, isDesktop),
                        const SizedBox(height: 16),
                        _buildProjectHeader(isMobile),
                        const SizedBox(height: 16),
                        _buildContentSection(context, isMobile, isTablet, isDesktop),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                _buildFooter(context, isMobile),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isTablet) {
    return Container(
      width: isTablet ? 280 : 300,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0A2E5A),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    widget.project.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Project Dashboard',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Overview'),
                  selected: true,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Documents'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Documents section coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.architecture),
                  title: const Text('Drawings'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Drawings section coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Schedule'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Schedule section coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Quality & Safety'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Quality & Safety section coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Reports'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Reports section coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photo Gallery'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Photo Gallery section coming soon')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Financials'),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Financials section coming soon')),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectMetrics(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
    
    widget.logger.d('📊 ProjectSummaryScreen: Building project metrics, isMobile: $isMobile, isTablet: $isTablet, isDesktop: $isDesktop');
    
    List<Widget> cards = [];
    
    // Budget card
    if (widget.project.budget != null) {
      cards.add(
        DashboardCard(
          title: 'Project Budget',
          value: '\$${(widget.project.budget! / 1000000).toStringAsFixed(1)}M',
          icon: Icons.attach_money,
          color: Colors.green,
          onTap: () {
            widget.logger.i('👆 ProjectSummaryScreen: Budget card tapped');
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
            widget.logger.i('👆 ProjectSummaryScreen: Budget (TBD) card tapped');
          },
        ),
      );
    }
    
    // Progress card
    cards.add(
      DashboardCard(
        title: 'Progress',
        value: '${widget.project.progress.toStringAsFixed(0)}%',
        icon: Icons.trending_up,
        color: widget.project.isActive ? Colors.blue : Colors.grey,
        onTap: () {
          widget.logger.i('👆 ProjectSummaryScreen: Progress card tapped');
        },
      ),
    );
    
    // Team members card
    cards.add(
      DashboardCard(
        title: 'Team Members',
        value: '${widget.project.teamMembers.length}',
        icon: Icons.people,
        color: Colors.purple,
        onTap: () {
          widget.logger.i('👆 ProjectSummaryScreen: Team members card tapped');
          _showTeamMembers(context);
        },
      ),
    );
    
    // Safety score card
    cards.add(
      DashboardCard(
        title: 'Safety Score',
        value: widget.project.safetyScore.toStringAsFixed(1),
        icon: Icons.security,
        color: Colors.orange,
        onTap: () {
          widget.logger.i('👆 ProjectSummaryScreen: Safety score card tapped');
        },
      ),
    );
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<int>(
              future: Future.value(cards.length),
              builder: (context, snapshot) {
                return DashboardCard(
                  title: 'Project Budget',
                  value: widget.project.budget != null 
                      ? '\$${(widget.project.budget! / 1000000).toStringAsFixed(1)}M' 
                      : 'TBD',
                  icon: Icons.attach_money,
                  color: Colors.green,
                  onTap: () {
                    widget.logger.i('👆 ProjectSummaryScreen: Budget card tapped');
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DashboardCard(
              title: 'Progress',
              value: '${widget.project.progress.toStringAsFixed(0)}%',
              icon: Icons.trending_up,
              color: widget.project.isActive ? Colors.blue : Colors.grey,
              onTap: () {
                widget.logger.i('👆 ProjectSummaryScreen: Progress card tapped');
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DashboardCard(
              title: 'Team Members',
              value: '${widget.project.teamMembers.length}',
              icon: Icons.people,
              color: Colors.purple,
              onTap: () {
                widget.logger.i('👆 ProjectSummaryScreen: Team members card tapped');
                _showTeamMembers(context);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProjectHeader(bool isMobile) {
    widget.logger.d('🏗️ ProjectSummaryScreen: Building project header');
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    backgroundColor: _getStatusColor(widget.project.status),
                    child: Text(
                      widget.project.name.substring(0, 1),
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
                          widget.project.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          widget.project.location,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (widget.project.status != null)
                    Chip(
                      label: Text(_getStatusText(widget.project.status!)),
                      backgroundColor: _getStatusColor(widget.project.status).withValues(alpha: 0.1),
                      labelStyle: TextStyle(color: _getStatusColor(widget.project.status)),
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
                widget.project.description,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem('Project Manager', widget.project.projectManager),
                  ),
                  Expanded(
                    child: _buildInfoItem('Team Size', '${widget.project.teamMembers.length} members'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildInfoItem('Start Date', _formatDate(widget.project.startDate)),
                  ),
                  Expanded(
                    child: _buildInfoItem(
                      'End Date',
                      widget.project.endDate != null ? _formatDate(widget.project.endDate!) : 'TBD'
                    ),
                  ),
                ],
              ),
              if (widget.project.daysRemaining != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Days Remaining',
                         '${widget.project.daysRemaining} days'
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem('Health Status', widget.project.healthStatus),
                    ),
                  ],
                ),
              ],
            ],
          ),
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
    widget.logger.i('👥 ProjectSummaryScreen: Showing team members dialog');
    
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Team Members'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: widget.project.teamMembers.length,
              itemBuilder: (context, index) {
                final member = widget.project.teamMembers[index];
                final isManager = member == widget.project.projectManager;
                
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

  Widget _buildContentSection(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = isMobile ? 0 : (isTablet ? 280 : 300);
    final availableWidth = screenWidth - sidebarWidth - (isMobile ? 24 : 32);
    
    // Fixed height for all widgets to ensure uniformity
    const double widgetHeight = 400.0;
    
    widget.logger.d('🏗️ ProjectSummaryScreen: Building content section, isMobile: $isMobile, availableWidth: $availableWidth');

    final widgets = [
      SizedBox(
        width: availableWidth,
        height: widgetHeight,
        child: const TodoWidget(),
      ),
      SizedBox(
        width: availableWidth,
        height: widgetHeight,
        child: const ActivityFeed(),
      ),
      SizedBox(
        width: availableWidth,
        height: widgetHeight,
        child: const WeatherWidget(),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Column(
        children: [
          SizedBox(
            height: widgetHeight,
            child: Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPage = index;
                    });
                  },
                  itemCount: widgets.length,
                  itemBuilder: (context, index) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: widgets[index],
                    );
                  },
                ),
                // Left arrow button
                if (_currentPage > 0)
                  Positioned(
                    left: 8,
                    top: widgetHeight / 2 - 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2E5A).withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      ),
                    ),
                  ),
                // Right arrow button
                if (_currentPage < widgets.length - 1)
                  Positioned(
                    right: 8,
                    top: widgetHeight / 2 - 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF0A2E5A).withValues(alpha: 0.9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: IconButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widgets.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 4),
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentPage == index
                      ? const Color(0xFF0A2E5A)
                      : Colors.grey.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isMobile) {
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
