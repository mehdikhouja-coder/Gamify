import 'package:hive/hive.dart';

class InventoryEvent extends HiveObject {
  String itemId;
  int quantity;
  DateTime acquiredAt;

  InventoryEvent({required this.itemId, this.quantity = 1, DateTime? acquiredAt})
      : acquiredAt = acquiredAt ?? DateTime.now();
}

class InventoryEventAdapter extends TypeAdapter<InventoryEvent> {
  @override
  final int typeId = 6;

  @override
  InventoryEvent read(BinaryReader reader) {
    final itemId = reader.readString();
    final qty = reader.readInt();
    final ts = reader.readInt();
    return InventoryEvent(
      itemId: itemId,
      quantity: qty,
      acquiredAt: DateTime.fromMillisecondsSinceEpoch(ts),
    );
  }

  @override
  void write(BinaryWriter writer, InventoryEvent obj) {
    writer.writeString(obj.itemId);
    writer.writeInt(obj.quantity);
    writer.writeInt(obj.acquiredAt.millisecondsSinceEpoch);
  }
}
