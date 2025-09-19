import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskType { mainTask, subTask, task }

class GanttRowData {  
  final String id;
  String? firestoreId;
  String? taskName;
  int? duration;
  DateTime? startDate;
  DateTime? endDate;
  TaskType taskType;
  
  String? parentId;
  int hierarchyLevel;
  int displayOrder;
  List<String> childIds;

  GanttRowData({
    required this.id,
    this.firestoreId,
    this.taskName,
    this.duration,
    this.startDate,
    this.endDate,
    this.taskType = TaskType.task,
    this.parentId,
    this.hierarchyLevel = 0,
    this.displayOrder = 0,
    List<String>? childIds,
  }) : childIds = childIds ?? <String>[];

  factory GanttRowData.from(GanttRowData other) {
    return GanttRowData(
      id: other.id,
      firestoreId: other.firestoreId,
      taskName: other.taskName,
      duration: other.duration,
      startDate: other.startDate,
      endDate: other.endDate,
      taskType: other.taskType,
      parentId: other.parentId,
      hierarchyLevel: other.hierarchyLevel,
      displayOrder: other.displayOrder,
      childIds: List<String>.from(other.childIds), // Create new mutable list
    );
  }

  bool get hasData =>
      taskName?.isNotEmpty == true && startDate != null && endDate != null;

  factory GanttRowData.fromFirebaseMap(String firestoreId, Map<String, dynamic> data) {
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

    // Ensure childIds is a mutable list
    List<String> childIdsList = <String>[];
    if (data['childIds'] != null) {
      childIdsList = List<String>.from(data['childIds']);
    }

    return GanttRowData(
      id: data['id'] as String? ?? firestoreId,
      firestoreId: firestoreId,
      taskName: data['taskName'] as String?,
      duration: data['duration'] as int?,
      startDate: (data['startDate'] as Timestamp?)?.toDate(),
      endDate: (data['endDate'] as Timestamp?)?.toDate(),
      taskType: taskType,
      parentId: data['parentId'] as String?,
      hierarchyLevel: data['hierarchyLevel'] as int? ?? 0,
      displayOrder: data['displayOrder'] as int? ?? 0,
      childIds: childIdsList, // Use the mutable list
    );
  }

  Map<String, dynamic> toFirebaseMap(
    String projectId,
    String projectName,
    int rowOrder,
  ) {
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
      'taskType': taskTypeString,
      'parentId': parentId,
      'hierarchyLevel': hierarchyLevel,
      'displayOrder': displayOrder,
      'childIds': childIds,
    };
  }

  GanttRowData copyWith({
    String? id,
    String? firestoreId,
    String? taskName,
    int? duration,
    DateTime? startDate,
    DateTime? endDate,
    TaskType? taskType,
  }) {
    return GanttRowData(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      taskName: taskName ?? this.taskName,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      taskType: taskType ?? this.taskType,
      parentId: parentId,
      hierarchyLevel: hierarchyLevel,
      displayOrder: displayOrder,
      childIds: List.from(childIds),
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
        other.taskType == taskType;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        firestoreId.hashCode ^
        taskName.hashCode ^
        duration.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        taskType.hashCode;
  }

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

  bool get isMainTask => taskType == TaskType.mainTask;

  bool get isSubTask => taskType == TaskType.subTask;

  bool get isRegularTask => taskType == TaskType.task;
}
