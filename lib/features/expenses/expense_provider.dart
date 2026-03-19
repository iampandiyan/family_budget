// lib/features/expenses/expense_provider.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/database/database_helper.dart';

class ExpenseProvider extends ChangeNotifier {
  List<Map<String, dynamic>> expenses = [];
  List<Map<String, dynamic>> budgets = [];
  List<Map<String, dynamic>> categories = [];
  List<Map<String, dynamic>> paymentSources = [];
  List<Map<String, dynamic>> dbSubcategories = [];

  int? filterBudgetId;
  int? filterCategoryId;
  int? filterSubcategoryId;

  // NEW: Date filters
  DateTime? filterStartDate;
  DateTime? filterEndDate;

  ExpenseProvider() {
    _initAndLoad();
  }

  Future<void> refreshData() async {
    final db = await DatabaseHelper.instance.database;
    budgets = await db.query('Budgets', orderBy: 'id DESC');
    categories = await db.query('Categories', orderBy: 'name ASC');
    dbSubcategories = await db.query('Subcategories', orderBy: 'name ASC');
    paymentSources = await db.query('Payment_Sources', orderBy: 'name ASC');

    if (filterBudgetId != null && !budgets.any((b) => b['id'] == filterBudgetId)) {
      filterBudgetId = null;
    }

    await loadExpenses();
  }

  Future<void> _initAndLoad() async {
    final db = await DatabaseHelper.instance.database;

    final res = await db.rawQuery('SELECT COUNT(*) as c FROM Payment_Sources');
    if ((res.first['c'] as int) == 0) {
      await db.insert('Payment_Sources', {'name': 'Cash', 'icon': '💵'});
      await db.insert('Payment_Sources', {'name': 'Credit Card', 'icon': '💳'});
      await db.insert('Payment_Sources', {'name': 'Online', 'icon': '📱'});
      await db.insert('Payment_Sources', {'name': 'Debt', 'icon': '🤝'});
    }

    paymentSources = await db.query('Payment_Sources');

    final currentBudgets = await db.query('Budgets', orderBy: 'id DESC');
    if (currentBudgets.isNotEmpty) {
      String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      var current = currentBudgets.where((b) {
        final start = (b['start_date'] as String?) ?? '';
        final end = (b['end_date'] as String?) ?? '';
        return start.compareTo(today) <= 0 && end.compareTo(today) >= 0;
      }).toList();
      filterBudgetId = current.isNotEmpty ? current.first['id'] as int : currentBudgets.first['id'] as int;
    }

    await refreshData();
  }

  Future<List<Map<String, dynamic>>> getCategoriesForBudget(int budgetId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT c.id, c.name, c.icon 
      FROM Budget_Items bi
      INNER JOIN Categories c ON bi.category_id = c.id
      WHERE bi.budget_id = ?
      ORDER BY c.name ASC
    ''', [budgetId]);
  }

  Future<List<Map<String, dynamic>>> getSubcategoriesForCategory(int categoryId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.query(
        'Subcategories',
        where: 'category_id = ?',
        whereArgs: [categoryId],
        orderBy: 'name ASC'
    );
  }

  Future<void> loadExpenses() async {
    final db = await DatabaseHelper.instance.database;
    String where = '1=1';
    List<dynamic> args = [];

    if (filterBudgetId != null) {
      where += ' AND e.budget_id = ?';
      args.add(filterBudgetId);
    }
    if (filterCategoryId != null) {
      where += ' AND e.category_id = ?';
      args.add(filterCategoryId);
    }
    if (filterSubcategoryId != null) {
      where += ' AND e.subcategory_id = ?';
      args.add(filterSubcategoryId);
    }

    // NEW: Apply Date Filtering to the SQL Query
    if (filterStartDate != null) {
      where += ' AND e.date >= ?';
      args.add(DateFormat('yyyy-MM-dd').format(filterStartDate!));
    }
    if (filterEndDate != null) {
      where += ' AND e.date <= ?';
      args.add(DateFormat('yyyy-MM-dd').format(filterEndDate!));
    }

    expenses = await db.rawQuery('''
      SELECT e.*, 
             b.name as budget_name, b.currency, 
             c.name as category_name, c.icon as category_icon, 
             ps.name as payment_source_name,
             sc.name as subcategory_name
      FROM Expenses e
      LEFT JOIN Budgets b ON e.budget_id = b.id
      LEFT JOIN Categories c ON e.category_id = c.id
      LEFT JOIN Payment_Sources ps ON e.payment_source_id = ps.id
      LEFT JOIN Subcategories sc ON e.subcategory_id = sc.id
      WHERE $where
      ORDER BY e.date DESC, e.id DESC
    ''', args);

    notifyListeners();
  }

  // NEW: Updated setFilters to accommodate dates
  void setFilters({
    int? budgetId,
    int? categoryId,
    int? subcategoryId,
    DateTime? startDate,
    DateTime? endDate,
    bool clearCat = false,
    bool clearSub = false,
    bool clearBudget = false,
    bool clearDates = false
  }) {
    if (clearBudget) filterBudgetId = null;
    else if (budgetId != null) filterBudgetId = budgetId;

    if (clearCat) filterCategoryId = null;
    else if (categoryId != null) filterCategoryId = categoryId;

    if (clearSub) filterSubcategoryId = null;
    else if (subcategoryId != null) filterSubcategoryId = subcategoryId;

    if (clearDates) {
      filterStartDate = null;
      filterEndDate = null;
    } else {
      if (startDate != null) filterStartDate = startDate;
      if (endDate != null) filterEndDate = endDate;
    }

    loadExpenses();
  }

  Future<void> addExpense(Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    await db.insert('Expenses', data);
    await loadExpenses();
  }

  Future<void> updateExpense(int id, Map<String, dynamic> data) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('Expenses', data, where: 'id = ?', whereArgs: [id]);
    await loadExpenses();
  }

  Future<void> deleteExpense(int id) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Expenses', where: 'id = ?', whereArgs: [id]);
    await loadExpenses();
  }
}
