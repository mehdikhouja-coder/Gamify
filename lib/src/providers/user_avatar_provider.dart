import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';

final userAvatarProvider = StateNotifierProvider<UserAvatarNotifier, String?>((ref) {
  final box = Hive.box('user');
  final initial = box.get('avatarBase64') as String?;
  return UserAvatarNotifier(box, initial);
});

class UserAvatarNotifier extends StateNotifier<String?> {
  UserAvatarNotifier(this._box, String? initial) : super(initial);
  final Box _box;

  Future<void> setAvatarBytes(List<int> bytes) async {
    final b64 = base64Encode(bytes);
    state = b64;
    await _box.put('avatarBase64', b64);
  }

  Future<void> clearAvatar() async {
    state = null;
    await _box.delete('avatarBase64');
  }
}
