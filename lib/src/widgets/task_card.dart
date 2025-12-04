import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/task.dart';
import '../providers/task_provider.dart';
import '../providers/inventory_provider.dart';
import '../models/item.dart';
import 'package:hive/hive.dart';

class TaskCard extends ConsumerWidget {
  final Task task;
  const TaskCard({super.key, required this.task});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final messenger = ScaffoldMessenger.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Dismissible(
          key: ValueKey(task.id),
          movementDuration: const Duration(milliseconds: 300),
          resizeDuration: const Duration(milliseconds: 200),
          dismissThresholds: const {DismissDirection.startToEnd: 0.25, DismissDirection.endToStart: 0.25},
          background: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(16)),
            child: Row(children: [
              Icon(Icons.check, color: scheme.onSecondaryContainer),
              const SizedBox(width: 8),
              Text('Complete', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onSecondaryContainer)),
            ]),
          ),
          secondaryBackground: Container(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            alignment: Alignment.centerRight,
            decoration: BoxDecoration(color: scheme.errorContainer, borderRadius: BorderRadius.circular(16)),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Delete', style: theme.textTheme.labelLarge?.copyWith(color: scheme.onErrorContainer)),
                const SizedBox(width: 8),
                Icon(Icons.delete, color: scheme.onErrorContainer),
              ],
            ),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // swipe right -> complete; check deadline first
              if (task.deadline != null && DateTime.now().isAfter(task.deadline!)) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Cannot complete task after deadline has passed'),
                    backgroundColor: Colors.red,
                  ),
                );
                return false;
              }
              // for non-habit tasks, remove them (archive-like). For habits, just complete and keep.
              final result = await ref.read(tasksProvider.notifier).completeTask(ref, task.id);
              if (!task.isHabit) {
                // remove simple tasks when completed via swipe so they appear to 'swipe away'
                await ref.read(tasksProvider.notifier).deleteTask(task.id);
                if (result.didComplete) {
                  final base = 'Completed "${task.title}" (+${task.xp} XP)';
                  final msg = result.dropName != null ? '$base  •  Found: ${result.dropName}' : base;
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(SnackBar(content: Text(msg)));
                }
                return true;
              } else {
                // keep habit tasks visible after checkbox/completion
                if (result.didComplete) {
                  final base = 'Habit completed: "${task.title}" (+${task.xp} XP)';
                  final msg = result.dropName != null ? '$base  •  Found: ${result.dropName}' : base;
                  messenger.hideCurrentSnackBar();
                  messenger.showSnackBar(SnackBar(content: Text(msg)));
                }
                return false;
              }
            } else if (direction == DismissDirection.endToStart) {
              // swipe left -> delete (confirm)
              final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Delete task'),
                      content: Text('Delete "${task.title}"? This cannot be undone.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                        TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                      ],
                    ),
                  ) ??
                  false;

              if (confirmed) {
                await ref.read(tasksProvider.notifier).deleteTask(task.id);
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(const SnackBar(content: Text('Task deleted')));
                return true;
              }
              return false;
            }
            return false;
          },
          child: Card(
            elevation: 0,
            color: Colors.transparent,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            margin: EdgeInsets.zero,
            clipBehavior: Clip.antiAlias,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: scheme.outlineVariant.withValues(alpha: task.completed ? 0.4 : 0.6)),
                color: task.completed ? scheme.surfaceContainerHighest : scheme.surfaceContainerHigh,
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _TaskBadge(task: task, scheme: scheme),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                task.title,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  color: scheme.onSurface,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.15,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Wrap(
                                spacing: 6,
                                runSpacing: 4,
                                crossAxisAlignment: WrapCrossAlignment.center,
                                children: [
                                  _metaChip(
                                    context,
                                    icon: Icons.folder_outlined,
                                    label: task.category,
                                    color: scheme.secondaryContainer,
                                    onColor: scheme.onSecondaryContainer,
                                  ),
                                  if (task.isHabit)
                                    _metaChip(
                                      context,
                                      icon: Icons.repeat,
                                      label: task.frequency.isNotEmpty ? task.frequency : 'Habit',
                                      color: scheme.tertiaryContainer,
                                      onColor: scheme.onTertiaryContainer,
                                    ),
                                  if (task.isHabit && task.streak > 0)
                                    _metaChip(
                                      context,
                                      icon: Icons.local_fire_department_outlined,
                                      label: '${task.streak} day streak',
                                      color: scheme.errorContainer,
                                      onColor: scheme.onErrorContainer,
                                    ),
                                  if (task.completed)
                                    _metaChip(
                                      context,
                                      icon: Icons.check_circle,
                                      label: 'Completed',
                                      color: scheme.primaryContainer,
                                      onColor: scheme.onPrimaryContainer,
                                    ),
                                  if (task.assignedItemId != null && task.assignedItemId!.isNotEmpty)
                                    _assignedItemChip(context, ref, task.assignedItemId!, scheme),
                                  if (task.deadline != null)
                                    _deadlineChip(context, task.deadline!, scheme),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            _xpPill(context, task),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        if (task.isHabit && task.lastCompletedAt != null)
                          Text(
                            'Last done ${_relativeTime(task.lastCompletedAt!)}',
                            style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Delete task',
                          style: IconButton.styleFrom(
                            backgroundColor: scheme.surfaceContainerHighest,
                            foregroundColor: scheme.onSurfaceVariant,
                            minimumSize: const Size(36, 36),
                            padding: EdgeInsets.zero,
                          ),
                          iconSize: 22,
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final confirmed = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Delete task'),
                                    content: Text('Delete "${task.title}"? This cannot be undone.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
                                      TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Delete')),
                                    ],
                                  ),
                                ) ??
                                false;

                            if (confirmed) {
                              await ref.read(tasksProvider.notifier).deleteTask(task.id);
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(const SnackBar(content: Text('Task deleted')));
                            }
                          },
                        ),
                        const SizedBox(width: 8),
                        Checkbox(
                          value: task.completed,
                          onChanged: (checked) async {
                            if (checked == null || task.completed) return;
                            // Check if deadline has passed
                            if (task.deadline != null && DateTime.now().isAfter(task.deadline!)) {
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Cannot complete task after deadline has passed'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return;
                            }
                            final result = await ref.read(tasksProvider.notifier).completeTask(ref, task.id);
                            if (result.didComplete) {
                              final base = 'Completed "${task.title}" (+${task.xp} XP)';
                              final msg = result.dropName != null ? '$base  •  Found: ${result.dropName}' : base;
                              messenger.hideCurrentSnackBar();
                              messenger.showSnackBar(SnackBar(content: Text(msg)));
                            }
                          },
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(4))),
                          visualDensity: VisualDensity.compact,
                          activeColor: scheme.primary,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
  Widget _assignedItemChip(BuildContext context, WidgetRef ref, String itemId, ColorScheme scheme) {
    final items = ref.read(itemsProvider);
    Item? item;
    if (items.isNotEmpty) {
      try {
        item = items.firstWhere((i) => i.id == itemId);
      } catch (_) {}
    }
    // Fallback: read directly from Hive if provider not yet populated
    item ??= Hive.isBoxOpen('items') ? Hive.box<Item>('items').values.firstWhere(
      (i) => i.id == itemId,
      orElse: () => Item(id: itemId, name: itemId, rarity: 'unknown', icon: '❓'),
    ) : Item(id: itemId, name: itemId, rarity: 'unknown', icon: '❓');

    final color = scheme.secondaryContainer;
    final onColor = scheme.onSecondaryContainer;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(14)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(item.icon, style: const TextStyle(fontSize: 14)),
          const SizedBox(width: 6),
          Text(item.name, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: onColor, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _xpPill(BuildContext context, Task task) {
    final scheme = Theme.of(context).colorScheme;
    final hasDeadline = task.deadline != null;
    final baseXp = task.xp;
    final awardedXp = hasDeadline ? (baseXp * 1.5).round() : baseXp;
    final label = hasDeadline ? '+$awardedXp XP (1.5x)' : '+$awardedXp XP';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: hasDeadline ? scheme.tertiaryContainer : scheme.primaryContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: (hasDeadline ? scheme.tertiary : scheme.primary).withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: hasDeadline ? scheme.onTertiaryContainer : scheme.onPrimaryContainer,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.2,
            ),
      ),
    );
  }

  Widget _metaChip(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
    required Color onColor,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }

  String _relativeTime(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    if (difference.inMinutes < 1) return 'just now';
    if (difference.inMinutes < 60) return '${difference.inMinutes} min ago';
    if (difference.inHours < 24) return '${difference.inHours} h ago';
    if (difference.inDays == 1) return 'yesterday';
    if (difference.inDays < 7) return '${difference.inDays} days ago';
    return '${(difference.inDays / 7).floor()} weeks ago';
  }

  Widget _deadlineChip(BuildContext context, DateTime deadline, ColorScheme scheme) {
    final now = DateTime.now();
    final isPast = now.isAfter(deadline);
    final color = isPast ? scheme.errorContainer : scheme.tertiaryContainer;
    final onColor = isPast ? scheme.onErrorContainer : scheme.onTertiaryContainer;
    final icon = isPast ? Icons.warning_amber : Icons.event;
    final label = isPast ? 'Expired' : '${deadline.month}/${deadline.day}/${deadline.year}';
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: onColor.withValues(alpha: 0.85)),
          const SizedBox(width: 4),
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskBadge extends StatelessWidget {
  final Task task;
  final ColorScheme scheme;

  const _TaskBadge({required this.task, required this.scheme});

  @override
  Widget build(BuildContext context) {
    final icon = task.isHabit
        ? Icons.repeat
        : (task.completed ? Icons.emoji_events_outlined : Icons.flag_outlined);
    final containerColor = task.completed ? scheme.primaryContainer : scheme.secondaryContainer;
    final foreground = task.completed ? scheme.onPrimaryContainer : scheme.onSecondaryContainer;
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: containerColor,
        border: Border.all(color: foreground.withValues(alpha: 0.35)),
      ),
      child: Center(child: Icon(icon, color: foreground, size: 20)),
    );
  }
}
