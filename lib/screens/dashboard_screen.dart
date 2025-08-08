import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'projects/projects_main_screen.dart';
import 'financial_screen.dart';
import 'schedule_screen.dart';
import 'quality_safety_screen.dart';
import 'reports_screen.dart';
import 'notifications_screen.dart';
import 'account_screen.dart';
import 'search_screen.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/activity_feed.dart';
import '../widgets/weather_widget.dart';
import '../widgets/todo_widget.dart';
import '../widgets/responsive_layout.dart';
import '../providers/selected_project_provider.dart';
import '../services/project_service.dart';

class DashboardScreen extends StatefulWidget {
  final Logger logger;
  
  const DashboardScreen({super.key, required this.logger});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ProjectService _projectService;
  late final Logger _logger;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger;
    _projectService = ProjectService();
    _logger.i('🏗️ DashboardScreen: Initialized with logger and project service');
  }

  // Move navigation method to the stateful widget to fix setState warning
  void navigateToProjects({int initialTab = 0}) {
    _logger.i('🧭 DashboardScreen: Navigating to projects with initial tab: $initialTab');
    
    setState(() {
      _selectedIndex = 1; // Projects index
    });
    
    _logger.d('✅ DashboardScreen: Successfully navigated to projects section');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('🎨 DashboardScreen: Building with selectedIndex: $_selectedIndex');
    
    return ChangeNotifierProvider(
      create: (context) {
        _logger.d('🏗️ DashboardScreen: Creating SelectedProjectProvider');
        return SelectedProjectProvider();
      },
      child: Consumer<SelectedProjectProvider>(
        builder: (context, projectProvider, child) {
          _logger.d('🔄 DashboardScreen: Consumer rebuilding, hasSelectedProject: ${projectProvider.hasSelectedProject}');
          
          return ResponsiveLayout(
            mobile: _buildMobileLayout(projectProvider),
            tablet: _buildTabletLayout(projectProvider),
            desktop: _buildDesktopLayout(projectProvider),
          );
        },
      ),
    );
  }

  Widget _buildMobileLayout(SelectedProjectProvider projectProvider) {
    _logger.d('📱 DashboardScreen: Building mobile layout');
    
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(projectProvider),
      drawer: _buildDrawer(projectProvider),
      body: _getSelectedScreen(projectProvider),
    );
  }

  Widget _buildTabletLayout(SelectedProjectProvider projectProvider) {
    _logger.d('📱 DashboardScreen: Building tablet layout');
    
    return Scaffold(
      appBar: _buildAppBar(projectProvider),
      body: Row(
        children: [
          Container(
            width: 280,
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
            child: _buildSidebarContent(projectProvider),
          ),
          Expanded(child: _getSelectedScreen(projectProvider)),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout(SelectedProjectProvider projectProvider) {
    _logger.d('🖥️ DashboardScreen: Building desktop layout');
    
    return Scaffold(
      appBar: _buildAppBar(projectProvider),
      body: Row(
        children: [
          Container(
            width: 300,
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
            child: _buildSidebarContent(projectProvider),
          ),
          Expanded(child: _getSelectedScreen(projectProvider)),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(SelectedProjectProvider projectProvider) {
    String title = 'AlmaWorks';
    if (_selectedIndex == 0) {
      title = 'AlmaWorks - Dashboard';
    } else if (_selectedIndex == 1) {
      title = 'Projects';
    } else if (projectProvider.hasSelectedProject && _selectedIndex > 1) {
      title = '${projectProvider.selectedProject!.name} - ${_getMenuTitle(_selectedIndex)}';
    } else {
      title = _getMenuTitle(_selectedIndex);
    }

    _logger.d('🏷️ DashboardScreen: Building app bar with title: $title');

    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            _logger.i('🔍 DashboardScreen: Search button pressed');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            _logger.i('🔔 DashboardScreen: Notifications button pressed');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            );
          },
        ),
        GestureDetector(
          onTap: () {
            _logger.i('👤 DashboardScreen: Account button pressed');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountScreen()),
            );
          },
          child: const Padding(
            padding: EdgeInsets.only(right: 16.0),
            child: CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 20),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDrawer(SelectedProjectProvider projectProvider) {
    _logger.d('📋 DashboardScreen: Building drawer');
    
    return Drawer(
      child: _buildSidebarContent(projectProvider),
    );
  }

  Widget _buildSidebarContent(SelectedProjectProvider projectProvider) {
    _logger.d('📋 DashboardScreen: Building sidebar content, hasSelectedProject: ${projectProvider.hasSelectedProject}');
    
    return Column(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF1976D2),
          ),
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'AlmaWorks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Site Management',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
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
              // Dashboard
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                selected: _selectedIndex == 0,
                onTap: () {
                  _logger.i('🏠 DashboardScreen: Dashboard menu item tapped');
                  setState(() {
                    _selectedIndex = 0;
                  });
                  // Clear selected project when going to dashboard
                  projectProvider.clearSelection();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              
              // Projects
              ListTile(
                leading: const Icon(Icons.folder),
                title: const Text('Projects'),
                selected: _selectedIndex == 1,
                onTap: () {
                  _logger.i('📁 DashboardScreen: Projects menu item tapped');
                  setState(() {
                    _selectedIndex = 1;
                  });
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),

              // Show project sections only when a project is selected or when in projects section
              if (projectProvider.hasSelectedProject || _selectedIndex == 1) ...[
                // Selected Project Display (only when project is selected)
                if (projectProvider.hasSelectedProject) ...[
                  Container(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.business, size: 16, color: Colors.blue),
                            const SizedBox(width: 8),
                            const Text(
                              'Selected Project:',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.blue,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          projectProvider.selectedProject!.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          projectProvider.selectedProject!.location,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],

                // Project-specific menu items
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Project Sections',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Documents'),
                  selected: _selectedIndex == 2,
                  enabled: projectProvider.hasSelectedProject,
                  onTap: projectProvider.hasSelectedProject ? () {
                    _logger.i('📄 DashboardScreen: Documents menu item tapped');
                    setState(() {
                      _selectedIndex = 2;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } : null,
                ),
                
                ListTile(
                  leading: const Icon(Icons.architecture),
                  title: const Text('Drawings'),
                  selected: _selectedIndex == 3,
                  enabled: projectProvider.hasSelectedProject,
                  onTap: projectProvider.hasSelectedProject ? () {
                    _logger.i('📐 DashboardScreen: Drawings menu item tapped');
                    setState(() {
                      _selectedIndex = 3;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } : null,
                ),
                
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Schedule'),
                  selected: _selectedIndex == 4,
                  enabled: projectProvider.hasSelectedProject,
                  onTap: projectProvider.hasSelectedProject ? () {
                    _logger.i('📅 DashboardScreen: Schedule menu item tapped');
                    setState(() {
                      _selectedIndex = 4;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } : null,
                ),
                
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Quality & Safety'),
                  selected: _selectedIndex == 5,
                  enabled: projectProvider.hasSelectedProject,
                  onTap: projectProvider.hasSelectedProject ? () {
                    _logger.i('🛡️ DashboardScreen: Quality & Safety menu item tapped');
                    setState(() {
                      _selectedIndex = 5;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } : null,
                ),
                
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Reports'),
                  selected: _selectedIndex == 6,
                  enabled: projectProvider.hasSelectedProject,
                  onTap: projectProvider.hasSelectedProject ? () {
                    _logger.i('📊 DashboardScreen: Reports menu item tapped');
                    setState(() {
                      _selectedIndex = 6;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } : null,
                ),
                
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photo Gallery'),
                  selected: _selectedIndex == 7,
                  enabled: projectProvider.hasSelectedProject,
                  onTap: projectProvider.hasSelectedProject ? () {
                    _logger.i('📸 DashboardScreen: Photo Gallery menu item tapped');
                    setState(() {
                      _selectedIndex = 7;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } : null,
                ),
                
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Financials'),
                  selected: _selectedIndex == 8,
                  enabled: projectProvider.hasSelectedProject,
                  onTap: projectProvider.hasSelectedProject ? () {
                    _logger.i('💰 DashboardScreen: Financials menu item tapped');
                    setState(() {
                      _selectedIndex = 8;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  } : null,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _getSelectedScreen(SelectedProjectProvider projectProvider) {
    _logger.d('🎯 DashboardScreen: Getting screen for index $_selectedIndex');
    
    try {
      switch (_selectedIndex) {
        case 0:
          // Always show general dashboard
          final screen = MainDashboard(
            projectService: _projectService, 
            logger: _logger,
            onNavigateToProjects: navigateToProjects, // Pass the navigation method
          );
          _logger.d('✅ DashboardScreen: Returning general dashboard screen');
          return screen;
        case 1:
          _logger.d('✅ DashboardScreen: Returning ProjectsMainScreen');
          return ProjectsMainScreen(logger: _logger);
        case 2:
          return _buildProjectSection('Documents', Icons.description);
        case 3:
          return _buildProjectSection('Drawings', Icons.architecture);
        case 4:
          return const ScheduleScreen();
        case 5:
          return const QualitySafetyScreen();
        case 6:
          return const ReportsScreen();
        case 7:
          return _buildProjectSection('Photo Gallery', Icons.photo_library);
        case 8:
          return const FinancialScreen();
        default:
          return MainDashboard(
            projectService: _projectService, 
            logger: _logger,
            onNavigateToProjects: navigateToProjects,
          );
      }
    } catch (e, stackTrace) {
      _logger.e('❌ DashboardScreen: Error getting selected screen',
        error: e, stackTrace: stackTrace);
      return _buildErrorScreen('Error loading screen', e.toString());
    }
  }

  Widget _buildProjectSection(String title, IconData icon) {
    _logger.d('🏗️ DashboardScreen: Building project section: $title');
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'This section is under development',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(String title, String error) {
    _logger.w('⚠️ DashboardScreen: Building error screen: $title');
    
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: const TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                _logger.i('🔄 DashboardScreen: Retry button pressed, going back to dashboard');
                setState(() {
                  _selectedIndex = 0;
                });
              },
              child: const Text('Go to Dashboard'),
            ),
          ],
        ),
      ),
    );
  }

  String _getMenuTitle(int index) {
    switch (index) {
      case 2: return 'Documents';
      case 3: return 'Drawings';
      case 4: return 'Schedule';
      case 5: return 'Quality & Safety';
      case 6: return 'Reports';
      case 7: return 'Photo Gallery';
      case 8: return 'Financials';
      default: return 'AlmaWorks';
    }
  }

  @override
  void dispose() {
    _logger.i('🧹 DashboardScreen: Disposing resources');
    super.dispose();
  }
}

class MainDashboard extends StatelessWidget {
  final ProjectService projectService;
  final Logger logger;
  final Function({int initialTab}) onNavigateToProjects; // Add callback
  
  const MainDashboard({
    super.key,
    required this.projectService,
    required this.logger,
    required this.onNavigateToProjects,
  });

  @override
  Widget build(BuildContext context) {
    logger.d('🏗️ MainDashboard: Building general dashboard');
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'General Overview',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildMetricsGrid(context),
          const SizedBox(height: 24),
          _buildContentSection(context),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    final isMobile = screenWidth < 600;
    
    logger.d('📊 MainDashboard: Building metrics grid, isTablet: $isTablet, isMobile: $isMobile');
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isMobile ? 1 : (isTablet ? 3 : 3),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isMobile ? 2.5 : (isTablet ? 1.8 : 2.0),
      children: [
        // Total Projects (All)
        FutureBuilder<int>(
          future: _safeGetProjectCount(() => projectService.getAllProjectsCount(), 'total'),
          builder: (context, snapshot) {
            logger.d('📈 MainDashboard: Total projects - hasData: ${snapshot.hasData}, data: ${snapshot.data}, hasError: ${snapshot.hasError}');
            return DashboardCard(
              title: 'Total Projects',
              value: snapshot.hasData ? '${snapshot.data}' : (snapshot.hasError ? '0' : '...'),
              icon: Icons.folder,
              color: Colors.blue,
              onTap: () {
                logger.i('👆 MainDashboard: Total projects card tapped - navigating to projects');
                onNavigateToProjects(); // Use callback instead of direct setState
              },
            );
          },
        ),
        // Active Projects
        FutureBuilder<int>(
          future: _safeGetProjectCount(() => projectService.getProjectCountByStatus('active'), 'active'),
          builder: (context, snapshot) {
            logger.d('📈 MainDashboard: Active projects - hasData: ${snapshot.hasData}, data: ${snapshot.data}, hasError: ${snapshot.hasError}');
            return DashboardCard(
              title: 'Active Projects',
              value: snapshot.hasData ? '${snapshot.data}' : (snapshot.hasError ? '0' : '...'),
              icon: Icons.work,
              color: Colors.green,
              onTap: () {
                logger.i('👆 MainDashboard: Active projects card tapped');
                onNavigateToProjects(initialTab: 1); // Active tab
              },
            );
          },
        ),
        // Completed Projects
        FutureBuilder<int>(
          future: _safeGetProjectCount(() => projectService.getProjectCountByStatus('completed'), 'completed'),
          builder: (context, snapshot) {
            logger.d('📈 MainDashboard: Completed projects - hasData: ${snapshot.hasData}, data: ${snapshot.data}, hasError: ${snapshot.hasError}');
            return DashboardCard(
              title: 'Completed Projects',
              value: snapshot.hasData ? '${snapshot.data}' : (snapshot.hasError ? '0' : '...'),
              icon: Icons.check_circle,
              color: Colors.orange,
              onTap: () {
                logger.i('👆 MainDashboard: Completed projects card tapped');
                onNavigateToProjects(initialTab: 2); // Completed tab
              },
            );
          },
        ),
      ],
    );
  }

  Future<int> _safeGetProjectCount(Future<int> Function() getCount, String type) async {
    try {
      logger.d('🔢 MainDashboard: Getting $type project count safely');
      final count = await getCount();
      logger.i('✅ MainDashboard: $type project count retrieved: $count');
      return count;
    } catch (e) {
      logger.e('❌ MainDashboard: Error getting $type project count: $e');
      return 0;
    }
  }

  Widget _buildContentSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 800;
    final isMobile = screenWidth < 600;
    
    logger.d('🏗️ MainDashboard: Building content section, isTablet: $isTablet, isMobile: $isMobile');
    
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
            child: Container(
              constraints: const BoxConstraints(maxHeight: 400),
              child: const WeatherWidget(),
            ),
          ),
        ],
      );
    } else {
      return Column(
        children: [
          const ActivityFeed(),
          const SizedBox(height: 16),
          Container(
            constraints: BoxConstraints(
              maxHeight: isMobile ? 300 : 400,
            ),
            child: const WeatherWidget(),
          ),
          const SizedBox(height: 16),
          const TodoWidget(),
        ],
      );
    }
  }
}
