import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';

class EditProjectScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;
  
  const EditProjectScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<EditProjectScreen> createState() => _EditProjectScreenState();
}

class _EditProjectScreenState extends State<EditProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _projectManagerController = TextEditingController();
  
  String? _selectedStatus;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final List<String> _teamMembers = [];
  final TextEditingController _teamMemberController = TextEditingController();
  
  late final ProjectService _projectService;
  late final Logger _logger;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger;
    _projectService = ProjectService();
    _populateFields();
    _logger.i('🏗️ EditProjectScreen: Initialized for project: ${widget.project.name}');
  }

  void _populateFields() {
    _nameController.text = widget.project.name;
    _descriptionController.text = widget.project.description;
    _locationController.text = widget.project.location;
    _budgetController.text = widget.project.budget?.toString() ?? '';
    _projectManagerController.text = widget.project.projectManager;
    _selectedStatus = widget.project.status;
    _startDate = widget.project.startDate;
    _endDate = widget.project.endDate;
    _teamMembers.addAll(widget.project.teamMembers);
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('🎨 EditProjectScreen: Building UI');
    
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    final isTablet = screenWidth >= 600 && screenWidth < 1200;
    
    if (isMobile) {
      return _buildMobileLayout();
    }
    return _buildTabletDesktopLayout(isTablet);
  }

  Widget _buildMobileLayout() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${widget.project.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.all(isMobile ? 12 : 16),
                child: Column(
                  children: [
                    _buildBasicInformationCard(isMobile),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildProjectDetailsCard(isMobile),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildTimelineCard(isMobile),
                    SizedBox(height: isMobile ? 12 : 16),
                    _buildTeamMembersCard(isMobile),
                    SizedBox(height: isMobile ? 24 : 32),
                    _buildUpdateButton(),
                    SizedBox(height: isMobile ? 12 : 16),
                  ],
                ),
              ),
              _buildFooter(context, isMobile),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabletDesktopLayout(bool isTablet) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Edit ${widget.project.name}',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: const Color(0xFF0A2E5A),
        foregroundColor: Colors.white,
      ),
      body: Row(
        children: [
          _buildSidebar(context, isTablet),
          Expanded(
            child: Form(
              key: _formKey,
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(isMobile ? 12 : 16),
                      child: Column(
                        children: [
                          _buildBasicInformationCard(isMobile),
                          SizedBox(height: isMobile ? 12 : 16),
                          _buildProjectDetailsCard(isMobile),
                          SizedBox(height: isMobile ? 12 : 16),
                          _buildTimelineCard(isMobile),
                          SizedBox(height: isMobile ? 12 : 16),
                          _buildTeamMembersCard(isMobile),
                          SizedBox(height: isMobile ? 24 : 32),
                          _buildUpdateButton(),
                          SizedBox(height: isMobile ? 12 : 16),
                        ],
                      ),
                    ),
                    _buildFooter(context, isMobile),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
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
                  padding: const EdgeInsets.symmetric(horizontal: 16.0),
                  child: Text(
                    'Site Management',
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 16,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
                  leading: const Icon(Icons.edit),
                  title: const Text('Edit Project'),
                  selected: true,
                  onTap: () {},
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    'Project Sections',
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

  Widget _buildBasicInformationCard(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Basic Information',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Project Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a project name';
                }
                return null;
              },
            ),
            SizedBox(height: isMobile ? 12 : 16),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.description),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a project description';
                }
                return null;
              },
            ),
            SizedBox(height: isMobile ? 12 : 16),
            TextFormField(
              controller: _locationController,
              decoration: const InputDecoration(
                labelText: 'Location *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_on),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a project location';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProjectDetailsCard(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Project Details',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            TextFormField(
              controller: _budgetController,
              decoration: const InputDecoration(
                labelText: 'Budget (USD)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.attach_money),
                prefixText: '\$ ',
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            DropdownButtonFormField<String?>(
              value: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Status (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
              items: const [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('Untracked'),
                ),
                DropdownMenuItem<String?>(
                  value: 'active',
                  child: Text('Active'),
                ),
                DropdownMenuItem<String?>(
                  value: 'completed',
                  child: Text('Completed'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedStatus = value;
                });
                _logger.d('📝 EditProjectScreen: Status changed to $_selectedStatus');
              },
            ),
            SizedBox(height: isMobile ? 12 : 16),
            TextFormField(
              controller: _projectManagerController,
              decoration: const InputDecoration(
                labelText: 'Project Manager *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a project manager';
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineCard(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Timeline',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.calendar_today, color: Color(0xFF0A2E5A)),
                title: const Text('Start Date'),
                subtitle: Text(_formatDate(_startDate)),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _selectStartDate(),
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Container(
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[400]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: ListTile(
                leading: const Icon(Icons.event, color: Color(0xFF0A2E5A)),
                title: const Text('End Date (Optional)'),
                subtitle: Text(_endDate != null ? _formatDate(_endDate!) : 'Not set'),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () => _selectEndDate(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamMembersCard(bool isMobile) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Team Members',
              style: TextStyle(
                fontSize: isMobile ? 16 : 18,
                fontWeight: FontWeight.bold
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _teamMemberController,
                    decoration: const InputDecoration(
                      labelText: 'Add Team Member',
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_add),
                    ),
                    onFieldSubmitted: (_) => _addTeamMember(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: _addTeamMember,
                  icon: const Icon(Icons.add),
                  label: const Text('Add'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
            SizedBox(height: isMobile ? 12 : 16),
            if (_teamMembers.isNotEmpty) ...[
              const Text(
                'Team Members:',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _teamMembers.map((member) {
                  return Chip(
                    avatar: CircleAvatar(
                      backgroundColor: const Color(0xFF0A2E5A),
                      child: Text(
                        member.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    label: Text(member),
                    onDeleted: () => _removeTeamMember(member),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  );
                }).toList(),
              ),
            ] else ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: Column(
                  children: [
                    Icon(Icons.people_outline,
                       size: 48,
                       color: Colors.grey[400]
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No team members added yet',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildUpdateButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _updateProject,
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF0A2E5A),
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
        child: _isLoading
            ? const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                  SizedBox(width: 12),
                  Text('Updating Project...', style: TextStyle(fontSize: 16)),
                ],
              )
            : const Text(
                'Update Project',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<void> _selectStartDate() async {
    _logger.d('📅 EditProjectScreen: Selecting start date');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365 * 2)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _logger.i('✅ EditProjectScreen: Start date selected: $_startDate');
    }
  }

  Future<void> _selectEndDate() async {
    _logger.d('📅 EditProjectScreen: Selecting end date');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? _startDate.add(const Duration(days: 365)),
      firstDate: _startDate,
      lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
    );
    if (picked != null) {
      setState(() {
        _endDate = picked;
      });
      _logger.i('✅ EditProjectScreen: End date selected: $_endDate');
    }
  }

  void _addTeamMember() {
    if (_teamMemberController.text.isNotEmpty) {
      final newMember = _teamMemberController.text.trim();
      if (!_teamMembers.contains(newMember)) {
        setState(() {
          _teamMembers.add(newMember);
          _teamMemberController.clear();
        });
        _logger.i('👥 EditProjectScreen: Team member added. Total: ${_teamMembers.length}');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Team member already exists'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    }
  }

  void _removeTeamMember(String member) {
    setState(() {
      _teamMembers.remove(member);
    });
    _logger.i('👥 EditProjectScreen: Team member removed: $member');
  }

  void _updateProject() async {
    _logger.i('💾 EditProjectScreen: Update project initiated');
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        _logger.d('🏗️ EditProjectScreen: Creating updated project model');
        
        List<String> allTeamMembers = List.from(_teamMembers);
        if (!allTeamMembers.contains(_projectManagerController.text.trim())) {
          allTeamMembers.insert(0, _projectManagerController.text.trim());
        }

        final updatedProject = ProjectModel(
          id: widget.project.id,
          name: _nameController.text.trim(),
          description: _descriptionController.text.trim(),
          location: _locationController.text.trim(),
          budget: _budgetController.text.isNotEmpty
              ? double.tryParse(_budgetController.text.replaceAll(',', ''))
              : null,
          status: _selectedStatus,
          startDate: _startDate,
          endDate: _endDate,
          projectManager: _projectManagerController.text.trim(),
          teamMembers: allTeamMembers,
          createdAt: widget.project.createdAt,
          updatedAt: DateTime.now(),
        );

        _logger.i('📋 EditProjectScreen: Updated project model created - Name: ${updatedProject.name}');
        _logger.d('📤 EditProjectScreen: Updating in Firestore...');

        await _projectService.updateProject(updatedProject);
        
        _logger.i('✅ EditProjectScreen: Project updated successfully');

        if (mounted) {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          
          navigator.pop(true);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Project "${updatedProject.name}" updated successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.e('❌ EditProjectScreen: Error updating project',
          error: e, stackTrace: stackTrace);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error updating project: ${e.toString()}'),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 5),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } else {
      _logger.w('⚠️ EditProjectScreen: Form validation failed');
    }
  }

  @override
  void dispose() {
    _logger.i('🧹 EditProjectScreen: Disposing controllers');
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _projectManagerController.dispose();
    _teamMemberController.dispose();
    super.dispose();
  }
}
