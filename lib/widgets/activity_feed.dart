import 'package:flutter/material.dart';
import '../models/activity_item.dart';

class ActivityFeed extends StatelessWidget {
  const ActivityFeed({super.key});

  @override
  Widget build(BuildContext context) {
    final activities = ActivityItem.getMockActivities();
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Card(
      elevation: 2,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.all(isMobile ? 12 : 16),
        constraints: const BoxConstraints(maxHeight: 400),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.timeline, color: Theme.of(context).primaryColor, size: isMobile ? 20 : 24),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Recent Activity',
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
              child: ListView.separated(
                shrinkWrap: true,
                physics: const ClampingScrollPhysics(),
                itemCount: activities.length > 4 ? 4 : activities.length,
                separatorBuilder: (context, index) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final activity = activities[index];
                  return Container(
                    padding: EdgeInsets.symmetric(vertical: isMobile ? 8 : 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: isMobile ? 28 : 32,
                          height: isMobile ? 28 : 32,
                          decoration: BoxDecoration(
                            color: activity.color.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(isMobile ? 14 : 16),
                          ),
                          child: Icon(
                            activity.icon,
                            color: activity.color,
                            size: isMobile ? 14 : 16,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activity.title,
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: isMobile ? 12 : 14,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                activity.description,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isMobile ? 10 : 12,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                activity.timestamp,
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: isMobile ? 10 : 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: TextButton(
                onPressed: () {},
                child: const Text('View All Activities'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}