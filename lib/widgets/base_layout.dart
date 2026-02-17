import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/rbacsystem/client_request_service.dart';
import 'package:almaworks/screens/financial_screen.dart';
import 'package:almaworks/screens/photo_gallery_screen.dart';
import 'package:almaworks/screens/projects/projects_main_screen.dart';
import 'package:almaworks/screens/projects/project_summary_screen.dart';
import 'package:almaworks/screens/documents_screen.dart';
import 'package:almaworks/screens/drawings_screen.dart';
import 'package:almaworks/screens/quality_and_safety_screen.dart';
import 'package:almaworks/screens/reports/reports_screen.dart';
import 'package:almaworks/screens/schedule/schedule_screen.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BaseLayout extends StatefulWidget {
  final Widget child;
  final String title;
  final ProjectModel? project;
  final Logger logger;
  final String selectedMenuItem;
  final Function(String) onMenuItemSelected;
  final Widget? floatingActionButton;
  final List<Widget>? actions;

  const BaseLayout({
    super.key,
    required this.child,
    required this.title,
    this.project,
    required this.logger,
    required this.selectedMenuItem,
    required this.onMenuItemSelected,
    this.floatingActionButton,
    this.actions,
  });

  @override
  State<BaseLayout> createState() => _BaseLayoutState();
}

class _BaseLayoutState extends State<BaseLayout> {
  String? _userRole;
  List<String>? _clientProjectIds;
  bool _isLoadingUserData = true;
  final ClientRequestService _requestService = ClientRequestService();

