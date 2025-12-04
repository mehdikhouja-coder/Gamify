import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import 'package:hive/hive.dart';
import '../models/task.dart';
import '../models/achievement.dart';
import '../models/item.dart';
import '../models/user.dart';
import 'inventory_provider.dart';

class CompletionResult {
  final bool didComplete;
  final String? dropName;
  const CompletionResult({required this.didComplete, this.dropName});
}

final tasksProvider = StateNotifierProvider<TasksNotifier, List<Task>>((ref) {
  return TasksNotifier();
});

final userProvider = StateProvider<User?>((ref) {
  final box = Hive.box('user');
  final stored = box.get('me') as User?;
  if (stored != null) return stored;
  final user = User();
  box.put('me', user);
  return user;
});

class TasksNotifier extends StateNotifier<List<Task>> {
  TasksNotifier() : super(_load());

  static List<Task> _load() {
    final box = Hive.box<Task>('tasks');
    return box.values.toList();
  }

  Future<void> addTask(Task t) async {
    final box = Hive.box<Task>('tasks');
    // Assign an item to the task based on rarity and task difficulty (xp)
    try {
      final itemsBox = Hive.box<Item>('items');
      final items = itemsBox.values.toList();
      if (items.isNotEmpty) {
        // Base rarity weights
        const baseWeights = {
          'common': 80.0,
          'rare': 18.0,
          'epic': 2.0,
        };
        double rareMul = 1.0;
        double epicMul = 1.0;
        if (t.xp >= 75) {
          rareMul = 1.4;
          epicMul = 2.0;
        } else if (t.xp >= 40) {
          rareMul = 1.2;
          epicMul = 1.5;
        }
        final excludeCommons = t.xp >= 50;
        final weighted = <Item, double>{};
        for (final it in items) {
          final rarity = it.rarity.toLowerCase();
          if (excludeCommons && rarity == 'common') continue;
          final base = baseWeights[rarity] ?? 50.0;
          double w = base;
          if (rarity == 'rare') w *= rareMul;
          if (rarity == 'epic') w *= epicMul;
          weighted[it] = w;
        }
        if (weighted.isEmpty) {
          // fallback: allow commons if exclusion removed all
          for (final it in items) {
            final base = baseWeights[it.rarity.toLowerCase()] ?? 50.0;
            weighted[it] = base;
          }
        }
        final total = weighted.values.fold<double>(0, (a, b) => a + b);
        if (total > 0) {
          final rng = Random();
          double pick = rng.nextDouble() * total;
          Item? selected;
          for (final entry in weighted.entries) {
            if (pick < entry.value) {
              selected = entry.key;
              break;
            }
            pick -= entry.value;
          }
          selected ??= weighted.keys.first;
          t.assignedItemId = selected.id;
        }
      }
    } catch (_) {
      // ignore assignment failures; proceed to store task
    }
    await box.put(t.id, t);
    state = _load();
  }

  Future<void> updateTask(Task t) async {
    final box = Hive.box<Task>('tasks');
    await box.put(t.id, t);
    state = _load();
  }

  Future<void> deleteTask(String id) async {
    final box = Hive.box<Task>('tasks');
    await box.delete(id);
    state = _load();
  }

  Future<void> clearAllTasks() async {
    final box = Hive.box<Task>('tasks');
    await box.clear();
    state = _load();
  }

  Future<String?> _unlockAchievementInternal(String id, String title, String description) async {
    final aBox = Hive.box<Achievement>('achievements');
    if (aBox.values.where((a) => a.id == id).isEmpty) {
      final ach = Achievement(id: id, title: title, description: description, unlocked: true, unlockedAt: DateTime.now());
      await aBox.put(ach.id, ach);
      return ach.id;
    }
    return null;
  }

