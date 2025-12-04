import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import '../models/drop_settings.dart';

final dropSettingsBoxProvider = Provider<Box<DropSettings>>((ref) => Hive.box<DropSettings>('drop_settings'));

final dropSettingsProvider = StateNotifierProvider<DropSettingsNotifier, DropSettings>((ref) {
  final box = ref.watch(dropSettingsBoxProvider);
  final settings = box.get('settings') ?? DropSettings();
  return DropSettingsNotifier(box, settings);
});

class DropSettingsNotifier extends StateNotifier<DropSettings> {
  final Box<DropSettings> box;
  DropSettingsNotifier(this.box, DropSettings initial) : super(initial);

  Future<void> update({
    double? chanceCap,
    double? commonWeight,
    double? rareWeight,
    double? epicWeight,
    double? scarcityBoost,
  }) async {
    final updated = state.copyWith(
      chanceCap: chanceCap,
      commonWeight: commonWeight,
      rareWeight: rareWeight,
      epicWeight: epicWeight,
      scarcityBoost: scarcityBoost,
    );
    await box.put('settings', updated);
    state = updated;
  }
}
