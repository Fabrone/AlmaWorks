import 'package:flutter/material.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  List<SearchResult> _searchResults = [];
  List<SearchResult> _recentSearches = [];
  bool _isSearching = false;

  final List<SearchResult> _allItems = [
    // Dashboard items
    SearchResult('Dashboard', 'Main dashboard overview', Icons.dashboard, 'dashboard'),
    SearchResult('Active Projects', 'View all active projects', Icons.folder, 'projects'),
    SearchResult('Total Budget', 'Budget overview and analysis', Icons.attach_money, 'financial'),
    SearchResult('Safety Score', 'Safety metrics and reports', Icons.security, 'quality_safety'),
    
    // Projects
    SearchResult('Projects', 'Project management section', Icons.folder, 'projects'),
    SearchResult('Downtown Office Complex', 'Project details and progress', Icons.business, 'project_detail'),
    SearchResult('Residential Tower', 'High-rise residential project', Icons.apartment, 'project_detail'),
    SearchResult('RFI Management', 'Request for Information tracking', Icons.help_outline, 'projects'),
    SearchResult('Change Orders', 'Project change order management', Icons.change_circle, 'projects'),
    
    // Financial
    SearchResult('Financial', 'Financial management section', Icons.attach_money, 'financial'),
    SearchResult('Budget Tracking', 'Project budget monitoring', Icons.trending_up, 'financial'),
    SearchResult('Cost Management', 'Cost coding and tracking', Icons.calculate, 'financial'),
    SearchResult('Invoices', 'Invoice management system', Icons.receipt, 'financial'),
    SearchResult('Payment Processing', 'Payment tracking and approval', Icons.payment, 'financial'),
    
    // Schedule
    SearchResult('Schedule', 'Project scheduling section', Icons.schedule, 'schedule'),
    SearchResult('Gantt Chart', 'Project timeline visualization', Icons.timeline, 'schedule'),
    SearchResult('Critical Path', 'Critical path analysis', Icons.route, 'schedule'),
    SearchResult('Resource Planning', 'Resource allocation and management', Icons.build, 'schedule'),
    
    // Quality & Safety
    SearchResult('Quality & Safety', 'Quality and safety management', Icons.security, 'quality_safety'),
    SearchResult('Safety Inspections', 'Safety inspection tracking', Icons.assignment_turned_in, 'quality_safety'),
    SearchResult('Quality Control', 'Quality control processes', Icons.verified, 'quality_safety'),
    SearchResult('Incident Reports', 'Safety incident reporting', Icons.warning, 'quality_safety'),
    
    // Field Productivity
    SearchResult('Field Productivity', 'Field operations management', Icons.work, 'field_productivity'),
    SearchResult('Daily Reports', 'Daily progress reporting', Icons.today, 'field_productivity'),
    SearchResult('Time & Attendance', 'Worker attendance tracking', Icons.access_time, 'field_productivity'),
    SearchResult('Equipment Management', 'Equipment tracking and maintenance', Icons.construction, 'field_productivity'),
    
    // Bid Management
    SearchResult('Bid Management', 'Vendor and bid management', Icons.gavel, 'bid_management'),
    SearchResult('Vendor Management', 'Vendor database and qualification', Icons.business, 'bid_management'),
    SearchResult('Bid Packages', 'Bid package creation and management', Icons.folder_open, 'bid_management'),
    SearchResult('Bid Comparisons', 'Vendor bid comparison tools', Icons.compare, 'bid_management'),
    
    // Design Coordination
    SearchResult('Design Coordination', 'Design and coordination management', Icons.architecture, 'design_coordination'),
    SearchResult('BIM Models', '3D model management', Icons.view_in_ar, 'design_coordination'),
    SearchResult('Drawing Management', 'Technical drawing control', Icons.architecture, 'design_coordination'),
    SearchResult('Clash Detection', 'Design conflict identification', Icons.warning, 'design_coordination'),
    
    // Reports
    SearchResult('Reports', 'Reporting and analytics', Icons.analytics, 'reports'),
    SearchResult('Project Reports', 'Comprehensive project reporting', Icons.assignment, 'reports'),
    SearchResult('Analytics Dashboard', 'Performance analytics', Icons.dashboard, 'reports'),
    SearchResult('Export Tools', 'Data export functionality', Icons.file_download, 'reports'),
  ];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  void _loadRecentSearches() {
    // Mock recent searches - in real app, load from storage
    _recentSearches = [
      SearchResult('Downtown Office Complex', 'Recently viewed project', Icons.business, 'project_detail'),
      SearchResult('Safety Inspections', 'Recently accessed', Icons.assignment_turned_in, 'quality_safety'),
      SearchResult('Budget Tracking', 'Recently viewed', Icons.trending_up, 'financial'),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _searchController,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Search for screens, features, projects...',
            border: InputBorder.none,
            hintStyle: TextStyle(color: Colors.white70),
          ),
          style: const TextStyle(color: Colors.white),
          onChanged: _performSearch,
        ),
        actions: [
          if (_searchController.text.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchResults.clear();
                  _isSearching = false;
                });
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isSearching && _searchResults.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No results found',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            Text(
              'Try different keywords',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_searchResults.isNotEmpty) {
      return _buildSearchResults();
    }

    return _buildRecentAndSuggestions();
  }

  Widget _buildSearchResults() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  Widget _buildRecentAndSuggestions() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_recentSearches.isNotEmpty) ...[
            const Text(
              'Recent Searches',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._recentSearches.map((result) => _buildSearchResultItem(result)),
            const SizedBox(height: 24),
          ],
          const Text(
            'Quick Access',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildQuickAccessGrid(),
          const SizedBox(height: 24),
          const Text(
            'Popular Searches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildPopularSearches(),
        ],
      ),
    );
  }

  Widget _buildSearchResultItem(SearchResult result) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            result.icon,
            color: Theme.of(context).primaryColor,
          ),
        ),
        title: Text(
          result.title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(result.description),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () => _navigateToResult(result),
      ),
    );
  }

  Widget _buildQuickAccessGrid() {
    final quickAccess = [
      SearchResult('Projects', 'View all projects', Icons.folder, 'projects'),
      SearchResult('Financial', 'Budget & costs', Icons.attach_money, 'financial'),
      SearchResult('Schedule', 'Project timeline', Icons.schedule, 'schedule'),
      SearchResult('Safety', 'Safety reports', Icons.security, 'quality_safety'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.5,
      ),
      itemCount: quickAccess.length,
      itemBuilder: (context, index) {
        final item = quickAccess[index];
        return Card(
          child: InkWell(
            onTap: () => _navigateToResult(item),
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    item.icon,
                    size: 32,
                    color: Theme.of(context).primaryColor,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildPopularSearches() {
    final popular = [
      'Active Projects',
      'Budget Tracking',
      'Safety Inspections',
      'Daily Reports',
      'RFI Management',
      'Change Orders',
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: popular.map((search) {
        return ActionChip(
          label: Text(search),
          onPressed: () {
            _searchController.text = search;
            _performSearch(search);
          },
        );
      }).toList(),
    );
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _searchResults.clear();
      } else {
        _searchResults = _allItems
            .where((item) =>
                item.title.toLowerCase().contains(query.toLowerCase()) ||
                item.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
      }
    });
  }

  void _navigateToResult(SearchResult result) {
    // Add to recent searches
    if (!_recentSearches.any((item) => item.title == result.title)) {
      setState(() {
        _recentSearches.insert(0, result);
        if (_recentSearches.length > 5) {
          _recentSearches.removeLast();
        }
      });
    }

    // Navigate based on screen type
    Navigator.pop(context); // Close search screen
    
    // In a real app, you would navigate to the appropriate screen
    // For now, show a snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to ${result.title}'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}

class SearchResult {
  final String title;
  final String description;
  final IconData icon;
  final String screenType;

  SearchResult(this.title, this.description, this.icon, this.screenType);
}
