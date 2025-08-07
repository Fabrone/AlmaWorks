import 'package:flutter/material.dart';
import 'package:almaworks/screens/projects/projects_screen.dart';
import 'financial_screen.dart';
import 'schedule_screen.dart';
import 'quality_safety_screen.dart';
import 'field_productivity_screen.dart';
import 'bid_management_screen.dart';
import 'design_coordination_screen.dart';
import 'reports_screen.dart';
import 'notifications_screen.dart';
import 'account_screen.dart';
import 'search_screen.dart';
import '../widgets/dashboard_card.dart';
import '../widgets/activity_feed.dart';
import '../widgets/weather_widget.dart';
import '../widgets/todo_widget.dart';
import '../widgets/responsive_layout.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  final List<Map<String, dynamic>> _menuItems = [
    {'title': 'Dashboard', 'icon': Icons.dashboard, 'screen': null},
    {'title': 'Projects', 'icon': Icons.folder, 'screen': const ProjectsScreen()},
    {'title': 'Financial', 'icon': Icons.attach_money, 'screen': const FinancialScreen()},
    {'title': 'Schedule', 'icon': Icons.schedule, 'screen': const ScheduleScreen()},
    {'title': 'Quality & Safety', 'icon': Icons.security, 'screen': const QualitySafetyScreen()},
    {'title': 'Field Productivity', 'icon': Icons.work, 'screen': const FieldProductivityScreen()},
    {'title': 'Bid Management', 'icon': Icons.gavel, 'screen': const BidManagementScreen()},
    {'title': 'Design Coordination', 'icon': Icons.architecture, 'screen': const DesignCoordinationScreen()},
    {'title': 'Reports', 'icon': Icons.analytics, 'screen': const ReportsScreen()},
  ];

  @override
  Widget build(BuildContext context) {
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      key: _scaffoldKey,
      appBar: _buildAppBar(),
      drawer: _buildDrawer(),
      body: _getSelectedScreen(),
    );
  }

  Widget _buildTabletLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
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
            child: _buildSidebarContent(),
          ),
          Expanded(child: _getSelectedScreen()),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
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
            child: _buildSidebarContent(),
          ),
          Expanded(child: _getSelectedScreen()),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: Text(
        _selectedIndex == 0 ? 'AlmaWorks' : _menuItems[_selectedIndex]['title'],
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.search),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SearchScreen()),
            );
          },
        ),
        IconButton(
          icon: const Icon(Icons.notifications),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const NotificationsScreen()),
            );
          },
        ),
        GestureDetector(
          onTap: () {
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

  Widget _buildDrawer() {
    return Drawer(
      child: _buildSidebarContent(),
    );
  }

  Widget _buildSidebarContent() {
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
          child: ListView.builder(
            padding: EdgeInsets.zero,
            itemCount: _menuItems.length,
            itemBuilder: (context, index) {
              final item = _menuItems[index];
              return ListTile(
                leading: Icon(item['icon']),
                title: Text(item['title']),
                selected: _selectedIndex == index,
                onTap: () {
                  setState(() {
                    _selectedIndex = index;
                  });
                  if (Navigator.canPop(context)) {
                    Navigator.pop(context);
                  }
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _getSelectedScreen() {
    if (_selectedIndex == 0) {
      return const DashboardHome();
    }
    return _menuItems[_selectedIndex]['screen'] ?? const DashboardHome();
  }
}

class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Project Overview',
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
    
    // Use the DashboardData model
    final dashboardData = DashboardData.getMockData();
    
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: isTablet ? 4 : 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: isTablet ? 1.2 : 1.1,
      children: [
        DashboardCard(
          title: 'Active Projects',
          value: '${dashboardData.activeProjects}',
          icon: Icons.folder,
          color: Colors.blue,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ProjectsScreen()),
            );
          },
        ),
        DashboardCard(
          title: 'Total Budget',
          value: '\$${dashboardData.totalBudget}M',
          icon: Icons.attach_money,
          color: Colors.green,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const FinancialScreen()),
            );
          },
        ),
        DashboardCard(
          title: 'On Schedule',
          value: '${dashboardData.onSchedulePercentage}%',
          icon: Icons.schedule,
          color: Colors.orange,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const ScheduleScreen()),
            );
          },
        ),
        DashboardCard(
          title: 'Safety Score',
          value: '${dashboardData.safetyScore}',
          icon: Icons.security,
          color: Colors.red,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const QualitySafetyScreen()),
            );
          },
        ),
      ],
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
}

class DashboardData {
  final int activeProjects;
  final double totalBudget;
  final double onSchedulePercentage;
  final double safetyScore;

  DashboardData({
    required this.activeProjects,
    required this.totalBudget,
    required this.onSchedulePercentage,
    required this.safetyScore,
  });

  static DashboardData getMockData() {
    return DashboardData(
      activeProjects: 15,
      totalBudget: 3.5,
      onSchedulePercentage: 92.0,
      safetyScore: 9.5,
    );
  }
}
