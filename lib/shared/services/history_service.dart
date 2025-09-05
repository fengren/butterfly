
import 'package:butterfly/shared/models/history_item.dart';
import 'package:butterfly/shared/services/database_service.dart';

class HistoryService {
  final dbService = DatabaseService.instance;

  Future<int> addHistoryItem(HistoryItem item) async {
    final db = await dbService.database;
    return await db.insert(DatabaseService.tableHistory, item.toMap());
  }

  Future<List<HistoryItem>> getHistoryItems() async {
    final db = await dbService.database;
    final List<Map<String, dynamic>> maps = await db.query(
      DatabaseService.tableHistory,
      orderBy: '${DatabaseService.columnCreationDate} DESC',
    );

    if (maps.isEmpty) {
      return [];
    }

    return List.generate(maps.length, (i) {
      return HistoryItem.fromMap(maps[i]);
    });
  }

  Future<int> updateHistoryItem(HistoryItem item) async {
    final db = await dbService.database;
    return await db.update(
      DatabaseService.tableHistory,
      item.toMap(),
      where: '${DatabaseService.columnId} = ?',
      whereArgs: [item.id],
    );
  }

  Future<int> deleteHistoryItem(int id) async {
    final db = await dbService.database;
    return await db.delete(
      DatabaseService.tableHistory,
      where: '${DatabaseService.columnId} = ?',
      whereArgs: [id],
    );
  }
}
