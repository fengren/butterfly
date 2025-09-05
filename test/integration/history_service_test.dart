
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:butterfly/shared/services/history_service.dart';
import 'package:butterfly/shared/models/history_item.dart';
import 'package:butterfly/shared/models/history_type.dart';
import 'package:butterfly/shared/models/share_details.dart';
import 'package:butterfly/shared/services/database_service.dart';

void main() {
  // Init ffi loader if needed.
  sqfliteFfiInit();

  group('HistoryService Tests', () {
    late HistoryService historyService;

    setUpAll(() {
      // Initialize FFI for all tests in this group
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      // Create a new service for each test to ensure isolation
      historyService = HistoryService();
      // Ensure the database is clean before each test
      final db = await historyService.dbService.database;
      await db.delete(DatabaseService.tableHistory); // Clear table
    });

    tearDown(() async {
      // Close the database after each test
      final db = await historyService.dbService.database;
      await db.close();
      // Reset the singleton for the next test
      DatabaseService.reset();
    });

    test('should add and retrieve a recording item', () async {
      final recordingItem = HistoryItem(
        type: HistoryType.recording,
        creationDate: DateTime.now(),
        content: '/path/to/recording.m4a',
      );

      await historyService.addHistoryItem(recordingItem);

      final items = await historyService.getHistoryItems();
      expect(items.length, 1);
      expect(items.first.type, HistoryType.recording);
      expect(items.first.content, '/path/to/recording.m4a');
    });

    test('should add and retrieve a share item', () async {
      final shareItem = HistoryItem(
        type: HistoryType.share,
        creationDate: DateTime.now(),
        content: 'This is a shared text',
        shareDetails: ShareDetails(
          url: 'https://example.com',
          sourceApp: 'Chrome',
        ),
      );

      await historyService.addHistoryItem(shareItem);

      final items = await historyService.getHistoryItems();
      expect(items.length, 1);
      expect(items.first.type, HistoryType.share);
      expect(items.first.content, 'This is a shared text');
      expect(items.first.shareDetails?.url, 'https://example.com');
    });

    test('should get items in descending order of creation date', () async {
      final item1 = HistoryItem(
        type: HistoryType.recording,
        creationDate: DateTime.now().subtract(const Duration(days: 1)),
        content: 'item1',
      );
      final item2 = HistoryItem(
        type: HistoryType.recording,
        creationDate: DateTime.now(),
        content: 'item2',
      );

      await historyService.addHistoryItem(item1);
      await historyService.addHistoryItem(item2);

      final items = await historyService.getHistoryItems();
      expect(items.length, 2);
      expect(items.first.content, 'item2');
      expect(items.last.content, 'item1');
    });

    test('should update an item', () async {
      final item = HistoryItem(
        type: HistoryType.share,
        creationDate: DateTime.now(),
        content: 'Original content',
      );

      final id = await historyService.addHistoryItem(item);

      final updatedItem = HistoryItem(
        id: id,
        type: HistoryType.share,
        creationDate: item.creationDate,
        content: 'Updated content',
      );

      await historyService.updateHistoryItem(updatedItem);

      final items = await historyService.getHistoryItems();
      expect(items.length, 1);
      expect(items.first.content, 'Updated content');
    });

    test('should delete an item', () async {
      final item = HistoryItem(
        type: HistoryType.recording,
        creationDate: DateTime.now(),
        content: 'to be deleted',
      );

      final id = await historyService.addHistoryItem(item);
      expect((await historyService.getHistoryItems()).length, 1);

      await historyService.deleteHistoryItem(id);
      expect((await historyService.getHistoryItems()).isEmpty, true);
    });
  });
}
