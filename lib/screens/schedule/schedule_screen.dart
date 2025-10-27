import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/screens/schedule/msproject_gantt_screen.dart';
import 'package:almaworks/screens/schedule/purchasing_plan_screen.dart';
import 'package:almaworks/screens/schedule/schedule_monitor_screen.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';

class ScheduleScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const ScheduleScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    widget.logger.i(
      '📅 ScheduleScreen: Initialized for project: ${widget.project.name} (ID: ${widget.project.id})',
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final width = MediaQuery.of(context).size.width;
      widget.logger.d(
        '📅 ScheduleScreen: Screen width: $width, isMobile: ${width < 600}',
      );
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    widget.logger.d('📅 ScheduleScreen: Building UI, isMobile: $isMobile');
    return BaseLayout(
      title: '${widget.project.name} - Schedule',
      project: widget.project,
      logger: widget.logger,
      selectedMenuItem: 'Schedule',
      onMenuItemSelected: (_) {},
      child: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: TabBar(
                          controller: _tabController,
                          labelColor: const Color(0xFF0A2E5A),
                          unselectedLabelColor: Colors.grey[600],
                          indicatorColor: const Color(0xFF0A2E5A),
                          labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                          tabs: const [
                            Tab(text: 'Gantt Chart'),
                            Tab(text: 'Schedule Monitor'),
                            Tab(text: 'Purchasing Plan/Resources'),
                            Tab(text: 'Updates'),
                          ],
                        ),
                      ),
                      SizedBox(
                        height:
                            constraints.maxHeight -
                            48 -
                            (isMobile ? 12 : 16) * 2,
                        child: 
                        TabBarView(
                          controller: _tabController,
                          children: [
                            MSProjectGanttScreen(
                              project: widget.project,
                              logger: widget.logger,
                            ),
                            ScheduleMonitorScreen(
                              project: widget.project,
                              logger: widget.logger,
                              projectId: widget.project.id, 
                              projectName: widget.project.name,
                            ),
                            PurchasingPlanScreen(
                              project: widget.project,
                              logger: widget.logger,
                              projectId: widget.project.id,
                              projectName: widget.project.name,
                            ),
                            _buildUpdatesTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                  _buildFooter(context),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildFooter(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 600;
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      color: const Color(0xFF0A2E5A),
      child: Text(
        '© 2025 JV Alma C.I.S Site Management System',
        style: TextStyle(
          color: Colors.white,
          fontSize: isMobile ? 12 : 14,
          fontWeight: FontWeight.w400,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildUpdatesTab() {
    widget.logger.d('📅 ScheduleScreen: Rendering Updates tab');
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.update, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            'Project Updates',
            style: GoogleFonts.poppins(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Schedule updates and notifications will appear here',
            style: GoogleFonts.poppins(
              fontSize: 16,
              color: Colors.grey.shade500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.shade200),
            ),
            child: Column(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade600, size: 32),
                const SizedBox(height: 12),
                Text(
                  'Coming Soon',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Real-time project updates, notifications, and activity tracking will be available in future releases.',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    color: Colors.blue.shade700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}