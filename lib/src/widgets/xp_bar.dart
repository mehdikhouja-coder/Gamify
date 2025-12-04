import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user.dart';
import '../providers/task_provider.dart';

class XPBar extends ConsumerWidget {
  final double height;
  const XPBar({super.key, this.height = 48});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final user = ref.watch(userProvider) ?? User();
    final next = user.xpForLevel(user.level);
    final progress = ((user.xp / next).clamp(0, 1)).toDouble();

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerHigh,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.7)),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              scheme.surfaceContainerHigh,
              scheme.surfaceContainerHigh.withValues(alpha: 0.85),
            ],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Level ${user.level}', style: theme.textTheme.titleMedium?.copyWith(color: scheme.onSurface)),
                Text('${user.xp} / $next XP', style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
              ],
            ),
            const SizedBox(height: 8),
            // Animate progress changes smoothly
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: progress),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, animatedProgress, child) {
                return Container(
                  height: height - 12,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    color: scheme.primaryContainer,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: LinearProgressIndicator(
                      value: animatedProgress,
                      minHeight: height - 12,
                      backgroundColor: scheme.primaryContainer.withValues(alpha: 0.4),
                      valueColor: AlwaysStoppedAnimation(scheme.primary),
                    ),
                  ),
                );
              },
            ),
            ],
          ),
        ),
      ),
    );
  }
}
