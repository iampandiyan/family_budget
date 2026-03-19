// lib/features/budget/budget_detail_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'budget_provider.dart';
import 'add_budget_screen.dart';

class BudgetDetailScreen extends StatefulWidget {
  final int budgetId;
  const BudgetDetailScreen({super.key, required this.budgetId});

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  Future<void> _handleDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Confirm Deletion', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this budget? All linked expenses will also be permanently deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      final provider = Provider.of<BudgetProvider>(context, listen: false);
      await provider.deleteBudget(widget.budgetId);

      if (!mounted) return;
      Navigator.pop(context);
    }
  }

  Widget _buildBoxContainer({required Widget child}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
      ),
      child: child,
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Budget Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AddBudgetScreen(existingBudgetId: widget.budgetId))),
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _handleDelete,
          ),
        ],
      ),
      body: FutureBuilder<Map<String, dynamic>>(
        future: Provider.of<BudgetProvider>(context).getBudgetDetails(widget.budgetId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final data = snapshot.data!;
          final budget = data['budget'] as Map<String, dynamic>? ?? {};
          final categories = data['categories'] as List<Map<String, dynamic>>? ?? [];
          final paymentSources = data['payment_sources'] as Map<String, double>? ?? {};

          if (budget.isEmpty) return const Center(child: Text('Budget not found'));

          final totalBudget = (budget['total_budget_amount'] as num).toDouble();
          final initialAmount = (budget['initial_amount'] as num).toDouble();
          final startDate = DateFormat('dd MMM yy').format(DateTime.parse(budget['start_date']));
          final endDate = DateFormat('dd MMM yy').format(DateTime.parse(budget['end_date']));
          final currency = budget['currency'];

          double totalSpent = 0;
          for (var cat in categories) {
            totalSpent += (cat['spent_amount'] as num).toDouble();
          }

          final budgetDiff = totalBudget - totalSpent;
          final remainingBal = initialAmount - totalSpent;

          Color spentColor = totalSpent > totalBudget ? Colors.red : Colors.green;
          Color budgetDiffColor = budgetDiff < 0 ? Colors.red : Colors.green;
          Color remainingBalColor = remainingBal < 0 ? Colors.red : Colors.green;

          double progressValue = totalBudget > 0 ? (totalSpent / totalBudget).clamp(0.0, 1.0) : 0.0;
          double progressPercentage = totalBudget > 0 ? (totalSpent / totalBudget * 100) : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Budget Header Details
                _buildBoxContainer(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(child: Text(budget['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor))),
                          Text('$startDate  →  $endDate', style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8.0),
                        child: Divider(height: 1),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Initial Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('$currency ${initialAmount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Budget Allocation', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('$currency ${totalBudget.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Spent', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('$currency ${totalSpent.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: spentColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(budgetDiff < 0 ? 'Over Budget' : 'Left Budget', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('$currency ${budgetDiff.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: budgetDiffColor)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Remaining Balance', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                          Text('$currency ${remainingBal.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: remainingBalColor)),
                        ],
                      ),

                      const SizedBox(height: 16),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(
                          value: progressValue,
                          minHeight: 8,
                          backgroundColor: Colors.grey.shade200,
                          valueColor: AlwaysStoppedAnimation<Color>(progressPercentage > 90 ? Colors.red : primaryColor),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Align(
                        alignment: Alignment.centerRight,
                        child: Text(
                          '${progressPercentage.toStringAsFixed(1)}% of budget used',
                          style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),

                // 2. Spent By Payment Source
                if (paymentSources.isNotEmpty) ...[
                  Text('Payment Sources', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                  const SizedBox(height: 8),
                  _buildBoxContainer(
                    child: Column(
                      children: paymentSources.entries.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6.0),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                              Text('$currency ${entry.value.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: primaryColor)),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],

                // 3. Allocations & Expenses List
                Text('Allocations & Expenses', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                const SizedBox(height: 8),

                if (categories.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.only(top: 20), child: Text('No allocations recorded.', style: TextStyle(color: Colors.grey.shade500, fontSize: 13))))
                else
                  ...categories.map((cat) {
                    final allocated = (cat['allocated_amount'] as num).toDouble();
                    final spent = (cat['spent_amount'] as num).toDouble();
                    final diff = allocated - spent;
                    final expensesList = cat['expenses'] as List<dynamic>? ?? [];

                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
                      ),
                      child: Theme(
                        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: Text(cat['cat_icon'] ?? '📁', style: const TextStyle(fontSize: 20)),
                          title: Text(cat['cat_name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text('Allocated: $currency${allocated.toStringAsFixed(2)} | Spent: $currency${spent.toStringAsFixed(2)}', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                              Text('${diff < 0 ? 'Over' : 'Left'}: $currency${diff.abs().toStringAsFixed(2)}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: diff < 0 ? Colors.red : Colors.green)),
                            ],
                          ),
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12))),
                              child: expensesList.isEmpty
                                  ? Center(child: Text('No expenses recorded', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)))
                                  : Column(
                                children: expensesList.map((e) {
                                  final expense = e as Map<String, dynamic>;

                                  // 1. Get raw string data safely
                                  String subCatRaw = (expense['sub_category_name'] ?? '').toString().trim();
                                  String noteRaw = (expense['note'] ?? '').toString().trim();

                                  // 2. Remove accidental placeholder text if it saved to the database in earlier tests
                                  if (subCatRaw.toLowerCase().contains('sub category') || subCatRaw.toLowerCase().contains('expense')) subCatRaw = '';
                                  if (noteRaw.toLowerCase().contains('sub category') || noteRaw.toLowerCase().contains('expense')) noteRaw = '';

                                  // 3. Apply the display format dynamically
                                  String displayName = '';

                                  if (subCatRaw.isNotEmpty && noteRaw.isNotEmpty) {
                                    displayName = '$subCatRaw - $noteRaw';
                                  } else if (subCatRaw.isNotEmpty) {
                                    displayName = subCatRaw;
                                  } else if (noteRaw.isNotEmpty) {
                                    displayName = noteRaw;
                                  } else {
                                    // YOUR REQUEST: The literal fallback text when BOTH are completely empty
                                    displayName = 'Sub category - Note';
                                  }

                                  final double amount = (expense['amount'] as num?)?.toDouble() ?? 0.0;
                                  final String date = expense['date']?.toString() ?? '';
                                  final String source = expense['payment_source']?.toString() ?? 'Cash';

                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 10),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                              const SizedBox(height: 2),
                                              Text('$date • $source', style: TextStyle(color: Colors.grey.shade600, fontSize: 11)),
                                            ],
                                          ),
                                        ),
                                        Text('$currency${amount.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14)),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
              ],
            ),
          );
        },
      ),
    );
  }
}
