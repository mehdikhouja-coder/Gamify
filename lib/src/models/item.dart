import 'package:hive/hive.dart';

class Item extends HiveObject {
  String id;
  String name;
  String rarity; // e.g., common, rare, epic
  String icon;   // emoji or material icon name
  String description;

  Item({
    required this.id,
    required this.name,
    required this.rarity,
    required this.icon,
    this.description = '',
  });
}

class ItemAdapter extends TypeAdapter<Item> {
  @override
  final int typeId = 3;

  @override
  Item read(BinaryReader reader) {
    final id = reader.readString();
    final name = reader.readString();
    final rarity = reader.readString();
    final icon = reader.readString();
    final hasDesc = reader.readBool();
    String desc = '';
    if (hasDesc) desc = reader.readString();
    return Item(id: id, name: name, rarity: rarity, icon: icon, description: desc);
  }

  @override
  void write(BinaryWriter writer, Item obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.rarity);
    writer.writeString(obj.icon);
    if (obj.description.isNotEmpty) {
      writer.writeBool(true);
      writer.writeString(obj.description);
    } else {
      writer.writeBool(false);
    }
  }
}
