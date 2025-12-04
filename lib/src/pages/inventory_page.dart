import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math';
import '../providers/inventory_provider.dart';
import '../models/item.dart';
import '../models/inventory_entry.dart';
import '../models/inventory_event.dart';
import 'package:hive_flutter/hive_flutter.dart';

class InventoryPage extends ConsumerWidget {
	const InventoryPage({super.key});

	@override
	Widget build(BuildContext context, WidgetRef ref) {
		// Ensure boxes are open before watching providers to avoid HiveError.
		if (!Hive.isBoxOpen('items') || !Hive.isBoxOpen('inventory') || !Hive.isBoxOpen('inventory_log')) {
			return FutureBuilder<void>(
				future: _ensureBoxes(),
				builder: (ctx, snap) {
					if (snap.connectionState != ConnectionState.done) {
						return Scaffold(
							appBar: AppBar(title: const Text('Inventory')),
							body: const Center(child: CircularProgressIndicator()),
						);
					}
					if (snap.hasError) {
						return Scaffold(
							appBar: AppBar(title: const Text('Inventory')),
							body: Center(child: Text('Failed to open boxes: ${snap.error}')),
						);
					}
					// Rebuild now that boxes are open.
					return const InventoryPage();
				},
			);
		}

		final items = ref.watch(itemsProvider);
		final entries = ref.watch(inventoryProvider);

		// Merge metadata
		final merged = <_DisplayEntry>[];
		for (final e in entries) {
			final item = items.firstWhere(
				(i) => i.id == e.itemId,
				orElse: () => Item(id: e.itemId, name: e.itemId, rarity: 'unknown', icon: '❓'),
			);
			merged.add(_DisplayEntry(item: item, qty: e.quantity));
		}

		// Sort by rarity priority then name
		const rank = {'epic': 0, 'rare': 1, 'common': 2, 'unknown': 3};
		merged.sort((a, b) {
			final ra = rank[a.item.rarity.toLowerCase()] ?? 99;
			final rb = rank[b.item.rarity.toLowerCase()] ?? 99;
			if (ra != rb) return ra.compareTo(rb);
			return a.item.name.compareTo(b.item.name);
		});

		final totalTypes = merged.length;
		final totalQty = merged.fold<int>(0, (s, e) => s + e.qty);

		return Scaffold(
			appBar: AppBar(title: const Text('Inventory')),
			body: Padding(
				padding: const EdgeInsets.all(16),
				child: Column(
					crossAxisAlignment: CrossAxisAlignment.start,
					children: [
						_statsRow(context, totalQty, totalTypes),
						const SizedBox(height: 12),
						_summaryChips(context, merged),
						const SizedBox(height: 12),
						Expanded(
							child: ValueListenableBuilder<Box<InventoryEvent>>(
								valueListenable: Hive.box<InventoryEvent>('inventory_log').listenable(),
								builder: (context, box, _) {
                  // 1. Get current inventory counts (The Truth)
                  final inventoryMap = {for (var e in entries) e.itemId: e.quantity};
                  
                  // 2. Get all events, sorted newest first
									final events = box.values.toList()
										..sort((a, b) => b.acquiredAt.compareTo(a.acquiredAt));
                    
                  final displayList = <_ItemWithDate>[];
                  final countsProcessed = <String, int>{};

                  // 3. Reconstruct owned items from history (FIFO consumption assumption)
                  for (final ev in events) {
                    final currentOwned = inventoryMap[ev.itemId] ?? 0;
                    final alreadyTaken = countsProcessed[ev.itemId] ?? 0;
                    
                    if (alreadyTaken < currentOwned) {
                      final needed = currentOwned - alreadyTaken;
                      final takeFromEvent = min(needed, ev.quantity);
                      
                      final item = items.firstWhere(
												(i) => i.id == ev.itemId,
												orElse: () => Item(id: ev.itemId, name: ev.itemId, rarity: 'unknown', icon: '❓'),
											);
                      
                      for (int i = 0; i < takeFromEvent; i++) {
                        displayList.add(_ItemWithDate(item: item, acquiredAt: ev.acquiredAt));
                      }
                      
                      countsProcessed[ev.itemId] = alreadyTaken + takeFromEvent;
                    }
                  }
                  
                  // 4. Add any owned items that weren't found in the log (legacy data fallback)
                  inventoryMap.forEach((id, qty) {
                    final taken = countsProcessed[id] ?? 0;
                    if (taken < qty) {
                      final missing = qty - taken;
                      final item = items.firstWhere(
												(i) => i.id == id,
												orElse: () => Item(id: id, name: id, rarity: 'unknown', icon: '❓'),
											);
                      for (int i = 0; i < missing; i++) {
                        // Use a very old date or now? Now is safer to ensure they appear.
                        displayList.add(_ItemWithDate(item: item, acquiredAt: DateTime.now()));
                      }
                    }
                  });
                  
                  // 5. Final sort
									displayList.sort((a, b) => b.acquiredAt.compareTo(a.acquiredAt));

									if (displayList.isEmpty) {
										return const Center(child: Text('No items yet. Complete tasks to find loot!'));
									}
                  
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      if (constraints.maxWidth > 600) {
                        final gridCount = (constraints.maxWidth / 300).floor().clamp(2, 6);
                        return GridView.builder(
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: gridCount,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            childAspectRatio: 3,
                          ),
                          itemCount: displayList.length,
                          itemBuilder: (ctx, i) => _ItemTile(item: displayList[i].item),
                        );
                      }
                      return ListView.separated(
                        itemCount: displayList.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (ctx, i) => _ItemTile(item: displayList[i].item),
                      );
                    },
                  );
								},
							),
						),
					],
				),
			),
		);
	}

	Widget _statsRow(BuildContext context, int totalQty, int totalTypes) {
		final theme = Theme.of(context);
		return Row(
			children: [
				Expanded(
					child: Card(
						color: theme.colorScheme.primaryContainer,
						child: Padding(
							padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text('Total Items', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.8))),
									const SizedBox(height: 4),
									Text('$totalQty', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w600)),
								],
							),
						),
					),
				),
				const SizedBox(width: 12),
				Expanded(
					child: Card(
						color: theme.colorScheme.secondaryContainer,
						child: Padding(
							padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
							child: Column(
								crossAxisAlignment: CrossAxisAlignment.start,
								children: [
									Text('Distinct Types', style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.8))),
									const SizedBox(height: 4),
									Text('$totalTypes', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
								],
							),
						),
					),
				),
			],
		);
	}
}

