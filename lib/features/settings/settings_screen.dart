// lib/features/settings/settings_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/database/database_helper.dart';
import '../expenses/expense_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Placeholder variables for Auth (To be wired up to Google Sign-In later)
  final String _userName = 'Guest User';
  final String _userEmail = 'Sign in to sync data';
  final bool _isPro = false;

  // --- ACTIONS ---
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: 'mepandiyan@gmail.com',
      query: 'subject=Expense Tracker Support Request',
    );
    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email client.')));
      }
    }
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://github.com/your-username/your-repo/blob/main/PRIVACY_POLICY.md');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Privacy Policy.')));
      }
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));
  }

  // --- MANAGEMENT BOTTOM SHEETS (BOX 2) ---
  void _manageCategories() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _CategoryManagerSheet(),
    );
  }

  void _manageSubcategories() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _SubcategoryManagerSheet(),
    );
  }

  void _managePaymentSources() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => const _PaymentSourceManagerSheet(),
    );
  }

  // --- WIDGET BUILDERS ---
  Widget _buildProfileHeader(Color primaryColor) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: primaryColor.withValues(alpha: 0.1),
            child: Icon(Icons.person, size: 35, color: primaryColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(_userName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: _isPro ? Colors.orange : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _isPro ? 'PRO' : 'FREE',
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _isPro ? Colors.white : Colors.grey.shade600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(_userEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: Colors.grey.shade400),
        ],
      ),
    );
  }

  Widget _buildSettingsGroup(List<Widget> children) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: children,
      ),
    );
  }

  Widget _buildTile(IconData icon, String title, String? subtitle, Color iconColor, VoidCallback onTap, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: subtitle != null ? Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)) : null,
          trailing: Icon(Icons.chevron_right, color: Colors.grey.shade300, size: 20),
          onTap: onTap,
        ),
        if (!isLast) Divider(height: 1, indent: 60, color: Colors.grey.shade100),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Settings'),
        // Standard App Bar Styling used across the app
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: () => _showSnackbar('Google Sign-In coming soon'),
              borderRadius: BorderRadius.circular(16),
              child: _buildProfileHeader(primaryColor),
            ),
            const SizedBox(height: 24),

            const Padding(padding: EdgeInsets.only(left: 8, bottom: 8), child: Text('Cloud & Data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            _buildSettingsGroup([
              _buildTile(Icons.cloud_upload, 'Backup to Google Drive', 'Save your data securely', Colors.blue, () => _showSnackbar('Backup integration pending')),
              _buildTile(Icons.settings_backup_restore, 'Restore Data', 'Recover from Google Drive', Colors.green, () => _showSnackbar('Restore integration pending'), isLast: true),
            ]),

            const Padding(padding: EdgeInsets.only(left: 8, bottom: 8), child: Text('Configuration', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            _buildSettingsGroup([
              _buildTile(Icons.category, 'Categories', 'Manage expense categories', Colors.purple, _manageCategories),
              _buildTile(Icons.account_tree, 'Subcategories', 'Manage 2nd-level classifications', Colors.orange, _manageSubcategories),
              _buildTile(Icons.account_balance_wallet, 'Payment Sources', 'Manage accounts & cards', Colors.teal, _managePaymentSources, isLast: true),
            ]),

            const Padding(padding: EdgeInsets.only(left: 8, bottom: 8), child: Text('About & Support', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            _buildSettingsGroup([
              _buildTile(Icons.privacy_tip, 'Privacy Policy', 'Read our data policy', Colors.indigo, _launchURL),
              _buildTile(Icons.email, 'Contact Support', 'mepandiyan@gmail.com', Colors.redAccent, _launchEmail, isLast: true),
            ]),

            const SizedBox(height: 40),
            Center(child: Text('Version 1.0.0', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// INLINE MANAGEMENT BOTTOM SHEETS
// ============================================================================

class _CategoryManagerSheet extends StatefulWidget {
  const _CategoryManagerSheet();
  @override
  State<_CategoryManagerSheet> createState() => _CategoryManagerSheetState();
}

class _CategoryManagerSheetState extends State<_CategoryManagerSheet> {
  final _nameCtrl = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      setState(() {
        _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addCategory() async {
    if (!_isButtonEnabled) return;
    try {
      final db = await DatabaseHelper.instance.database;
      // FIX: Added 'color' field to satisfy DB constraint
      await db.insert('Categories', {
        'name': _nameCtrl.text.trim(),
        'icon': '📁',
        'color': '#4CAF50'
      });
      if (!mounted) return;
      _nameCtrl.clear();
      Provider.of<ExpenseProvider>(context, listen: false).refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding category: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expProvider = Provider.of<ExpenseProvider>(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            const Text('Manage Categories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'New Category Name', isDense: true))),
                const SizedBox(width: 8),
                IconButton(
                    icon: Icon(Icons.add_circle, color: _isButtonEnabled ? Colors.blue : Colors.grey, size: 30),
                    onPressed: _isButtonEnabled ? _addCategory : null
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: expProvider.categories.length,
                itemBuilder: (ctx, i) {
                  final cat = expProvider.categories[i];
                  return ListTile(
                    leading: Text(cat['icon'] ?? '📁', style: const TextStyle(fontSize: 20)),
                    title: Text(cat['name']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SubcategoryManagerSheet extends StatefulWidget {
  const _SubcategoryManagerSheet();
  @override
  State<_SubcategoryManagerSheet> createState() => _SubcategoryManagerSheetState();
}

class _SubcategoryManagerSheetState extends State<_SubcategoryManagerSheet> {
  int? _selectedCatId;
  final _nameCtrl = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    final cats = Provider.of<ExpenseProvider>(context, listen: false).categories;
    if (cats.isNotEmpty) _selectedCatId = cats.first['id'] as int;

    _nameCtrl.addListener(() {
      setState(() {
        _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty && _selectedCatId != null;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSubcat() async {
    if (!_isButtonEnabled) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('Subcategories', {'category_id': _selectedCatId, 'name': _nameCtrl.text.trim()});
      if (!mounted) return;
      _nameCtrl.clear();
      Provider.of<ExpenseProvider>(context, listen: false).refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding subcategory: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expProvider = Provider.of<ExpenseProvider>(context);
    final subcats = expProvider.dbSubcategories.where((s) => s['category_id'] == _selectedCatId).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SizedBox(
        height: 500,
        child: Column(
          children: [
            const Text('Manage Subcategories', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              decoration: const InputDecoration(labelText: 'Parent Category', isDense: true),
              value: _selectedCatId,
              items: expProvider.categories.map((c) => DropdownMenuItem<int?>(value: c['id'] as int, child: Text(c['name']))).toList(),
              onChanged: (val) {
                setState(() {
                  _selectedCatId = val;
                  _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty && _selectedCatId != null;
                });
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'New Subcategory Name', isDense: true))),
                const SizedBox(width: 8),
                IconButton(
                    icon: Icon(Icons.add_circle, color: _isButtonEnabled ? Colors.blue : Colors.grey, size: 30),
                    onPressed: _isButtonEnabled ? _addSubcat : null
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: subcats.isEmpty
                  ? const Center(child: Text('No subcategories yet.', style: TextStyle(color: Colors.grey)))
                  : ListView.builder(
                itemCount: subcats.length,
                itemBuilder: (ctx, i) => ListTile(title: Text(subcats[i]['name'])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaymentSourceManagerSheet extends StatefulWidget {
  const _PaymentSourceManagerSheet();
  @override
  State<_PaymentSourceManagerSheet> createState() => _PaymentSourceManagerSheetState();
}

class _PaymentSourceManagerSheetState extends State<_PaymentSourceManagerSheet> {
  final _nameCtrl = TextEditingController();
  bool _isButtonEnabled = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() {
      setState(() {
        _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _addSource() async {
    if (!_isButtonEnabled) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('Payment_Sources', {'name': _nameCtrl.text.trim(), 'icon': '💳'});
      if (!mounted) return;
      _nameCtrl.clear();
      Provider.of<ExpenseProvider>(context, listen: false).refreshData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error adding source: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final expProvider = Provider.of<ExpenseProvider>(context);
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SizedBox(
        height: 400,
        child: Column(
          children: [
            const Text('Manage Payment Sources', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'New Payment Source', isDense: true))),
                const SizedBox(width: 8),
                IconButton(
                    icon: Icon(Icons.add_circle, color: _isButtonEnabled ? Colors.blue : Colors.grey, size: 30),
                    onPressed: _isButtonEnabled ? _addSource : null
                ),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: expProvider.paymentSources.length,
                itemBuilder: (ctx, i) {
                  final src = expProvider.paymentSources[i];
                  return ListTile(
                    leading: Text(src['icon'] ?? '💳', style: const TextStyle(fontSize: 20)),
                    title: Text(src['name']),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
