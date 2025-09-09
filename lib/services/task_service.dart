import 'dart:convert';
import 'package:almaworks/models/task.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TaskService {
  static const String _tasksKey = 'tasks';

  List<Task> getTasks() {
    // Return mock tasks for now, will be replaced with cached data
    return [
      Task(
        id: '1',
        title: 'Submit RFI Response',
        description: 'Foundation clarification response needed',
        deadline: 'Due Tomorrow',
        priority: 'High',
        assignedTo: 'John Smith',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Task(
        id: '2',
        title: 'Review Change Order #23',
        description: 'Additional electrical work approval',
        deadline: 'Due in 2 days',
        priority: 'Medium',
        assignedTo: 'Sarah Johnson',
        createdAt: DateTime.now().subtract(const Duration(hours: 6)),
      ),
      Task(
        id: '3',
        title: 'Safety Inspection Report',
        description: 'Weekly safety compliance check',
        deadline: 'Due in 3 days',
        priority: 'Medium',
        assignedTo: 'Mike Davis',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Task(
        id: '4',
        title: 'Monthly Progress Report',
        description: 'Compile monthly project progress',
        deadline: 'Due in 1 week',
        priority: 'Low',
        assignedTo: 'Lisa Brown',
        createdAt: DateTime.now(),
      ),
    ];
  }

  Future<void> addTask(Task task) async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = getTasks();
    tasks.add(task);
    
    final tasksJson = tasks.map((task) => task.toJson()).toList();
    await prefs.setString(_tasksKey, json.encode(tasksJson));
  }

  Future<List<Task>> getCachedTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final tasksString = prefs.getString(_tasksKey);
    
    if (tasksString != null) {
      final tasksJson = json.decode(tasksString) as List;
      return tasksJson.map((json) => Task.fromJson(json)).toList();
    }
    
    return getTasks(); 
  }
}
