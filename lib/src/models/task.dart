import 'package:hive/hive.dart';

class Task extends HiveObject {
  String id;
  String title;
  String category;
  int xp;
  bool isHabit;
  String frequency; // e.g., daily, weekly
  bool completed;
  DateTime? lastCompletedAt;
  int streak; // consecutive days streak for habits
  String? assignedItemId; // item tied to task for display
  DateTime? deadline; // optional deadline for task completion

  Task({
    required this.id,
    required this.title,
    required this.category,
    required this.xp,
    this.isHabit = false,
    this.frequency = '',
    this.completed = false,
    this.lastCompletedAt,
    this.streak = 0,
    this.assignedItemId,
    this.deadline,
  });
}

class TaskAdapter extends TypeAdapter<Task> {
  @override
  final int typeId = 0;

  @override
  Task read(BinaryReader reader) {
    final id = reader.readString();
    final title = reader.readString();
    final category = reader.readString();
    final xp = reader.readInt();
    final isHabit = reader.readBool();
    final frequency = reader.readString();
    final completed = reader.readBool();
    // new fields: lastCompletedAt (int ms or -1), streak (int)
    DateTime? last;
    int streak = 0;
    try {
      final lastMs = reader.readInt();
      if (lastMs != -1) last = DateTime.fromMillisecondsSinceEpoch(lastMs);
      streak = reader.readInt();
      // optional: assigned item id (added later)
      String? assignedId;
      DateTime? deadline;
      try {
        final hasAssigned = reader.readBool();
        if (hasAssigned) {
          assignedId = reader.readString();
        }
        // optional: deadline (added later)
        try {
          final hasDeadline = reader.readBool();
          if (hasDeadline) {
            final deadlineMs = reader.readInt();
            deadline = DateTime.fromMillisecondsSinceEpoch(deadlineMs);
          }
        } catch (_) {
          deadline = null;
        }
      } catch (_) {
        assignedId = null;
        deadline = null;
      }
      return Task(
        id: id,
        title: title,
        category: category,
        xp: xp,
        isHabit: isHabit,
        frequency: frequency,
        completed: completed,
        lastCompletedAt: last,
        streak: streak,
        assignedItemId: assignedId,
        deadline: deadline,
      );
    } catch (e) {
      // Older records may not have these fields; default to null/0
      last = null;
      streak = 0;
      // assigned item not present
      return Task(
        id: id,
        title: title,
        category: category,
        xp: xp,
        isHabit: isHabit,
        frequency: frequency,
        completed: completed,
        lastCompletedAt: last,
        streak: streak,
        assignedItemId: null,
        deadline: null,
      );
    }
  }

  @override
  void write(BinaryWriter writer, Task obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.title);
    writer.writeString(obj.category);
    writer.writeInt(obj.xp);
    writer.writeBool(obj.isHabit);
    writer.writeString(obj.frequency);
    writer.writeBool(obj.completed);
    // write nullable DateTime as milliseconds or -1
    if (obj.lastCompletedAt != null) {
      writer.writeInt(obj.lastCompletedAt!.millisecondsSinceEpoch);
    } else {
      writer.writeInt(-1);
    }
    writer.writeInt(obj.streak);
    // write assigned item id presence + value for forward compatibility
    final hasAssigned = obj.assignedItemId != null && obj.assignedItemId!.isNotEmpty;
    writer.writeBool(hasAssigned);
    if (hasAssigned) {
      writer.writeString(obj.assignedItemId!);
    }
    // write deadline presence + value for forward compatibility
    final hasDeadline = obj.deadline != null;
    writer.writeBool(hasDeadline);
    if (hasDeadline) {
      writer.writeInt(obj.deadline!.millisecondsSinceEpoch);
    }
  }
}
