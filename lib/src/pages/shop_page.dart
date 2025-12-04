import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/inventory_provider.dart';
import '../models/inventory_entry.dart';
import '../models/item.dart';
import '../models/user.dart';
import '../widgets/animated_avatar_border.dart';
import '../widgets/avatar_widget.dart';
import '../providers/user_avatar_provider.dart';
import '../providers/task_provider.dart';

class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> with SingleTickerProviderStateMixin {
  final Box _userBox = Hive.box('user');
  late List<String> _unlockedBorders;
  late AnimationController _controller;

  final Map<String, Map<String, dynamic>> _shopItems = {
    'rainbow': {
      'name': 'Rainbow',
      'costs': [
        {'currencyId': 'potion_common', 'amount': 5, 'name': 'Small Potion'}
      ]
    },
    'gold': {
      'name': 'Gold',
      'costs': [
        {'currencyId': 'potion_common', 'amount': 10, 'name': 'Small Potion'}
      ]
    },
    'neon_blue': {
      'name': 'Neon',
      'costs': [
        {'currencyId': 'gem_rare', 'amount': 3, 'name': 'Shiny Gem'}
      ]
    },
    'fire': {
      'name': 'Fire',
      'costs': [
        {'currencyId': 'gem_rare', 'amount': 5, 'name': 'Shiny Gem'}
      ]
    },
    'ice': {
      'name': 'Ice Aura',
      'costs': [
        {'currencyId': 'potion_common', 'amount': 10, 'name': 'Small Potion'},
        {'currencyId': 'gem_rare', 'amount': 3, 'name': 'Shiny Gem'}
      ]
    },
    'galaxy': {
      'name': 'Galaxy',
      'costs': [
        {'currencyId': 'ticket_epic', 'amount': 1, 'name': 'Epic Ticket'}
      ]
    },
    'electric': {
      'name': 'Electric',
      'costs': [
        {'currencyId': 'ticket_epic', 'amount': 2, 'name': 'Epic Ticket'}
      ]
    },
    'liquid': {
      'name': 'Liquid Flow',
      'costs': [
        {'currencyId': 'potion_common', 'amount': 8, 'name': 'Small Potion'},
        {'currencyId': 'gem_rare', 'amount': 3, 'name': 'Shiny Gem'},
        {'currencyId': 'ticket_epic', 'amount': 1, 'name': 'Epic Ticket'},
      ]
    },
    'nature': {
      'name': 'Nature\'s Embrace',
      'costs': [
        {'currencyId': 'gem_rare', 'amount': 3, 'name': 'Shiny Gem'},
        {'currencyId': 'ticket_epic', 'amount': 3, 'name': 'Epic Ticket'}
      ]
    },
  };

