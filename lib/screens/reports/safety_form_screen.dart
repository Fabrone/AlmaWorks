import 'dart:io' show File;
import 'package:almaworks/models/project_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

class SafetyFormScreen extends StatefulWidget {
  final ProjectModel project;
  final Logger logger;

  const SafetyFormScreen({
    super.key,
    required this.project,
    required this.logger,
  });

  @override
  State<SafetyFormScreen> createState() => _SafetyFormScreenState();
}

class _SafetyFormScreenState extends State<SafetyFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');
  DateTime? _selectedDateTime;
  String _type = 'SafetyWeekly';
  final Map<String, bool> _items = {
    'Housekeeping': false,
    'Personal Protective Equipment': false,
    'Fall Protection': false,
    'Scaffolds': false,
    'Ladders': false,
    'Excavations': false,
    'Electrical': false,
    'Hand & Power Tools': false,
    'Fire Protection': false,
    'Hazard Communication': false,
    'Cranes & Rigging': false,
    'Heavy Equipment': false,
    'Traffic Control': false,
    'Other': false,
  };
  final TextEditingController _observationsController = TextEditingController();
  final TextEditingController _actionsController = TextEditingController();
  final List<Map<String, dynamic>> _jvAlmaAttendance = List.generate(4, (_) => {'name': '', 'title': '', 'signature': ''});
  List<TextEditingController> _jvAlmaNameControllers = [];
  List<TextEditingController> _jvAlmaTitleControllers = [];
  List<TextEditingController> _jvAlmaSignatureControllers = [];
  final List<Map<String, dynamic>> _subContractorAttendance = List.generate(4, (_) => {'companyName': '', 'name': '', 'title': '', 'signature': ''});
  List<TextEditingController> _subContractorCompanyNameControllers = [];
  List<TextEditingController> _subContractorNameControllers = [];
  List<TextEditingController> _subContractorTitleControllers = [];
  List<TextEditingController> _subContractorSignatureControllers = [];

  @override
  void initState() {
    super.initState();
    _updateControllers();
  }

  void _updateControllers() {
    _jvAlmaNameControllers = _jvAlmaAttendance.map((row) => TextEditingController(text: row['name'])).toList();
    _jvAlmaTitleControllers = _jvAlmaAttendance.map((row) => TextEditingController(text: row['title'])).toList();
    _jvAlmaSignatureControllers = _jvAlmaAttendance.map((row) => TextEditingController()).toList();
    _subContractorCompanyNameControllers = _subContractorAttendance.map((row) => TextEditingController(text: row['companyName'])).toList();
    _subContractorNameControllers = _subContractorAttendance.map((row) => TextEditingController(text: row['name'])).toList();
    _subContractorTitleControllers = _subContractorAttendance.map((row) => TextEditingController(text: row['title'])).toList();
    _subContractorSignatureControllers = _subContractorAttendance.map((row) => TextEditingController()).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Safety Report Form', style: GoogleFonts.poppins()),
        backgroundColor: const Color(0xFF0A2E5A),
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: _buildSafetyForm(constraints),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final formData = _processFormData();
          if (formData != null) {
            await _saveSafetyForm(_type, formData);
            if (context.mounted) {
              Navigator.pop(context);
            }
          }
        },
        backgroundColor: const Color(0xFF0A2E5A),
        child: const Icon(Icons.save, color: Colors.white),
      ),
    );
  }

  Widget _buildJvAlmaAttendanceTable(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('JV Alma CIS Attendance:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey[400]!, width: 1),
              verticalInside: BorderSide(color: Colors.grey[400]!, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Title', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Signature', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows
              ..._jvAlmaAttendance.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _jvAlmaNameControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _jvAlmaAttendance[index]['name'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _jvAlmaTitleControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _jvAlmaAttendance[index]['title'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildSignatureField(row, index, false, _jvAlmaSignatureControllers[index]),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        // Remove buttons for rows beyond the first 4
        ..._jvAlmaAttendance.asMap().entries.where((entry) => entry.key >= 4).map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _jvAlmaAttendance.removeAt(index);
                  _updateControllers();
                });
              },
              child: Text(
                'Remove Row ${index + 1}',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _jvAlmaAttendance.add({'name': '', 'title': '', 'signature': ''});
              _updateControllers();
            });
          },
          child: Text(
            'Add Entry',
            style: GoogleFonts.poppins(
              color: const Color(0xFF0A2E5A),
              decoration: TextDecoration.underline,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSubContractorAttendanceTable(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Sub-Contractor Attendance:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[400]!, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Table(
            border: TableBorder(
              horizontalInside: BorderSide(color: Colors.grey[400]!, width: 1),
              verticalInside: BorderSide(color: Colors.grey[400]!, width: 1),
            ),
            columnWidths: const {
              0: FlexColumnWidth(1),
              1: FlexColumnWidth(1),
              2: FlexColumnWidth(1),
              3: FlexColumnWidth(1),
            },
            children: [
              // Header row
              TableRow(
                decoration: BoxDecoration(color: Colors.grey[100]),
                children: [
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Company Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Name', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Title', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Text('Signature', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              // Data rows
              ..._subContractorAttendance.asMap().entries.map((entry) {
                final index = entry.key;
                final row = entry.value;
                return TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _subContractorCompanyNameControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _subContractorAttendance[index]['companyName'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _subContractorNameControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _subContractorAttendance[index]['name'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: TextFormField(
                        controller: _subContractorTitleControllers[index],
                        decoration: InputDecoration(
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                          isDense: true,
                        ),
                        style: GoogleFonts.poppins(fontSize: 14),
                        onChanged: (value) {
                          setState(() {
                            _subContractorAttendance[index]['title'] = value;
                          });
                        },
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: _buildSignatureField(row, index, true, _subContractorSignatureControllers[index]),
                    ),
                  ],
                );
              }),
            ],
          ),
        ),
        // Remove buttons for rows beyond the first 4
        ..._subContractorAttendance.asMap().entries.where((entry) => entry.key >= 4).map((entry) {
          final index = entry.key;
          return Padding(
            padding: const EdgeInsets.only(left: 8, top: 4),
            child: TextButton(
              onPressed: () {
                setState(() {
                  _subContractorAttendance.removeAt(index);
                  _updateControllers();
                });
              },
              child: Text(
                'Remove Row ${index + 1}',
                style: GoogleFonts.poppins(
                  color: Colors.red,
                  decoration: TextDecoration.underline,
                  fontSize: 14,
                ),
              ),
            ),
          );
        }),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () {
            setState(() {
              _subContractorAttendance.add({'companyName': '', 'name': '', 'title': '', 'signature': ''});
              _updateControllers();
            });
          },
          child: Text(
            'Add Entry',
            style: GoogleFonts.poppins(
              color: const Color(0xFF0A2E5A),
              decoration: TextDecoration.underline,
              fontSize: 14,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSafetyForm(BoxConstraints constraints) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text('Select Date and Time:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (!mounted) return;
                final date = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2020),
                  lastDate: DateTime(2030),
                );
                if (!mounted || date == null) return;
                final time = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.now(),
                );
                if (!mounted || time == null) return;
                setState(() {
                  _selectedDateTime = DateTime(
                    date.year,
                    date.month,
                    date.day,
                    time.hour,
                    time.minute,
                  );
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A2E5A),
                foregroundColor: Colors.white,
              ),
              child: Text(
                _selectedDateTime != null ? _dateFormat.format(_selectedDateTime!) : 'Select Date',
                style: GoogleFonts.poppins(),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text('Report Type:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700)),
        DropdownButton<String>(
          value: _type,
          items: ['SafetyWeekly', 'SafetyMonthly'].map((type) {
            return DropdownMenuItem(
              value: type,
              child: Text(type == 'SafetyWeekly' ? 'Weekly' : 'Monthly', style: GoogleFonts.poppins()),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() {
                _type = value;
              });
            }
          },
        ),
        const SizedBox(height: 16),
        Text('Items:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        ..._items.keys.map((item) => CheckboxListTile(
              title: Text(item, style: GoogleFonts.poppins()),
              value: _items[item],
              activeColor: const Color(0xFF228B22),
              onChanged: (value) {
                setState(() {
                  _items[item] = value!;
                });
              },
            )),
        const SizedBox(height: 16),
        Text('Observations and Comments:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        TextFormField(
          controller: _observationsController,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter observations',
            hintStyle: GoogleFonts.poppins(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter observations';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        Text('Actions Taken:', style: GoogleFonts.poppins(fontWeight: FontWeight.w700, fontSize: 16)),
        TextFormField(
          controller: _actionsController,
          maxLines: 5,
          decoration: InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'Enter actions taken',
            hintStyle: GoogleFonts.poppins(),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter actions taken';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        // Use the new table widgets
        _buildJvAlmaAttendanceTable(constraints),
        if (_type == 'SafetyWeekly') ...[
          const SizedBox(height: 16),
          _buildSubContractorAttendanceTable(constraints),
        ],
      ],
    );
  }

  Widget _buildSignatureField(Map<String, dynamic> row, int index, bool isSubContractor, TextEditingController signatureController) {
    signatureController.text = row['signature'].startsWith('http') ? '' : row['signature'];
    return TextFormField(
      controller: signatureController,
      decoration: InputDecoration(
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(4)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        isDense: true,
        suffixIcon: row['signature'].startsWith('http')
            ? Icon(Icons.image, color: Colors.green, size: 16)
            : null,
      ),
      style: GoogleFonts.poppins(fontSize: 14),
      readOnly: true,
      onTap: () async {
        final signature = await showDialog<String>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: Text('Signature Input', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    final url = await _getSignature();
                    // Check if the dialog context is still valid before using it
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, url);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Upload Image', style: GoogleFonts.poppins()),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () async {
                    final url = await _getSignature(useCamera: true);
                    // Check if the dialog context is still valid before using it
                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext, url);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0A2E5A),
                    foregroundColor: Colors.white,
                  ),
                  child: Text('Take Photo', style: GoogleFonts.poppins()),
                ),
                const SizedBox(height: 8),
                TextField(
                  decoration: InputDecoration(
                    labelText: 'Enter Signature',
                    border: OutlineInputBorder(),
                    hintStyle: GoogleFonts.poppins(),
                  ),
                  onSubmitted: (value) {
                    if (value.isNotEmpty && dialogContext.mounted) {
                      Navigator.pop(dialogContext, value);
                    }
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  if (dialogContext.mounted) {
                    Navigator.pop(dialogContext);
                  }
                },
                child: Text('Cancel', style: GoogleFonts.poppins()),
              ),
            ],
          ),
        );
        
        // Check if the widget is still mounted before updating state
        if (signature != null && mounted) {
          setState(() {
            if (isSubContractor) {
              _subContractorAttendance[index]['signature'] = signature;
            } else {
              _jvAlmaAttendance[index]['signature'] = signature;
            }
            signatureController.text = signature.startsWith('http') ? 'Image Selected' : signature;
          });
        }
      },
    );
  }

  Future<String?> _getSignature({bool useCamera = false}) async {
    final source = useCamera ? ImageSource.camera : ImageSource.gallery;
    final image = await ImagePicker().pickImage(source: source);
    if (image == null) {
      widget.logger.d('📊 SafetyFormScreen: Image picker cancelled for ${useCamera ? 'camera' : 'gallery'}');
      return null;
    }
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child(widget.project.id)
          .child('Signatures')
          .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
      final uploadTask = await storageRef.putFile(File(image.path));
      final url = await uploadTask.ref.getDownloadURL();
      widget.logger.i('✅ SafetyFormScreen: Uploaded signature from ${useCamera ? 'camera' : 'gallery'}');
      return url;
    } catch (e, stackTrace) {
      widget.logger.e('❌ SafetyFormScreen: Error uploading signature from ${useCamera ? 'camera' : 'gallery'}', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  Map<String, dynamic>? _processFormData() {
    // Validate basic form fields first
    if (!_formKey.currentState!.validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please fill all required fields', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }
    
    if (_selectedDateTime == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Please select date and time', style: GoogleFonts.poppins())),
        );
      }
      return null;
    }

    // Validate JV Alma attendance rows
    String? jvAlmaError = _validateAttendanceRows(_jvAlmaAttendance, 'JV Alma CIS');
    if (jvAlmaError != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(jvAlmaError, style: GoogleFonts.poppins())),
        );
      }
      return null;
    }

    // Validate sub-contractor attendance rows (only for weekly reports)
    if (_type == 'SafetyWeekly') {
      String? subContractorError = _validateAttendanceRows(_subContractorAttendance, 'Sub-Contractor');
      if (subContractorError != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(subContractorError, style: GoogleFonts.poppins())),
          );
        }
        return null;
      }
    }

    // Filter out completely empty rows before saving
    final filteredJvAlmaAttendance = _jvAlmaAttendance.where((row) {
      return row['name'].toString().isNotEmpty || 
            row['title'].toString().isNotEmpty || 
            row['signature'].toString().isNotEmpty;
    }).toList();

    final filteredSubContractorAttendance = _subContractorAttendance.where((row) {
      return row['companyName'].toString().isNotEmpty || 
            row['name'].toString().isNotEmpty || 
            row['title'].toString().isNotEmpty || 
            row['signature'].toString().isNotEmpty;
    }).toList();

    return {
      'items': _items,
      'observations': _observationsController.text,
      'actions': _actionsController.text,
      'jvAlmaAttendance': filteredJvAlmaAttendance,
      if (_type == 'SafetyWeekly') 'subContractorAttendance': filteredSubContractorAttendance,
    };
  }

  String? _validateAttendanceRows(List<Map<String, dynamic>> attendance, String tableName) {
    for (int i = 0; i < attendance.length; i++) {
      final row = attendance[i];
      final name = row['name']?.toString() ?? '';
      final title = row['title']?.toString() ?? '';
      final signature = row['signature']?.toString() ?? '';
      final companyName = row['companyName']?.toString() ?? '';

      // Check if row has any content
      bool hasAnyContent = name.isNotEmpty || title.isNotEmpty || signature.isNotEmpty;
      if (tableName == 'Sub-Contractor') {
        hasAnyContent = hasAnyContent || companyName.isNotEmpty;
      }

      // If row has any content, all fields must be filled
      if (hasAnyContent) {
        if (tableName == 'Sub-Contractor') {
          if (companyName.isEmpty || name.isEmpty || title.isEmpty || signature.isEmpty) {
            return '$tableName attendance row ${i + 1}: All fields must be filled if any field is filled';
          }
        } else {
          if (name.isEmpty || title.isEmpty || signature.isEmpty) {
            return '$tableName attendance row ${i + 1}: All fields must be filled if any field is filled';
          }
        }
      }
    }
    return null; // No validation errors
  }

  Future<void> _saveSafetyForm(String type, Map<String, dynamic> formData) async {
    try {
      final docRef = await FirebaseFirestore.instance.collection('Reports').add({
        'name': '$type Safety Report - ${_dateFormat.format(_selectedDateTime!)}',
        'projectId': widget.project.id,
        'projectName': widget.project.name,
        'uploadedAt': Timestamp.fromDate(_selectedDateTime!),
        'type': type,
        'safetyFormData': formData,
      });
      widget.logger.i('✅ SafetyFormScreen: Saved safety report with ID: ${docRef.id}');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Safety report saved successfully', style: GoogleFonts.poppins())),
        );
      }
    } catch (e, stackTrace) {
      widget.logger.e('❌ SafetyFormScreen: Error saving safety report', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving safety report: $e', style: GoogleFonts.poppins())),
        );
      }
    }
  }
}