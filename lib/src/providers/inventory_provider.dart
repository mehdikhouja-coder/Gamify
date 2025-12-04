import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/item.dart';
import '../models/inventory_entry.dart';
import '../models/task.dart';
import '../models/inventory_event.dart';

final itemsBoxProvider = Provider<Box<Item>>((ref) => Hive.box<Item>('items'));
final inventoryBoxProvider = Provider<Box<InventoryEntry>>((ref) => Hive.box<InventoryEntry>('inventory'));

final itemsProvider = StateNotifierProvider<ItemsNotifier, List<Item>>((ref) {
  return ItemsNotifier(ref);
});

final inventoryProvider = StateNotifierProvider<InventoryNotifier, List<InventoryEntry>>((ref) {
  return InventoryNotifier(ref);
});

class ItemsNotifier extends StateNotifier<List<Item>> {
  final Ref ref;
  ItemsNotifier(this.ref) : super(_load());

  static List<Item> _load() {
    if (!Hive.isBoxOpen('items')) {
      // Open lazily if hot restart skipped main or during web refresh.
      Hive.openBox<Item>('items');
    }
    final box = Hive.box<Item>('items');
    return box.values.toList();
  }

  Future<void> addAll(List<Item> items) async {
    final box = Hive.box<Item>('items');
    for (final item in items) {
      await box.put(item.id, item);
    }
    state = _load();
  }
}

class InventoryNotifier extends StateNotifier<List<InventoryEntry>> {
  final Ref ref;
  InventoryNotifier(this.ref) : super(_load());

  static List<InventoryEntry> _load() {
    if (!Hive.isBoxOpen('inventory')) {
      Hive.openBox<InventoryEntry>('inventory');
    }
    final box = Hive.box<InventoryEntry>('inventory');
    return box.values.toList();
  }

  Future<void> addItem(String itemId, {int count = 1}) async {
    if (!Hive.isBoxOpen('inventory')) {
      await Hive.openBox<InventoryEntry>('inventory');
    }
    final box = Hive.box<InventoryEntry>('inventory');
    // find existing entry by itemId
    final existingKey = box.keys.cast<dynamic>().firstWhere(
      (k) => box.get(k)?.itemId == itemId,
      orElse: () => null,
    );
    if (existingKey != null) {
      final entry = box.get(existingKey);
      if (entry != null) {
        entry.quantity += count;
        await entry.save();
      }
    } else {
      final entry = InventoryEntry(itemId: itemId, quantity: count);
      await box.add(entry);
    }
    // Log acquisition events
    if (!Hive.isBoxOpen('inventory_log')) {
      await Hive.openBox<InventoryEvent>('inventory_log');
    }
    final logBox = Hive.box<InventoryEvent>('inventory_log');
    await logBox.add(InventoryEvent(itemId: itemId, quantity: count, acquiredAt: DateTime.now()));

    state = _load();
  }

  Future<bool> removeItem(String itemId, {int count = 1}) async {
    if (!Hive.isBoxOpen('inventory')) {
      await Hive.openBox<InventoryEntry>('inventory');
    }
    final box = Hive.box<InventoryEntry>('inventory');
    final existingKey = box.keys.cast<dynamic>().firstWhere(
      (k) => box.get(k)?.itemId == itemId,
      orElse: () => null,
    );

    if (existingKey != null) {
      final entry = box.get(existingKey);
      if (entry != null && entry.quantity >= count) {
        entry.quantity -= count;
        if (entry.quantity <= 0) {
          await box.delete(existingKey);
        } else {
          await entry.save();
        }
        state = _load();
        return true;
      }
    }
    return false;
  }

  /// Returns dropped Item name if any, else null
  Future<String?> maybeDropRandomItem({double chance = 0.25}) async {
    final rng = Random();
    if (rng.nextDouble() > chance) return null;
    final items = ref.read(itemsProvider);
    if (items.isEmpty) return null;
    // Weighted by rarity could be added later; for now uniform
    final item = items[rng.nextInt(items.length)];
    await addItem(item.id, count: 1);
    return item.name;
  }

  /// Returns dropped Item name if any, using rarity-weighted selection and per-task drop bonuses.
  Future<String?> maybeDropForTask(Task task) async {
    final rng = Random();
    // Base chance plus XP-based bonus: +0.005 per XP up to cap of 0.50
    double chance = 0.20 + (task.xp * 0.005);
    if (chance > 0.50) chance = 0.50;

    if (rng.nextDouble() > chance) return null;

    final items = ref.read(itemsProvider);
    if (items.isEmpty) return null;

    // Current inventory counts per item to bias toward items you have less of
    // Read directly from Hive to avoid self-dependency on this provider.
    if (!Hive.isBoxOpen('inventory')) {
      await Hive.openBox<InventoryEntry>('inventory');
    }
    final invBox = Hive.box<InventoryEntry>('inventory');
    final counts = <String, int>{};
    for (final e in invBox.values) {
      counts[e.itemId] = (counts[e.itemId] ?? 0) + e.quantity;
    }

    // Base rarity weights (constants)
    const baseWeights = {
      'common': 78.0,
      'rare': 18.0,
      'epic': 4.0,
    };

    // Difficulty-based multipliers tilt towards rarer items as XP increases
    double rareMul = 1.0;
    double epicMul = 1.0;
    if (task.xp >= 75) {
      rareMul = 1.4;
      epicMul = 2.0;
    } else if (task.xp >= 40) {
      rareMul = 1.2;
      epicMul = 1.5;
    }

    // Build weighted list
    final weighted = <Item, double>{};
    // Scarcity factor boost constant
    const scarcityBoost = 1.5;
    for (final it in items) {
      final rarity = it.rarity.toLowerCase();
      final base = baseWeights[rarity] ?? 50.0;
      double w = base;
      if (rarity == 'rare') w *= rareMul;
      if (rarity == 'epic') w *= epicMul;
      final qty = counts[it.id] ?? 0;
      final scarcityMul = 1.0 + (scarcityBoost / (qty + 1));
      w *= scarcityMul;
      weighted[it] = w;
    }

    final total = weighted.values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return null;

    double pick = rng.nextDouble() * total;
    for (final entry in weighted.entries) {
      if (pick < entry.value) {
        await addItem(entry.key.id, count: 1);
        return entry.key.name;
      }
      pick -= entry.value;
    }
    return null;
  }
}