Future<void> _ensureBoxes() async {
	if (!Hive.isBoxOpen('items')) {
		await Hive.openBox<Item>('items');
	}
	if (!Hive.isBoxOpen('inventory')) {
		await Hive.openBox<InventoryEntry>('inventory');
	}
  if (!Hive.isBoxOpen('inventory_log')) {
    await Hive.openBox<InventoryEvent>('inventory_log');
  }
}

class _DisplayEntry {
	final Item item;
	final int qty;
	_DisplayEntry({required this.item, required this.qty});
}

class _ItemWithDate {
	final Item item;
	final DateTime acquiredAt;
	_ItemWithDate({required this.item, required this.acquiredAt});
}

class _ItemTile extends StatelessWidget {
  final Item item;
  const _ItemTile({required this.item});

  Color _rarityColor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (item.rarity.toLowerCase()) {
      case 'epic':
        return scheme.errorContainer;
      case 'rare':
        return scheme.tertiaryContainer;
      case 'common':
        return scheme.surfaceVariant;
      default:
        return scheme.surfaceVariant;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rarityColor = _rarityColor(context);
    return Card(
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: rarityColor.withValues(alpha: 0.25),
              child: Text(item.icon, style: const TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.name, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600)),
                  if (item.description.isNotEmpty)
                    Text(item.description, style: theme.textTheme.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _summaryChips(BuildContext context, List<_DisplayEntry> summary) {
	final theme = Theme.of(context);
	final scheme = theme.colorScheme;
	if (summary.isEmpty) return const SizedBox.shrink();
	return Wrap(
		spacing: 8,
		runSpacing: 8,
		children: [
			for (final s in summary)
				Container(
					padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
					decoration: BoxDecoration(
						color: scheme.surfaceContainerHighest,
						borderRadius: BorderRadius.circular(14),
						border: Border.all(color: scheme.outlineVariant),
					),
					child: Row(
						mainAxisSize: MainAxisSize.min,
						children: [
							Text(s.item.icon, style: const TextStyle(fontSize: 14)),
							const SizedBox(width: 6),
							Text('${s.item.name} x${s.qty}', style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600)),
						],
					),
				),
		],
	);
}
