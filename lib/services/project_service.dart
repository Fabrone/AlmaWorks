import 'package:almaworks/models/project_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:logger/logger.dart';
import 'dart:async';

class ProjectService {
  static ProjectService? _instance;
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 2,
      errorMethodCount: 5,
      lineLength: 120,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
  );
  
  late final FirebaseFirestore _firestore;
  final String _collection = 'Projects';
  bool _isInitialized = false;
  
  // Stream controllers for better stream management
  final Map<String, StreamController<List<ProjectModel>>> _streamControllers = {};
  final Map<String, StreamSubscription> _subscriptions = {};

  ProjectService._internal() {
    _logger.i('🏗️ ProjectService: Creating singleton instance');
    _initializeFirestore();
  }

  factory ProjectService() {
    _instance ??= ProjectService._internal();
    return _instance!;
  }

  Future<void> _initializeFirestore() async {
    try {
      _logger.i('🔥 ProjectService: Initializing Firestore connection');
      
      // Ensure Firebase is initialized
      await Firebase.initializeApp();
      _firestore = FirebaseFirestore.instance;
      _isInitialized = true;
      
      _logger.i('✅ ProjectService: Firestore initialized successfully');
      
      // Test connection
      await _testConnection();
      
    } catch (e, stackTrace) {
      _logger.e('❌ ProjectService: Failed to initialize Firestore',
        error: e, stackTrace: stackTrace);
      _isInitialized = false;
    }
  }

  Future<void> _testConnection() async {
    try {
      _logger.d('🧪 ProjectService: Testing Firestore connection');
      await _firestore.collection(_collection).limit(1).get();
      _logger.i('✅ ProjectService: Firestore connection test successful');
    } catch (e) {
      _logger.w('⚠️ ProjectService: Firestore connection test failed: $e');
    }
  }

  Future<void> _ensureInitialized() async {
    if (!_isInitialized) {
      _logger.w('⚠️ ProjectService: Not initialized, attempting to initialize');
      await _initializeFirestore();
    }
    
    if (!_isInitialized) {
      throw Exception('ProjectService: Firestore not properly initialized');
    }
  }

  // Get all projects with improved stream management
  Stream<List<ProjectModel>> getAllProjects() {
    const streamKey = 'all_projects';
    _logger.i('📡 ProjectService: Getting all projects stream');
    
    // Return existing stream if available and controller is not closed
    if (_streamControllers.containsKey(streamKey) && 
        !_streamControllers[streamKey]!.isClosed) {
      _logger.d('♻️ ProjectService: Returning existing all projects stream');
      return _streamControllers[streamKey]!.stream;
    }
    
    // Clean up any existing controller and subscription
    _cleanupStream(streamKey);
    
    // Create new stream controller
    final controller = StreamController<List<ProjectModel>>.broadcast();
    _streamControllers[streamKey] = controller;
    
    _createAllProjectsSubscription(controller);
    
    return controller.stream;
  }

  void _createAllProjectsSubscription(StreamController<List<ProjectModel>> controller) async {
    try {
      await _ensureInitialized();
      
      _logger.d('🔄 ProjectService: Creating all projects subscription');
      
      final subscription = _firestore
          .collection(_collection)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _logger.d('📥 ProjectService: Received ${snapshot.docs.length} projects from Firestore');
              
              final projects = snapshot.docs
                  .map((doc) {
                    try {
                      return ProjectModel.fromFirestore(doc);
                    } catch (e) {
                      _logger.w('⚠️ ProjectService: Error parsing project ${doc.id}: $e');
                      return null;
                    }
                  })
                  .where((project) => project != null)
                  .cast<ProjectModel>()
                  .toList();
              
              _logger.i('✅ ProjectService: Successfully parsed ${projects.length} projects');
              controller.add(projects);
            },
            onError: (error) {
              _logger.e('❌ ProjectService: Error in all projects stream: $error');
              controller.add(<ProjectModel>[]);
            },
          );
      
      _subscriptions['all_projects'] = subscription;
      
    } catch (e) {
      _logger.e('❌ ProjectService: Failed to create all projects subscription: $e');
      controller.add(<ProjectModel>[]);
    }
  }

  // Get projects by status with improved stream management
  Stream<List<ProjectModel>> getProjectsByStatus(String status) {
    final streamKey = 'projects_$status';
    _logger.i('📡 ProjectService: Getting projects by status: $status');
    
    // Return existing stream if available and controller is not closed
    if (_streamControllers.containsKey(streamKey) && 
        !_streamControllers[streamKey]!.isClosed) {
      _logger.d('♻️ ProjectService: Returning existing $status projects stream');
      return _streamControllers[streamKey]!.stream;
    }
    
    // Clean up any existing controller and subscription
    _cleanupStream(streamKey);
    
    // Create new stream controller
    final controller = StreamController<List<ProjectModel>>.broadcast();
    _streamControllers[streamKey] = controller;
    
    _createStatusProjectsSubscription(controller, status);
    
    return controller.stream;
  }

  void _createStatusProjectsSubscription(StreamController<List<ProjectModel>> controller, String status) async {
    try {
      await _ensureInitialized();
      
      _logger.d('🔄 ProjectService: Creating $status projects subscription');
      
      final subscription = _firestore
          .collection(_collection)
          .where('status', isEqualTo: status)
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _logger.d('📥 ProjectService: Received ${snapshot.docs.length} $status projects from Firestore');
              
              final projects = snapshot.docs
                  .map((doc) {
                    try {
                      return ProjectModel.fromFirestore(doc);
                    } catch (e) {
                      _logger.w('⚠️ ProjectService: Error parsing $status project ${doc.id}: $e');
                      return null;
                    }
                  })
                  .where((project) => project != null)
                  .cast<ProjectModel>()
                  .toList();
              
              _logger.i('✅ ProjectService: Successfully parsed ${projects.length} $status projects');
              controller.add(projects);
            },
            onError: (error) {
              _logger.e('❌ ProjectService: Error in $status projects stream: $error');
              controller.add(<ProjectModel>[]);
            },
          );
      
      _subscriptions['projects_$status'] = subscription;
      
    } catch (e) {
      _logger.e('❌ ProjectService: Failed to create $status projects subscription: $e');
      controller.add(<ProjectModel>[]);
    }
  }

  // Get tracked projects (active and completed)
  Stream<List<ProjectModel>> getTrackedProjects() {
    const streamKey = 'tracked_projects';
    _logger.i('📡 ProjectService: Getting tracked projects stream');
    
    // Return existing stream if available
    if (_streamControllers.containsKey(streamKey)) {
      _logger.d('♻️ ProjectService: Returning existing tracked projects stream');
      return _streamControllers[streamKey]!.stream;
    }
    
    // Create new stream controller
    final controller = StreamController<List<ProjectModel>>.broadcast();
    _streamControllers[streamKey] = controller;
    
    _createTrackedProjectsSubscription(controller);
    
    return controller.stream;
  }

  void _createTrackedProjectsSubscription(StreamController<List<ProjectModel>> controller) async {
    try {
      await _ensureInitialized();
      
      _logger.d('🔄 ProjectService: Creating tracked projects subscription');
      
      final subscription = _firestore
          .collection(_collection)
          .where('status', whereIn: ['active', 'completed'])
          .orderBy('createdAt', descending: true)
          .snapshots()
          .listen(
            (snapshot) {
              _logger.d('📥 ProjectService: Received ${snapshot.docs.length} tracked projects from Firestore');
              
              final projects = snapshot.docs
                  .map((doc) {
                    try {
                      return ProjectModel.fromFirestore(doc);
                    } catch (e) {
                      _logger.w('⚠️ ProjectService: Error parsing tracked project ${doc.id}: $e');
                      return null;
                    }
                  })
                  .where((project) => project != null)
                  .cast<ProjectModel>()
                  .toList();
              
              _logger.i('✅ ProjectService: Successfully parsed ${projects.length} tracked projects');
              controller.add(projects);
            },
            onError: (error) {
              _logger.e('❌ ProjectService: Error in tracked projects stream: $error');
              controller.add(<ProjectModel>[]);
            },
          );
      
      _subscriptions['tracked_projects'] = subscription;
      
    } catch (e) {
      _logger.e('❌ ProjectService: Failed to create tracked projects subscription: $e');
      controller.add(<ProjectModel>[]);
    }
  }

  // Add new project
  Future<String> addProject(ProjectModel project) async {
    _logger.i('➕ ProjectService: Adding project: ${project.name}');
    
    try {
      await _ensureInitialized();
      
      final projectData = project.toFirestore();
      _logger.d('📤 ProjectService: Sending project data to Firestore');
      
      final docRef = await _firestore.collection(_collection).add(projectData);
      
      _logger.i('✅ ProjectService: Project added successfully with ID: ${docRef.id}');
      return docRef.id;
      
    } catch (e, stackTrace) {
      _logger.e('❌ ProjectService: Failed to add project',
        error: e, stackTrace: stackTrace);
      throw Exception('Failed to add project: $e');
    }
  }

  // Update project
  Future<void> updateProject(ProjectModel project) async {
    _logger.i('✏️ ProjectService: Updating project: ${project.id}');
    
    try {
      await _ensureInitialized();
      
      final projectData = project.toFirestore();
      _logger.d('📤 ProjectService: Sending updated project data to Firestore');
      
      await _firestore.collection(_collection).doc(project.id).update(projectData);
      
      _logger.i('✅ ProjectService: Project updated successfully');
      
    } catch (e, stackTrace) {
      _logger.e('❌ ProjectService: Failed to update project',
        error: e, stackTrace: stackTrace);
      throw Exception('Failed to update project: $e');
    }
  }

  // Delete project
  Future<void> deleteProject(String projectId) async {
    _logger.i('🗑️ ProjectService: Deleting project: $projectId');
    
    try {
      await _ensureInitialized();
      
      await _firestore.collection(_collection).doc(projectId).delete();
      
      _logger.i('✅ ProjectService: Project deleted successfully');
      
    } catch (e, stackTrace) {
      _logger.e('❌ ProjectService: Failed to delete project',
        error: e, stackTrace: stackTrace);
      throw Exception('Failed to delete project: $e');
    }
  }

  // Get project by ID
  Future<ProjectModel?> getProjectById(String projectId) async {
    _logger.i('🔍 ProjectService: Getting project by ID: $projectId');
    
    try {
      await _ensureInitialized();
      
      final doc = await _firestore.collection(_collection).doc(projectId).get();
      
      if (doc.exists) {
        _logger.i('✅ ProjectService: Project found');
        return ProjectModel.fromFirestore(doc);
      } else {
        _logger.w('⚠️ ProjectService: Project not found');
        return null;
      }
      
    } catch (e, stackTrace) {
      _logger.e('❌ ProjectService: Failed to get project by ID',
        error: e, stackTrace: stackTrace);
      throw Exception('Failed to get project: $e');
    }
  }

  // Get total projects count (NEW METHOD)
  Future<int> getAllProjectsCount() async {
    _logger.i('🔢 ProjectService: Getting total projects count');
    
    try {
      await _ensureInitialized();
      
      final snapshot = await _firestore
          .collection(_collection)
          .get();
      
      final count = snapshot.docs.length;
      _logger.i('✅ ProjectService: Found $count total projects');
      return count;
      
    } catch (e) {
      _logger.e('❌ ProjectService: Failed to get total projects count: $e');
      return 0;
    }
  }

  // Get project count by status
  Future<int> getProjectCountByStatus(String status) async {
    _logger.i('🔢 ProjectService: Getting project count for status: $status');
    
    try {
      await _ensureInitialized();
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', isEqualTo: status)
          .get();
      
      final count = snapshot.docs.length;
      _logger.i('✅ ProjectService: Found $count projects with status $status');
      return count;
      
    } catch (e) {
      _logger.e('❌ ProjectService: Failed to get project count for status $status: $e');
      return 0;
    }
  }

  // Get total tracked projects count
  Future<int> getTrackedProjectsCount() async {
    _logger.i('🔢 ProjectService: Getting tracked projects count');
    
    try {
      await _ensureInitialized();
      
      final snapshot = await _firestore
          .collection(_collection)
          .where('status', whereIn: ['active', 'completed'])
          .get();
      
      final count = snapshot.docs.length;
      _logger.i('✅ ProjectService: Found $count tracked projects');
      return count;
      
    } catch (e) {
      _logger.e('❌ ProjectService: Failed to get tracked projects count: $e');
      return 0;
    }
  }

  // Check if Firebase is available
  Future<bool> isFirebaseAvailable() async {
    try {
      await _ensureInitialized();
      await _firestore.collection(_collection).limit(1).get();
      _logger.i('✅ ProjectService: Firebase is available');
      return true;
    } catch (e) {
      _logger.w('⚠️ ProjectService: Firebase is not available: $e');
      return false;
    }
  }

  void _cleanupStream(String streamKey) {
    // Cancel existing subscription
    if (_subscriptions.containsKey(streamKey)) {
      _subscriptions[streamKey]?.cancel();
      _subscriptions.remove(streamKey);
    }
    
    // Close existing controller
    if (_streamControllers.containsKey(streamKey)) {
      if (!_streamControllers[streamKey]!.isClosed) {
        _streamControllers[streamKey]!.close();
      }
      _streamControllers.remove(streamKey);
    }
  }

  // Dispose method to clean up resources
  void dispose() {
    _logger.i('🧹 ProjectService: Disposing resources');
    
    // Cancel all subscriptions
    for (final subscription in _subscriptions.values) {
      subscription.cancel();
    }
    _subscriptions.clear();
    
    // Close all stream controllers
    for (final controller in _streamControllers.values) {
      controller.close();
    }
    _streamControllers.clear();
    
    _logger.i('✅ ProjectService: Resources disposed successfully');
  }
  
  // Get projects count for client (filtered by grantedProjects)
  Future<int> getClientProjectsCount(List<String> grantedProjectIds) async {
    if (grantedProjectIds.isEmpty) return 0;
    
    try {
      final snapshot = await _firestore
          .collection('projects')
          .where(FieldPath.documentId, whereIn: grantedProjectIds)
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      _logger.e('Error getting client projects count: $e');
      return 0;
    }
  }

  // Get active projects count for client
  Future<int> getClientActiveProjectsCount(List<String> grantedProjectIds) async {
    if (grantedProjectIds.isEmpty) return 0;
    
    try {
      final snapshot = await _firestore
          .collection('projects')
          .where(FieldPath.documentId, whereIn: grantedProjectIds)
          .where('status', isEqualTo: 'active')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      _logger.e('Error getting client active projects count: $e');
      return 0;
    }
  }

  // Get completed projects count for client
  Future<int> getClientCompletedProjectsCount(List<String> grantedProjectIds) async {
    if (grantedProjectIds.isEmpty) return 0;
    
    try {
      final snapshot = await _firestore
          .collection('projects')
          .where(FieldPath.documentId, whereIn: grantedProjectIds)
          .where('status', isEqualTo: 'completed')
          .get();
      
      return snapshot.docs.length;
    } catch (e) {
      _logger.e('Error getting client completed projects count: $e');
      return 0;
    }
  }

  // Stream all client projects
  Stream<List<Map<String, dynamic>>> streamClientProjects(List<String> grantedProjectIds) {
    if (grantedProjectIds.isEmpty) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('projects')
        .where(FieldPath.documentId, whereIn: grantedProjectIds)
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Stream active client projects
  Stream<List<Map<String, dynamic>>> streamClientActiveProjects(List<String> grantedProjectIds) {
    if (grantedProjectIds.isEmpty) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('projects')
        .where(FieldPath.documentId, whereIn: grantedProjectIds)
        .where('status', isEqualTo: 'active')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

  // Stream completed client projects
  Stream<List<Map<String, dynamic>>> streamClientCompletedProjects(List<String> grantedProjectIds) {
    if (grantedProjectIds.isEmpty) {
      return Stream.value([]);
    }
    
    return _firestore
        .collection('projects')
        .where(FieldPath.documentId, whereIn: grantedProjectIds)
        .where('status', isEqualTo: 'completed')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) {
              final data = doc.data();
              data['id'] = doc.id;
              return data;
            }).toList());
  }

}
