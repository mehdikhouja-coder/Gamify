import 'package:hive/hive.dart';

class User extends HiveObject {
  int level;
  int xp;
  String username;
  late Map<String, int> xpHistory; // date string (yyyy-MM-dd) -> total xp

  User({this.level = 1, this.xp = 0, this.username = 'user', dynamic xpHistory}) {
    if (xpHistory is Map) {
      this.xpHistory = Map<String, int>.from(xpHistory);
    } else {
      this.xpHistory = {};
    }
  }

  int xpForLevel(int n) => 50 + (n * 25);

  int xpNeededForNext() => xpForLevel(level) - xp;

  void addXp(int amount) {
    xp += amount;
    final today = DateTime.now().toIso8601String().split('T')[0];
    xpHistory[today] = (xpHistory[today] ?? 0) + amount;
    
    while (xp >= xpForLevel(level)) {
      xp -= xpForLevel(level);
      level += 1;
    }
    save();
  }
}

class UserAdapter extends TypeAdapter<User> {
  @override
  final int typeId = 2;

  @override
  User read(BinaryReader reader) {
    final level = reader.readInt();
    final xp = reader.readInt();
    final count = reader.readInt();
    final history = <String, int>{};
    
    // Attempt to read as Map<String, int>. 
    // If the data is old (List<int>), this might fail or produce weird results.
    // Since we can't easily peek, we'll try to read. 
    // In a production app, we'd version the data.
    try {
      for (var i = 0; i < count; i++) {
        final key = reader.readString();
        final val = reader.readInt();
        // Basic validation to ensure key is a date string (YYYY-MM-DD)
        // This prevents garbage data from old List<int> migrations from crashing the UI
        if (key.contains('-') && key.length >= 10) {
          history[key] = val;
        }
      }
    } catch (e) {
      // If reading fails (likely due to type mismatch from old data), 
      // we start with empty history to prevent crash.
    }

    String username = 'user';
    if (reader.availableBytes > 0) {
      try {
        // Use dynamic to safely check for null or type mismatch
        final dynamic val = reader.readString();
        if (val is String) {
          username = val;
        }
      } catch (e) {
        // If reading username fails, we stick to default 'user'
      }
    }
    
    return User(level: level, xp: xp, username: username, xpHistory: history);
  }

  @override
  void write(BinaryWriter writer, User obj) {
    writer.writeInt(obj.level);
    writer.writeInt(obj.xp);
    writer.writeInt(obj.xpHistory.length);
    for (final entry in obj.xpHistory.entries) {
      writer.writeString(entry.key);
      writer.writeInt(entry.value);
    }
    writer.writeString(obj.username);
  }
}
