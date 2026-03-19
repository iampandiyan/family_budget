// lib/core/database/database_helper.dart
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('family_budget.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Create Tables
    await db.execute('''
      CREATE TABLE Budgets (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        start_date TEXT NOT NULL,
        end_date TEXT NOT NULL,
        initial_amount REAL NOT NULL,
        total_budget_amount REAL NOT NULL,
        currency TEXT NOT NULL
      )
      
    ''');
    await db.execute('''
      CREATE TABLE Budget_Items (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        allocated_amount REAL NOT NULL,
        FOREIGN KEY (budget_id) REFERENCES Budgets (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES Categories (id)
      )
    ''');


    await db.execute('''
      CREATE TABLE Categories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL,
        color TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Subcategories (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        category_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        FOREIGN KEY (category_id) REFERENCES Categories (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE Payment_Sources (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        icon TEXT NOT NULL
      )
    ''');

    await db.execute('''
      CREATE TABLE Expenses (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        budget_id INTEGER NOT NULL,
        category_id INTEGER NOT NULL,
        subcategory_id INTEGER,
        note TEXT,
        amount REAL NOT NULL,
        payment_source_id INTEGER NOT NULL,
        date TEXT NOT NULL,
        FOREIGN KEY (budget_id) REFERENCES Budgets (id) ON DELETE CASCADE,
        FOREIGN KEY (category_id) REFERENCES Categories (id),
        FOREIGN KEY (payment_source_id) REFERENCES Payment_Sources (id)
      )
    ''');

    // 2. Insert Default Categories
    final categories = [
      {'name': 'Housing', 'icon': '🏠', 'color': '0xFF4CAF50'}, // Green
      {'name': 'Food & Dining', 'icon': '🍔', 'color': '0xFFFF9800'}, // Orange
      {'name': 'Transportation', 'icon': '🚗', 'color': '0xFF2196F3'}, // Blue
      {'name': 'Shopping', 'icon': '🛍️', 'color': '0xFFE91E63'}, // Pink
      {'name': 'Health', 'icon': '💊', 'color': '0xFFF44336'}, // Red
    ];
    for (var cat in categories) {
      await db.insert('Categories', cat);
    }

    // 3. Insert Default Subcategories (Linked to Food & Dining - ID 2)
    final foodSubcategories = ['Groceries', 'Restaurants', 'Snacks'];
    for (var sub in foodSubcategories) {
      await db.insert('Subcategories', {'category_id': 2, 'name': sub});
    }

    // 4. Insert Default Payment Sources
    final sources = [
      {'name': 'Cash', 'icon': '💵'},
      {'name': 'Credit Card', 'icon': '💳'},
      {'name': 'Bank Account', 'icon': '🏦'},
      {'name': 'UPI / GPay', 'icon': '📱'},
      {'name': 'Debt / Borrowed', 'icon': '🤝'},
    ];
    for (var source in sources) {
      await db.insert('Payment_Sources', source);
    }
  }
}
