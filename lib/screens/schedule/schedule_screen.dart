import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/screens/schedule/general_schedule_screen.dart';
import 'package:almaworks/screens/schedule/dynamic_schedule_screen.dart';
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
    _tabController = TabController(length: 2, vsync: this);
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
                          indicatorWeight: 3,
                          labelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          unselectedLabelStyle: GoogleFonts.poppins(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                          tabs: const [
                            Tab(
                              icon: Icon(Icons.description),
                              text: 'General Schedule',
                            ),
                            Tab(
                              icon: Icon(Icons.dashboard_customize),
                              text: 'Dynamic Schedule',
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        height:
                            constraints.maxHeight -
                            88 - // TabBar height (48) + icon height (24) + padding (16)
                            (isMobile ? 12 : 16) * 2,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            GeneralScheduleScreen(
                              project: widget.project,
                              logger: widget.logger,
                            ),
                            DynamicScheduleScreen(
                              project: widget.project,
                              logger: widget.logger,
                            ),
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
}