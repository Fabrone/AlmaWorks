import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/screens/financial_screen.dart';
import 'package:almaworks/screens/projects/project_summary_screen.dart';
import 'package:almaworks/screens/projects/projects_main_screen.dart';
import 'package:almaworks/screens/schedule/schedule_screen.dart';
import 'package:almaworks/services/project_service.dart';
import 'package:almaworks/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:logger/logger.dart';

class SearchScreen extends StatefulWidget {
  final Logger? logger;
  
  const SearchScreen({super.key, this.logger});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ProjectService _projectService = ProjectService();
  late final Logger _logger;
  
  List<SearchResult> _searchResults = [];
  List<SearchResult> _recentSearches = [];
  List<ProjectModel> _projects = [];
  bool _isSearching = false;
  bool _isLoading = false;

  final List<SearchResult> _systemItems = [
    // Dashboard items
    SearchResult('Dashboard', 'Main dashboard overview', Icons.dashboard, 'dashboard'),
    SearchResult('Projects', 'Project management section', Icons.folder, 'projects'),
    SearchResult('Financial', 'Financial management section', Icons.attach_money, 'financial'),
    SearchResult('Schedule', 'Project scheduling section', Icons.schedule, 'schedule'),
    SearchResult('Quality & Safety', 'Quality and safety management', Icons.security, 'quality_safety'),
    SearchResult('Reports', 'Reporting and analytics', Icons.analytics, 'reports'),
    SearchResult('Photo Gallery', 'Project photo management', Icons.photo_library, 'photo_gallery'),
    SearchResult('Documents', 'Document management', Icons.description, 'documents'),
    SearchResult('Drawings', 'Technical drawing control', Icons.architecture, 'drawings'),
  ];

  @override
  void initState() {
    super.initState();
    _logger = widget.logger ?? Logger();
    _logger.i('🔍 SearchScreen: Initialized');
    _loadProjects();
    _loadRecentSearches();
  }

