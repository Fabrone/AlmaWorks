class Project {
  final String id;
  final String name;
  final String location;
  final double budget;
  final int progress;
  final String status;
  final String startDate;
  final String endDate;

  Project({
    required this.id,
    required this.name,
    required this.location,
    required this.budget,
    required this.progress,
    required this.status,
    required this.startDate,
    required this.endDate,
  });

  static List<Project> getMockProjects() {
    return [
      Project(
        id: '1',
        name: 'Downtown Office Complex',
        location: 'New York, NY',
        budget: 2.4,
        progress: 65,
        status: 'Active',
        startDate: '2024-01-15',
        endDate: '2024-08-30',
      ),
      Project(
        id: '2',
        name: 'Residential Tower',
        location: 'Chicago, IL',
        budget: 1.8,
        progress: 30,
        status: 'Active',
        startDate: '2024-02-01',
        endDate: '2024-12-15',
      ),
      Project(
        id: '3',
        name: 'Shopping Mall Renovation',
        location: 'Miami, FL',
        budget: 3.2,
        progress: 85,
        status: 'Active',
        startDate: '2023-10-01',
        endDate: '2024-04-30',
      ),
      Project(
        id: '4',
        name: 'Hospital Extension',
        location: 'Los Angeles, CA',
        budget: 4.5,
        progress: 15,
        status: 'Planning',
        startDate: '2024-03-01',
        endDate: '2025-02-28',
      ),
      Project(
        id: '5',
        name: 'School Building',
        location: 'Houston, TX',
        budget: 1.2,
        progress: 100,
        status: 'Completed',
        startDate: '2023-06-01',
        endDate: '2024-01-31',
      ),
    ];
  }
}
