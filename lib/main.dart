import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'src/app_theme.dart';
import 'src/pages/main_screen.dart';
import 'src/models/task.dart';
import 'src/models/achievement.dart';
import 'src/models/user.dart';
import 'src/models/item.dart';
import 'src/models/inventory_entry.dart';
import 'src/models/inventory_event.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // Register adapters
  Hive.registerAdapter(TaskAdapter());
  Hive.registerAdapter(AchievementAdapter());
  Hive.registerAdapter(UserAdapter());
  Hive.registerAdapter(ItemAdapter());
  Hive.registerAdapter(InventoryEntryAdapter());
  Hive.registerAdapter(InventoryEventAdapter());

  // Open boxes
  await Hive.openBox<Task>('tasks');
  await Hive.openBox<Achievement>('achievements');
  await Hive.openBox('user');
  await Hive.openBox<Item>('items');
  await Hive.openBox<InventoryEntry>('inventory');
  await Hive.openBox<InventoryEvent>('inventory_log');
  await Hive.openBox('wallet');

  // Run migration to normalize older Hive Task records
  await _migrateHiveTasksIfNeeded();

  // Seed default items if empty
  final itemsBox = Hive.box<Item>('items');
  if (itemsBox.isEmpty) {
    itemsBox.putAll({
      'potion_common': Item(id: 'potion_common', name: 'Small Potion', rarity: 'common', icon: '🧪', description: 'A small restorative potion.'),
      'gem_rare': Item(id: 'gem_rare', name: 'Shiny Gem', rarity: 'rare', icon: '💎', description: 'A rare gemstone.'),
      'ticket_epic': Item(id: 'ticket_epic', name: 'Epic Ticket', rarity: 'epic', icon: '🎟️', description: 'A mysterious epic ticket.'),
    });
  }
  // Backfill inventory_log from current totals if log is empty
  final invBox = Hive.box<InventoryEntry>('inventory');
  final logBox = Hive.box<InventoryEvent>('inventory_log');
  if (logBox.isEmpty && invBox.isNotEmpty) {
    final now = DateTime.now();
    for (final entry in invBox.values) {
      if (entry.quantity > 0) {
        await logBox.add(InventoryEvent(itemId: entry.itemId, quantity: entry.quantity, acquiredAt: now));
      }
    }
  }

  // Check and perform midnight reset if needed
  await _checkMidnightReset();

  runApp(const ProviderScope(child: GamifyApp()));
}
class GamifyApp extends StatelessWidget {
  const GamifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        ColorScheme lightColorScheme;
        ColorScheme darkColorScheme;
        if (lightDynamic != null && darkDynamic != null) {
          lightColorScheme = lightDynamic.harmonized();
          darkColorScheme = darkDynamic.harmonized();
        } else {
          lightColorScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.light);
          darkColorScheme = ColorScheme.fromSeed(seedColor: Colors.teal, brightness: Brightness.dark);
        }
        return MaterialApp(
          title: 'Gamify Your Life',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.fromColorScheme(lightColorScheme),
          darkTheme: AppTheme.fromColorScheme(darkColorScheme),
          home: const MainScreen(),
        );
      },
    );
  }
}

// Simple routing via MaterialApp.home to keep dependencies minimal

/// Migration: iterate all tasks and ensure new fields exist with safe defaults.
Future<void> _migrateHiveTasksIfNeeded() async {
  try {
    final box = Hive.box<Task>('tasks');
    final keys = box.keys.toList();
    for (final key in keys) {
      try {
        final task = box.get(key);
        if (task == null) continue;

        // Adapter already handles missing fields; just attempt to access them
        // so any deserialization errors are caught per-record.
      } catch (e) {
        // Log and continue; don't fail startup because of a bad record
        // ignore: avoid_print
        print('Warning: failed to migrate task $key: $e');
      }
    }
  } catch (e) {
    // ignore: avoid_print
    print('Hive migration error: $e');
  }
}

/// Check if midnight has passed since last reset and perform task cleanup.
Future<void> _checkMidnightReset() async {
  try {
    final prefs = Hive.box('user');
    final lastResetMs = prefs.get('lastMidnightReset') as int?;
    final now = DateTime.now();
    final todayMidnight = DateTime(now.year, now.month, now.day);
    
    DateTime? lastReset;
    if (lastResetMs != null) {
      lastReset = DateTime.fromMillisecondsSinceEpoch(lastResetMs);
    }
    
    // If no last reset or last reset was before today's midnight, perform reset
    if (lastReset == null || lastReset.isBefore(todayMidnight)) {
      await _performMidnightReset();
      await prefs.put('lastMidnightReset', now.millisecondsSinceEpoch);
    }
  } catch (e) {
    // ignore: avoid_print
    print('Midnight reset check error: $e');
  }
}

/// Perform midnight reset: delete non-habits, refresh habits with new items.
Future<void> _performMidnightReset() async {
  try {
    final tasksBox = Hive.box<Task>('tasks');
    final itemsBox = Hive.box<Item>('items');
    final items = itemsBox.values.toList();
    
    final keys = tasksBox.keys.toList();
    for (final key in keys) {
      final task = tasksBox.get(key);
      if (task == null) continue;
      
      // Tasks with a deadline should ignore midnight reset
      final hasDeadline = task.deadline != null;
      if (hasDeadline) {
        // Skip any reset actions
        continue;
      }

      if (task.isHabit) {
        // Refresh habit: uncheck, assign new item, keep streak
        task.completed = false;
        // Assign new item using same logic as addTask
        if (items.isNotEmpty) {
          final assignedItem = _assignItemToTask(task, items);
          if (assignedItem != null) {
            task.assignedItemId = assignedItem.id;
          }
        }
        await task.save();
      } else {
        // Delete non-habit task
        await tasksBox.delete(key);
      }
    }
  } catch (e) {
    // ignore: avoid_print
    print('Midnight reset error: $e');
  }
}

/// Assign an item to a task based on rarity and difficulty.
Item? _assignItemToTask(Task task, List<Item> items) {
  try {
    const baseWeights = {
      'common': 80.0,
      'rare': 18.0,
      'epic': 2.0,
    };
    double rareMul = 1.0;
    double epicMul = 1.0;
    if (task.xp >= 75) {
      rareMul = 1.4;
      epicMul = 2.0;
    } else if (task.xp >= 40) {
      rareMul = 1.2;
      epicMul = 1.5;
    }
    final excludeCommons = task.xp >= 50;
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
      for (final it in items) {
        final base = baseWeights[it.rarity.toLowerCase()] ?? 50.0;
        weighted[it] = base;
      }
    }
    final total = weighted.values.fold<double>(0, (a, b) => a + b);
    if (total > 0) {
      final rng = Random();
      double pick = rng.nextDouble() * total;
      for (final entry in weighted.entries) {
        if (pick < entry.value) {
          return entry.key;
        }
        pick -= entry.value;
      }
      return weighted.keys.first;
    }
  } catch (e) {
    return null;
  }
  return null;
}
