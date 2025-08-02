import 'package:flutter/material.dart';

class FieldProductivityScreen extends StatefulWidget {
  const FieldProductivityScreen({super.key});

  @override
  State<FieldProductivityScreen> createState() => _FieldProductivityScreenState();
}

class _FieldProductivityScreenState extends State<FieldProductivityScreen> with SingleTickerProviderStateMixin {
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
                Tab(text: 'Daily Reports'),
                Tab(text: 'Time & Attendance'),
                Tab(text: 'Equipment'),
                Tab(text: 'Progress Photos'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDailyReportsTab(),
                _buildTimeAttendanceTab(),
                _buildEquipmentTab(),
                _buildProgressPhotosTab(),
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

  Widget _buildDailyReportsTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildDailyReportItem('2024-02-20', 'Foundation work continued', '8 workers', 'Clear skies'),
        _buildDailyReportItem('2024-02-19', 'Concrete pour completed', '12 workers', 'Partly cloudy'),
        _buildDailyReportItem('2024-02-18', 'Site preparation finished', '6 workers', 'Light rain'),
      ],
    );
  }

  Widget _buildDailyReportItem(String date, String work, String crew, String weather) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.today),
        title: Text(date, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Work: $work'),
            Text('Crew: $crew'),
            Text('Weather: $weather'),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.edit),
          onPressed: () {},
        ),
      ),
    );
  }

  Widget _buildTimeAttendanceTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Today\'s Attendance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                _buildAttendanceMetric('Total Workers', '24'),
                _buildAttendanceMetric('Present', '22'),
                _buildAttendanceMetric('Absent', '2'),
                _buildAttendanceMetric('Late', '1'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildWorkerAttendanceItem('John Smith', 'Present', '7:30 AM', '8 hours'),
        _buildWorkerAttendanceItem('Mike Johnson', 'Present', '8:00 AM', '7.5 hours'),
        _buildWorkerAttendanceItem('Sarah Davis', 'Absent', '-', '0 hours'),
        _buildWorkerAttendanceItem('Tom Wilson', 'Late', '8:30 AM', '7 hours'),
      ],
    );
  }

  Widget _buildAttendanceMetric(String label, String value) {
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

  Widget _buildWorkerAttendanceItem(String name, String status, String checkIn, String hours) {
    Color statusColor = status == 'Present' ? Colors.green : 
                       status == 'Late' ? Colors.orange : Colors.red;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor,
          child: Text(name.substring(0, 1), style: const TextStyle(color: Colors.white)),
        ),
        title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Check-in: $checkIn'),
            Text('Hours: $hours'),
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

  Widget _buildEquipmentTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildEquipmentItem('Excavator #1', 'In Use', '8.5 hours', 'Foundation work'),
        _buildEquipmentItem('Crane #1', 'Available', '0 hours', 'Standby'),
        _buildEquipmentItem('Concrete Mixer', 'In Use', '6 hours', 'Concrete pour'),
        _buildEquipmentItem('Bulldozer', 'Maintenance', '0 hours', 'Scheduled service'),
      ],
    );
  }

  Widget _buildEquipmentItem(String equipment, String status, String hours, String activity) {
    Color statusColor = status == 'In Use' ? Colors.green : 
                       status == 'Available' ? Colors.blue : Colors.orange;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(Icons.construction, color: statusColor),
        title: Text(equipment, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hours today: $hours'),
            Text('Activity: $activity'),
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

  Widget _buildProgressPhotosTab() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: 8,
      itemBuilder: (context, index) {
        return _buildProgressPhotoItem(index);
      },
    );
  }

  Widget _buildProgressPhotoItem(int index) {
    final photos = [
      'Foundation - Day 1',
      'Foundation - Day 5',
      'Framing - Week 1',
      'Framing - Week 2',
      'Electrical - Rough-in',
      'Plumbing - Rough-in',
      'Insulation - Progress',
      'Drywall - Started',
    ];

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
              ),
              child: const Icon(Icons.photo, size: 50, color: Colors.grey),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  photos[index],
                  style: const TextStyle(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '2024-02-${15 + index}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showNewReportDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('New Daily Report'),
          content: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: 'Work Description',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),
              SizedBox(height: 16),
              TextField(
                decoration: InputDecoration(
                  labelText: 'Weather Conditions',
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}
