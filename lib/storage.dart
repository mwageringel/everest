import 'package:everest/game.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:localstorage/localstorage.dart';

abstract class DatabaseWrapper {
  bool isUsable() => true;
  Future<void> storeAnswer(Level level, Question question);
  Future<Map<String, String>> loadAnswers(List<Level> levels);
  Future<void> deleteAnswers(List<Level> levels);
  Future<String?> loadKeyValue(String key);
  Future<void> storeKeyValue(String key, String value);

  static Future<DatabaseWrapper> create() async {
    if (kIsWeb) {
      final storage = LocalStorage('everest-data.json');
      await storage.ready;
      return WebStorageDatabaseWrapper(storage);
    } else {
      Database? db;
      try {
        db = await openDatabase(
          join(await getDatabasesPath(), 'everest-data.db'),
          onCreate: (db, version) async {
            // note that adding additional tables to existing database file requires some extra steps
            await db.execute(
              'CREATE TABLE $tableKV($columnKey TEXT PRIMARY KEY, $columnValue TEXT)',
            );
            await db.execute(
              'CREATE TABLE $tableAnswers($columnId TEXT PRIMARY KEY, $columnLevel TEXT, $columnQuestion TEXT, $columnInputs TEXT)',
            );
          },
          version: 1,
        );
      } on MissingPluginException {
        db = null;  // database is not available (should not happen on supported platforms anymore)
      }
      return SqfliteDatabaseWrapper(db);
    }
  }
}

class SqfliteDatabaseWrapper extends DatabaseWrapper {
  final Database? db;
  SqfliteDatabaseWrapper(this.db);

  @override
  bool isUsable() => db != null;

  @override
  Future<void> storeAnswer(Level level, Question question) async {
    await db?.insert(tableAnswers, question.toMap(level), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  @override
  Future<Map<String, String>> loadAnswers(List<Level> levels) async {
    if (db != null) {
      List<Map> maps = await (db!.query(tableAnswers, columns: [columnId, columnInputs]));
      // map from fullId to stringified answer
      return Map.fromEntries(maps.expand((m) {
        final id = m[columnId];
        final answer = m[columnInputs];
        return (id == null || answer == null) ? [] : [MapEntry(id , answer)];
      }));
    } else {
      return Future.value({});
    }
  }

  @override
  Future<void> deleteAnswers(List<Level> levels) async {
    if (db != null) {
      await db!.delete(tableAnswers);
    }
  }

  @override
  Future<String?> loadKeyValue(String key) async {
    if (db != null) {
      List<Map> maps = await db!.query(tableKV,
        where: '$columnKey = ?',
        whereArgs: [key],
      );
      return maps.isNotEmpty ? maps.first[columnValue] : null;
    } else {
      return null;
    }
  }

  @override
  Future<void> storeKeyValue(String key, String value) async {
    if (db != null) {
      await db!.insert(tableKV, {columnKey: key, columnValue: value}, conflictAlgorithm: ConflictAlgorithm.replace);
    }
  }
}

class WebStorageDatabaseWrapper extends DatabaseWrapper {
  final LocalStorage storage;
  WebStorageDatabaseWrapper(this.storage);

  @override
  Future<void> storeAnswer(Level level, Question question) {
    final item = question.toMap(level);
    return storage.setItem(item[columnId]!, item);
  }

  @override
  Future<Map<String, String>> loadAnswers(List<Level> levels) async {
    Map<String, String> result = {};
    for (final level in levels) {
      for (final question in level.exercise.questions.followedBy(level.exam.questions)) {
        final id = question.fullId(level);
        dynamic m = storage.getItem(id);
        if (m != null && m[columnId] != null) {
          String? answer = m[columnInputs] is String ? m[columnInputs] : null;
          if (answer != null) {
            result[id] = answer;
          }
        }
      }
    }
    return result;
  }

  @override
  Future<void> deleteAnswers(List<Level> levels) async {
    Iterable<Future<void>> deletions = levels.expand((level) =>
      level.exercise.questions
      .followedBy(level.exam.questions)
      .map((question) => storage.deleteItem(question.fullId(level)))
    );
    await Future.wait(deletions);
  }

  @override
  Future<String?> loadKeyValue(String key) async {
    dynamic value = storage.getItem(key);
    return value is String ? value : null;
  }

  @override
  Future<void> storeKeyValue(String key, String value) {
    return storage.setItem(key, value);
  }
}
