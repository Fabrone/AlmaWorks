import 'package:flutter/material.dart';
import '../../models/project.dart';

class ProjectDetailScreen extends StatefulWidget {
  final Project project;

  const ProjectDetailScreen({super.key, required this.project});

  @override
  State<ProjectDetailScreen> createState() => _ProjectDetailScreenState();
}

class _ProjectDetailScreenState extends State<ProjectDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.project.name),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Documents'),
            Tab(text: 'RFIs'),
            Tab(text: 'Submittals'),
            Tab(text: 'Change Orders'),
            Tab(text: 'Team'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildOverviewTab(),
          _buildDocumentsTab(),
          _buildRFIsTab(),
          _buildSubmittalsTab(),
          _buildChangeOrdersTab(),
          _buildTeamTab(),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Project Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildDetailRow('Location', widget.project.location),
                  _buildDetailRow('Budget', '\$${widget.project.budget}M'),
                  _buildDetailRow('Progress', '${widget.project.progress}%'),
                  _buildDetailRow('Status', widget.project.status),
                  _buildDetailRow('Start Date', widget.project.startDate),
                  _buildDetailRow('End Date', widget.project.endDate),
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
                  const Text('Progress Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: widget.project.progress / 100,
                    backgroundColor: Colors.grey[300],
                    valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
                  ),
                  const SizedBox(height: 8),
                  Text('${widget.project.progress}% Complete'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }

  Widget _buildDocumentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDocumentItem('Site Plans', 'PDF', '2.3 MB', Icons.picture_as_pdf),
        _buildDocumentItem('Specifications', 'PDF', '5.1 MB', Icons.picture_as_pdf),
        _buildDocumentItem('Contract', 'PDF', '1.8 MB', Icons.picture_as_pdf),
        _buildDocumentItem('Photos', 'Folder', '45 items', Icons.folder),
      ],
    );
  }

  Widget _buildDocumentItem(String name, String type, String size, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(name),
        subtitle: Text('$type • $size'),
        trailing: IconButton(
          icon: const Icon(Icons.more_vert),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildRFIsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildRFIItem('RFI-001', 'Clarification on Foundation Details', 'Open', Colors.orange),
        _buildRFIItem('RFI-002', 'Material Specification Question', 'Answered', Colors.green),
        _buildRFIItem('RFI-003', 'Electrical Layout Confirmation', 'Pending', Colors.red),
      ],
    );
  }

  Widget _buildRFIItem(String number, String title, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(title),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  Widget _buildSubmittalsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildSubmittalItem('SUB-001', 'Concrete Mix Design', 'Approved', Colors.green),
        _buildSubmittalItem('SUB-002', 'Steel Reinforcement', 'Under Review', Colors.orange),
        _buildSubmittalItem('SUB-003', 'HVAC Equipment', 'Rejected', Colors.red),
      ],
    );
  }

  Widget _buildSubmittalItem(String number, String title, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(title),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  Widget _buildChangeOrdersTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildChangeOrderItem('CO-001', 'Additional Electrical Work', '\$15,000', 'Approved'),
        _buildChangeOrderItem('CO-002', 'Foundation Modification', '\$8,500', 'Pending'),
        _buildChangeOrderItem('CO-003', 'HVAC Upgrade', '\$22,000', 'Under Review'),
      ],
    );
  }

  Widget _buildChangeOrderItem(String number, String description, String amount, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.green)),
          ],
        ),
        trailing: Text(status),
      ),
    );
  }

  Widget _buildTeamTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildTeamMember('John Smith', 'Project Manager', 'john@company.com'),
        _buildTeamMember('Sarah Johnson', 'Site Supervisor', 'sarah@company.com'),
        _buildTeamMember('Mike Davis', 'Safety Officer', 'mike@company.com'),
        _buildTeamMember('Lisa Brown', 'Quality Control', 'lisa@company.com'),
      ],
    );
  }

  Widget _buildTeamMember(String name, String role, String email) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          child: Text(name.substring(0, 1)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(role),
            Text(email, style: TextStyle(color: Colors.grey[600])),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.phone),
          onPressed: () {},
        ),
      ),
    );
  }
}
