// lib/features/expenses/expenses_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';
import 'expense_provider.dart';
import 'add_expense_screen.dart';

class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    Future.microtask(() => provider.refreshData());
  }

  Future<void> _exportData(ExpenseProvider provider) async {
    try {
      // If no data for current filters, show message and exit
      if (provider.expenses.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No data available for this filter')),
        );
        return;
      }

      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln("Date,Budget,Category,Subcategory,Amount,Payment Source,Note");
      for (var exp in provider.expenses) {
        final date = exp['date'] ?? '';
        final budget = (exp['budget_name'] ?? '').toString().replaceAll(',', ' ');
        final category = (exp['category_name'] ?? '').toString().replaceAll(',', ' ');
        final subcategory = (exp['subcategory_name'] ?? '').toString().replaceAll(',', ' ');
        final amount = exp['amount'].toString();
        final payment = (exp['payment_source_name'] ?? '').toString().replaceAll(',', ' ');
        final note = (exp['note'] ?? '').toString().replaceAll(',', ' ').replaceAll('\n', ' ');
        csvBuffer.writeln("$date,$budget,$category,$subcategory,$amount,$payment,$note");
      }

      final dir = await getTemporaryDirectory();
      final path = "${dir.path}/Expenses_Export.csv";
      final file = File(path);
      await file.writeAsString(csvBuffer.toString());

      final params = ShareParams(files: [XFile(path)], subject: 'My Expenses Data');
      await SharePlus.instance.share(params);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e')),
      );
    }
  }


  void _showOptions(Map<String, dynamic> exp) {
    final expenseProvider = Provider.of<ExpenseProvider>(context, listen: false);
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
                leading: Icon(Icons.edit, color: primaryColor),
                title: const Text('Edit Expense', style: TextStyle(fontWeight: FontWeight.bold)),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => AddExpenseScreen(existingExpense: exp)));
                }
            ),
            ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Delete Expense', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                onTap: () async {
                  Navigator.pop(ctx);
                  await expenseProvider.deleteExpense(exp['id']);
                }
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickDateRange(BuildContext context, ExpenseProvider provider) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: provider.filterStartDate != null && provider.filterEndDate != null
          ? DateTimeRange(start: provider.filterStartDate!, end: provider.filterEndDate!)
          : null,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            appBarTheme: const AppBarTheme(iconTheme: IconThemeData(color: Colors.white)),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      provider.setFilters(startDate: picked.start, endDate: picked.end);
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expenses'),
        actions: [
          // FIX: Changed to TextButton.icon to clearly show the word "Export"
          TextButton.icon(
            icon: const Icon(Icons.download, color: Colors.white),
            label: const Text('Export', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            onPressed: () => _exportData(Provider.of<ExpenseProvider>(context, listen: false)),
          ),
        ],
      ),
      body: Consumer<ExpenseProvider>(
        builder: (context, provider, child) {
          int? validBudgetId = provider.filterBudgetId;
          if (validBudgetId != null && !provider.budgets.any((b) => b['id'] == validBudgetId)) {
            validBudgetId = null;
          }

          // Format Date Range Text
          String dateRangeText = 'Filter by Date Range';
          if (provider.filterStartDate != null && provider.filterEndDate != null) {
            dateRangeText = '${DateFormat('MMM dd, yyyy').format(provider.filterStartDate!)} - ${DateFormat('MMM dd, yyyy').format(provider.filterEndDate!)}';
          }

          return Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
                child: Column(
                  children: [
                    DropdownButtonFormField<int?>(
                      key: ValueKey(validBudgetId),
                      isExpanded: true,
                      decoration: const InputDecoration(hintText: 'Filter by Budget', isDense: true),
                      value: validBudgetId,
                      items: [
                        const DropdownMenuItem<int?>(value: null, child: Text('All Budgets', style: TextStyle(fontWeight: FontWeight.bold))),
                        ...provider.budgets.map((b) => DropdownMenuItem<int?>(value: b['id'] as int, child: Text(b['name'], style: const TextStyle(fontSize: 14)))),
                      ],
                      onChanged: (val) => provider.setFilters(budgetId: val, clearBudget: val == null),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(provider.filterCategoryId),
                            isExpanded: true,
                            decoration: const InputDecoration(hintText: 'Category', isDense: true),
                            value: provider.filterCategoryId,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('All Categories', style: TextStyle(fontSize: 13))),
                              ...provider.categories.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['name'], style: const TextStyle(fontSize: 13)))),
                            ],
                            onChanged: (val) => provider.setFilters(categoryId: val, clearCat: val == null),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: ValueKey(provider.filterSubcategoryId),
                            isExpanded: true,
                            decoration: const InputDecoration(hintText: 'Subcategory', isDense: true),
                            value: provider.filterSubcategoryId,
                            items: [
                              const DropdownMenuItem<int?>(value: null, child: Text('All Subcategories', style: TextStyle(fontSize: 13))),
                              ...provider.dbSubcategories.map((s) => DropdownMenuItem<int?>(value: s['id'] as int, child: Text(s['name'], style: const TextStyle(fontSize: 13)))),
                            ],
                            onChanged: (val) => provider.setFilters(subcategoryId: val, clearSub: val == null),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // NEW: Date Range Filter Button
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => _pickDateRange(context, provider),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade400),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dateRangeText,
                                    style: TextStyle(
                                      color: provider.filterStartDate != null ? primaryColor : Colors.grey.shade700,
                                      fontWeight: provider.filterStartDate != null ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Icon(Icons.calendar_month, size: 18, color: Colors.grey.shade600),
                                ],
                              ),
                            ),
                          ),
                        ),
                        if (provider.filterStartDate != null) ...[
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.clear, color: Colors.red),
                            tooltip: 'Clear Dates',
                            onPressed: () => provider.setFilters(clearDates: true),
                          )
                        ]
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: provider.expenses.isEmpty
                    ? const Center(child: Text('No expenses found for these filters.', style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: provider.expenses.length,
                  itemBuilder: (ctx, index) {
                    final exp = provider.expenses[index];

                    String subCat = (exp['subcategory_name'] ?? '').toString();
                    String displaySubtitle = exp['date'];
                    if (subCat.isNotEmpty) {
                      displaySubtitle += ' • $subCat';
                    }

                    return Card(
                      elevation: 0,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(color: Colors.grey.shade100, shape: BoxShape.circle),
                          child: Text(exp['category_icon'] ?? '🧾', style: const TextStyle(fontSize: 20)),
                        ),
                        title: Text(exp['category_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                        subtitle: Text(displaySubtitle, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text('${exp['currency'] ?? ''} ${(exp['amount'] as num).toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.redAccent)),
                            const SizedBox(height: 2),
                            Text(exp['payment_source_name'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                          ],
                        ),
                        onTap: () => _showOptions(exp),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AddExpenseScreen())),
        icon: const Icon(Icons.add),
        label: const Text('Add Expense'),
      ),
    );
  }
}
