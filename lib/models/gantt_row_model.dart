import 'package:cloud_firestore/cloud_firestore.dart';

// Add the TaskType enum
enum TaskType { mainTask, subTask, task }

/// Data model for gantt rows with Firebase integration
class GanttRowData {
  final String id;
  String? firestoreId; // Firebase document ID
  String? taskName;
  int? duration;
  DateTime? startDate;
  DateTime? endDate;
  TaskType taskType; // Add the new field

  GanttRowData({
    required this.id,
    this.firestoreId,
    this.taskName,
    this.duration,
    this.startDate,
    this.endDate,
    this.taskType = TaskType.task, // Default to regular task
  });

  // Factory constructor to create a copy of an existing GanttRowData instance
  factory GanttRowData.from(GanttRowData other) {
    return GanttRowData(
      id: other.id,
      firestoreId: other.firestoreId,
      taskName: other.taskName,
      duration: other.duration,
      startDate: other.startDate,
      endDate: other.endDate,
      taskType: other.taskType, // Include taskType in copy
    );
  }

  /// Returns true if the row has meaningful data
  bool get hasData => taskName?.isNotEmpty == true && startDate != null && endDate != null;

  /// Create GanttRowData from Firebase document
  factory GanttRowData.fromFirebaseMap(String firestoreId, Map<String, dynamic> data) {
    // Parse taskType from Firebase data
    TaskType taskType = TaskType.task;
    if (data['taskType'] != null) {
      switch (data['taskType']) {
        case 'MainTask':
          taskType = TaskType.mainTask;
          break;
        case 'Subtask':
          taskType = TaskType.subTask;
          break;
        case 'Task':
        default:
          taskType = TaskType.task;
          break;
      }
    }

    return GanttRowData(
      id: data['id'] as String? ?? firestoreId,
      firestoreId: firestoreId,
      taskName: data['taskName'] as String?,
      duration: data['duration'] as int?,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      taskType: taskType,
    );
  }

  /// Convert GanttRowData to Firebase map for storage
  Map<String, dynamic> toFirebaseMap(String projectId, String projectName, int rowOrder) {
    // Convert TaskType enum to string for Firebase storage
    String taskTypeString = 'Task';
    switch (taskType) {
      case TaskType.mainTask:
        taskTypeString = 'MainTask';
        break;
      case TaskType.subTask:
        taskTypeString = 'Subtask';
        break;
      case TaskType.task:
        taskTypeString = 'Task';
        break;
    }

    return {
      'id': id,
      'projectId': projectId,
      'projectName': projectName,
      'taskName': taskName,
      'duration': duration,
      'startDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'endDate': endDate != null ? Timestamp.fromDate(endDate!) : null,
      'rowOrder': rowOrder,
      'updatedAt': Timestamp.fromDate(DateTime.now()),
      'taskType': taskTypeString, // Store as string in Firebase
    };
  }

  /// Create a copy of this GanttRowData with updated values
  GanttRowData copyWith({
    String? id,
    String? firestoreId,
    String? taskName,
    int? duration,
    DateTime? startDate,
    DateTime? endDate,
    TaskType? taskType, // Add taskType to copyWith
  }) {
    return GanttRowData(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      taskName: taskName ?? this.taskName,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      taskType: taskType ?? this.taskType,
    );
  }

  @override
  String toString() {
    return 'GanttRowData(id: $id, firestoreId: $firestoreId, taskName: $taskName, duration: $duration, startDate: $startDate, endDate: $endDate, taskType: $taskType)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GanttRowData &&
        other.id == id &&
        other.firestoreId == firestoreId &&
        other.taskName == taskName &&
        other.duration == duration &&
        other.startDate == startDate &&
        other.endDate == endDate &&
        other.taskType == taskType; // Include taskType in equality check
  }

  @override
  int get hashCode {
    return id.hashCode ^
        firestoreId.hashCode ^
        taskName.hashCode ^
        duration.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        taskType.hashCode; // Include taskType in hash
  }

  /// Helper method to get display text for task type
  String get taskTypeDisplayText {
    switch (taskType) {
      case TaskType.mainTask:
        return 'Main Task';
      case TaskType.subTask:
        return 'Subtask';
      case TaskType.task:
        return 'Task';
    }
  }

  /// Helper method to check if this is a main task
  bool get isMainTask => taskType == TaskType.mainTask;

  /// Helper method to check if this is a subtask
  bool get isSubTask => taskType == TaskType.subTask;

  /// Helper method to check if this is a regular task
  bool get isRegularTask => taskType == TaskType.task;
}