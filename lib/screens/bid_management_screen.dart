import 'package:flutter/material.dart';

class BidManagementScreen extends StatefulWidget {
  const BidManagementScreen({super.key});

  @override
  State<BidManagementScreen> createState() => _BidManagementScreenState();
}

class _BidManagementScreenState extends State<BidManagementScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'Vendors'),
                Tab(text: 'Bid Packages'),
                Tab(text: 'Comparisons'),
                Tab(text: 'Prequalification'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildVendorsTab(),
                _buildBidPackagesTab(),
                _buildComparisonsTab(),
                _buildPrequalificationTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showNewVendorDialog();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildVendorsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildVendorItem('ABC Construction', 'General Contractor', '★★★★★', 'Active'),
        _buildVendorItem('Steel Supply Co.', 'Materials Supplier', '★★★★☆', 'Active'),
        _buildVendorItem('Electrical Services Inc.', 'Electrical Contractor', '★★★★★', 'Active'),
        _buildVendorItem('Plumbing Solutions', 'Plumbing Contractor', '★★★☆☆', 'Inactive'),
      ],
    );
  }

  Widget _buildVendorItem(String name, String category, String rating, String status) {
    Color statusColor = status == 'Active' ? Colors.green : Colors.grey;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.business),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(category),
            Text(rating, style: const TextStyle(color: Colors.orange)),
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

  Widget _buildBidPackagesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildBidPackageItem('BP-001', 'Foundation Work', '5 bidders', 'Open', Colors.green),
        _buildBidPackageItem('BP-002', 'Electrical Installation', '3 bidders', 'Closed', Colors.red),
        _buildBidPackageItem('BP-003', 'HVAC System', '7 bidders', 'Under Review', Colors.orange),
        _buildBidPackageItem('BP-004', 'Roofing Work', '4 bidders', 'Draft', Colors.blue),
      ],
    );
  }

  Widget _buildBidPackageItem(String id, String description, String bidders, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.folder_open),
        title: Text(id, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            Text(bidders, style: TextStyle(color: Colors.grey[600])),
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

  Widget _buildComparisonsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Foundation Work - Bid Comparison', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildBidComparisonItem('ABC Construction', '\$150,000', '30 days', '★★★★★'),
                _buildBidComparisonItem('XYZ Builders', '\$145,000', '35 days', '★★★★☆'),
                _buildBidComparisonItem('Foundation Pro', '\$160,000', '25 days', '★★★★★'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBidComparisonItem(String vendor, String price, String duration, String rating) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(vendor, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(child: Text(price)),
          Expanded(child: Text(duration)),
          Text(rating, style: const TextStyle(color: Colors.orange)),
        ],
      ),
    );
  }

  Widget _buildPrequalificationTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPrequalificationItem('ABC Construction', 'Approved', 'Insurance: Valid, License: Active', Colors.green),
        _buildPrequalificationItem('Steel Supply Co.', 'Pending', 'Awaiting insurance documents', Colors.orange),
        _buildPrequalificationItem('New Contractor LLC', 'Under Review', 'Background check in progress', Colors.blue),
        _buildPrequalificationItem('Old Builder Inc.', 'Rejected', 'License expired', Colors.red),
      ],
    );
  }

  Widget _buildPrequalificationItem(String vendor, String status, String notes, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.verified_user, color: statusColor),
        title: Text(vendor, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(notes),
        trailing: Chip(
          label: Text(status),
          backgroundColor: statusColor.withValues(alpha: 0.1),
          labelStyle: TextStyle(color: statusColor),
        ),
      ),
    );
  }

  void _showNewVendorDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Vendor'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Vendor Name',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Category',
                  border: OutlineInputBorder(),
                ),
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Contact Email',
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
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}
