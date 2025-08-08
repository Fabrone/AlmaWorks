import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:logger/logger.dart';
import '../../models/project_model.dart';
import '../../services/project_service.dart';

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
    _logger.i('🏗️ AddProjectScreen: Initialized');
  }

  @override
  Widget build(BuildContext context) {
    _logger.d('🎨 AddProjectScreen: Building UI');
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Project'),
        actions: [
          TextButton(
            onPressed: _isLoading ? null : _saveProject,
            child: _isLoading
                ? const SizedBox(
                   width: 20,
                   height: 20,
                   child: CircularProgressIndicator(
                     strokeWidth: 2,
                     valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                   ),
                 )
               : const Text('SAVE', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Basic Information',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Project Name *',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a project name';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _descriptionController,
                      decoration: const InputDecoration(
                        labelText: 'Description *',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 3,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter a project description';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _locationController,
                      decoration: const InputDecoration(
                        labelText: 'Location *',
                        border: OutlineInputBorder(),
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
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Project Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _budgetController,
                      decoration: const InputDecoration(
                        labelText: 'Budget (USD)',
                        border: OutlineInputBorder(),
                        prefixText: '\$ ',
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
                      ],
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      value: _selectedStatus,
                      decoration: const InputDecoration(
                        labelText: 'Status (Optional)',
                        border: OutlineInputBorder(),
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
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _projectManagerController,
                      decoration: const InputDecoration(
                        labelText: 'Project Manager *',
                        border: OutlineInputBorder(),
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
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Timeline',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('Start Date'),
                      subtitle: Text(_formatDate(_startDate)),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectStartDate(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ListTile(
                      title: const Text('End Date (Optional)'),
                      subtitle: Text(_endDate != null ? _formatDate(_endDate!) : 'Not set'),
                      trailing: const Icon(Icons.calendar_today),
                      onTap: () => _selectEndDate(),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Team Members',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _teamMemberController,
                            decoration: const InputDecoration(
                              labelText: 'Add Team Member',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _addTeamMember,
                          child: const Text('Add'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_teamMembers.isNotEmpty) ...[
                      const Text('Team Members:'),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _teamMembers.map((member) {
                          return Chip(
                            label: Text(member),
                            onDeleted: () => _removeTeamMember(member),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
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
    if (_teamMemberController.text.isNotEmpty) {
      setState(() {
        _teamMembers.add(_teamMemberController.text.trim());
        _teamMemberController.clear();
      });
      _logger.i('👥 AddProjectScreen: Team member added. Total: ${_teamMembers.length}');
    }
  }

  void _removeTeamMember(String member) {
    setState(() {
      _teamMembers.remove(member);
    });
    _logger.i('👥 AddProjectScreen: Team member removed: $member');
  }

  void _saveProject() async {
    _logger.i('💾 AddProjectScreen: Save project initiated');
    
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        _logger.d('🏗️ AddProjectScreen: Creating project model');
        
        // Add project manager to team members if not already included
        List<String> allTeamMembers = List.from(_teamMembers);
        if (!allTeamMembers.contains(_projectManagerController.text.trim())) {
          allTeamMembers.insert(0, _projectManagerController.text.trim());
        }

        // Create project model
        final newProject = ProjectModel(
          id: '', // Will be set by Firestore
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
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        _logger.i('📋 AddProjectScreen: Project model created - Name: ${newProject.name}');
        _logger.d('📤 AddProjectScreen: Saving to Firestore...');

        // Save to Firestore
        final projectId = await _projectService.addProject(newProject);
        
        _logger.i('✅ AddProjectScreen: Project saved successfully with ID: $projectId');

        if (mounted) {
          Navigator.pop(context, true);
          ScaffoldMessenger.of(context).showSnackBar(
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
    super.dispose();
  }
}
