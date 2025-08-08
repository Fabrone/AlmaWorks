import 'package:cloud_firestore/cloud_firestore.dart';

class ProjectModel {
  final String id;
  final String name;
  final String description;
  final String location;
  final double? budget;
  final String? status; // 'active', 'completed', or null for untracked
  final DateTime startDate;
  final DateTime? endDate;
  final String projectManager;
  final List<String> teamMembers;
  final DateTime createdAt;
  final DateTime updatedAt;

  ProjectModel({
    required this.id,
    required this.name,
    required this.description,
    required this.location,
    this.budget,
    this.status,
    required this.startDate,
    this.endDate,
    required this.projectManager,
    required this.teamMembers,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ProjectModel.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return ProjectModel(
      id: doc.id,
      name: data['name'] ?? '',
      description: data['description'] ?? '',
      location: data['location'] ?? '',
      budget: data['budget']?.toDouble(),
      status: data['status'], // Can be null
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: data['endDate'] != null ? (data['endDate'] as Timestamp).toDate() : null,
      projectManager: data['projectManager'] ?? '',
      teamMembers: List<String>.from(data['teamMembers'] ?? []),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      updatedAt: (data['updatedAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'description': description,
      'location': location,
      'budget': budget,
      'status': status,
      'startDate': Timestamp.fromDate(startDate),
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'projectManager': projectManager,
      'teamMembers': teamMembers,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ProjectModel copyWith({
    String? name,
    String? description,
    String? location,
    double? budget,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? projectManager,
    List<String>? teamMembers,
    DateTime? updatedAt,
  }) {
    return ProjectModel(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      location: location ?? this.location,
      budget: budget ?? this.budget,
      status: status ?? this.status,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      projectManager: projectManager ?? this.projectManager,
      teamMembers: teamMembers ?? this.teamMembers,
      createdAt: createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  bool get isTracked => status != null;
  bool get isActive => status == 'active';
  bool get isCompleted => status == 'completed';

  // Mock data for testing
  static List<ProjectModel> getMockProjects() {
    return [
      ProjectModel(
        id: '1',
        name: 'Downtown Office Complex',
        description: 'Modern office building with 20 floors',
        location: 'Nairobi CBD, Kenya',
        budget: 2400000,
        status: 'active',
        startDate: DateTime(2024, 1, 15),
        endDate: DateTime(2024, 8, 30),
        projectManager: 'John Smith',
        teamMembers: ['John Smith', 'Sarah Johnson', 'Mike Davis'],
        createdAt: DateTime(2024, 1, 1),
        updatedAt: DateTime.now(),
      ),
      ProjectModel(
        id: '2',
        name: 'Residential Tower',
        description: 'High-rise residential apartments',
        location: 'Westlands, Nairobi',
        budget: 1800000,
        status: 'active',
        startDate: DateTime(2024, 2, 1),
        endDate: DateTime(2024, 12, 15),
        projectManager: 'Sarah Johnson',
        teamMembers: ['Sarah Johnson', 'Mike Davis', 'Lisa Brown'],
        createdAt: DateTime(2024, 1, 15),
        updatedAt: DateTime.now(),
      ),
      ProjectModel(
        id: '3',
        name: 'Shopping Mall Renovation',
        description: 'Complete renovation of existing mall',
        location: 'Kilimani, Nairobi',
        budget: 3200000,
        status: 'completed',
        startDate: DateTime(2023, 10, 1),
        endDate: DateTime(2024, 4, 30),
        projectManager: 'Mike Davis',
        teamMembers: ['Mike Davis', 'Lisa Brown', 'Tom Wilson'],
        createdAt: DateTime(2023, 9, 15),
        updatedAt: DateTime.now(),
      ),
      ProjectModel(
        id: '4',
        name: 'Hospital Extension',
        description: 'New wing addition to existing hospital',
        location: 'Karen, Nairobi',
        budget: null,
        status: null, // Untracked project
        startDate: DateTime(2024, 3, 1),
        endDate: DateTime(2025, 2, 28),
        projectManager: 'Lisa Brown',
        teamMembers: ['Lisa Brown', 'Tom Wilson'],
        createdAt: DateTime(2024, 2, 1),
        updatedAt: DateTime.now(),
      ),
      ProjectModel(
        id: '5',
        name: 'School Building',
        description: 'New primary school construction',
        location: 'Kasarani, Nairobi',
        budget: null,
        status: null, // Untracked project
        startDate: DateTime(2024, 4, 1),
        endDate: null,
        projectManager: 'Tom Wilson',
        teamMembers: ['Tom Wilson', 'John Smith'],
        createdAt: DateTime(2024, 3, 1),
        updatedAt: DateTime.now(),
      ),
    ];
  }
}
