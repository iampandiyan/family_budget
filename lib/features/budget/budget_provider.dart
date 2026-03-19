// lib/features/budget/budget_provider.dart
import 'package:flutter/material.dart';
import '../../core/database/database_helper.dart';

class BudgetProvider extends ChangeNotifier {
  List<Map<String, dynamic>> budgets = [];
  List<Map<String, dynamic>> categories = [];

  BudgetProvider() {
    loadData();
  }

  Future<void> loadData() async {
    final db = await DatabaseHelper.instance.database;
    budgets = await db.rawQuery('''
      SELECT b.*, COALESCE(SUM(e.amount), 0) as total_spent
      FROM Budgets b
      LEFT JOIN Expenses e ON b.id = e.budget_id
      GROUP BY b.id
      ORDER BY b.id DESC
    ''');
    categories = await db.query('Categories');
    notifyListeners();
  }

  Future<void> addBudget(Map<String, dynamic> budgetData, List<Map<String, dynamic>> items) async {
    final db = await DatabaseHelper.instance.database;
    int budgetId = await db.insert('Budgets', budgetData);
    for (var item in items) {
      await db.insert('Budget_Items', {
        'budget_id': budgetId,
        'category_id': item['category_id'],
        'allocated_amount': item['amount'],
      });
    }
    await loadData();
  }

  Future<void> updateBudget(int budgetId, Map<String, dynamic> budgetData, List<Map<String, dynamic>> items) async {
    final db = await DatabaseHelper.instance.database;
    await db.update('Budgets', budgetData, where: 'id = ?', whereArgs: [budgetId]);

    await db.delete('Budget_Items', where: 'budget_id = ?', whereArgs: [budgetId]);
    for (var item in items) {
      await db.insert('Budget_Items', {
        'budget_id': budgetId,
        'category_id': item['category_id'],
        'allocated_amount': item['amount'],
      });
    }
    await loadData();
  }

  Future<Map<String, dynamic>> getBudgetDetails(int budgetId) async {
    final db = await DatabaseHelper.instance.database;
    final budgetRes = await db.query('Budgets', where: 'id = ?', whereArgs: [budgetId]);

    final budgetItemsRes = await db.rawQuery('''
      SELECT bi.allocated_amount, c.id as cat_id, c.name as cat_name, c.icon as cat_icon
      FROM Budget_Items bi
      JOIN Categories c ON bi.category_id = c.id
      WHERE bi.budget_id = ?
      ORDER BY c.name
    ''', [budgetId]);

    // FIX: Perfectly matched with your DB schema: 'Subcategories' table and 'subcategory_id'
    final expensesRes = await db.rawQuery('''
      SELECT e.id, e.category_id, e.amount, COALESCE(e.note, '') as note, e.date, 
             COALESCE(ps.name, 'Cash') as payment_source,
             COALESCE(sc.name, '') as sub_category_name
      FROM Expenses e
      LEFT JOIN Payment_Sources ps ON e.payment_source_id = ps.id
      LEFT JOIN Subcategories sc ON e.subcategory_id = sc.id
      WHERE e.budget_id = ?
      ORDER BY e.date DESC
    ''', [budgetId]);

    List<Map<String, dynamic>> categoriesList = [];
    Map<String, double> paymentSourceTotals = {};

    for (var item in budgetItemsRes) {
      double allocated = (item['allocated_amount'] as num).toDouble();
      int catId = item['cat_id'] as int;

      var catExpenses = expensesRes.where((e) => e['category_id'] == catId).toList();
      double spent = 0.0;

      for (var e in catExpenses) {
        double amt = (e['amount'] as num).toDouble();
        spent += amt;

        String ps = e['payment_source'] as String;
        paymentSourceTotals[ps] = (paymentSourceTotals[ps] ?? 0.0) + amt;
      }

      categoriesList.add({
        'cat_id': catId,
        'cat_name': item['cat_name'],
        'cat_icon': item['cat_icon'],
        'allocated_amount': allocated,
        'spent_amount': spent,
        'expenses': catExpenses,
      });
    }

    return {
      'budget': budgetRes.isNotEmpty ? budgetRes.first : {},
      'categories': categoriesList,
      'payment_sources': paymentSourceTotals,
    };
  }

  Future<List<Map<String, dynamic>>> getBudgetItems(int budgetId) async {
    final db = await DatabaseHelper.instance.database;
    return await db.rawQuery('''
      SELECT Budget_Items.category_id, Budget_Items.allocated_amount AS amount, Categories.name, Categories.icon
      FROM Budget_Items
      INNER JOIN Categories ON Budget_Items.category_id = Categories.id
      WHERE Budget_Items.budget_id = ?
    ''', [budgetId]);
  }

  Future<void> deleteBudget(int budgetId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Budgets', where: 'id = ?', whereArgs: [budgetId]);
    await db.delete('Budget_Items', where: 'budget_id = ?', whereArgs: [budgetId]);
    await db.delete('Expenses', where: 'budget_id = ?', whereArgs: [budgetId]);
    await loadData();
  }

  Future<void> deleteBudgetItem(int budgetId, int categoryId) async {
    final db = await DatabaseHelper.instance.database;
    await db.delete('Budget_Items', where: 'budget_id = ? AND category_id = ?', whereArgs: [budgetId, categoryId]);
    await db.delete('Expenses', where: 'budget_id = ? AND category_id = ?', whereArgs: [budgetId, categoryId]);
  }
}
