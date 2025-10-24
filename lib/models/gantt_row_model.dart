import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

enum TaskType { mainTask, subTask, task }

class GanttRowData {  
  final String id;
  String? firestoreId;
  String? taskName;
  int? duration;
  DateTime? startDate;
  DateTime? endDate;
  TaskType taskType;
  bool isUnsaved;
  String? resourceQuantity;
  
  // NEW: Project information fields
  String? projectId;
  String? projectName;
  
  String? parentId;
  int hierarchyLevel;
  int displayOrder;
  List<String> childIds;

  // New: Resource assignment field
  String? resourceId;

  // NEW: Actual dates fields
  DateTime? actualStartDate;
  DateTime? actualEndDate;

  GanttRowData({
    required this.id,
    this.firestoreId,
    this.taskName,
    this.duration,
    this.startDate,
    this.endDate,
    this.taskType = TaskType.task,
    this.isUnsaved = false,
    this.projectId,
    this.projectName,
    this.parentId,
    this.hierarchyLevel = 0,
    this.displayOrder = 0,
    List<String>? childIds,
    this.resourceId,
    this.resourceQuantity,
    this.actualStartDate,
    this.actualEndDate,
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
      isUnsaved: other.isUnsaved,
      projectId: other.projectId,
      projectName: other.projectName,
      parentId: other.parentId,
      hierarchyLevel: other.hierarchyLevel,
      displayOrder: other.displayOrder,
      childIds: List<String>.from(other.childIds),
      resourceId: other.resourceId,
      resourceQuantity: other.resourceQuantity,
      actualStartDate: other.actualStartDate,
      actualEndDate: other.actualEndDate,
    );
  }

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
      isUnsaved: false,
      projectId: data['projectId'] as String?,
      projectName: data['projectName'] as String?,
      parentId: data['parentId'] as String?,
      hierarchyLevel: data['hierarchyLevel'] as int? ?? 0,
      displayOrder: data['displayOrder'] as int? ?? 0,
      childIds: childIdsList,
      resourceId: data['resourceId'] as String?,
      resourceQuantity: data['resourceQuantity'] as String?,
      actualStartDate: (data['actualStartDate'] as Timestamp?)?.toDate(),
      actualEndDate: (data['actualEndDate'] as Timestamp?)?.toDate(),
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
      'resourceId': resourceId,
      'resourceQuantity': resourceQuantity,
      'actualStartDate': actualStartDate != null ? Timestamp.fromDate(actualStartDate!) : null,
      'actualEndDate': actualEndDate != null ? Timestamp.fromDate(actualEndDate!) : null,
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
    bool? isUnsaved,
    String? projectId,
    String? projectName,
    String? resourceId,
    String? resourceQuantity,
    DateTime? actualStartDate,
    DateTime? actualEndDate,
  }) {
    return GanttRowData(
      id: id ?? this.id,
      firestoreId: firestoreId ?? this.firestoreId,
      taskName: taskName ?? this.taskName,
      duration: duration ?? this.duration,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      taskType: taskType ?? this.taskType,
      isUnsaved: isUnsaved ?? this.isUnsaved,
      projectId: projectId ?? this.projectId,
      projectName: projectName ?? this.projectName,
      parentId: parentId,
      hierarchyLevel: hierarchyLevel,
      displayOrder: displayOrder,
      childIds: List.from(childIds),
      resourceId: resourceId ?? this.resourceId,
      resourceQuantity: resourceQuantity ?? this.resourceQuantity,
      actualStartDate: actualStartDate ?? this.actualStartDate,
      actualEndDate: actualEndDate ?? this.actualEndDate,
    );
  }

  @override
  String toString() {
    return 'GanttRowData(id: $id, firestoreId: $firestoreId, taskName: $taskName, duration: $duration, startDate: $startDate, endDate: $endDate, taskType: $taskType, isUnsaved: $isUnsaved, projectId: $projectId, projectName: $projectName, resourceId: $resourceId, actualStartDate: $actualStartDate, actualEndDate: $actualEndDate)';
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
        other.taskType == taskType &&
        other.isUnsaved == isUnsaved &&
        other.projectId == projectId &&
        other.projectName == projectName &&
        other.resourceId == resourceId &&
        other.actualStartDate == actualStartDate &&
        other.actualEndDate == actualEndDate;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        firestoreId.hashCode ^
        taskName.hashCode ^
        duration.hashCode ^
        startDate.hashCode ^
        endDate.hashCode ^
        taskType.hashCode ^
        isUnsaved.hashCode ^
        projectId.hashCode ^
        projectName.hashCode ^
        resourceId.hashCode ^
        actualStartDate.hashCode ^
        actualEndDate.hashCode;
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

  bool get hasData =>
      taskName?.isNotEmpty == true && startDate != null && endDate != null;

  // NEW: Helper getter for formatted actual dates display
  String get actualDatesDisplayText {
    if (actualStartDate == null && actualEndDate == null) {
      return '';
    } else if (actualStartDate != null && actualEndDate != null) {
      return '${DateFormat('MM/dd/yy').format(actualStartDate!)} - ${DateFormat('MM/dd/yy').format(actualEndDate!)}';
    } else if (actualStartDate != null) {
      return '${DateFormat('MM/dd/yy').format(actualStartDate!)} - ...';
    } else {
      return '... - ${DateFormat('MM/dd/yy').format(actualEndDate!)}';
    }
  }
  
  // NEW: Check if row can have actual dates (only regular tasks)
  bool get canHaveActualDates => taskType == TaskType.task;
}