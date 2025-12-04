import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/user_avatar_provider.dart';
import '../widgets/xp_history_chart.dart';
import '../providers/task_provider.dart';
import 'package:hive/hive.dart';
import '../models/user.dart';
import 'package:permission_handler/permission_handler.dart';
import '../widgets/circular_crop_dialog.dart';
import 'border_selection_page.dart';
import '../widgets/user_avatar_display.dart';
import 'achievements_page.dart';
import '../models/achievement.dart';
import '../models/task.dart';
import '../models/inventory_entry.dart';
import '../models/inventory_event.dart';
import '../providers/inventory_provider.dart';

class ProfilePage extends ConsumerStatefulWidget {
  const ProfilePage({super.key});

  @override
  ConsumerState<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends ConsumerState<ProfilePage> {
  late TextEditingController _usernameController;

  @override
  void initState() {
    super.initState();
    final user = ref.read(userProvider);
    _usernameController = TextEditingController(text: user?.username ?? 'user');
  }

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = ref.watch(userProvider);
    if (user == null) {
      return const Scaffold(body: Center(child: Text('No user')));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const AchievementsPage())),
            icon: const Icon(Icons.emoji_events),
            tooltip: 'Achievements',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Center(child: UserAvatarDisplay(size: 140, showEditHint: false)),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: TextField(
                controller: _usernameController,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Username',
                  suffixIcon: Icon(Icons.edit, size: 20, color: theme.colorScheme.onSurfaceVariant),
                  // Add a transparent prefix icon to balance the layout and keep text centered
                  prefixIcon: const Icon(Icons.edit, size: 20, color: Colors.transparent),
                ),
                style: theme.textTheme.headlineSmall,
                onSubmitted: (value) {
                  user.username = value;
                  user.save();
                },
                onTapOutside: (_) {
                   if (user.username != _usernameController.text) {
                     user.username = _usernameController.text;
                     user.save();
                   }
                   FocusScope.of(context).unfocus();
                },
              ),
            ),
            Text('Tap to edit', style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.outline)),
            const SizedBox(height: 12),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FilledButton.tonal(
                  onPressed: () => _pickAvatar(context, ref),
                  child: const Text('Change Picture'),
                ),
                const SizedBox(width: 8),
                FilledButton.tonal(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const BorderSelectionPage()),
                  ).then((_) => ref.invalidate(userAvatarProvider)),
                  child: const Text('Change Border'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.45), width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    theme.colorScheme.primaryContainer,
                    theme.colorScheme.primaryContainer.withValues(alpha: 0.85),
                  ],
                ),
              ),
              child: Text(
                'Level ${user.level}',
                style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${user.xp} XP',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _statCard(context, 'Next Level', '${user.xpForLevel(user.level)} XP'),
                _statCard(context, 'Active Days', '${user.xpHistory.length}'),
              ],
            ),
            const SizedBox(height: 20),
            XPHistoryChart(history: user.xpHistory),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _resetProgress(context, ref),
              style: ElevatedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              icon: const Icon(Icons.delete_forever),
              label: const Text('Reset Everything'),
            )
          ],
        ),
      ),
    );
  }

  Future<void> _pickAvatar(BuildContext context, WidgetRef ref) async {
    try {
      // Request permissions for mobile platforms
      if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS)) {
        final status = await Permission.photos.request();
        if (!status.isGranted) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Photo permission denied')),
          );
          return;
        }
      }

      List<int>? selected;
      if (kIsWeb || defaultTargetPlatform == TargetPlatform.windows || defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.macOS) {
        final res = await FilePicker.platform.pickFiles(
          allowMultiple: false,
          type: FileType.image,
          withData: true,
        );
        if (res != null && res.files.isNotEmpty && res.files.first.bytes != null) {
          selected = res.files.first.bytes!;
        }
      } else {
        final picker = ImagePicker();
        final file = await picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
          maxWidth: 1024,
          maxHeight: 1024,
        );
        if (file != null) {
          selected = await file.readAsBytes();
        }
      }
      if (selected != null) {
        // Show crop dialog
        final croppedBytes = await showDialog<Uint8List>(
          context: context,
          builder: (ctx) => CircularCropDialog(imageBytes: Uint8List.fromList(selected!)),
        );
        if (croppedBytes != null) {
          await ref.read(userAvatarProvider.notifier).setAvatarBytes(croppedBytes);
          if (context.mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile picture updated')));
          }
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to pick image')));
    }
  }

  Widget _statCard(BuildContext context, String title, String value) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Text(title, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer.withValues(alpha: 0.85))),
            const SizedBox(height: 6),
            Text(value, style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSecondaryContainer, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Future<void> _resetProgress(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Reset Profile'),
            content: const Text('This will delete all data (tasks, inventory, progress, avatar). This action cannot be undone. Continue?'),
            actions: [
              TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
                child: const Text('Reset Everything'),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      // 1. Clear Tasks
      final taskBox = Hive.box<Task>('tasks');
      await taskBox.clear();
      ref.invalidate(tasksProvider);

      // 2. Clear Achievements
      if (Hive.isBoxOpen('achievements')) await Hive.box<Achievement>('achievements').clear();

      // 3. Clear Inventory & Logs
      if (Hive.isBoxOpen('inventory')) await Hive.box<InventoryEntry>('inventory').clear();
      if (Hive.isBoxOpen('inventory_log')) await Hive.box<InventoryEvent>('inventory_log').clear();
      ref.invalidate(inventoryProvider);

      // 4. Reset User Data
      final userBox = Hive.box('user');
      await userBox.clear();
      
      // Create fresh user
      final newUser = User();
      await userBox.put('me', newUser);
      ref.invalidate(userProvider);

      // 5. Clear Avatar
      await ref.read(userAvatarProvider.notifier).clearAvatar();

      if (context.mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile reset successfully')));
        // Update local state for username controller
        setState(() {
          _usernameController.text = newUser.username;
        });
      }
    }
  }
}




