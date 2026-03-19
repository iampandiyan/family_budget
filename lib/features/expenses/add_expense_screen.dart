// lib/features/expenses/add_expense_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';
import 'expense_provider.dart';
import '../budget/budget_provider.dart';

class AddExpenseScreen extends StatefulWidget {
  final Map<String, dynamic>? existingExpense;
  const AddExpenseScreen({super.key, this.existingExpense});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  int? _selectedBudgetId;
  int? _selectedCategoryId;
  int? _selectedSubcategoryId;
  int? _selectedPaymentSourceId;
  DateTime _selectedDate = DateTime.now();
  String _currencySymbol = '';

  List<Map<String, dynamic>> _filteredCategories = [];
  List<Map<String, dynamic>> _filteredSubcategories = [];

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<ExpenseProvider>(context, listen: false);

    provider.refreshData().then((_) {
      if (!mounted) return;

      if (widget.existingExpense != null) {
        final exp = widget.existingExpense!;
        setState(() {
          _selectedBudgetId = exp['budget_id'];
          _selectedCategoryId = exp['category_id'];
          _selectedSubcategoryId = exp['subcategory_id'];
          _selectedPaymentSourceId = exp['payment_source_id'];
          _amountController.text = exp['amount'].toString();
          _noteController.text = exp['note'] ?? '';
          _selectedDate = DateTime.parse(exp['date']);
        });
      } else {
        setState(() {
          _selectedBudgetId = provider.filterBudgetId ?? (provider.budgets.isNotEmpty ? provider.budgets.first['id'] : null);
          _selectedPaymentSourceId = provider.paymentSources.isNotEmpty ? provider.paymentSources.first['id'] : null;
        });
      }
      _onBudgetChanged();
      if (_selectedCategoryId != null) {
        _onCategoryChanged(_selectedCategoryId!);
      }
    });
  }

  Future<void> _onBudgetChanged() async {
    if (_selectedBudgetId == null) return;

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final budget = provider.budgets.firstWhere((b) => b['id'] == _selectedBudgetId, orElse: () => {});

    if (budget.isNotEmpty) {
      final currencyCode = budget['currency'];
      final currency = CurrencyService().findByCode(currencyCode);
      final catList = await provider.getCategoriesForBudget(_selectedBudgetId!);

      bool resetCategory = _selectedCategoryId != null && !catList.any((c) => c['id'] == _selectedCategoryId);

      if (!mounted) return;
      setState(() {
        _currencySymbol = currency?.symbol ?? currencyCode;
        _filteredCategories = catList;
        if (resetCategory) {
          _selectedCategoryId = null;
          _selectedSubcategoryId = null;
          _filteredSubcategories = [];
        }
      });
    }
  }

  Future<void> _onCategoryChanged(int categoryId) async {
    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final subcats = await provider.getSubcategoriesForCategory(categoryId);

    bool resetSubcat = _selectedSubcategoryId != null && !subcats.any((s) => s['id'] == _selectedSubcategoryId);

    if (!mounted) return;
    setState(() {
      _filteredSubcategories = subcats;
      if (resetSubcat) _selectedSubcategoryId = null;
    });
  }

  Future<void> _saveExpense() async {
    if (_selectedBudgetId == null || _selectedCategoryId == null || _amountController.text.isEmpty || _selectedPaymentSourceId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    final provider = Provider.of<ExpenseProvider>(context, listen: false);
    final budget = provider.budgets.firstWhere((b) => b['id'] == _selectedBudgetId);
    final start = DateTime.parse(budget['start_date']);
    final end = DateTime.parse(budget['end_date']);
    final dateOnly = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);

    if (dateOnly.isBefore(start) || dateOnly.isAfter(end)) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Date must be within budget bounds: ${budget['start_date']} to ${budget['end_date']}'),
        backgroundColor: Colors.red,
      ));
      return;
    }

    final data = {
      'budget_id': _selectedBudgetId,
      'category_id': _selectedCategoryId,
      'subcategory_id': _selectedSubcategoryId,
      'payment_source_id': _selectedPaymentSourceId,
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'note': _noteController.text.trim(),
      'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
    };

    if (widget.existingExpense == null) {
      await provider.addExpense(data);
    } else {
      await provider.updateExpense(widget.existingExpense!['id'], data);
    }

    if (!mounted) return;
    Provider.of<BudgetProvider>(context, listen: false).loadData();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final provider = Provider.of<ExpenseProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: Text(widget.existingExpense == null ? 'New Expense' : 'Edit Expense')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(hintText: 'Select Budget', labelText: 'Budget', isDense: true),
                          value: _selectedBudgetId,
                          items: provider.budgets.map((b) => DropdownMenuItem(value: b['id'] as int, child: Text(b['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))).toList(),
                          onChanged: (val) {
                            setState(() => _selectedBudgetId = val);
                            _onBudgetChanged();
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 4,
                        child: InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2030));
                            if (picked != null) setState(() => _selectedDate = picked);
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
                            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                            child: Text(DateFormat('dd MMM yy').format(_selectedDate), style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor, fontSize: 13), textAlign: TextAlign.center),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(hintText: 'Category', labelText: 'Category', isDense: true),
                          value: _selectedCategoryId,
                          items: _filteredCategories.map((c) => DropdownMenuItem(value: c['id'] as int, child: Text('${c['icon']} ${c['name']}', style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) {
                            setState(() => _selectedCategoryId = val);
                            if (val != null) _onCategoryChanged(val);
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(hintText: 'Subcategory (Optional)', labelText: 'Subcategory', isDense: true),
                          value: _selectedSubcategoryId,
                          items: _filteredSubcategories.map((s) => DropdownMenuItem(value: s['id'] as int, child: Text(s['name'], style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) => setState(() => _selectedSubcategoryId = val),
                        ),
                      ),
                    ],
                  ),
                  if (_selectedBudgetId != null && _filteredCategories.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text('No allocations exist for this budget. Please add items in the Budget tab first.', style: TextStyle(color: Colors.red.shade700, fontSize: 12, fontWeight: FontWeight.bold)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade300)),
              child: Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: primaryColor),
                          decoration: InputDecoration(
                            labelText: 'Amount',
                            prefixIcon: Padding(padding: const EdgeInsets.all(14), child: Text(_currencySymbol, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor))),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          isExpanded: true,
                          decoration: const InputDecoration(labelText: 'Payment Source', isDense: true),
                          value: _selectedPaymentSourceId,
                          items: provider.paymentSources.map((ps) => DropdownMenuItem(value: ps['id'] as int, child: Text(ps['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)))).toList(),
                          onChanged: (val) => setState(() => _selectedPaymentSourceId = val),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _noteController,
                    decoration: const InputDecoration(labelText: 'Note (Optional)', hintText: 'What was this for?', isDense: true),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]),
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            onPressed: _filteredCategories.isEmpty ? null : _saveExpense,
            child: Text(widget.existingExpense == null ? 'Save Expense' : 'Update Expense', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ),
      ),
    );
  }
}
