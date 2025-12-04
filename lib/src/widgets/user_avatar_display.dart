import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../providers/user_avatar_provider.dart';
import '../providers/task_provider.dart';
import 'avatar_widget.dart';
import 'animated_avatar_border.dart';

class UserAvatarDisplay extends ConsumerWidget {
  final double size;
  final double borderWidth;
  final bool showEditHint;
  final Animation<double>? animation;

  const UserAvatarDisplay({
    super.key,
    required this.size,
    this.borderWidth = 3,
    this.showEditHint = true,
    this.animation,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final b64 = ref.watch(userAvatarProvider);
    Uint8List? bytes;
    if (b64 != null) {
      try { bytes = base64Decode(b64); } catch (_) {}
    }
    
    // Listen to box changes for border color updates
    return ValueListenableBuilder(
      valueListenable: Hive.box('user').listenable(keys: ['avatarBorderColor', 'avatarBorderStyle']),
      builder: (context, box, _) {
        final borderArgb = box.get('avatarBorderColor') as int?;
        final borderColor = borderArgb != null ? Color(borderArgb) : Theme.of(context).colorScheme.primary;
        final borderStyle = box.get('avatarBorderStyle', defaultValue: 'static') as String;
        
        return AnimatedAvatarBorder(
          size: size,
          borderWidth: borderWidth,
          style: borderStyle,
          staticColor: borderColor,
          animation: animation,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Theme.of(context).colorScheme.secondaryContainer,
            ),
            clipBehavior: Clip.antiAlias,
            child: bytes != null
                ? Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    key: ValueKey(b64.hashCode),
                    gaplessPlayback: true,
                  )
                : AvatarWidget(
                    level: ref.watch(userProvider)?.level ?? 1,
                    size: size,
                    showEditHint: showEditHint,
                  ),
          ),
        );
      },
    );
  }
}
