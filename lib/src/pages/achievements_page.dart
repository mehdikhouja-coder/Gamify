import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import '../models/achievement.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({super.key});

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  // Define all possible achievements
  final List<Map<String, String>> _allAchievements = [
    {'id': 'first_task', 'title': 'First Task Completed', 'description': 'Complete your first task', 'icon': '🎯'},
    {'id': 'first_level', 'title': 'Level Up!', 'description': 'Reach level 2', 'icon': '⬆️'},
    {'id': 'level_5', 'title': 'Level 5 Reached', 'description': 'Reach level 5', 'icon': '⭐'},
    {'id': 'level_10', 'title': 'Level 10 Reached', 'description': 'Reach level 10', 'icon': '🌟'},
    {'id': 'level_25', 'title': 'Quarter Century', 'description': 'Reach level 25', 'icon': '💫'},
    {'id': 'level_50', 'title': 'Half Century Hero', 'description': 'Reach level 50', 'icon': '🏆'},
    {'id': 'perfect_7_day', 'title': 'Perfect 7-Day Habit', 'description': 'Complete a habit 7 days in a row', 'icon': '🔥'},
    {'id': 'streak_14', 'title': 'Two Week Warrior', 'description': 'Maintain a 14-day streak', 'icon': '💪'},
    {'id': 'streak_30', 'title': 'Monthly Master', 'description': 'Maintain a 30-day streak', 'icon': '👑'},
    {'id': 'streak_100', 'title': 'Streak Legend', 'description': 'Maintain a 100-day streak', 'icon': '🏅'},
    {'id': 'tasks_10', 'title': 'Getting Started', 'description': 'Complete 10 tasks', 'icon': '📝'},
    {'id': 'tasks_50', 'title': 'Task Master', 'description': 'Complete 50 tasks', 'icon': '📚'},
    {'id': 'tasks_100', 'title': 'Centurion', 'description': 'Complete 100 tasks', 'icon': '💯'},
    {'id': 'tasks_250', 'title': 'Unstoppable', 'description': 'Complete 250 tasks', 'icon': '🚀'},
    {'id': 'habits_5', 'title': 'Habit Builder', 'description': 'Create 5 habits', 'icon': '🔨'},
    {'id': 'habits_10', 'title': 'Habit Expert', 'description': 'Create 10 habits', 'icon': '🎓'},
  ];

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<Achievement>('achievements');
    final unlockedIds = box.values.map((a) => a.id).toSet();
    
    final unlockedAchievements = _allAchievements.where((a) => unlockedIds.contains(a['id'])).toList();
    final lockedAchievements = _allAchievements.where((a) => !unlockedIds.contains(a['id'])).toList();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Achievements'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Icon(Icons.emoji_events, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Text(
                  '${unlockedAchievements.length} / ${_allAchievements.length} Unlocked',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (unlockedAchievements.isNotEmpty) ...[
              Text('Unlocked', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildGrid(unlockedAchievements, box, true),
              const SizedBox(height: 24),
            ],
            if (lockedAchievements.isNotEmpty) ...[
              Text('Locked', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.outline)),
              const SizedBox(height: 12),
              _buildGrid(lockedAchievements, box, false),
            ],
            if (unlockedAchievements.isEmpty && lockedAchievements.isEmpty)
              const Center(child: Padding(padding: EdgeInsets.all(48.0), child: Text('Complete tasks to unlock achievements!'))),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Map<String, String>> achievements, Box<Achievement> box, bool unlocked) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 800 ? 4 : (constraints.maxWidth > 480 ? 3 : 2);
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          itemCount: achievements.length,
          itemBuilder: (context, index) {
            final achData = achievements[index];
            final achModel = unlocked ? box.get(achData['id']) : null;
            return _buildCard(achData, achModel, unlocked);
          },
        );
      },
    );
  }

  Widget _buildCard(Map<String, String> data, Achievement? achievement, bool unlocked) {
    final theme = Theme.of(context);
    return Card(
      elevation: unlocked ? 4 : 1,
      color: unlocked ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: unlocked ? () => _showDetails(data, achievement) : null,
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: unlocked ? theme.colorScheme.primary.withValues(alpha: 0.15) : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
                ),
                child: Center(
                  child: unlocked
                      ? Text(data['icon'] ?? '🏆', style: const TextStyle(fontSize: 32))
                      : Icon(Icons.lock_outline, size: 32, color: theme.colorScheme.outlineVariant),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data['title'] ?? '',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: unlocked ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 6),
              Text(
                data['description'] ?? '',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: unlocked ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.7) : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (unlocked && achievement?.unlockedAt != null) ...[
                const SizedBox(height: 8),
                Text(
                  _formatDate(achievement!.unlockedAt!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: 10,
                    color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.55),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(Map<String, String> data, Achievement? achievement) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Text(data['icon'] ?? '🏆', style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 12),
            Expanded(child: Text(data['title'] ?? '')),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(data['description'] ?? ''),
            if (achievement?.unlockedAt != null) ...[
              const SizedBox(height: 16),
              Text('Unlocked: ${_formatDate(achievement!.unlockedAt!)}', style: const TextStyle(fontStyle: FontStyle.italic)),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Close')),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
