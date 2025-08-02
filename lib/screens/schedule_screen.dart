import 'package:flutter/material.dart';

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key});

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'Gantt Chart'),
                Tab(text: 'Critical Path'),
                Tab(text: 'Resources'),
                Tab(text: 'Updates'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildGanttTab(),
                _buildCriticalPathTab(),
                _buildResourcesTab(),
                _buildUpdatesTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGanttTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Project Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          _buildGanttItem('Site Preparation', '2024-01-01', '2024-01-15', 1.0, Colors.green),
          _buildGanttItem('Foundation Work', '2024-01-16', '2024-02-15', 0.8, Colors.blue),
          _buildGanttItem('Framing', '2024-02-16', '2024-03-30', 0.4, Colors.orange),
          _buildGanttItem('Electrical Rough-in', '2024-03-15', '2024-04-15', 0.0, Colors.grey),
          _buildGanttItem('Plumbing Rough-in', '2024-03-20', '2024-04-20', 0.0, Colors.grey),
          _buildGanttItem('Insulation', '2024-04-21', '2024-05-05', 0.0, Colors.grey),
          _buildGanttItem('Drywall', '2024-05-06', '2024-05-25', 0.0, Colors.grey),
          _buildGanttItem('Flooring', '2024-05-26', '2024-06-15', 0.0, Colors.grey),
          _buildGanttItem('Final Inspections', '2024-06-16', '2024-06-30', 0.0, Colors.grey),
        ],
      ),
    );
  }

  Widget _buildGanttItem(String task, String startDate, String endDate, double progress, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(task, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Row(
              children: [
                Text('$startDate - $endDate', style: TextStyle(color: Colors.grey[600])),
                const Spacer(),
                Text('${(progress * 100).toInt()}%', style: const TextStyle(fontWeight: FontWeight.w500)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriticalPathTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Card(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Critical Path Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Text('Total Project Duration: 180 days'),
                Text('Critical Path Duration: 175 days'),
                Text('Float Available: 5 days'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildCriticalPathItem('Site Preparation', 'Critical', Colors.red),
        _buildCriticalPathItem('Foundation Work', 'Critical', Colors.red),
        _buildCriticalPathItem('Framing', 'Critical', Colors.red),
        _buildCriticalPathItem('Electrical Rough-in', '3 days float', Colors.orange),
        _buildCriticalPathItem('Plumbing Rough-in', '5 days float', Colors.green),
      ],
    );
  }

  Widget _buildCriticalPathItem(String task, String status, Color color) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(task, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Chip(
          label: Text(status),
          backgroundColor: color.withAlpha(26), // Updated line
          labelStyle: TextStyle(color: color),
        ),
      ),
    );
  }

  Widget _buildResourcesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildResourceItem('Construction Crew A', '8 workers', 'Assigned to Foundation'),
        _buildResourceItem('Crane #1', '1 unit', 'Available'),
        _buildResourceItem('Excavator', '2 units', 'In use - Site Prep'),
        _buildResourceItem('Concrete Truck', '3 units', 'Scheduled for tomorrow'),
      ],
    );
  }

  Widget _buildResourceItem(String resource, String quantity, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.build),
        title: Text(resource, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(quantity),
            Text(status, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }

  Widget _buildUpdatesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildUpdateItem('Foundation Work Completed', '2 days ahead of schedule', '2024-02-13'),
        _buildUpdateItem('Weather Delay', 'Rain delayed concrete pour by 1 day', '2024-02-10'),
        _buildUpdateItem('Material Delivery', 'Steel beams delivered on time', '2024-02-08'),
        _buildUpdateItem('Inspection Passed', 'Foundation inspection approved', '2024-02-05'),
      ],
    );
  }

  Widget _buildUpdateItem(String title, String description, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.update),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text(date, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
      ),
    );
  }
}
