import 'package:hive/hive.dart';

class Achievement extends HiveObject {
  String id;
  String title;
  String description;
  bool unlocked;
  DateTime? unlockedAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    this.unlocked = false,
    this.unlockedAt,
  });
}

class AchievementAdapter extends TypeAdapter<Achievement> {
  @override
  final int typeId = 1;

  @override
  Achievement read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final description = reader.readString();
    final unlocked = reader.readBool();
    final hasDate = reader.readBool();
    DateTime? unlockedAt;
    if (hasDate) unlockedAt = DateTime.fromMillisecondsSinceEpoch(reader.readInt());
    return Achievement(
      id: id,
      title: title,
      description: description,
      unlocked: unlocked,
      unlockedAt: unlockedAt,
    );
  }

  @override
  void write(BinaryWriter writer, Achievement obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.description);
    writer.writeBool(obj.unlocked);
    if (obj.unlockedAt != null) {
      writer.writeBool(true);
      writer.writeInt(obj.unlockedAt!.millisecondsSinceEpoch);
    } else {
      writer.writeBool(false);
    }
  }
}
