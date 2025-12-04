import 'package:hive/hive.dart';

class InventoryEntry extends HiveObject {
  String itemId;
  int quantity;

  InventoryEntry({required this.itemId, this.quantity = 0});
}

class InventoryEntryAdapter extends TypeAdapter<InventoryEntry> {
  @override
  final int typeId = 4;

  @override
  InventoryEntry read(BinaryReader reader) {
    final itemId = reader.readString();
    final qty = reader.readInt();
    return InventoryEntry(itemId: itemId, quantity: qty);
  }

  @override
  void write(BinaryWriter writer, InventoryEntry obj) {
    writer.writeString(obj.itemId);
    writer.writeInt(obj.quantity);
  }
}