  @override
  void initState() {
    super.initState();
    _unlockedBorders = List<String>.from(_userBox.get('unlockedBorders', defaultValue: <String>[]));
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _buyBorder(String borderId, List<Map<String, dynamic>> costs) async {
    final inventoryNotifier = ref.read(inventoryProvider.notifier);
    final inventory = ref.read(inventoryProvider);

    // Verify affordability again just in case
    bool canAfford = true;
    for (final cost in costs) {
      final currencyId = cost['currencyId'] as String;
      final amount = cost['amount'] as int;
      final entry = inventory.firstWhere(
        (e) => e.itemId == currencyId,
        orElse: () => InventoryEntry(itemId: currencyId, quantity: 0),
      );
      if (entry.quantity < amount) {
        canAfford = false;
        break;
      }
    }

    if (!canAfford) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Not enough items!')),
        );
      }
      return;
    }

    // Deduct items
    bool allSuccess = true;
    for (final cost in costs) {
      final currencyId = cost['currencyId'] as String;
      final amount = cost['amount'] as int;
      final success = await inventoryNotifier.removeItem(currencyId, count: amount);
      if (!success) {
        allSuccess = false;
        // In a real app, we would need to rollback here.
        break;
      }
    }

    if (allSuccess) {
      setState(() {
        _unlockedBorders.add(borderId);
        _userBox.put('unlockedBorders', _unlockedBorders);
      });
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Border unlocked!')),
        );
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error processing transaction!')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final inventory = ref.watch(inventoryProvider);
    final items = ref.watch(itemsProvider);
    final avatarBase64 = ref.watch(userAvatarProvider);
    final user = ref.watch(userProvider);
    
    Uint8List? bytes;
    if (avatarBase64 != null) {
      try { bytes = base64Decode(avatarBase64); } catch (_) {}
    }

    Widget buildCurrencyChip(String id, String fallbackName, Color color) {
       final entry = inventory.firstWhere((e) => e.itemId == id, orElse: () => InventoryEntry(itemId: id, quantity: 0));
       final item = items.firstWhere((i) => i.id == id, orElse: () => Item(id: id, name: fallbackName, rarity: 'common', icon: '💰'));
       
       final theme = Theme.of(context);
       final scheme = theme.colorScheme;

       return Container(
         padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
         decoration: BoxDecoration(
           color: color.withValues(alpha: 0.2),
           borderRadius: BorderRadius.circular(14),
           border: Border.all(color: scheme.outlineVariant),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Text(item.icon, style: const TextStyle(fontSize: 14)),
             const SizedBox(width: 6),
             Text(
               '${entry.quantity}',
               style: theme.textTheme.labelSmall?.copyWith(fontWeight: FontWeight.w600),
             ),
           ],
         ),
       );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Border Shop'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                buildCurrencyChip('potion_common', 'Small Potion', Colors.green),
                buildCurrencyChip('gem_rare', 'Shiny Gem', Colors.blue),
                buildCurrencyChip('ticket_epic', 'Epic Ticket', Colors.purple),
              ],
            ),
          ),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth > 600;
                final gridCount = isWide ? (constraints.maxWidth / 400).floor().clamp(2, 4) : 1;

                if (isWide) {
                  return GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: gridCount,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 2.5,
                    ),
                    itemCount: _shopItems.length,
                    itemBuilder: (context, index) => _buildShopItem(context, index, inventory, user, bytes),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _shopItems.length,
                  itemBuilder: (context, index) => _buildShopItem(context, index, inventory, user, bytes),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShopItem(BuildContext context, int index, List<InventoryEntry> inventory, User? user, Uint8List? bytes) {
    final borderId = _shopItems.keys.elementAt(index);
    final itemData = _shopItems[borderId]!;
    final isUnlocked = _unlockedBorders.contains(borderId);
    final costs = (itemData['costs'] as List).cast<Map<String, dynamic>>();

    // Check if user has enough currency
    bool canAfford = true;
    for (final cost in costs) {
      final currencyId = cost['currencyId'] as String;
      final amount = cost['amount'] as int;
      final entry = inventory.firstWhere(
        (e) => e.itemId == currencyId,
        orElse: () => InventoryEntry(itemId: currencyId, quantity: 0),
      );
      if (entry.quantity < amount) {
        canAfford = false;
        break;
      }
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            SizedBox(
              width: 80,
              height: 80,
              child: AnimatedAvatarBorder(
                style: borderId,
                size: 80,
                staticColor: Colors.grey,
                animation: _controller,
                child: Container(
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: bytes != null
                      ? Image.memory(bytes, fit: BoxFit.cover)
                      : AvatarWidget(level: user?.level ?? 1, size: 70),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    itemData['name'],
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  ...costs.map((cost) {
                    final currencyId = cost['currencyId'] as String;
                    final amount = cost['amount'] as int;
                    final currencyName = cost['name'] as String;
                    
                    final entry = inventory.firstWhere(
                      (e) => e.itemId == currencyId,
                      orElse: () => InventoryEntry(itemId: currencyId, quantity: 0),
                    );
                    final hasEnough = entry.quantity >= amount;

                    return Text(
                      '$amount $currencyName',
                      style: TextStyle(
                        color: hasEnough ? Colors.green : Colors.red,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    );
                  }),
                ],
              ),
            ),
            if (isUnlocked)
              const Chip(
                label: Text('Owned'),
                visualDensity: VisualDensity.compact,
                side: BorderSide.none,
              )
            else
              FilledButton(
                onPressed: canAfford
                    ? () => _buyBorder(borderId, costs)
                    : null,
                child: const Text('Buy'),
              ),
          ],
        ),
      ),
    );
  }
}
