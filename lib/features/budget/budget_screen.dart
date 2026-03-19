// lib/features/budget/budget_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'budget_provider.dart';
import 'budget_detail_screen.dart';
import 'add_budget_screen.dart';

class BudgetScreen extends StatelessWidget {
  const BudgetScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Budgets')),
      body: Consumer<BudgetProvider>(
        builder: (context, provider, child) {
          if (provider.budgets.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 60, color: Colors.grey),
                    SizedBox(height: 16),
                    Text('No budgets created yet', style: TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.bold)),
                    SizedBox(height: 8),
                    Text('Tap the + button to create your first budget', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  ],
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: provider.budgets.length,
            itemBuilder: (context, index) {
              final b = provider.budgets[index];
              final totalBudget = (b['total_budget_amount'] as num).toDouble();
              final totalSpent = (b['total_spent'] as num).toDouble();

              // NEW: Conditional coloring
              final spentColor = totalSpent <= totalBudget ? Colors.green : Colors.red;

              return Card(
                elevation: 1,
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  title: Text(
                    b['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  subtitle: Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // NEW: Side-by-side Budget and Spent comparison
                        Row(
                          children: [
                            Text(
                                'Budget: ${b['currency']} ${totalBudget.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)
                            ),
                            const SizedBox(width: 12),
                            Text(
                                'Spent: ${b['currency']} ${totalSpent.toStringAsFixed(0)}',
                                style: TextStyle(fontSize: 13, color: spentColor, fontWeight: FontWeight.bold)
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text('${b['start_date']} to ${b['end_date']}', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => BudgetDetailScreen(budgetId: b['id']),
                      ),
                    );
                  },
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: null,
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddBudgetScreen()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('New Budget'),
      ),
    );
  }
}
