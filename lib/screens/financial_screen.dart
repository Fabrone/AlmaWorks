import 'package:flutter/material.dart';

class FinancialScreen extends StatefulWidget {
  const FinancialScreen({super.key});

  @override
  State<FinancialScreen> createState() => _FinancialScreenState();
}

class _FinancialScreenState extends State<FinancialScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
              isScrollable: true,
              labelColor: Theme.of(context).primaryColor,
              unselectedLabelColor: Colors.grey,
              indicatorColor: Theme.of(context).primaryColor,
              tabs: const [
                Tab(text: 'Budget'),
                Tab(text: 'Cost Coding'),
                Tab(text: 'Invoices'),
                Tab(text: 'Payments'),
                Tab(text: 'Lien Waivers'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildBudgetTab(),
                _buildCostCodingTab(),
                _buildInvoicesTab(),
                _buildPaymentsTab(),
                _buildLienWaiversTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetTab() {
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
                  const Text('Budget Overview', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildBudgetItem('Total Budget', '\$2,400,000', '\$2,400,000', 1.0),
                  _buildBudgetItem('Committed', '\$1,800,000', '\$2,400,000', 0.75),
                  _buildBudgetItem('Spent', '\$1,200,000', '\$2,400,000', 0.5),
                  _buildBudgetItem('Remaining', '\$1,200,000', '\$2,400,000', 0.5),
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
                  const Text('Budget by Category', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  _buildCategoryItem('Labor', '\$800,000', 0.6),
                  _buildCategoryItem('Materials', '\$600,000', 0.8),
                  _buildCategoryItem('Equipment', '\$300,000', 0.4),
                  _buildCategoryItem('Subcontractors', '\$700,000', 0.7),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBudgetItem(String label, String amount, String total, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: progress,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryItem(String category, String amount, double progress) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(category, style: const TextStyle(fontWeight: FontWeight.w500)),
          ),
          Expanded(
            flex: 3,
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: Colors.grey[300],
              valueColor: AlwaysStoppedAnimation<Color>(Theme.of(context).primaryColor),
            ),
          ),
          const SizedBox(width: 16),
          Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildCostCodingTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildCostCodeItem('01-100', 'Site Preparation', '\$150,000'),
        _buildCostCodeItem('02-200', 'Foundation Work', '\$300,000'),
        _buildCostCodeItem('03-300', 'Concrete Work', '\$450,000'),
        _buildCostCodeItem('04-400', 'Masonry', '\$200,000'),
        _buildCostCodeItem('05-500', 'Steel Work', '\$350,000'),
      ],
    );
  }

  Widget _buildCostCodeItem(String code, String description, String amount) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(code, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(description),
        trailing: Text(amount, style: const TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInvoicesTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildInvoiceItem('INV-001', 'ABC Construction', '\$25,000', 'Paid', Colors.green),
        _buildInvoiceItem('INV-002', 'Steel Supply Co.', '\$45,000', 'Pending', Colors.orange),
        _buildInvoiceItem('INV-003', 'Electrical Services', '\$18,000', 'Overdue', Colors.red),
      ],
    );
  }

  Widget _buildInvoiceItem(String number, String vendor, String amount, String status, Color statusColor) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendor),
            Text(amount, style: const TextStyle(fontWeight: FontWeight.w500)),
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

  Widget _buildPaymentsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPaymentItem('PAY-001', 'Progress Payment #1', '\$200,000', 'Approved'),
        _buildPaymentItem('PAY-002', 'Material Payment', '\$75,000', 'Processing'),
        _buildPaymentItem('PAY-003', 'Subcontractor Payment', '\$120,000', 'Pending'),
      ],
    );
  }

  Widget _buildPaymentItem(String number, String description, String amount, String status) {
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

  Widget _buildLienWaiversTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildLienWaiverItem('LW-001', 'ABC Construction', 'Conditional', 'Received'),
        _buildLienWaiverItem('LW-002', 'Steel Supply Co.', 'Unconditional', 'Pending'),
        _buildLienWaiverItem('LW-003', 'Electrical Services', 'Conditional', 'Overdue'),
      ],
    );
  }

  Widget _buildLienWaiverItem(String number, String vendor, String type, String status) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(number, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(vendor),
            Text(type),
          ],
        ),
        trailing: Text(status),
      ),
    );
  }
}
