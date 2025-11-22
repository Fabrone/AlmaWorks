import 'package:almaworks/models/project_model.dart';
import 'package:almaworks/services/project_service.dart';
import 'package:almaworks/widgets/base_layout.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';

class AddProjectScreen extends StatefulWidget {
  final Logger logger;
  
  const AddProjectScreen({super.key, required this.logger});

  @override
  State<AddProjectScreen> createState() => _AddProjectScreenState();
}

class _AddProjectScreenState extends State<AddProjectScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _locationController = TextEditingController();
  final _budgetController = TextEditingController();
  final _projectManagerController = TextEditingController();
  
  String? _selectedStatus;
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  final List<TeamMember> _teamMembers = [];
  final TextEditingController _teamMemberController = TextEditingController();
  final TextEditingController _categoryController = TextEditingController();
  String? _selectedRole;
  
  late final ProjectService _projectService;
  late final Logger _logger;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _logger = widget.logger;
    _projectService = ProjectService();
    _logger.i('🏗️ AddProjectScreen: Initialized');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('🎨 AddProjectScreen: Building UI');
    
    return BaseLayout(
      title: 'Add New Project',
      selectedMenuItem: 'Add Project', // No specific menu item selected
      logger: _logger,
      onMenuItemSelected: _handleMenuNavigation,
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _buildBasicInformationCard(false),
                    const SizedBox(height: 16),
                    _buildProjectDetailsCard(false),
                    const SizedBox(height: 16),
                    _buildTimelineCard(false),
                    const SizedBox(height: 16),
                    _buildTeamMembersCard(false),
                    const SizedBox(height: 32),
                    _buildSaveButton(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              _buildFooter(context, false),
            ],
          ),
        ),
      ),
    );
  }

  void _handleMenuNavigation(String menuItem) {
    switch (menuItem) {
      case 'Switch Project':
        Navigator.pushReplacementNamed(context, '/projects');
        break;
      case 'Overview':
        Navigator.pushReplacementNamed(context, '/project-summary');
        break;
      case 'Documents':
        Navigator.pushReplacementNamed(context, '/documents');
        break;
      case 'Drawings':
        Navigator.pushReplacementNamed(context, '/drawings');
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$menuItem section coming soon')),
        );
    }
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
              initialValue: _selectedStatus,
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
                _logger.d('📝 AddProjectScreen: Status changed to $_selectedStatus');
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
            DropdownButtonFormField<String>(
              initialValue: _selectedRole,
              decoration: const InputDecoration(
                labelText: 'Role *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.work),
              ),
              items: const [
                DropdownMenuItem<String>(
                  value: 'subcontractor',
                  child: Text('Subcontractor'),
                ),
                DropdownMenuItem<String>(
                  value: 'supplier',
                  child: Text('Supplier'),
                ),
                DropdownMenuItem<String>(
                  value: 'technician',
                  child: Text('Technician'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _selectedRole = value;
                });
                _logger.d('📝 AddProjectScreen: Role selected: $_selectedRole');
              },
            ),
            SizedBox(height: isMobile ? 12 : 16),
            TextFormField(
              controller: _teamMemberController,
              decoration: const InputDecoration(
                labelText: 'Team Member Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person_add),
              ),
              onFieldSubmitted: (_) => _addTeamMember(),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            TextFormField(
              controller: _categoryController,
              decoration: const InputDecoration(
                labelText: 'Category (Optional)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
            ),
            SizedBox(height: isMobile ? 12 : 16),
            ElevatedButton.icon(
              onPressed: _addTeamMember,
              icon: const Icon(Icons.add),
              label: const Text('Add'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5A),
                foregroundColor: Colors.white,
              ),
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
                        member.name.substring(0, 1).toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    label: Text('${member.name} (${member.role.capitalize()}${member.category != null ? ' - ${member.category}' : ''})'),
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

  Widget _buildSaveButton() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _saveProject,
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
                  Text('Creating Project...', style: TextStyle(fontSize: 16)),
                ],
              )
            : const Text(
                'Create Project',
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
    _logger.d('📅 AddProjectScreen: Selecting start date');
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 5)),
    );
    if (picked != null && picked != _startDate) {
      setState(() {
        _startDate = picked;
      });
      _logger.i('✅ AddProjectScreen: Start date selected: $_startDate');
    }
  }

  Future<void> _selectEndDate() async {
    _logger.d('📅 AddProjectScreen: Selecting end date');
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
      _logger.i('✅ AddProjectScreen: End date selected: $_endDate');
    }
  }

  void _addTeamMember() {
    if (_selectedRole == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a role')),
      );
      return;
    }
    if (_teamMemberController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a team member name')),
      );
      return;
    }
    final name = _teamMemberController.text.trim();
    final category = _categoryController.text.trim().isNotEmpty ? _categoryController.text.trim() : null;
    if (_teamMembers.any((m) => m.name == name)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Team member already exists'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }
    setState(() {
      _teamMembers.add(TeamMember(name: name, role: _selectedRole!, category: category));
      _teamMemberController.clear();
      _categoryController.clear();
    });
    _logger.i('👥 AddProjectScreen: Team member added. Total: ${_teamMembers.length}');
  }

  void _removeTeamMember(TeamMember member) {
    setState(() {
      _teamMembers.remove(member);
    });
    _logger.i('👥 AddProjectScreen: Team member removed: ${member.name}');
  }

  void _saveProject() async {
    _logger.i('💾 AddProjectScreen: Save project initiated');
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        _logger.d('🏗️ AddProjectScreen: Creating project model');
        
        final newProject = ProjectModel(
          id: '',
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
          teamMembers: _teamMembers,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _logger.i('📋 AddProjectScreen: Project model created - Name: ${newProject.name}');
        _logger.d('📤 AddProjectScreen: Saving to Firestore...');

        final projectId = await _projectService.addProject(newProject);
        
        _logger.i('✅ AddProjectScreen: Project saved successfully with ID: $projectId');

        if (mounted) {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          
          navigator.pop(true);
          scaffoldMessenger.showSnackBar(
            SnackBar(
              content: Text('Project "${newProject.name}" created successfully!'),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e, stackTrace) {
        _logger.e('❌ AddProjectScreen: Error saving project',
          error: e, stackTrace: stackTrace);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error creating project: ${e.toString()}'),
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
      _logger.w('⚠️ AddProjectScreen: Form validation failed');
    }
  }

  @override
  void dispose() {
    _logger.i('🧹 AddProjectScreen: Disposing controllers');
    _nameController.dispose();
    _descriptionController.dispose();
    _locationController.dispose();
    _budgetController.dispose();
    _projectManagerController.dispose();
    _teamMemberController.dispose();
    _categoryController.dispose();
    super.dispose();
  }
}

extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${substring(1)}";
  }
}