import 'package:flutter/material.dart';

class DesignCoordinationScreen extends StatefulWidget {
  const DesignCoordinationScreen({super.key});

  @override
  State<DesignCoordinationScreen> createState() => _DesignCoordinationScreenState();
}

class _DesignCoordinationScreenState extends State<DesignCoordinationScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'BIM Models'),
                Tab(text: 'Drawings'),
                Tab(text: 'Clash Detection'),
                Tab(text: 'Reviews'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBIMModelsTab(),
                _buildDrawingsTab(),
                _buildClashDetectionTab(),
                _buildReviewsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showUploadDialog();
        },
        child: const Icon(Icons.upload),
      ),
    );
  }

  Widget _buildBIMModelsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBIMModelItem('Architectural Model', 'v2.1', '45.2 MB', 'Updated today'),
        _buildBIMModelItem('Structural Model', 'v1.8', '32.1 MB', 'Updated 2 days ago'),
        _buildBIMModelItem('MEP Model', 'v1.5', '28.7 MB', 'Updated 1 week ago'),
        _buildBIMModelItem('Site Model', 'v1.2', '15.3 MB', 'Updated 2 weeks ago'),
      ],
    );
  }

  Widget _buildBIMModelItem(String name, String version, String size, String lastUpdated) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.view_in_ar, color: Colors.blue),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Version: $version'),
            Text('Size: $size'),
            Text(lastUpdated, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.download),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildDrawingsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDrawingItem('A-001', 'Site Plan', 'Rev C', 'Current'),
        _buildDrawingItem('A-101', 'Floor Plan - Level 1', 'Rev B', 'Current'),
        _buildDrawingItem('S-201', 'Foundation Plan', 'Rev A', 'Superseded'),
        _buildDrawingItem('E-301', 'Electrical Layout', 'Rev D', 'Current'),
        _buildDrawingItem('M-401', 'HVAC Plan', 'Rev A', 'Under Review'),
      ],
    );
  }

  Widget _buildDrawingItem(String number, String title, String revision, String status) {
    Color statusColor = status == 'Current' ? Colors.green : 
                       status == 'Under Review' ? Colors.orange : Colors.grey;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.architecture),
        title: Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title),
            Text(revision, style: TextStyle(color: Colors.grey[600])),
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

  Widget _buildClashDetectionTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Clash Detection Summary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildClashSummaryItem('Total Clashes', '23', Colors.red),
                _buildClashSummaryItem('Resolved', '18', Colors.green),
                _buildClashSummaryItem('Active', '5', Colors.orange),
                _buildClashSummaryItem('Critical', '2', Colors.red),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildClashItem('CLASH-001', 'HVAC duct conflicts with beam', 'Critical', 'Active'),
        _buildClashItem('CLASH-002', 'Electrical conduit interference', 'Medium', 'Resolved'),
        _buildClashItem('CLASH-003', 'Plumbing pipe clearance issue', 'High', 'Active'),
      ],
    );
  }

  Widget _buildClashSummaryItem(String label, String count, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(count, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildClashItem(String id, String description, String severity, String status) {
    Color severityColor = severity == 'Critical' ? Colors.red : 
                         severity == 'High' ? Colors.orange : Colors.yellow;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.warning, color: severityColor),
        title: Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text('Severity: $severity', style: TextStyle(color: severityColor)),
          ],
        ),
        trailing: Text(status),
      ),
    );
  }

  Widget _buildReviewsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildReviewItem('Design Review #1', 'Architectural plans review', 'Completed', '2024-02-15'),
        _buildReviewItem('Design Review #2', 'Structural drawings review', 'In Progress', '2024-02-20'),
        _buildReviewItem('Design Review #3', 'MEP coordination review', 'Scheduled', '2024-02-25'),
        _buildReviewItem('Design Review #4', 'Final design review', 'Pending', '2024-03-01'),
      ],
    );
  }

  Widget _buildReviewItem(String title, String description, String status, String date) {
    Color statusColor = status == 'Completed' ? Colors.green : 
                       status == 'In Progress' ? Colors.blue : Colors.orange;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.rate_review, color: statusColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text('Date: $date', style: TextStyle(color: Colors.grey[600])),
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

  void _showUploadDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Upload File'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'File Name',
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
              child: const Text('Upload'),
            ),
          ],
        );
      },
    );
  }
}