  Future<void> _checkAchievements(WidgetRef ref) async {
    final user = ref.read(userProvider);
    if (user == null) return;

    final completedTasks = state.where((t) => t.completed).length;
    final habits = state.where((t) => t.isHabit).toList();
    final maxStreak = habits.isEmpty ? 0 : habits.map((h) => h.streak).reduce((a, b) => a > b ? a : b);

    String? lastUnlockedId;

    // Helper to record the last unlocked id
    Future<void> track(String id, String title, String description) async {
      final unlockedId = await _unlockAchievementInternal(id, title, description);
      if (unlockedId != null) {
        lastUnlockedId = unlockedId;
      }
    }

    // Level-based achievements
    if (user.level >= 5) await track('level_5', 'Level 5 Reached', 'Reach level 5');
    if (user.level >= 10) await track('level_10', 'Level 10 Reached', 'Reach level 10');
    if (user.level >= 25) await track('level_25', 'Quarter Century', 'Reach level 25');
    if (user.level >= 50) await track('level_50', 'Half Century Hero', 'Reach level 50');

    // Task completion achievements
    if (completedTasks >= 10) await track('tasks_10', 'Getting Started', 'Complete 10 tasks');
    if (completedTasks >= 50) await track('tasks_50', 'Task Master', 'Complete 50 tasks');
    if (completedTasks >= 100) await track('tasks_100', 'Centurion', 'Complete 100 tasks');
    if (completedTasks >= 250) await track('tasks_250', 'Unstoppable', 'Complete 250 tasks');

    // Streak achievements
    if (maxStreak >= 14) await track('streak_14', 'Two Week Warrior', 'Maintain a 14-day streak');
    if (maxStreak >= 30) await track('streak_30', 'Monthly Master', 'Maintain a 30-day streak');
    if (maxStreak >= 100) await track('streak_100', 'Streak Legend', 'Maintain a 100-day streak');

    // Habit-specific achievements
    if (habits.length >= 5) await track('habits_5', 'Habit Builder', 'Create 5 habits');
    if (habits.length >= 10) await track('habits_10', 'Habit Expert', 'Create 10 habits');

    // Popup removed: no publishing of newly unlocked achievements
  }

  /// Completes the task and returns whether it completed now, plus any drop name.
  Future<CompletionResult> completeTask(WidgetRef ref, String id) async {
    final box = Hive.box<Task>('tasks');
    final task = box.get(id);
    if (task == null) return const CompletionResult(didComplete: false);

    // Check if deadline has passed
    if (task.deadline != null && DateTime.now().isAfter(task.deadline!)) {
      return const CompletionResult(didComplete: false);
    }

    // If this task is already marked completed, don't award XP again.
    if (task.completed) return const CompletionResult(didComplete: false);

    final now = DateTime.now();
    int totalXpAwarded = task.xp;
    // Deadline bonus: tasks with a deadline award 1.5x XP
    if (task.deadline != null) {
      totalXpAwarded = (task.xp * 1.5).round();
    }

    if (task.isHabit) {
      // Habit logic: update streak based on lastCompletedAt
      if (task.lastCompletedAt != null) {
        final daysDiff = now.difference(task.lastCompletedAt!).inDays;
        if (daysDiff == 0) {
          // already completed today — ignore
          return const CompletionResult(didComplete: false);
        } else if (daysDiff == 1) {
          task.streak = (task.streak) + 1;
        } else {
          task.streak = 1;
        }
      } else {
        task.streak = 1;
      }

      task.lastCompletedAt = now;

      // bonuses: +5 every time the streak reaches a multiple of 3, +20 at 7
      if (task.streak % 3 == 0) {
        totalXpAwarded += 5;
      }
      if (task.streak == 7) {
        totalXpAwarded += 20;
        final unlockedId = await _unlockAchievementInternal(
          'perfect_7_day',
          'Perfect 7-Day Habit',
          'Complete a habit 7 days in a row',
        );
        // Popup removed: no publishing to UI
      }

      // mark completed (per-day)
      task.completed = true;
      await task.save();
    } else {
      // Non-habit task: simple complete
      task.completed = true;
      await task.save();

      // simple achievement: first task
      final unlockedId = await _unlockAchievementInternal(
        'first_task',
        'First Task Completed',
        'Complete your first task',
      );
      // Popup removed: no publishing to UI
    }

    // Award XP to user and update provider with a fresh instance
    final ubox = Hive.box('user');
    User stored = ubox.get('me') as User? ?? User();
    final oldLevel = stored.level;
    // mutate stored to compute new values
    stored.addXp(totalXpAwarded);
    // create a fresh copy so Riverpod sees a new identity and notifies listeners
    final updatedUser = User(level: stored.level, xp: stored.xp, xpHistory: Map<String, int>.from(stored.xpHistory));
    await ubox.put('me', updatedUser);
    ref.read(userProvider.notifier).state = updatedUser;

    // Check if leveled up
    if (updatedUser.level > oldLevel) {
      await _unlockAchievementInternal('first_level', 'Level Up!', 'Reach level 2');
    }

    state = _load();
    
    // Check all achievements after state update
    await _checkAchievements(ref);

    // If task has an assigned item, add it to inventory deterministically.
    try {
      final assignedId = task.assignedItemId;
      if (assignedId != null && assignedId.isNotEmpty) {
        await ref.read(inventoryProvider.notifier).addItem(assignedId, count: 1);
      }
    } catch (_) {
      // ignore inventory write errors here
    }

    // Random item drop (25% chance by default)
    try {
      final dropName = await ref.read(inventoryProvider.notifier).maybeDropForTask(task);
      return CompletionResult(didComplete: true, dropName: dropName);
    } catch (_) {
      return const CompletionResult(didComplete: true);
    }
  }
}
