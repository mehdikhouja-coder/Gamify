import 'package:flutter/material.dart';

class AvatarWidget extends StatelessWidget {
  final int level;
  final double size;
  final bool showEditHint;
  const AvatarWidget({super.key, required this.level, this.size = 120, this.showEditHint = false});

  // Determine visual tier by level
  int get tier {
    if (level >= 15) return 4;
    if (level >= 10) return 3;
    if (level >= 5) return 2;
    return 1;
  }

  Color _ringColor(BuildContext context) {
    switch (tier) {
      case 4:
        return Colors.amber.shade700;
      case 3:
        return Colors.purple.shade400;
      case 2:
        return Colors.blue.shade400;
      default:
        return Theme.of(context).colorScheme.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final ring = _ringColor(context);
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer ring
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [ring.withAlpha((0.18 * 255).toInt()), ring.withAlpha((0.04 * 255).toInt())]),
            ),
          ),
          // Ring border
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ring, width: 4),
              gradient: LinearGradient(colors: [Theme.of(context).colorScheme.surface, Theme.of(context).colorScheme.surfaceContainerHighest]),
            ),
            child: Center(
              child: showEditHint
                  ? Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          size: size * 0.4,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        Text(
                          'Tap to edit',
                          style: TextStyle(
                            fontSize: size * 0.1,
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    )
                  : Icon(
                      Icons.person,
                      size: size * 0.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
            ),
          ),
          // Small badge for high tiers
          if (tier >= 3)
            Positioned(
              right: 6,
              top: 6,
              child: CircleAvatar(
                radius: size * 0.08,
                backgroundColor: Colors.white,
                child: Icon(
                  tier >= 4 ? Icons.whatshot : Icons.star,
                  color: ring,
                  size: size * 0.08,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
