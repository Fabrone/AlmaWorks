import 'package:almaworks/services/attendance_service.dart';
import 'package:almaworks/widgets/responsive_layout.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';

class AccountScreen extends StatefulWidget {
  final Logger? logger;
  
  const AccountScreen({super.key, this.logger});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  late final Logger _logger;
  
  bool _isSignedIn = false;
  String _signInTime = '';
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  String _selectedLanguage = 'English';
  
  // User profile data
  String _userName = 'Fabron Lubanga';
  final String _userRole = 'Project Manager';
  String _userEmail = 'fabron.lubanga@almaworks.com';
  String _userPhone = '+254 712 345 678';
  final String _employeeId = 'EMP001';
  bool _isEditingProfile = false;
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _logger = widget.logger ?? Logger();
    _logger.i('👤 AccountScreen: Initialized');
    _checkSignInStatus();
    _initializeControllers();
  }

  void _initializeControllers() {
    _nameController.text = _userName;
    _emailController.text = _userEmail;
    _phoneController.text = _userPhone;
  }

  void _checkSignInStatus() {
    final status = _attendanceService.getTodayAttendance();
    setState(() {
      _isSignedIn = status['isSignedIn'] ?? false;
      _signInTime = status['signInTime'] ?? '';
    });
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
          Expanded(child: _buildAccountContent(true)),
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
                Expanded(child: _buildAccountContent(false)),
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
                Expanded(child: _buildAccountContent(false)),
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
      title: const Text(
        'Account',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
      centerTitle: true,
      backgroundColor: const Color(0xFF0A2E5A),
      foregroundColor: Colors.white,
      actions: [
        IconButton(
          icon: Icon(_isEditingProfile ? Icons.save : Icons.edit),
          onPressed: () {
            if (_isEditingProfile) {
              _saveProfile();
            } else {
              setState(() {
                _isEditingProfile = true;
              });
            }
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
            color: Colors.grey.withValues(alpha: 0.1),
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
                  leading: const Icon(Icons.person),
                  title: const Text('Account'),
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

  Widget _buildAccountContent(bool isMobile) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      child: Column(
        children: [
          _buildProfileSection(isMobile),
          const SizedBox(height: 24),
          _buildAttendanceSection(isMobile),
          const SizedBox(height: 24),
          _buildOrganizationSection(isMobile),
          const SizedBox(height: 24),
          _buildSettingsSection(isMobile),
        ],
      ),
    );
  }

  Widget _buildProfileSection(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          children: [
            CircleAvatar(
              radius: isMobile ? 40 : 50,
              backgroundColor: const Color(0xFF0A2E5A),
              child: Text(
                _userName.split(' ').map((name) => name[0]).join(''),
                style: TextStyle(
                  fontSize: isMobile ? 24 : 30,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditingProfile) ...[
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  border: OutlineInputBorder(),
                ),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  border: OutlineInputBorder(),
                ),
              ),
            ] else ...[
              Text(
                _userName,
                style: TextStyle(
                  fontSize: isMobile ? 20 : 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _userRole,
                style: TextStyle(
                  fontSize: isMobile ? 14 : 16,
                  color: Colors.grey,
                ),
              ),
              const SizedBox(height: 16),
              _buildInfoRow('Email', _userEmail),
              _buildInfoRow('Phone', _userPhone),
              _buildInfoRow('Employee ID', _employeeId),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAttendanceSection(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.access_time, color: const Color(0xFF0A2E5A)),
                const SizedBox(width: 8),
                Text(
                  'Today\'s Attendance',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isSignedIn) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 32),
                    const SizedBox(height: 8),
                    const Text(
                      'Signed In',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                    ),
                    Text(
                      'Sign-in time: $_signInTime',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signOut,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Sign Out'),
                ),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  children: [
                    Icon(Icons.schedule, color: Colors.orange, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Not Signed In',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                    ),
                    Text('Tap below to mark your attendance'),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Sign In'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildOrganizationSection(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.business, color: const Color(0xFF0A2E5A)),
                const SizedBox(width: 8),
                Text(
                  'Organization Details',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildInfoRow('Organization', 'AlmaWorks Construction Ltd'),
            _buildInfoRow('Department', 'Project Management'),
            _buildInfoRow('Location', 'Nairobi, Kenya'),
            _buildInfoRow('Joined Date', '14 Feb 2025'),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsSection(bool isMobile) {
    return Card(
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: const Color(0xFF0A2E5A)),
                const SizedBox(width: 8),
                Text(
                  'Settings',
                  style: TextStyle(
                    fontSize: isMobile ? 16 : 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildSettingsTile(
              Icons.notifications,
              'Notifications',
              Switch(
                value: _notificationsEnabled,
                onChanged: (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                  _logger.i('🔔 AccountScreen: Notifications ${value ? 'enabled' : 'disabled'}');
                },
                activeThumbColor: const Color(0xFF0A2E5A),

              ),
            ),
            _buildSettingsTile(
              Icons.dark_mode,
              'Dark Mode',
              Switch(
                value: _darkModeEnabled,
                onChanged: (value) {
                  setState(() {
                    _darkModeEnabled = value;
                  });
                  _logger.i('🌙 AccountScreen: Dark mode ${value ? 'enabled' : 'disabled'}');
                },
                activeThumbColor: const Color(0xFF0A2E5A),

              ),
            ),
            _buildSettingsTile(
              Icons.language,
              'Language',
              DropdownButton<String>(
                value: _selectedLanguage,
                underline: Container(),
                items: ['English', 'Swahili', 'Italian'].map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() {
                      _selectedLanguage = newValue;
                    });
                    _logger.i('🌐 AccountScreen: Language changed to $newValue');
                  }
                },
              ),
            ),
            _buildSettingsTile(
              Icons.security,
              'Privacy & Security',
              const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Privacy & Security settings coming soon')),
                );
              },
            ),
            _buildSettingsTile(
              Icons.help,
              'Help & Support',
              const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Help & Support coming soon')),
                );
              },
            ),
            _buildSettingsTile(
              Icons.logout,
              'Logout',
              const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: _showLogoutDialog,
              textColor: Colors.red,
              iconColor: Colors.red,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile(
    IconData icon,
    String title,
    Widget trailing, {
    VoidCallback? onTap,
    Color? textColor,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Icon(icon, color: iconColor),
      title: Text(
        title,
        style: TextStyle(color: textColor),
      ),
      trailing: trailing,
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildInfoRow(String label, String value) {
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

  Widget _buildFooter(BuildContext context, bool isMobile) {
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

  void _saveProfile() {
    setState(() {
      _userName = _nameController.text;
      _userEmail = _emailController.text;
      _userPhone = _phoneController.text;
      _isEditingProfile = false;
    });
    
    _logger.i('💾 AccountScreen: Profile updated - Name: $_userName');
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Profile updated successfully!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _signIn() async {
    final success = await _attendanceService.signIn();
    if (success) {
      _checkSignInStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed in!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      _logger.i('✅ AccountScreen: User signed in successfully');
    }
  }

  void _signOut() async {
    final success = await _attendanceService.signOut();
    if (success) {
      _checkSignInStatus();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Successfully signed out!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
      _logger.i('✅ AccountScreen: User signed out successfully');
    }
  }

  void _showLogoutDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _logger.i('🚪 AccountScreen: User logged out');
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Logged out successfully'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _logger.i('🧹 AccountScreen: Disposing resources');
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }
}
