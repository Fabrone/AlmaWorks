import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:logger/logger.dart';
import '../models/project_model.dart';

class BaseLayout extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;

    return Scaffold(
      appBar: _buildAppBar(context),
      drawer: isMobile ? _buildDrawer(context) : null,
      body: Row(
        children: [
          if (!isMobile) _buildSidebar(context, isTablet),
          Expanded(child: child),
        ],
      ),
      floatingActionButton: floatingActionButton,
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: GoogleFonts.poppins(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF0A2E5A),
      foregroundColor: Colors.white,
      actions: actions,
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
                  project?.name ?? 'AlmaWorks',
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
                  'Project Dashboard',
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
                title: Text('Switch Project', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Switch Project',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  onMenuItemSelected('Switch Project');
                },
              ),
              ListTile(
                leading: const Icon(Icons.dashboard),
                title: Text('Overview', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Overview',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  onMenuItemSelected('Overview');
                },
              ),
              ListTile(
                leading: const Icon(Icons.description),
                title: Text('Documents', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Documents',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  onMenuItemSelected('Documents');
                },
              ),
              ListTile(
                leading: const Icon(Icons.architecture),
                title: Text('Drawings', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Drawings',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  onMenuItemSelected('Drawings');
                },
              ),
              ListTile(
                leading: const Icon(Icons.schedule),
                title: Text('Schedule', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Schedule',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Schedule section coming soon', style: GoogleFonts.poppins())),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.security),
                title: Text('Quality & Safety', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Quality & Safety',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Quality & Safety section coming soon', style: GoogleFonts.poppins())),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.analytics),
                title: Text('Reports', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Reports',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Reports section coming soon', style: GoogleFonts.poppins())),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.photo_library),
                title: Text('Photo Gallery', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Photo Gallery',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Photo Gallery section coming soon', style: GoogleFonts.poppins())),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.attach_money),
                title: Text('Financials', style: GoogleFonts.poppins()),
                selected: selectedMenuItem == 'Financials',
                selectedTileColor: Colors.blueGrey[50],
                onTap: () {
                  if (isMobile) Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Financials section coming soon', style: GoogleFonts.poppins())),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}
