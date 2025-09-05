
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseService {
  static const _databaseName = "butterfly.db";
  static const _databaseVersion = 1;

  static const tableHistory = 'history';

  static const columnId = 'id';
  static const columnType = 'type';
  static const columnCreationDate = 'creationDate';
  static const columnContent = 'content';
  static const columnShareDetails = 'shareDetails';

  // Make this a singleton class.
  DatabaseService._privateConstructor();
  static final DatabaseService instance = DatabaseService._privateConstructor();

  // Only have a single app-wide reference to the database.
  static Database? _database;
  Future<Database> get database async {
    if (_database != null) return _database!;
    // Lazily instantiate the db the first time it is accessed.
    _database = await _initDatabase();
    return _database!;
  }

  // This opens the database (and creates it if it doesn't exist).
  _initDatabase() async {
    String path = join(await getDatabasesPath(), _databaseName);
    return await openDatabase(path,
        version: _databaseVersion, onCreate: _onCreate);
  }

  // SQL code to create the database table.
  Future _onCreate(Database db, int version) async {
    await db.execute('''
          CREATE TABLE $tableHistory (
            $columnId INTEGER PRIMARY KEY AUTOINCREMENT,
            $columnType INTEGER NOT NULL,
            $columnCreationDate TEXT NOT NULL,
            $columnContent TEXT NOT NULL,
            $columnShareDetails TEXT
          )
          ''');
  }

  // For testing purposes only
  static void reset() {
    _database = null;
  }
}
