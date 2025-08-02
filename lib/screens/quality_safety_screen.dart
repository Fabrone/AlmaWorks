import 'package:flutter/material.dart';

class QualitySafetyScreen extends StatefulWidget {
  const QualitySafetyScreen({super.key});

  @override
  State<QualitySafetyScreen> createState() => _QualitySafetyScreenState();
}

class _QualitySafetyScreenState extends State<QualitySafetyScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'Inspections'),
                Tab(text: 'Issues'),
                Tab(text: 'Safety Reports'),
                Tab(text: 'Action Plans'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildInspectionsTab(),
                _buildIssuesTab(),
                _buildSafetyReportsTab(),
                _buildActionPlansTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewInspectionDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildInspectionsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInspectionItem('Foundation Inspection', 'Passed', '2024-02-15', Colors.green),
        _buildInspectionItem('Electrical Rough-in', 'Pending', '2024-02-20', Colors.orange),
        _buildInspectionItem('Plumbing Rough-in', 'Scheduled', '2024-02-25', Colors.blue),
        _buildInspectionItem('Framing Inspection', 'Failed', '2024-02-10', Colors.red),
      ],
    );
  }

  Widget _buildInspectionItem(String title, String status, String date, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.assignment_turned_in, color: statusColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text('Date: $date'),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  Widget _buildIssuesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildIssueItem('ISS-001', 'Concrete crack in foundation', 'High', 'Open', Colors.red),
        _buildIssueItem('ISS-002', 'Missing safety railing', 'Medium', 'In Progress', Colors.orange),
        _buildIssueItem('ISS-003', 'Electrical conduit misalignment', 'Low', 'Resolved', Colors.green),
      ],
    );
  }

  Widget _buildIssueItem(String id, String description, String priority, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.warning, color: _getPriorityColor(priority)),
        title: Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text('Priority: $priority', style: TextStyle(color: _getPriorityColor(priority))),
          ],
        ),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return Colors.red;
      case 'Medium':
        return Colors.orange;
      case 'Low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Widget _buildSafetyReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Safety Statistics', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildSafetyMetric('Days without incident', '45'),
                _buildSafetyMetric('Total incidents this month', '2'),
                _buildSafetyMetric('Safety score', '9.2/10'),
                _buildSafetyMetric('Training completion', '95%'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildSafetyReportItem('Near Miss Report', 'Worker almost hit by falling tool', '2024-02-18'),
        _buildSafetyReportItem('Safety Meeting Minutes', 'Weekly safety briefing notes', '2024-02-15'),
        _buildSafetyReportItem('Incident Report', 'Minor cut on hand', '2024-02-10'),
      ],
    );
  }

  Widget _buildSafetyMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSafetyReportItem(String title, String description, String date) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.security),
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

  Widget _buildActionPlansTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildActionPlanItem('AP-001', 'Improve scaffolding safety', 'In Progress', '2024-02-25'),
        _buildActionPlanItem('AP-002', 'Update safety training materials', 'Completed', '2024-02-20'),
        _buildActionPlanItem('AP-003', 'Install additional safety signage', 'Pending', '2024-03-01'),
      ],
    );
  }

  Widget _buildActionPlanItem(String id, String description, String status, String dueDate) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.assignment),
        title: Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text('Due: $dueDate', style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        trailing: Text(status),
      ),
    );
  }

  void _showNewInspectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Inspection'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Inspection Type',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Inspector Name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );
  }
}
