import 'package:almaworks/models/project_model.dart';
import 'package:flutter/foundation.dart';

class SelectedProjectProvider extends ChangeNotifier {
  ProjectModel? _selectedProject;

  ProjectModel? get selectedProject => _selectedProject;

  void selectProject(ProjectModel project) {
    _selectedProject = project;
    notifyListeners();
  }

  void clearSelection() {
    _selectedProject = null;
    notifyListeners();
  }

  bool get hasSelectedProject => _selectedProject != null;
}
