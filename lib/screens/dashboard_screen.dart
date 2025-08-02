import 'package:almaworks/screens/bid_management_screen.dart';
import 'package:almaworks/screens/design_coordination_screen.dart';
import 'package:almaworks/screens/field_productivity_screen.dart';
import 'package:almaworks/screens/financial_screen.dart';
import 'package:almaworks/screens/projects/projects_screen.dart';
import 'package:almaworks/screens/quality_safety_screen.dart';
import 'package:almaworks/screens/reports_screen.dart';
import 'package:almaworks/screens/schedule_screen.dart';
import 'package:flutter/material.dart';
import '../../widgets/dashboard_card.dart';
import '../../widgets/activity_feed.dart';
import '../../widgets/weather_widget.dart';
import '../../widgets/todo_widget.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _selectedIndex = 0;

  final List<Widget> _screens = [
    const DashboardHome(),
    const ProjectsScreen(),
    const FinancialScreen(),
    const ScheduleScreen(),
    const QualitySafetyScreen(),
    const FieldProductivityScreen(),
    const BidManagementScreen(),
    const DesignCoordinationScreen(),
    const ReportsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AlmaWorks'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications),
            onPressed: () {},
          ),
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () {},
          ),
          const Padding(
            padding: EdgeInsets.only(right: 8.0),
            child: CircleAvatar(
              radius: 16,
              child: Icon(Icons.person, size: 20),
            ),
          ),
        ],
      ),
      drawer: _buildDrawer(),
      body: _screens[_selectedIndex],
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(
              color: Color(0xFF1976D2),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AlmaWorks',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Construction Management',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          _buildDrawerItem(Icons.dashboard, 'Dashboard', 0),
          _buildDrawerItem(Icons.folder, 'Projects', 1),
          _buildDrawerItem(Icons.attach_money, 'Financial', 2),
          _buildDrawerItem(Icons.schedule, 'Schedule', 3),
          _buildDrawerItem(Icons.security, 'Quality & Safety', 4),
          _buildDrawerItem(Icons.work, 'Field Productivity', 5),
          _buildDrawerItem(Icons.gavel, 'Bid Management', 6),
          _buildDrawerItem(Icons.architecture, 'Design Coordination', 7),
          _buildDrawerItem(Icons.analytics, 'Reports', 8),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(IconData icon, String title, int index) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      selected: _selectedIndex == index,
      onTap: () {
        setState(() {
          _selectedIndex = index;
        });
        Navigator.pop(context);
      },
    );
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
    // Check screen width to determine layout
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 600;
    
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
          value: '12',
          icon: Icons.folder,
          color: Colors.blue,
        ),
        DashboardCard(
          title: 'Total Budget',
          value: '\$2.4M',
          icon: Icons.attach_money,
          color: Colors.green,
        ),
        DashboardCard(
          title: 'On Schedule',
          value: '85%',
          icon: Icons.schedule,
          color: Colors.orange,
        ),
        DashboardCard(
          title: 'Safety Score',
          value: '9.2',
          icon: Icons.security,
          color: Colors.red,
        ),
      ],
    );
  }

  Widget _buildContentSection(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth > 800;
    
    if (isTablet) {
      // Tablet layout - side by side
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
      // Mobile layout - stacked
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
