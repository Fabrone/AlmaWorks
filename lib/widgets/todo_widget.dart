import 'package:almaworks/models/task.dart';
import 'package:almaworks/services/task_service.dart';
import 'package:flutter/material.dart';

class TodoWidget extends StatefulWidget {
  const TodoWidget({super.key});

  @override
  State<TodoWidget> createState() => _TodoWidgetState();
}

class _TodoWidgetState extends State<TodoWidget> {
  final TaskService _taskService = TaskService();
  List<Task> _tasks = [];
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  void _loadTasks() {
    setState(() {
      _tasks = _taskService.getTasks();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;
    
    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        height: double.infinity,
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.assignment, color: Theme.of(context).primaryColor, size: isMobile ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Upcoming Deadlines',
                    style: TextStyle(
                      fontSize: isMobile ? 16 : 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _tasks.isEmpty
                  ? Center(
                      child: Text(
                        'No tasks available',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: isMobile ? 12 : 14,
                        ),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.builder(
                            itemCount: _isExpanded ? _tasks.length : (_tasks.length > 4 ? 4 : _tasks.length),
                            itemBuilder: (context, index) {
                              return _buildTodoItem(_tasks[index], isMobile);
                            },
                          ),
                        ),
                        if (_tasks.length > 4)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Center(
                              child: TextButton(
                                onPressed: () {
                                  setState(() {
                                    _isExpanded = !_isExpanded;
                                  });
                                },
                                child: Text(_isExpanded ? 'Show Less' : 'View All Tasks (${_tasks.length})'),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodoItem(Task task, bool isMobile) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(isMobile ? 8 : 12),
      decoration: BoxDecoration(
        color: task.isUrgent ? task.priorityColor.withValues(alpha: 0.1) : Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: task.isUrgent ? Border.all(color: task.priorityColor.withValues(alpha: 0.3)) : null,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            width: 4,
            height: isMobile ? 28 : 32,
            decoration: BoxDecoration(
              color: task.priorityColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  task.title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 12 : 14,
                    color: task.isUrgent ? task.priorityColor : null,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      task.isUrgent ? Icons.warning : Icons.schedule,
                      size: isMobile ? 10 : 12,
                      color: task.priorityColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      task.deadline,
                      style: TextStyle(
                        color: task.priorityColor,
                        fontSize: isMobile ? 10 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (task.isUrgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: task.priorityColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'URGENT',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: isMobile ? 8 : 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
