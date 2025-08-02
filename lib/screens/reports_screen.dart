import 'package:flutter/material.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'Templates'),
                Tab(text: 'Analytics'),
                Tab(text: 'Dashboards'),
                Tab(text: 'Exports'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTemplatesTab(),
                _buildAnalyticsTab(),
                _buildDashboardsTab(),
                _buildExportsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewReportDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildTemplatesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTemplateItem('Project Status Report', 'Weekly project overview', Icons.assignment),
        _buildTemplateItem('Financial Summary', 'Budget and cost analysis', Icons.attach_money),
        _buildTemplateItem('Safety Report', 'Safety metrics and incidents', Icons.security),
        _buildTemplateItem('Progress Report', 'Construction progress tracking', Icons.trending_up),
        _buildTemplateItem('Quality Control Report', 'Quality metrics and issues', Icons.verified),
        _buildTemplateItem('Resource Utilization', 'Equipment and labor usage', Icons.build),
      ],
    );
  }

  Widget _buildTemplateItem(String name, String description, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {},
            ),
            IconButton(
              icon: const Icon(Icons.play_arrow),
              onPressed: () {},
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Project Performance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildAnalyticsMetric('On-Time Completion Rate', '85%', Colors.green),
                  _buildAnalyticsMetric('Budget Variance', '-2.3%', Colors.red),
                  _buildAnalyticsMetric('Safety Score', '9.2/10', Colors.blue),
                  _buildAnalyticsMetric('Quality Rating', '4.8/5', Colors.orange),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Productivity Trends', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('Productivity Chart Placeholder'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsMetric(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(value, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDashboardItem('Executive Dashboard', 'High-level project overview', 'Last updated: 1 hour ago'),
        _buildDashboardItem('Project Manager Dashboard', 'Detailed project metrics', 'Last updated: 30 minutes ago'),
        _buildDashboardItem('Safety Dashboard', 'Safety metrics and alerts', 'Last updated: 2 hours ago'),
        _buildDashboardItem('Financial Dashboard', 'Budget and cost tracking', 'Last updated: 1 day ago'),
      ],
    );
  }

  Widget _buildDashboardItem(String name, String description, String lastUpdated) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.dashboard),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text(lastUpdated, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.open_in_new),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildExportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Export Options', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildExportOption('PDF Report', 'Generate comprehensive PDF reports', Icons.picture_as_pdf),
                _buildExportOption('Excel Spreadsheet', 'Export data to Excel format', Icons.table_chart),
                _buildExportOption('CSV Data', 'Export raw data as CSV', Icons.file_present),
                _buildExportOption('PowerPoint Presentation', 'Create presentation slides', Icons.slideshow),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Recent Exports', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildRecentExportItem('Project Status Report.pdf', '2024-02-20 10:30 AM'),
                _buildRecentExportItem('Financial Summary.xlsx', '2024-02-19 3:45 PM'),
                _buildRecentExportItem('Safety Data.csv', '2024-02-18 9:15 AM'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildExportOption(String name, String description, IconData icon) {
    return ListTile(
      leading: Icon(icon, color: Theme.of(context).primaryColor),
      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(description),
      trailing: ElevatedButton(
        onPressed: () {},
        child: const Text('Export'),
      ),
    );
  }

  Widget _buildRecentExportItem(String filename, String timestamp) {
    return ListTile(
      leading: const Icon(Icons.file_download),
      title: Text(filename, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(timestamp),
      trailing: IconButton(
        icon: const Icon(Icons.download),
        onPressed: () {},
      ),
    );
  }

  void _showNewReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Create New Report'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Report Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 2,
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
