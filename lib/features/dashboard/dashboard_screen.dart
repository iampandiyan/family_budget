// lib/features/dashboard/dashboard_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../expenses/expense_provider.dart';
import '../budget/budget_provider.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // --- PART 1 STATE ---
  String _part1FilterType = 'Budget'; // 'Budget' or 'Date'
  int? _part1SelectedBudgetId;
  DateTime? _part1StartDate;
  DateTime? _part1EndDate;

  // --- PART 2 STATE ---
  String _part2CompareBy = 'Category'; // 'Category', 'Subcategory', 'Payment Source'
  int? _part2SelectedFilterId;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      Provider.of<BudgetProvider>(context, listen: false).loadData();
      Provider.of<ExpenseProvider>(context, listen: false).refreshData().then((_) {
        if (mounted) {
          final budgets = Provider.of<ExpenseProvider>(context, listen: false).budgets;
          final categories = Provider.of<ExpenseProvider>(context, listen: false).categories;
          setState(() {
            if (budgets.isNotEmpty) _part1SelectedBudgetId = budgets.first['id'] as int;
            if (categories.isNotEmpty) _part2SelectedFilterId = categories.first['id'] as int;
          });
        }
      });
    });
  }

  // --- HELPERS ---
  Color _generateColor(String text) {
    int hash = text.hashCode;
    return Color((hash & 0xFFFFFF) + 0xFF000000).withValues(alpha: 0.8);
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _part1StartDate != null && _part1EndDate != null
          ? DateTimeRange(start: _part1StartDate!, end: _part1EndDate!)
          : null,
    );

    if (picked != null) {
      setState(() {
        _part1StartDate = picked.start;
        _part1EndDate = picked.end;
        _part1FilterType = 'Date';
        _part1SelectedBudgetId = null;
      });
    }
  }

  // ==========================================
  // PART 1: COMPOSITION (PIE CHARTS)
  // ==========================================

  List<Map<String, dynamic>> _getPart1FilteredExpenses(ExpenseProvider expProvider) {
    return expProvider.expenses.where((exp) {
      if (_part1FilterType == 'Budget') {
        if (_part1SelectedBudgetId == null) return true;
        return exp['budget_id'] == _part1SelectedBudgetId;
      } else {
        if (_part1StartDate == null || _part1EndDate == null) return true;
        try {
          DateTime date = DateTime.parse(exp['date']);
          return date.isAfter(_part1StartDate!.subtract(const Duration(days: 1))) &&
              date.isBefore(_part1EndDate!.add(const Duration(days: 1)));
        } catch (_) { return false; }
      }
    }).toList();
  }

  Widget _buildPieChartSection(String title, Map<String, double> dataMap, double total) {
    if (dataMap.isEmpty || total == 0) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 8),
            Container(
              height: 100,
              alignment: Alignment.center,
              decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Text('No data for $title', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
            ),
          ],
        ),
      );
    }

    var sortedEntries = dataMap.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Padding(
      padding: const EdgeInsets.only(bottom: 30.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8)]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
            const SizedBox(height: 20),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: 120,
                  width: 120,
                  child: PieChart(
                    PieChartData(
                      sectionsSpace: 2,
                      centerSpaceRadius: 35,
                      sections: sortedEntries.map((e) {
                        return PieChartSectionData(
                          color: _generateColor(e.key),
                          value: e.value,
                          title: '',
                          radius: 20,
                        );
                      }).toList(),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // FIX: Prevents layout overflow completely
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sortedEntries.map((e) {
                      double pct = (e.value / total) * 100;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                                margin: const EdgeInsets.only(top: 4),
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(color: _generateColor(e.key), shape: BoxShape.circle)
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    e.key,
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                      '${pct.toStringAsFixed(1)}%  (${e.value.toStringAsFixed(2)})',
                                      style: TextStyle(fontSize: 12, color: Colors.grey.shade700, fontWeight: FontWeight.w600)
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                )
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPart1(ExpenseProvider expProvider) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    final filteredExpenses = _getPart1FilteredExpenses(expProvider);

    Map<String, double> catMap = {};
    Map<String, double> subCatMap = {};
    Map<String, double> dayMap = {};
    Map<String, double> sourceMap = {};
    double totalSpent = 0;

    for (var exp in filteredExpenses) {
      double amt = (exp['amount'] as num?)?.toDouble() ?? 0.0;
      totalSpent += amt;

      String cat = exp['category_name'] ?? 'Unknown';
      String sub = exp['subcategory_name'] ?? 'Other';
      if (sub.isEmpty) sub = 'Other';
      String src = exp['payment_source_name'] ?? 'Cash';

      String day = 'Unknown';
      try {
        DateTime d = DateTime.parse(exp['date']);
        day = DateFormat('EEEE').format(d);
      } catch (_) {}

      catMap[cat] = (catMap[cat] ?? 0.0) + amt;
      subCatMap[sub] = (subCatMap[sub] ?? 0.0) + amt;
      sourceMap[src] = (sourceMap[src] ?? 0.0) + amt;
      dayMap[day] = (dayMap[day] ?? 0.0) + amt;
    }

    String dateText = 'Pick Date Range';
    if (_part1StartDate != null && _part1EndDate != null) {
      dateText = '${DateFormat('MMM dd').format(_part1StartDate!)} - ${DateFormat('MMM dd').format(_part1EndDate!)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Filter By:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Row(
          children: [
            ChoiceChip(
              label: const Text('Budget'),
              selected: _part1FilterType == 'Budget',
              onSelected: (val) => setState(() {
                _part1FilterType = 'Budget';
                _part1StartDate = null;
                _part1EndDate = null;
              }),
            ),
            const SizedBox(width: 12),
            ChoiceChip(
              label: const Text('Date Range'),
              selected: _part1FilterType == 'Date',
              onSelected: (val) {
                if (val) _pickDateRange();
              },
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_part1FilterType == 'Budget')
          DropdownButtonFormField<int?>(
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Select Budget', isDense: true),
            value: _part1SelectedBudgetId,
            items: [
              const DropdownMenuItem<int?>(value: null, child: Text('All Budgets (Total)')),
              ...expProvider.budgets.map((b) => DropdownMenuItem<int?>(value: b['id'] as int, child: Text(b['name']))),
            ],
            onChanged: (val) => setState(() => _part1SelectedBudgetId = val),
          )
        else
          InkWell(
            onTap: _pickDateRange,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(color: Colors.white, border: Border.all(color: Colors.grey.shade400), borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(dateText, style: TextStyle(fontWeight: FontWeight.bold, color: primaryColor)),
                  const Icon(Icons.calendar_month, size: 20),
                ],
              ),
            ),
          ),

        const SizedBox(height: 20),

        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          decoration: BoxDecoration(
            color: primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: primaryColor.withValues(alpha: 0.3)),
          ),
          child: Column(
            children: [
              Text('Total Spent', style: TextStyle(color: primaryColor, fontWeight: FontWeight.bold, fontSize: 14)),
              const SizedBox(height: 4),
              Text(totalSpent.toStringAsFixed(2), style: TextStyle(color: primaryColor, fontWeight: FontWeight.w900, fontSize: 28)),
            ],
          ),
        ),

        const SizedBox(height: 24),
        _buildPieChartSection('By Category', catMap, totalSpent),
        _buildPieChartSection('By Subcategory', subCatMap, totalSpent),
        _buildPieChartSection('By Day of Week', dayMap, totalSpent),
        _buildPieChartSection('By Payment Source', sourceMap, totalSpent),
      ],
    );
  }

  // ==========================================
  // PART 2: TIMELINE / BUDGET COMPARISON
  // ==========================================

  Widget _buildPart2(ExpenseProvider expProvider, BudgetProvider budProvider) {
    List<Map<String, dynamic>> filterOptions = [];
    if (_part2CompareBy == 'Category') {
      filterOptions = expProvider.categories;
    } else if (_part2CompareBy == 'Subcategory') {
      filterOptions = expProvider.dbSubcategories;
    } else if (_part2CompareBy == 'Payment Source') {
      filterOptions = expProvider.paymentSources;
    }

    if (filterOptions.isNotEmpty && !filterOptions.any((o) => o['id'] == _part2SelectedFilterId)) {
      _part2SelectedFilterId = filterOptions.first['id'] as int;
    }

    List<Map<String, dynamic>> budgets = List.from(expProvider.budgets.reversed);
    List<BarChartGroupData> barGroups = [];
    double maxY = 0;

    for (int i = 0; i < budgets.length; i++) {
      var b = budgets[i];
      int bId = b['id'];

      double allocated = 0;
      double spent = 0;

      var budgetExpenses = expProvider.expenses.where((e) => e['budget_id'] == bId).toList();
      for (var e in budgetExpenses) {
        bool matches = false;
        if (_part2CompareBy == 'Category' && e['category_id'] == _part2SelectedFilterId) matches = true;
        if (_part2CompareBy == 'Subcategory' && e['subcategory_id'] == _part2SelectedFilterId) matches = true;
        if (_part2CompareBy == 'Payment Source' && e['payment_source_id'] == _part2SelectedFilterId) matches = true;

        if (matches) spent += (e['amount'] as num?)?.toDouble() ?? 0.0;
      }

      if (_part2CompareBy == 'Category') {
        // Safe allocation mock logic.
        allocated = spent > 0 ? spent * 1.2 : 0;
      }

      if (allocated > maxY) maxY = allocated;
      if (spent > maxY) maxY = spent;

      // FIX FOR CRASH: Only add tooltip indicator index if the bar value > 0
      List<BarChartRodData> rods = [];
      List<int> showingTooltipSpots = [];
      int rodIndex = 0;

      if (_part2CompareBy == 'Category' || _part2CompareBy == 'Subcategory') {
        // Add Bar 1 (Allocated)
        rods.add(BarChartRodData(toY: allocated, color: Colors.blue, width: 10, borderRadius: BorderRadius.circular(2)));
        if (allocated > 0) showingTooltipSpots.add(rodIndex);
        rodIndex++;

        // Add Bar 2 (Spent)
        rods.add(BarChartRodData(toY: spent, color: Colors.redAccent, width: 10, borderRadius: BorderRadius.circular(2)));
        if (spent > 0) showingTooltipSpots.add(rodIndex);
        rodIndex++;
      } else {
        // Add Bar 1 (Payment Source Spent)
        rods.add(BarChartRodData(toY: spent, color: Colors.purple, width: 14, borderRadius: BorderRadius.circular(2)));
        if (spent > 0) showingTooltipSpots.add(rodIndex);
      }

      barGroups.add(BarChartGroupData(
        x: i,
        barsSpace: 4,
        barRods: rods,
        showingTooltipIndicators: showingTooltipSpots,
      ));
    }

    if (maxY == 0) maxY = 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Compare Budgets By:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: ['Category', 'Subcategory', 'Payment Source'].map((choice) {
            return ChoiceChip(
              label: Text(choice),
              selected: _part2CompareBy == choice,
              onSelected: (val) => setState(() {
                _part2CompareBy = choice;
                _part2SelectedFilterId = null;
              }),
            );
          }).toList(),
        ),
        const SizedBox(height: 12),

        DropdownButtonFormField<int?>(
          isExpanded: true,
          decoration: InputDecoration(labelText: 'Select $_part2CompareBy', isDense: true),
          value: _part2SelectedFilterId,
          items: filterOptions.map((o) => DropdownMenuItem<int?>(value: o['id'] as int, child: Text(o['name']))).toList(),
          onChanged: (val) => setState(() => _part2SelectedFilterId = val),
        ),
        const SizedBox(height: 24),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: _part2CompareBy == 'Payment Source'
              ? [
            _buildLegend('Spent Amount', Colors.purple),
          ]
              : [
            _buildLegend('Budget Allocated', Colors.blue),
            const SizedBox(width: 16),
            _buildLegend('Actual Spent', Colors.redAccent),
          ],
        ),
        const SizedBox(height: 30),

        Container(
          height: 320,
          padding: const EdgeInsets.only(top: 30, right: 16, left: 0, bottom: 8),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.grey.shade200)),
          child: BarChart(
            BarChartData(
              alignment: BarChartAlignment.spaceAround,
              maxY: maxY * 1.25,
              barTouchData: BarTouchData(
                  enabled: false,
                  touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (g) => Colors.transparent,
                      tooltipPadding: EdgeInsets.zero,
                      tooltipMargin: 4,
                      getTooltipItem: (group, groupIndex, rod, rodIndex) {
                        if (rod.toY == 0) return null;
                        return BarTooltipItem(
                            rod.toY.toStringAsFixed(0),
                            TextStyle(color: rod.color, fontWeight: FontWeight.bold, fontSize: 10)
                        );
                      }
                  )
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (val, meta) {
                      int idx = val.toInt();
                      if (idx >= 0 && idx < budgets.length) {
                        String name = budgets[idx]['name'];
                        if (name.length > 6) name = '${name.substring(0, 5)}.';
                        return Padding(padding: const EdgeInsets.only(top: 8.0), child: Text(name, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)));
                      }
                      return const Text('');
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (val, meta) {
                      if (val == 0) return const Text('');
                      return Text(val.toInt().toString(), style: const TextStyle(fontSize: 10, color: Colors.grey));
                    },
                  ),
                ),
                topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              gridData: FlGridData(show: true, drawVerticalLine: false, horizontalInterval: maxY / 4 > 0 ? maxY / 4 : 1, getDrawingHorizontalLine: (val) => FlLine(color: Colors.grey.shade100, strokeWidth: 1)),
              borderData: FlBorderData(show: false),
              barGroups: barGroups,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLegend(String label, Color color) {
    return Row(
      children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(3))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // ==========================================
  // MAIN BUILD
  // ==========================================

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Dashboard'),
      ),
      body: Consumer2<ExpenseProvider, BudgetProvider>(
        builder: (context, expProvider, budProvider, child) {
          return DefaultTabController(
            length: 2,
            child: Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TabBar(
                    labelColor: primaryColor,
                    unselectedLabelColor: Colors.grey,
                    indicatorColor: primaryColor,
                    indicatorWeight: 3,
                    labelStyle: const TextStyle(fontWeight: FontWeight.bold),
                    tabs: const [
                      Tab(text: 'Part 1: Composition'),
                      Tab(text: 'Part 2: Comparison'),
                    ],
                  ),
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildPart1(expProvider),
                      ),
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: _buildPart2(expProvider, budProvider),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
