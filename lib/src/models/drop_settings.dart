import 'package:hive/hive.dart';

part 'drop_settings.g.dart';

@HiveType(typeId: 5)
class DropSettings extends HiveObject {
  @HiveField(0)
  double chanceCap;
  @HiveField(1)
  double commonWeight;
  @HiveField(2)
  double rareWeight;
  @HiveField(3)
  double epicWeight;
  @HiveField(4)
  double scarcityBoost;

  DropSettings({
    this.chanceCap = 0.50,
    this.commonWeight = 80.0,
    this.rareWeight = 18.0,
    this.epicWeight = 2.0,
    this.scarcityBoost = 1.5,
  });

  DropSettings copyWith({
    double? chanceCap,
    double? commonWeight,
    double? rareWeight,
    double? epicWeight,
    double? scarcityBoost,
  }) {
    return DropSettings(
      chanceCap: chanceCap ?? this.chanceCap,
      commonWeight: commonWeight ?? this.commonWeight,
      rareWeight: rareWeight ?? this.rareWeight,
      epicWeight: epicWeight ?? this.epicWeight,
      scarcityBoost: scarcityBoost ?? this.scarcityBoost,
    );
  }
}
