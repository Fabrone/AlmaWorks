import 'package:almaworks/providers/selected_project_provider.dart';
import 'package:almaworks/screens/account_screen.dart';
import 'package:almaworks/screens/notifications_screen.dart';
import 'package:almaworks/screens/projects/projects_main_screen.dart';
import 'package:almaworks/screens/search_screen.dart';
import 'package:almaworks/services/project_service.dart';
import 'package:almaworks/widgets/activity_feed.dart';
import 'package:almaworks/widgets/dashboard_card.dart';
import 'package:almaworks/widgets/responsive_layout.dart';
import 'package:almaworks/widgets/todo_widget.dart';
import 'package:almaworks/widgets/weather_widget.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardScreen extends StatefulWidget {
  final Logger logger;
  
  const DashboardScreen({super.key, required this.logger});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  int _projectsInitialTab = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final ProjectService _projectService;
  late final Logger _logger;
  String _userRole = '';
  bool _isLoadingRole = true;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger;
    _projectService = ProjectService();
    _logger.i('🏗️ DashboardScreen: Initialized with logger and project service');
    _fetchUserRole();
  }

  Future<void> _fetchUserRole() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _logger.e('❌ DashboardScreen: No authenticated user found');
        setState(() => _isLoadingRole = false);
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final role = userData['role'] as String? ?? 'Client';
        
        setState(() {
          _userRole = role;
          _isLoadingRole = false;
        });
        
        _logger.i('✅ DashboardScreen: User role fetched: $role');
      } else {
        _logger.w('⚠️ DashboardScreen: User document not found');
        setState(() {
          _userRole = 'Client';
          _isLoadingRole = false;
        });
      }
    } catch (e) {
      _logger.e('❌ DashboardScreen: Error fetching user role: $e');
      setState(() {
        _userRole = 'Client';
        _isLoadingRole = false;
      });
    }
  }

  void navigateToProjects({int initialTab = 0}) {
    _logger.i('🧭 DashboardScreen: Navigating to projects with initial tab: $initialTab');
    
    setState(() {
      _selectedIndex = 1;
      _projectsInitialTab = initialTab;
    });
    
    _logger.d('✅ DashboardScreen: Successfully navigated to projects section with tab: $initialTab');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('🎨 DashboardScreen: Building with selectedIndex: $_selectedIndex');
    
    if (_isLoadingRole) {
      return Scaffold(
        backgroundColor: const Color(0xFF0A2E5A),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: Colors.white),
              const SizedBox(height: 16),
              Text(
                'Loading Dashboard...',
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
            ],
          ),
        ),
      );
    }
    
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
    }

    _logger.d('🏷️ DashboardScreen: Building app bar with title: $title');

    return AppBar(
      title: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
      ),
      backgroundColor: const Color(0xFF0A2E5A),
      actions: [
        IconButton(
          icon: const Icon(Icons.search, color: Colors.white),
          onPressed: () {
            _logger.i('🔍 DashboardScreen: Search button pressed');
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications, color: Colors.white),
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
              backgroundColor: Colors.white,
              child: Icon(Icons.person, size: 20, color: Color(0xFF0A2E5A)),
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
    _logger.d('📋 DashboardScreen: Building simplified sidebar content');
    
    return Column(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF0A2E5A),
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
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: const Text('Dashboard'),
                selected: _selectedIndex == 0,
                onTap: () {
                  _logger.i('🏠 DashboardScreen: Dashboard menu item tapped');
                  setState(() {
                    _selectedIndex = 0;
                  });
                  projectProvider.clearSelection();
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              ),
              if (_userRole == 'MainAdmin' || _userRole == 'Admin')
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Projects'),
                  selected: _selectedIndex == 1,
                  onTap: () {
                    _logger.i('📁 DashboardScreen: Projects menu item tapped');
                    setState(() {
                      _selectedIndex = 1;
                      _projectsInitialTab = 0;
                    });
                    if (Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
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
          if (_userRole == 'Client') {
            return _buildClientDashboard();
          } else {
            final screen = MainDashboard(
              projectService: _projectService, 
              logger: _logger,
              onNavigateToProjects: navigateToProjects,
            );
            _logger.d('✅ DashboardScreen: Returning general dashboard screen');
            return screen;
          }
        case 1:
          if (_userRole == 'MainAdmin' || _userRole == 'Admin') {
            _logger.d('✅ DashboardScreen: Returning ProjectsMainScreen with initialTab: $_projectsInitialTab');
            return ProjectsMainScreen(
              logger: _logger,
              initialTabIndex: _projectsInitialTab,
            );
          } else {
            return _buildClientDashboard();
          }
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

  Widget _buildClientDashboard() {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.construction,
                size: 100,
                color: const Color(0xFF0A2E5A).withValues(alpha: 0.5),
              ),
              const SizedBox(height: 24),
              const Text(
                'Client Dashboard',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0A2E5A),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF0A2E5A).withValues(alpha: 0.2)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.hourglass_empty,
                      color: const Color(0xFF0A2E5A),
                      size: 48,
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Under Development',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF0A2E5A),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'The Client Dashboard is currently being developed.\nCheck back soon for updates!',
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Thank you for your patience.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
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

  @override
  void dispose() {
    _logger.i('🧹 DashboardScreen: Disposing resources');
    super.dispose();
  }
}

class MainDashboard extends StatefulWidget {
  final ProjectService projectService;
  final Logger logger;
  final Function({int initialTab}) onNavigateToProjects;
  
  const MainDashboard({
    super.key,
    required this.projectService,
    required this.logger,
    required this.onNavigateToProjects,
  });

  @override
  State<MainDashboard> createState() => _MainDashboardState();
}

class _MainDashboardState extends State<MainDashboard> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    final isDesktop = screenWidth >= 1200;

    widget.logger.d('🏗️ MainDashboard: Building general dashboard, isMobile: $isMobile, isTablet: $isTablet');

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 16),
            child: const Text(
              'General Overview',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          _buildMetricsGrid(context),
          const SizedBox(height: 16),
          _buildContentSection(context, isMobile, isTablet, isDesktop),
          const SizedBox(height: 16),
          _buildFooter(context, isMobile),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    widget.logger.d('📊 MainDashboard: Building metrics grid, isMobile: $isMobile');
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Row(
        children: [
          Expanded(
            child: FutureBuilder<int>(
              future: _safeGetProjectCount(() => widget.projectService.getAllProjectsCount(), 'total'),
              builder: (context, snapshot) {
                widget.logger.d('📈 MainDashboard: Total projects - hasData: ${snapshot.hasData}, data: ${snapshot.data}, hasError: ${snapshot.hasError}');
                return DashboardCard(
                  title: 'Total Projects',
                  value: snapshot.hasData ? '${snapshot.data}' : (snapshot.hasError ? '0' : '...'),
                  icon: Icons.folder,
                  color: Colors.blue,
                  onTap: () {
                    widget.logger.i('👆 MainDashboard: Total projects card tapped - navigating to All Projects tab');
                    widget.onNavigateToProjects(initialTab: 0);
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<int>(
              future: _safeGetProjectCount(() => widget.projectService.getProjectCountByStatus('active'), 'active'),
              builder: (context, snapshot) {
                widget.logger.d('📈 MainDashboard: Active projects - hasData: ${snapshot.hasData}, data: ${snapshot.data}, hasError: ${snapshot.hasError}');
                return DashboardCard(
                  title: 'Active Projects',
                  value: snapshot.hasData ? '${snapshot.data}' : (snapshot.hasError ? '0' : '...'),
                  icon: Icons.work,
                  color: Colors.green,
                  onTap: () {
                    widget.logger.i('👆 MainDashboard: Active projects card tapped - navigating to Active Projects tab');
                    widget.onNavigateToProjects(initialTab: 1);
                  },
                );
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: FutureBuilder<int>(
              future: _safeGetProjectCount(() => widget.projectService.getProjectCountByStatus('completed'), 'completed'),
              builder: (context, snapshot) {
                widget.logger.d('📈 MainDashboard: Completed projects - hasData: ${snapshot.hasData}, data: ${snapshot.data}, hasError: ${snapshot.hasError}');
                return DashboardCard(
                  title: 'Completed Projects',
                  value: snapshot.hasData ? '${snapshot.data}' : (snapshot.hasError ? '0' : '...'),
                  icon: Icons.check_circle,
                  color: Colors.orange,
                  onTap: () {
                    widget.logger.i('👆 MainDashboard: Completed projects card tapped - navigating to Completed Projects tab');
                    widget.onNavigateToProjects(initialTab: 2);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<int> _safeGetProjectCount(Future<int> Function() getCount, String type) async {
    try {
      widget.logger.d('🔢 MainDashboard: Getting $type project count safely');
      final count = await getCount();
      widget.logger.i('✅ MainDashboard: $type project count retrieved: $count');
      return count;
    } catch (e) {
      widget.logger.e('❌ MainDashboard: Error getting $type project count: $e');
      return 0;
    }
  }

  Widget _buildContentSection(BuildContext context, bool isMobile, bool isTablet, bool isDesktop) {
    final screenWidth = MediaQuery.of(context).size.width;
    final sidebarWidth = isMobile ? 0 : (isTablet ? 280 : 300);
    final availableWidth = screenWidth - sidebarWidth - (isMobile ? 24 : 32);
    const double widgetHeight = 400.0;

    widget.logger.d('🗳️ MainDashboard: Building content section, isMobile: $isMobile, availableWidth: $availableWidth');

    final widgets = [
      SizedBox(
        width: availableWidth,
        height: widgetHeight,
        child: TodoWidget(
          showAllProjects: true,
          logger: widget.logger,
        ),
      ),
      SizedBox(
        width: availableWidth,
        height: widgetHeight,
        child: ActivityFeed(
          showAllProjects: true,
          logger: widget.logger,
        ),
      ),
      SizedBox(
        width: availableWidth,
        height: widgetHeight,
        child: const WeatherWidget(),
      ),
    ];

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isMobile ? 12 : 16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: widgetHeight,
            child: PageView.builder(
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
              physics: const BouncingScrollPhysics(),
              pageSnapping: true,
              scrollBehavior: const ScrollBehavior().copyWith(
                scrollbars: false,
                overscroll: false,
              ),
            ),
          ),
          Positioned(
            left: 0,
            child: _currentPage > 0
                ? FloatingActionButton(
                    onPressed: () {
                      _pageController.previousPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                    mini: true,
                    backgroundColor: const Color(0xFF0A2E5A),
                    child: const Icon(
                      Icons.arrow_left,
                      color: Colors.white,
                      size: 30,
                      weight: 800,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            right: 0,
            child: _currentPage < widgets.length - 1
                ? FloatingActionButton(
                    onPressed: () {
                      _pageController.nextPage(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOutCubic,
                      );
                    },
                    mini: true,
                    backgroundColor: const Color(0xFF0A2E5A),
                    child: const Icon(
                      Icons.arrow_right,
                      color: Colors.white,
                      size: 30,
                      weight: 800,
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          Positioned(
            bottom: 8,
            child: Row(
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
}