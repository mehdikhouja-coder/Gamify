import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/task_provider.dart';
import '../widgets/user_avatar_display.dart';
import '../widgets/animated_avatar_border.dart';
import '../models/user.dart';
import 'shop_page.dart';

class BorderSelectionPage extends ConsumerStatefulWidget {
  const BorderSelectionPage({super.key});

  @override
  ConsumerState<BorderSelectionPage> createState() => _BorderSelectionPageState();
}

class _BorderSelectionPageState extends ConsumerState<BorderSelectionPage> with SingleTickerProviderStateMixin {
  late int _selectedColorValue;
  late String _selectedStyle;
  // late List<String> _unlockedBorders;
  late AnimationController _controller;

  final List<Color> _colors = [
    Colors.red,
    Colors.pink,
    Colors.purple,
    Colors.deepPurple,
    Colors.indigo,
    Colors.blue,
    Colors.lightBlue,
    Colors.cyan,
    Colors.teal,
    Colors.green,
    Colors.lightGreen,
    Colors.lime,
    Colors.yellow,
    Colors.amber,
    Colors.orange,
    Colors.deepOrange,
    Colors.brown,
    Colors.grey,
    Colors.blueGrey,
    Colors.black,
    Colors.white,
  ];

  final List<Map<String, String>> _animatedBorders = [
    {'id': 'rainbow', 'name': 'Rainbow'},
    {'id': 'gold', 'name': 'Gold'},
    {'id': 'neon_blue', 'name': 'Neon'},
    {'id': 'fire', 'name': 'Fire'},
    {'id': 'ice', 'name': 'Ice Aura'},
    {'id': 'galaxy', 'name': 'Galaxy'},
    {'id': 'electric', 'name': 'Electric'},
    {'id': 'liquid', 'name': 'Liquid Flow'},
    {'id': 'nature', 'name': 'Nature\'s Embrace'},
  ];

  @override
  void initState() {
    super.initState();
    final box = Hive.box('user');
    _selectedColorValue = box.get('avatarBorderColor', defaultValue: 0xFF2196F3) as int;
    _selectedStyle = box.get('avatarBorderStyle', defaultValue: 'static') as String;
    // _unlockedBorders = List<String>.from(box.get('unlockedBorders', defaultValue: <String>[]));
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

  void _selectColor(Color color) {
    setState(() {
      _selectedColorValue = color.value;
      _selectedStyle = 'static';
    });
    final box = Hive.box('user');
    box.put('avatarBorderColor', color.value);
    box.put('avatarBorderStyle', 'static');
  }

  void _selectAnimatedStyle(String style) {
    setState(() {
      _selectedStyle = style;
    });
    final box = Hive.box('user');
    box.put('avatarBorderStyle', style);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(userProvider) ?? User();
    
    final themeColors = [
      theme.colorScheme.primary,
      theme.colorScheme.secondary,
      theme.colorScheme.tertiary,
      theme.colorScheme.error,
    ];

    final allColors = [...themeColors, ..._colors];

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Select Border Style'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Colors'),
              Tab(text: 'Animated'),
            ],
          ),
        ),
        body: Column(
          children: [
            const SizedBox(height: 32),
            // Preview
            Center(
              child: UserAvatarDisplay(size: 160, borderWidth: 4, animation: _controller),
            ),
            const SizedBox(height: 16),
            Text(
              'Preview',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 32),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: theme.colorScheme.surfaceContainer,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                child: TabBarView(
                  children: [
                    _buildColorGrid(theme, allColors, user.level),
                    _buildAnimatedGrid(theme),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorGrid(ThemeData theme, List<Color> allColors, int userLevel) {
    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: allColors.length,
      itemBuilder: (context, index) {
        final color = allColors[index];
        final isSelected = _selectedStyle == 'static' && color.value == _selectedColorValue;
        
        // Unlock logic: Row 0 (0-4) unlocked at lvl 1, Row 1 (5-9) at lvl 5, etc.
        final row = index ~/ 5;
        final requiredLevel = row == 0 ? 1 : row * 5;
        final isLocked = userLevel < requiredLevel;

        return GestureDetector(
          onTap: () {
            if (isLocked) {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Reach Level $requiredLevel to unlock this color!')),
              );
            } else {
              _selectColor(color);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isLocked ? theme.colorScheme.surfaceContainerHigh : color,
              shape: BoxShape.circle,
              border: Border.all(
                color: isSelected ? theme.colorScheme.onSurface : theme.colorScheme.outlineVariant,
                width: isSelected ? 3 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: color.withOpacity(0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ]
                  : null,
            ),
            child: isLocked
                ? Icon(Icons.lock, color: theme.colorScheme.onSurfaceVariant, size: 20)
                : (isSelected
                    ? Icon(Icons.check, color: _getContrastColor(color), size: 20)
                    : null),
          ),
        );
      },
    );
  }

  Widget _buildAnimatedGrid(ThemeData theme) {
    // Refresh unlocked borders from Hive in case they were bought
    final box = Hive.box('user');
    final unlocked = List<String>.from(box.get('unlockedBorders', defaultValue: <String>[]));

    return GridView.builder(
      padding: const EdgeInsets.all(24),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.8,
      ),
      itemCount: _animatedBorders.length,
      itemBuilder: (context, index) {
        final item = _animatedBorders[index];
        final id = item['id']!;
        final name = item['name']!;
        final isSelected = _selectedStyle == id;
        final isLocked = !unlocked.contains(id);

        return GestureDetector(
          onTap: () {
            if (isLocked) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const ShopPage()));
            } else {
              _selectAnimatedStyle(id);
            }
          },
          child: Opacity(
            opacity: isLocked ? 0.5 : 1.0,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(color: theme.colorScheme.primary, width: 3)
                          : null,
                    ),
                    padding: const EdgeInsets.all(4),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedAvatarBorder(
                          size: 60,
                          borderWidth: 3,
                          style: id,
                          staticColor: Colors.transparent,
                          animation: _controller,
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: theme.colorScheme.surfaceContainerHigh,
                            ),
                          ),
                        ),
                        if (isLocked)
                          Icon(Icons.lock, color: theme.colorScheme.onSurface, size: 24),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  name,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? theme.colorScheme.primary : null,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _getContrastColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark
        ? Colors.white
        : Colors.black;
  }
}
