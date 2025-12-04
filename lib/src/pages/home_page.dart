import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../models/user.dart';
import '../widgets/xp_bar.dart';
import '../widgets/task_card.dart';
import '../providers/task_provider.dart';
import 'task_editor_page.dart';
import '../widgets/user_avatar_display.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final allTasks = ref.watch(tasksProvider);
    final tasks = allTasks.toList();
    final habitTasks = allTasks.where((t) => t.isHabit).toList();
    int longestStreak = 0;
    int activeHabits = 0;
    for (final h in habitTasks) {
      if (h.streak > longestStreak) longestStreak = h.streak;
      if (h.streak > 0) activeHabits += 1;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gamify Your Life'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Center(
                child: UserAvatarDisplay(size: 120, borderWidth: 4),
              ),
              const SizedBox(height: 16),
              Center(
                child: ValueListenableBuilder(
                  valueListenable: Hive.box('user').listenable(keys: ['me']),
                  builder: (context, box, _) {
                    final user = box.get('me') as User?;
                    return Text(
                      'Hello there, ${user?.username ?? "User"}!',
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
              const XPBar(),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Active Habits: $activeHabits', style: Theme.of(context).textTheme.titleMedium),
                      Text('Longest Streak: $longestStreak days', style: Theme.of(context).textTheme.bodySmall),
                    ],
                  ),
                  FilledButton.icon(
                    onPressed: () => _openAddTask(context),
                    icon: const Icon(Icons.add),
                    label: const Text('Add Task'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Text('Today', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              if (tasks.isEmpty) const Text('No tasks yet — add your first one!'),
              for (final t in tasks) TaskCard(task: t),
            ],
          ),
        ),
      ),
      // Removed FAB per request; use header actions instead.
    );
  }

  void _openAddTask(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TaskEditorPage()));
  }
}
