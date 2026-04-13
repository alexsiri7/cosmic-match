import 'package:hive/hive.dart';

class LevelProgress {
  final int levelId;
  int stars;
  int highScore;
  bool completed;

  LevelProgress({
    required this.levelId,
    this.stars = 0,
    this.highScore = 0,
    this.completed = false,
  });
}

class LevelProgressAdapter extends TypeAdapter<LevelProgress> {
  @override
  final int typeId = 0;

  @override
  LevelProgress read(BinaryReader reader) {
    final numFields = reader.readByte();
    final fields = <int, dynamic>{};
    for (int i = 0; i < numFields; i++) {
      fields[reader.readByte()] = reader.read();
    }
    return LevelProgress(
      levelId: fields[0] as int,
      stars: fields[1] as int? ?? 0,
      highScore: fields[2] as int? ?? 0,
      completed: fields[3] as bool? ?? false,
    );
  }

  @override
  void write(BinaryWriter writer, LevelProgress obj) {
    writer.writeByte(4); // number of fields
    writer.writeByte(0);
    writer.write(obj.levelId);
    writer.writeByte(1);
    writer.write(obj.stars);
    writer.writeByte(2);
    writer.write(obj.highScore);
    writer.writeByte(3);
    writer.write(obj.completed);
  }
}