  void _loadProjects() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Listen to the stream and get the first snapshot
      final projectsStream = _projectService.getAllProjects();
      projectsStream.listen((projects) {
        if (mounted) {
          setState(() {
            _projects = projects;
            _isLoading = false;
          });
          _logger.d('📁 SearchScreen: Loaded ${projects.length} projects');
        }
      }).onError((error) {
        _logger.e('❌ SearchScreen: Error loading projects: $error');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      });
    } catch (e) {
      _logger.e('❌ SearchScreen: Error setting up projects stream: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _loadRecentSearches() {
    FirebaseFirestore.instance
        .collection('RecentSearches')
        .orderBy('timestamp', descending: true)
        .limit(5)
        .snapshots()
        .listen((snapshot) {
      final searches = snapshot.docs.map((doc) {
        final data = doc.data();
        return SearchResult(
          data['title'] ?? '',
          data['description'] ?? '',
          _getIconFromString(data['icon'] ?? 'search'),
          data['screenType'] ?? 'general',
        );
      }).toList();
      
      setState(() {
        _recentSearches = searches;
      });
      _logger.d('🕒 SearchScreen: Loaded ${searches.length} recent searches');
    });
  }

  IconData _getIconFromString(String iconName) {
    switch (iconName) {
      case 'business': return Icons.business;
      case 'folder': return Icons.folder;
      case 'attach_money': return Icons.attach_money;
      case 'schedule': return Icons.schedule;
      case 'security': return Icons.security;
      case 'analytics': return Icons.analytics;
      case 'photo_library': return Icons.photo_library;
      case 'description': return Icons.description;
      case 'architecture': return Icons.architecture;
      default: return Icons.search;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    
    return ResponsiveLayout(
      mobile: _buildMobileLayout(),
      tablet: _buildTabletLayout(isTablet),
      desktop: _buildDesktopLayout(),
    );
  }

  Widget _buildMobileLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Column(
        children: [
          Expanded(child: _buildBody()),
          _buildFooter(context, true),
        ],
      ),
    );
  }

  Widget _buildTabletLayout(bool isTablet) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSidebar(context, isTablet),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildBody()),
                _buildFooter(context, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Row(
        children: [
          _buildSidebar(context, false),
          Expanded(
            child: Column(
              children: [
                Expanded(child: _buildBody()),
                _buildFooter(context, false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
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
      backgroundColor: const Color(0xFF0A2E5A),
      foregroundColor: Colors.white,
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
    );
  }

  Widget _buildSidebar(BuildContext context, bool isTablet) {
    return Container(
      width: isTablet ? 280 : 300,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0A2E5A).withValues(alpha: 25),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            height: 120,
            width: double.infinity,
            decoration: const BoxDecoration(
              color: Color(0xFF0A2E5A),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'AlmaWorks',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Site Management',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                ListTile(
                  leading: const Icon(Icons.dashboard),
                  title: const Text('Dashboard'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.folder),
                  title: const Text('Projects'),
                  onTap: () {
                    Navigator.pop(context);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.search),
                  title: const Text('Search'),
                  selected: true,
                  onTap: () {},
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'System Sections',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey,
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.description),
                  title: const Text('Documents'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.architecture),
                  title: const Text('Drawings'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.schedule),
                  title: const Text('Schedule'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Quality & Safety'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.analytics),
                  title: const Text('Reports'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library),
                  title: const Text('Photo Gallery'),
                  enabled: false,
                  onTap: () {},
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Financials'),
                  enabled: false,
                  onTap: () {},
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

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
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return ListView.builder(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      itemCount: _searchResults.length,
      itemBuilder: (context, index) {
        final result = _searchResults[index];
        return _buildSearchResultItem(result);
      },
    );
  }

  Widget _buildRecentAndSuggestions() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
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
            'Popular Searches',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildPopularSearches(isMobile),
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
            color: const Color(0xFF0A2E5A).withValues(alpha: 25),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Icon(
            result.icon,
            color: const Color(0xFF0A2E5A),
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

  Widget _buildPopularSearches(bool isMobile) {
    final popular = [
      SearchResult('Active Projects', 'View all active projects', Icons.work, 'projects'),
      SearchResult('Budget Tracking', 'Financial overview', Icons.trending_up, 'financial'),
      SearchResult('Safety Inspections', 'Safety reports', Icons.security, 'quality_safety'),
      SearchResult('Daily Reports', 'Progress reports', Icons.today, 'reports'),
      SearchResult('Schedule', 'Project timeline', Icons.schedule, 'schedule'),
      SearchResult('Documents', 'Project documents', Icons.description, 'documents'),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: isMobile ? 2 : 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: isMobile ? 1.2 : 1.5,
      ),
      itemCount: popular.length,
      itemBuilder: (context, index) {
        final item = popular[index];
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
                    size: isMobile ? 28 : 32,
                    color: const Color(0xFF0A2E5A),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    item.title,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isMobile ? 12 : 14,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, bool isMobile) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: const Color(0xFF0A2E5A),
      child: Text(
        '© 2026 JV Alma C.I.S Site Management System',
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  void _performSearch(String query) {
    setState(() {
      _isSearching = query.isNotEmpty;
      if (query.isEmpty) {
        _searchResults.clear();
      } else {
        _searchResults = [];
        
        // Search system items
        final systemResults = _systemItems
            .where((item) =>
                item.title.toLowerCase().contains(query.toLowerCase()) ||
                item.description.toLowerCase().contains(query.toLowerCase()))
            .toList();
        
        // Search projects
        final projectResults = _projects
            .where((project) =>
                project.name.toLowerCase().contains(query.toLowerCase()) ||
                project.description.toLowerCase().contains(query.toLowerCase()) ||
                project.location.toLowerCase().contains(query.toLowerCase()) ||
                project.projectManager.toLowerCase().contains(query.toLowerCase()))
            .map((project) => SearchResult(
                project.name,
                '${project.location} - ${project.projectManager}',
                Icons.business,
                'project_detail',
                projectId: project.id,
              ))
            .toList();
        
        _searchResults = [...systemResults, ...projectResults];
      }
    });
  }

  void _navigateToResult(SearchResult result) async {
    // Save to recent searches
    try {
      await FirebaseFirestore.instance.collection('RecentSearches').add({
        'title': result.title,
        'description': result.description,
        'icon': result.icon.toString().split('.').last,
        'screenType': result.screenType,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      _logger.e('❌ SearchScreen: Error saving recent search: $e');
    }

    if (!mounted) return;
    
    final navigator = Navigator.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    navigator.pop(); // Close search screen

    // Navigate based on screen type
    switch (result.screenType) {
      case 'projects':
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ProjectsMainScreen(logger: _logger),
          ),
        );
        break;
      case 'project_detail':
        if (result.projectId != null) {
          try {
            final project = _projects.firstWhere((p) => p.id == result.projectId);
            navigator.push(
              MaterialPageRoute(
                builder: (context) => ProjectSummaryScreen(
                  project: project,
                  logger: _logger,
                ),
              ),
            );
          } catch (e) {
            _logger.e('❌ SearchScreen: Project not found: ${result.projectId}');
          }
        }
        break;
      case 'financial':
        // Provide required parameters to FinancialScreen
        navigator.push(
          MaterialPageRoute(
            builder: (context) => FinancialScreen(
              project: _projects.isNotEmpty ? _projects.first : ProjectModel.defaultModel(), // Pass a project
              logger: _logger, // Pass the logger
            ),
          ),
        );
        break;
      case 'schedule':
        navigator.push(
          MaterialPageRoute(
            builder: (context) => ScheduleScreen(
              project: _projects.isNotEmpty ? _projects.first : ProjectModel.defaultModel(),
              logger: _logger,
            ),
          ),
        );
        break;
      /*case 'quality_safety':
        navigator.push(
          MaterialPageRoute(builder: (context) => const QualityAndSafetyScreen()),
        );
        break;
      case 'reports':
        navigator.push(
          MaterialPageRoute(builder: (context) => const ReportsScreen()),
        );
        break;*/
      default:
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Navigating to ${result.title}'),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  @override
  void dispose() {
    _logger.i('🧹 SearchScreen: Disposing resources');
    _searchController.dispose();
    super.dispose();
  }
}

class SearchResult {
  final String title;
  final String description;
  final IconData icon;
  final String screenType;
  final String? projectId;

  SearchResult(
    this.title,
    this.description,
    this.icon,
    this.screenType, {
    this.projectId,
  });
}