  @override
  void initState() {
    super.initState();
    // FIX (window.dart:99): Defer the Firestore fetch to after the first frame.
    //
    // ROOT CAUSE: When the user taps a sidebar menu item, Flutter processes the
    // tap inside its pointer-event pipeline. That tap calls
    // Navigator.pushReplacement, which immediately mounts the new route's
    // widget tree — including a new BaseLayout — synchronously within the same
    // pointer frame. If _fetchUserRoleAndAccess() is called directly from
    // initState(), Firestore may resolve the Future from its local cache during
    // the *same* microtask queue flush that is still inside the pointer event.
    // The resulting setState() then schedules a frame from within the pointer
    // pipeline, which is exactly what window.dart:99 forbids.
    //
    // By deferring to addPostFrameCallback we guarantee that the first frame
    // has been committed before any async work begins, so any subsequent
    // setState() calls arrive outside the pointer pipeline entirely.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fetchUserRoleAndAccess();
    });
  }

  Future<void> _fetchUserRoleAndAccess() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        widget.logger.e('❌ BaseLayout: No authenticated user found');
        // FIX: Guard every setState with mounted check — the widget may have
        // been disposed between the frame callback scheduling and now.
        if (mounted) {
          setState(() {
            _isLoadingUserData = false;
          });
        }
        return;
      }

      final querySnapshot = await FirebaseFirestore.instance
          .collection('Users')
          .where('uid', isEqualTo: user.uid)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final userData = querySnapshot.docs.first.data();
        final role = userData['role'] as String? ?? 'Client';

        List<String> grantedIds = [];
        if (role == 'Client') {
          grantedIds =
              await _requestService.getClientGrantedProjects(user.uid);
          widget.logger
              .i('✅ BaseLayout: Client granted project IDs: $grantedIds');
        }

        // FIX: Every setState after an await must be guarded by mounted.
        if (mounted) {
          setState(() {
            _userRole = role;
            _clientProjectIds = role == 'Client' ? grantedIds : null;
            _isLoadingUserData = false;
          });
        }

        widget.logger.i(
            '✅ BaseLayout: User role fetched: $role, Granted Projects: ${grantedIds.length}');
      } else {
        widget.logger.w('⚠️ BaseLayout: User document not found');
        if (mounted) {
          setState(() {
            _userRole = 'Client';
            _isLoadingUserData = false;
          });
        }
      }
    } catch (e) {
      widget.logger.e('❌ BaseLayout: Error fetching user role: $e');
      if (mounted) {
        setState(() {
          _userRole = 'Client';
          _isLoadingUserData = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    if (_isLoadingUserData) {
      return Scaffold(
        appBar: _buildAppBar(context),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return Scaffold(
      appBar: _buildAppBar(context),
      drawer: isMobile ? _buildDrawer(context) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(context, isTablet),
          Expanded(child: widget.child),
        ],
      ),
      floatingActionButton: widget.floatingActionButton,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        widget.title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF0A2E5A),
      foregroundColor: Colors.white,
      actions: widget.actions,
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      child: _buildSidebarContent(context),
    );
  }

  Widget _buildSidebar(BuildContext context, bool isTablet) {
    return Container(
      width: isTablet ? 280 : 300,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(2, 0),
          ),
        ],
      ),
      child: _buildSidebarContent(context),
    );
  }

  Widget _buildSidebarContent(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final bool isClient = _userRole == 'Client';

    return Column(
      children: [
        Container(
          height: 120,
          width: double.infinity,
          decoration: const BoxDecoration(
            color: Color(0xFF0A2E5A),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  widget.project?.name ?? 'AlmaWorks',
                  style: GoogleFonts.poppins(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  isClient ? 'My Project Dashboard' : 'Project Dashboard',
                  style: GoogleFonts.poppins(
                    color: Colors.white70,
                    fontSize: 14,
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
                leading: const Icon(Icons.swap_horiz),
                title: Text(
                  isClient ? 'My Projects' : 'Switch Project',
                  style: GoogleFonts.poppins(),
                ),
                selected: widget.selectedMenuItem == 'Switch Project',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  widget.logger.i(
                      '🧭 BaseLayout: Switch Project selected, isClient: $isClient');
                  if (isMobile) Navigator.pop(context);

                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ProjectsMainScreen(
                        logger: widget.logger,
                        clientProjectIds:
                            isClient ? _clientProjectIds : null,
                      ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: Text('Overview', style: GoogleFonts.poppins()),
                selected: widget.selectedMenuItem == 'Overview',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  widget.logger.i('🧭 BaseLayout: Overview selected');
                  if (isMobile) Navigator.pop(context);
                  if (widget.project != null) {
                    if (isClient &&
                        _clientProjectIds != null &&
                        !_clientProjectIds!.contains(widget.project!.id)) {
                      widget.logger.w(
                          '⚠️ BaseLayout: Client attempted to access unauthorized project');
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'You do not have access to this project',
                            style: GoogleFonts.poppins(),
                          ),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ProjectSummaryScreen(
                          project: widget.project!,
                          logger: widget.logger,
                        ),
                      ),
                    );
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'No project selected',
                          style: GoogleFonts.poppins(),
                        ),
                      ),
                    );
                  }
                },
              ),
              _buildProtectedMenuItem(
                context: context,
                icon: Icons.description,
                title: 'Documents',
                selectedItem: 'Documents',
                isMobile: isMobile,
                isClient: isClient,
                onNavigate: () => DocumentsScreen(
                  project: widget.project!,
                  logger: widget.logger,
                ),
              ),
              _buildProtectedMenuItem(
                context: context,
                icon: Icons.architecture,
                title: 'Drawings',
                selectedItem: 'Drawings',
                isMobile: isMobile,
                isClient: isClient,
                onNavigate: () => DrawingsScreen(
                  project: widget.project!,
                  logger: widget.logger,
                ),
              ),
              _buildProtectedMenuItem(
                context: context,
                icon: Icons.schedule,
                title: 'Schedule',
                selectedItem: 'Schedule',
                isMobile: isMobile,
                isClient: isClient,
                onNavigate: () => ScheduleScreen(
                  project: widget.project!,
                  logger: widget.logger,
                ),
              ),
              _buildProtectedMenuItem(
                context: context,
                icon: Icons.shield_sharp,
                title: 'Quality & Safety',
                selectedItem: 'Quality & Safety',
                isMobile: isMobile,
                isClient: isClient,
                onNavigate: () => QualityAndSafetyScreen(
                  project: widget.project!,
                  logger: widget.logger,
                ),
              ),
              if (!isClient)
                _buildProtectedMenuItem(
                  context: context,
                  icon: Icons.insert_chart,
                  title: 'Reports',
                  selectedItem: 'Reports',
                  isMobile: isMobile,
                  isClient: isClient,
                  onNavigate: () => ReportsScreen(
                    project: widget.project!,
                    logger: widget.logger,
                  ),
                ),
              _buildProtectedMenuItem(
                context: context,
                icon: Icons.photo_library,
                title: 'Photo Gallery',
                selectedItem: 'Photo Gallery',
                isMobile: isMobile,
                isClient: isClient,
                onNavigate: () => PhotoGalleryScreen(
                  project: widget.project!,
                  logger: widget.logger,
                ),
              ),
              _buildProtectedMenuItem(
                context: context,
                icon: Icons.account_balance,
                title: 'Financials',
                selectedItem: 'Financials',
                isMobile: isMobile,
                isClient: isClient,
                onNavigate: () => FinancialScreen(
                  project: widget.project!,
                  logger: widget.logger,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildProtectedMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String selectedItem,
    required bool isMobile,
    required bool isClient,
    required Widget Function() onNavigate,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title, style: GoogleFonts.poppins()),
      selected: widget.selectedMenuItem == selectedItem,
      selectedTileColor: Colors.blueGrey[50],
      onTap: () {
        widget.logger.i('🧭 BaseLayout: $title selected');
        if (isMobile) Navigator.pop(context);

        if (widget.project != null) {
          if (isClient &&
              _clientProjectIds != null &&
              !_clientProjectIds!.contains(widget.project!.id)) {
            widget.logger.w(
                '⚠️ BaseLayout: Client attempted to access unauthorized project: $title');
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'You do not have access to this project',
                  style: GoogleFonts.poppins(),
                ),
                backgroundColor: Colors.red,
              ),
            );
            return;
          }

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => onNavigate(),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'No project selected',
                style: GoogleFonts.poppins(),
              ),
            ),
          );
        }
      },
    );
  }
}