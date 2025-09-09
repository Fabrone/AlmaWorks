class DashboardData {
  final int activeProjects;
  final double totalBudget;
  final int onSchedulePercentage;
  final double safetyScore;

  DashboardData({
    required this.activeProjects,
    required this.totalBudget,
    required this.onSchedulePercentage,
    required this.safetyScore,
  });

  static DashboardData getMockData() {
    return DashboardData(
      activeProjects: 12,
      totalBudget: 2.4,
      onSchedulePercentage: 85,
      safetyScore: 9.2,
    );
  }
}