// lib/features/budget/add_budget_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';
import 'budget_provider.dart';

class AddBudgetScreen extends StatefulWidget {
  final int? existingBudgetId;
  const AddBudgetScreen({super.key, this.existingBudgetId});

  @override
  State<AddBudgetScreen> createState() => _AddBudgetScreenState();
}

class _AddBudgetScreenState extends State<AddBudgetScreen> {
  final _nameController = TextEditingController();
  final _initialAmountController = TextEditingController();

  DateTime? _startDate;
  DateTime? _endDate;

  String _currencyCode = 'USD';
  String _currencySymbol = '\$';

  List<Map<String, dynamic>> _allocations = [];
  List<Map<String, dynamic>> _previousBudgets = [];
  int? _selectedCopyBudgetId;

  double get _totalBudget {
    return _allocations.fold(0.0, (sum, item) => sum + (item['amount'] as num));
  }

  double get _initialBalance => double.tryParse(_initialAmountController.text) ?? 0.0;
  double get _difference => _initialBalance - _totalBudget;

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<BudgetProvider>(context, listen: false);

    Future.microtask(() async {
      await provider.loadData();
      if (!mounted) return;

      setState(() {
        _previousBudgets = provider.budgets;
      });

      if (widget.existingBudgetId != null) {
        final data = await provider.getBudgetDetails(widget.existingBudgetId!);
        if (!mounted) return;

        final budget = data['budget'];
        final categories = data['categories'] as List;

        setState(() {
          _nameController.text = budget['name'];
          _initialAmountController.text = budget['initial_amount'].toString();
          _startDate = DateTime.parse(budget['start_date']);
          _endDate = DateTime.parse(budget['end_date']);
          _currencyCode = budget['currency'];

          final currency = CurrencyService().findByCode(_currencyCode);
          if (currency != null) {
            _currencySymbol = currency.symbol;
          }

          _allocations = categories.map((cat) => {
            'category_id': cat['cat_id'],
            'name': cat['cat_name'],
            'icon': cat['cat_icon'],
            'amount': (cat['allocated_amount'] as num).toDouble(),
          }).toList();
        });
      }
    });
  }

  void _pickDate(bool isStart) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      if (!mounted) return;
      setState(() {
        if (isStart) {
          _startDate = picked;
        } else {
          _endDate = picked;
        }
      });
    }
  }

  void _showCurrencyPicker() {
    showCurrencyPicker(
      context: context,
      showFlag: true,
      showCurrencyName: true,
      showCurrencyCode: true,
      onSelect: (Currency currency) {
        if (!mounted) return;
        setState(() {
          _currencyCode = currency.code;
          _currencySymbol = currency.symbol;
        });
      },
    );
  }

  Future<void> _copyFromBudget(int budgetId) async {
    final provider = Provider.of<BudgetProvider>(context, listen: false);
    final items = await provider.getBudgetItems(budgetId);

    if (!mounted) return;
    setState(() {
      _allocations = items.map((e) => {
        'category_id': e['category_id'],
        'name': e['name'],
        'icon': e['icon'],
        'amount': (e['amount'] as num).toDouble(),
      }).toList();
    });
  }

  void _showAddCategoryModal() {
    int? selectedCatId;
    final amountController = TextEditingController();
    final categories = Provider.of<BudgetProvider>(context, listen: false).categories;
    final primaryColor = Theme.of(context).colorScheme.primary;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Add Allocation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor)),
                            IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(ctx)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        DropdownButtonFormField<int>(
                          decoration: const InputDecoration(hintText: 'Select Category'),
                          items: categories.map((c) => DropdownMenuItem<int>(
                            value: c['id'] as int,
                            child: Row(
                              children: [
                                Text(c['icon'], style: const TextStyle(fontSize: 18)),
                                const SizedBox(width: 10),
                                Text(c['name'], style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          )).toList(),
                          onChanged: (val) => setModalState(() => selectedCatId = val),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
                          decoration: InputDecoration(
                            prefixIcon: Padding(
                              padding: const EdgeInsets.all(14.0),
                              child: Text(_currencySymbol, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                            ),
                            hintText: '0.00',
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: primaryColor,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: () {
                              if (selectedCatId == null || amountController.text.isEmpty) {
                                return;
                              }

                              bool alreadyExists = _allocations.any((item) => item['category_id'] == selectedCatId);
                              if (alreadyExists) {
                                showDialog(
                                  context: ctx,
                                  builder: (dialogCtx) => AlertDialog(
                                    title: const Text('Duplicate Category', style: TextStyle(fontWeight: FontWeight.bold)),
                                    content: const Text('This category is already added to your budget.'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(dialogCtx), child: Text('OK', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
                                    ],
                                  ),
                                );
                                return;
                              }

                              setState(() {
                                _allocations.add({
                                  'category_id': selectedCatId,
                                  'name': categories.firstWhere((c) => c['id'] == selectedCatId)['name'],
                                  'icon': categories.firstWhere((c) => c['id'] == selectedCatId)['icon'],
                                  'amount': double.parse(amountController.text.trim()),
                                });
                              });
                              Navigator.pop(ctx);
                            },
                            child: const Text('Add to Budget', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _editAllocation(int index) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final item = _allocations[index];
    final amountController = TextEditingController(text: item['amount'].toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Allocation', style: TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor),
          decoration: const InputDecoration(hintText: 'Amount'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              final value = double.tryParse(amountController.text.trim());
              if (value != null) {
                if (mounted) {
                  setState(() => _allocations[index]['amount'] = value);
                }
                Navigator.pop(ctx);
              }
            },
            child: Text('Save', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _saveBudget() async {
    if (_nameController.text.isEmpty || _startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all main details')));
      return;
    }

    final newBudget = {
      'name': _nameController.text.trim(),
      'start_date': DateFormat('yyyy-MM-dd').format(_startDate!),
      'end_date': DateFormat('yyyy-MM-dd').format(_endDate!),
      'initial_amount': _initialBalance,
      'total_budget_amount': _totalBudget,
      'currency': _currencyCode,
    };

    final provider = Provider.of<BudgetProvider>(context, listen: false);

    if (widget.existingBudgetId == null) {
      await provider.addBudget(newBudget, _allocations);
    } else {
      await provider.updateBudget(widget.existingBudgetId!, newBudget, _allocations);
    }

    if (!mounted) return;
    Navigator.pop(context);
  }

  Future<void> _handleDeleteCategory(int index, Map<String, dynamic> item) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Category', style: TextStyle(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to remove this category? Any expenses linked to this category in this budget will also be deleted.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    ) ?? false;

    if (confirm) {
      // Synchronously capture the provider BEFORE the async gap
      if (widget.existingBudgetId != null) {
        if (!mounted) return;
        final provider = Provider.of<BudgetProvider>(context, listen: false);
        await provider.deleteBudgetItem(widget.existingBudgetId!, item['category_id']);
      }

      if (!mounted) return;
      setState(() => _allocations.removeAt(index));
    }
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(widget.existingBudgetId == null ? 'New Budget' : 'Edit Budget'),
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: Colors.grey.shade50, border: Border(bottom: BorderSide(color: Colors.grey.shade300))),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 6,
                      child: TextField(
                        controller: _nameController,
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                        decoration: const InputDecoration(hintText: 'Budget Name', isDense: true),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 4,
                      child: TextField(
                        controller: _initialAmountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: primaryColor),
                        decoration: const InputDecoration(hintText: 'Initial Bal.', isDense: true),
                        onChanged: (_) => setState(() {}),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                          child: Text(_startDate == null ? 'Start Date' : DateFormat('dd MMM yy').format(_startDate!), style: TextStyle(fontWeight: FontWeight.bold, color: _startDate == null ? Colors.grey : primaryColor, fontSize: 13), textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const Padding(padding: EdgeInsets.symmetric(horizontal: 4), child: Icon(Icons.arrow_right_alt, size: 16, color: Colors.grey)),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey.shade300)),
                          child: Text(_endDate == null ? 'End Date' : DateFormat('dd MMM yy').format(_endDate!), style: TextStyle(fontWeight: FontWeight.bold, color: _endDate == null ? Colors.grey : primaryColor, fontSize: 13), textAlign: TextAlign.center),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    InkWell(
                      onTap: _showCurrencyPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(color: primaryColor, borderRadius: BorderRadius.circular(8)),
                        child: Text('$_currencySymbol $_currencyCode', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (_initialAmountController.text.isNotEmpty || _allocations.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Balance after allocations', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                        Text('$_currencySymbol${_difference.toStringAsFixed(2)}', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: _difference >= 0 ? Colors.green : Colors.red)),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Allocations', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: primaryColor)),
                        if (_previousBudgets.isNotEmpty)
                          DropdownButton<int>(
                            value: _selectedCopyBudgetId,
                            hint: const Text('Copy from previous', style: TextStyle(fontSize: 12)),
                            underline: const SizedBox(),
                            items: _previousBudgets.map((b) => DropdownMenuItem<int>(value: b['id'] as int, child: Text(b['name'] as String, style: const TextStyle(fontSize: 12)))).toList(),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() => _selectedCopyBudgetId = val);
                                _copyFromBudget(val);
                              }
                            },
                          ),
                      ],
                    ),
                    TextButton.icon(onPressed: _showAddCategoryModal, icon: Icon(Icons.add_circle, color: primaryColor), label: Text('Add Item', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold))),
                  ],
                ),
                const SizedBox(height: 8),
                if (_allocations.isEmpty)
                  Center(child: Padding(padding: const EdgeInsets.only(top: 40), child: Text("Tap 'Add Item' or copy from previous.", style: TextStyle(color: Colors.grey.shade500, fontSize: 13))))
                else
                  ..._allocations.asMap().entries.map((entry) {
                    final index = entry.key;
                    final item = entry.value;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 5)],
                      ),
                      child: Row(
                        children: [
                          Text(item['icon'], style: const TextStyle(fontSize: 20)),
                          const SizedBox(width: 16),
                          Expanded(
                            child: InkWell(
                              onTap: () => _editAllocation(index),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  const SizedBox(height: 2),
                                  Text('Tap to edit', style: TextStyle(color: Colors.grey.shade500, fontSize: 11)),
                                ],
                              ),
                            ),
                          ),
                          Text('$_currencySymbol${(item['amount'] as num).toStringAsFixed(2)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: primaryColor)),

                          // Extracted asynchronous deletion logic to a separate helper function above to cleanly satisfy the linter
                          IconButton(
                            icon: const Icon(Icons.delete_outline, size: 20, color: Colors.redAccent),
                            onPressed: () => _handleDeleteCategory(index, item),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, -5))]
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('TOTAL BUDGET', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1)),
                  Text('$_currencySymbol${_totalBudget.toStringAsFixed(2)}', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor)),
                ],
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: primaryColor, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                onPressed: _saveBudget,
                child: Text(widget.existingBudgetId == null ? 'Save Budget' : 'Update Budget', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
