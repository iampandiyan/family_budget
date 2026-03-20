// lib/features/settings/settings_screen.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../core/database/database_helper.dart';
import '../../core/services/background_backup_service.dart';
import '../expenses/expense_provider.dart';
import '../budget/budget_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final GoogleSignIn _googleSignIn = GoogleSignIn(scopes: [drive.DriveApi.driveFileScope]);
  final _secureStorage = const FlutterSecureStorage();

  GoogleSignInAccount? _currentUser;
  bool _isPro = false;

  // Backup States
  String _lastManualBackup = 'Never';
  bool _isAutoBackupEnabled = false;
  String _autoBackupEmail = '';
  TimeOfDay _autoBackupTime = const TimeOfDay(hour: 2, minute: 0);
  String _lastAutoBackupStatus = 'None';
  bool _requireWiFi = true;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _googleSignIn.onCurrentUserChanged.listen((GoogleSignInAccount? account) {
      setState(() {
        _currentUser = account;
        _isPro = account != null ? false : false;
      });
      if (account != null) _saveTokensForBackground(account);
    });
    _googleSignIn.signInSilently();
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastManualBackup = prefs.getString('last_manual_backup') ?? 'Never';
      _isAutoBackupEnabled = prefs.getBool('auto_backup_enabled') ?? false;
      _autoBackupEmail = prefs.getString('auto_backup_email') ?? '';
      _lastAutoBackupStatus = prefs.getString('last_auto_backup_status') ?? 'None';
      _requireWiFi = prefs.getBool('auto_backup_require_wifi') ?? true;

      int hour = prefs.getInt('auto_backup_hour') ?? 2;
      int minute = prefs.getInt('auto_backup_minute') ?? 0;
      _autoBackupTime = TimeOfDay(hour: hour, minute: minute);
    });
  }

  Future<void> _saveTokensForBackground(GoogleSignInAccount account) async {
    try {
      final auth = await account.authentication;
      if (auth.accessToken != null) {
        await _secureStorage.write(key: 'drive_access_token', value: auth.accessToken);
      }
    } catch (e) {
      debugPrint("Token save error: $e");
    }
  }

  // --- AUTH ACTIONS ---
  Future<void> _handleSignIn() async {
    try {
      if (_currentUser == null) await _googleSignIn.signIn();
    } catch (error) {
      _showSnackbar('Error signing in: $error');
    }
  }

  Future<void> _handleSignOut() async {
    try {
      await _googleSignIn.signOut();
      setState(() {
        _currentUser = null;
        _isPro = false;
      });
      _showSnackbar('Signed out successfully.');
    } catch (e) {
      _showSnackbar('Error signing out: $e');
    }
  }

  // --- GOOGLE DRIVE BACKUP & RESTORE UX FLOW ---
  Future<bool> _confirmDriveAccount(String actionText) async {
    if (_currentUser == null) {
      final account = await _googleSignIn.signIn();
      if (account == null) return false;
      setState(() => _currentUser = account);
      await _saveTokensForBackground(account);
      return true;
    }

    bool? proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$actionText Data'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('You are about to $actionText your data using this Google account:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: Row(
                children: [
                  const Icon(Icons.email, color: Colors.blue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(_currentUser!.email, style: const TextStyle(fontWeight: FontWeight.bold))),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          TextButton(
              onPressed: () async {
                await _googleSignIn.signOut();
                final account = await _googleSignIn.signIn();
                if (account != null) {
                  setState(() => _currentUser = account);
                  await _saveTokensForBackground(account);
                  if (ctx.mounted) Navigator.pop(ctx, true);
                }
              },
              child: const Text('Change Account')
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
              ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Proceed')),
            ],
          ),
        ],
      ),
    );
    return proceed == true;
  }

  Future<drive.DriveApi?> _getDriveApi() async {
    try {
      final headers = await _currentUser!.authHeaders;
      final client = GoogleAuthClient(headers);
      return drive.DriveApi(client);
    } catch (e) { return null; }
  }

  Future<void> _manualBackupToDrive() async {
    bool confirmed = await _confirmDriveAccount('Backup');
    if (!confirmed) return;

    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      _showSnackbar('Authentication failed. Please try signing in again.');
      return;
    }

    _showLoadingDialog('Backing up to ${_currentUser!.email}...');

    try {
      final dbPath = p.join(await getDatabasesPath(), 'family_budget.db');
      final file = File(dbPath);

      final fileList = await driveApi.files.list(q: "name = 'family_budget_backup.db'");
      var driveFile = drive.File()..name = 'family_budget_backup.db';

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(driveFile, fileId, uploadMedia: drive.Media(file.openRead(), file.lengthSync()));
      } else {
        await driveApi.files.create(driveFile, uploadMedia: drive.Media(file.openRead(), file.lengthSync()));
      }

      final prefs = await SharedPreferences.getInstance();
      String timeStr = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now());
      await prefs.setString('last_manual_backup', timeStr);
      setState(() => _lastManualBackup = timeStr);

      if (mounted) Navigator.pop(context);
      _showSnackbar('Backup successful!');
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Backup failed: $e');
    }
  }

  Future<void> _restoreFromDrive() async {
    bool confirmed = await _confirmDriveAccount('Restore');
    if (!confirmed) return;

    bool? finalConfirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Warning'),
        content: const Text('This will overwrite ALL current local data with the backup from Google Drive. Are you sure?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Overwrite Data', style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (finalConfirm != true) return;

    final driveApi = await _getDriveApi();
    if (driveApi == null) {
      _showSnackbar('Authentication failed. Please sign in again.');
      return;
    }

    _showLoadingDialog('Restoring from ${_currentUser!.email}...');

    try {
      final fileList = await driveApi.files.list(q: "name = 'family_budget_backup.db'");
      if (fileList.files == null || fileList.files!.isEmpty) {
        throw Exception('No backup file found in this account.');
      }

      final fileId = fileList.files!.first.id!;
      final drive.Media media = await driveApi.files.get(fileId, downloadOptions: drive.DownloadOptions.fullMedia) as drive.Media;

      final dbPath = p.join(await getDatabasesPath(), 'family_budget.db');
      final saveFile = File(dbPath);

      List<int> dataStore = [];
      await for (var data in media.stream) { dataStore.addAll(data); }
      await saveFile.writeAsBytes(dataStore);

      if (mounted) {
        await Provider.of<BudgetProvider>(context, listen: false).loadData();
        await Provider.of<ExpenseProvider>(context, listen: false).refreshData();
        Navigator.pop(context);
        _showSnackbar('Restore successful!');
      }
    } catch (e) {
      if (mounted) Navigator.pop(context);
      _showSnackbar('Restore failed: $e');
    }
  }

  // --- AUTO BACKUP CONFIGURATION ---
  Future<void> _toggleAutoBackup(bool value) async {
    final prefs = await SharedPreferences.getInstance();

    if (value) {
      bool hasAccount = await _confirmDriveAccount('Auto Backup');
      if (!hasAccount) return;

      String networkText = _requireWiFi ? '(Requires Wi-Fi)' : '(Any network)';
      String scheduledStatus = 'Scheduled: Waiting for OS after ${_autoBackupTime.format(context)} $networkText';

      setState(() {
        _isAutoBackupEnabled = true;
        _autoBackupEmail = _currentUser!.email;
        _lastAutoBackupStatus = scheduledStatus;
      });

      await prefs.setBool('auto_backup_enabled', true);
      await prefs.setString('auto_backup_email', _currentUser!.email);
      await prefs.setString('last_auto_backup_status', scheduledStatus);

      await BackgroundBackupHelper.scheduleDailyBackup(_autoBackupTime, _requireWiFi);
      _showSnackbar('Auto Backup enabled.');
    } else {
      setState(() {
        _isAutoBackupEnabled = false;
        _lastAutoBackupStatus = 'Disabled';
      });
      await prefs.setBool('auto_backup_enabled', false);
      await prefs.setString('last_auto_backup_status', 'Disabled');
      await BackgroundBackupHelper.cancelAutoBackup();
      _showSnackbar('Auto Backup disabled.');
    }
  }

  Future<void> _pickAutoBackupTime() async {
    final TimeOfDay? picked = await showTimePicker(context: context, initialTime: _autoBackupTime);
    if (picked != null && picked != _autoBackupTime) {
      final prefs = await SharedPreferences.getInstance();

      String networkText = _requireWiFi ? '(Requires Wi-Fi)' : '(Any network)';
      String newStatus = 'Scheduled: Waiting for OS after ${picked.format(context)} $networkText';

      await prefs.setInt('auto_backup_hour', picked.hour);
      await prefs.setInt('auto_backup_minute', picked.minute);
      await prefs.setString('last_auto_backup_status', newStatus);

      setState(() {
        _autoBackupTime = picked;
        if (_isAutoBackupEnabled) _lastAutoBackupStatus = newStatus;
      });

      if (_isAutoBackupEnabled) {
        await BackgroundBackupHelper.scheduleDailyBackup(picked, _requireWiFi);
        _showSnackbar('Auto Backup time updated.');
      }
    }
  }

  Future<void> _toggleRequireWiFi(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('auto_backup_require_wifi', value);

    String networkText = value ? '(Requires Wi-Fi)' : '(Any network)';
    String newStatus = 'Scheduled: Waiting for OS after ${_autoBackupTime.format(context)} $networkText';
    await prefs.setString('last_auto_backup_status', newStatus);

    setState(() {
      _requireWiFi = value;
      if (_isAutoBackupEnabled) _lastAutoBackupStatus = newStatus;
    });

    if (_isAutoBackupEnabled) {
      await BackgroundBackupHelper.scheduleDailyBackup(_autoBackupTime, value);
      _showSnackbar(value ? 'Backup will only run on Wi-Fi.' : 'Backup will run on any connection.');
    }
  }

  // --- ACTIONS ---
  Future<void> _launchEmail() async {
    final Uri emailUri = Uri(scheme: 'mailto', path: 'mepandiyan@gmail.com', queryParameters: {'subject': 'Family Budget App Support Request'});
    try { await launchUrl(emailUri); } catch (e) {
      if (mounted) _showSnackbar('Could not open email app.');
    }
  }

  Future<void> _launchURL() async {
    final Uri url = Uri.parse('https://iampandiyan.github.io/one-on-one-tracker-privacy/');
    try { await launchUrl(url, mode: LaunchMode.externalApplication); } catch (e) {
      if (mounted) _showSnackbar('Could not open Privacy Policy URL.');
    }
  }

  void _showLoadingDialog(String message) {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(content: Row(children: [const CircularProgressIndicator(), const SizedBox(width: 20), Expanded(child: Text(message))])));
  }

  void _showSnackbar(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), behavior: SnackBarBehavior.floating));

  // --- MANAGEMENT BOTTOM SHEETS ---
  void _manageCategories() => showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => const _CategoryManagerSheet());
  void _manageSubcategories() => showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => const _SubcategoryManagerSheet());
  void _managePaymentSources() => showModalBottomSheet(context: context, isScrollControlled: true, shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))), builder: (ctx) => const _PaymentSourceManagerSheet());

  // --- WIDGET BUILDERS ---
  Widget _buildProfileHeader(Color primaryColor) {
    String displayName = _currentUser?.displayName ?? 'Guest User';
    String displayEmail = _currentUser?.email ?? 'Click here to sign in & sync';
    String displayPhotoUrl = _currentUser?.photoUrl ?? '';

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
            backgroundImage: displayPhotoUrl.isNotEmpty ? NetworkImage(displayPhotoUrl) : null,
            child: displayPhotoUrl.isEmpty ? Icon(Icons.person, size: 35, color: primaryColor) : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: _isPro ? Colors.orange : Colors.grey.shade200, borderRadius: BorderRadius.circular(12)),
                      child: Text(_isPro ? 'PRO' : 'FREE', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900, color: _isPro ? Colors.white : Colors.grey.shade700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(displayEmail, style: TextStyle(color: Colors.grey.shade600, fontSize: 12), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (_currentUser == null)
            Icon(Icons.login, color: primaryColor)
          else
            IconButton(icon: const Icon(Icons.logout, color: Colors.redAccent), onPressed: _handleSignOut, tooltip: 'Sign Out'),
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
      child: Column(children: children),
    );
  }

  Widget _buildTile(IconData icon, String title, String subtitle, Color iconColor, VoidCallback onTap, {bool isLast = false}) {
    return Column(
      children: [
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: iconColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: iconColor, size: 22)),
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
          subtitle: Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
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
      appBar: AppBar(title: const Text('Settings'), actions: [
        IconButton(icon: const Icon(Icons.refresh), tooltip: 'Refresh Sync Status', onPressed: _loadPreferences)
      ]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: _currentUser == null ? _handleSignIn : null,
              borderRadius: BorderRadius.circular(16),
              child: _buildProfileHeader(primaryColor),
            ),
            const SizedBox(height: 24),

            const Padding(padding: EdgeInsets.only(left: 8, bottom: 8), child: Text('Cloud & Data', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))),
            _buildSettingsGroup([
              _buildTile(Icons.cloud_upload, 'Manual Backup', 'Last backup: $_lastManualBackup', Colors.blue, _manualBackupToDrive),
              _buildTile(Icons.settings_backup_restore, 'Restore Data', 'Recover from Google Drive', Colors.green, _restoreFromDrive),
              Column(
                children: [
                  Divider(height: 1, color: Colors.grey.shade100),
                  SwitchListTile(
                    title: const Text('Automatic Backup', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                    subtitle: Text('Backup daily in the background', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                    value: _isAutoBackupEnabled,
                    activeColor: Colors.purple,
                    onChanged: _toggleAutoBackup,
                    secondary: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.autorenew, color: Colors.purple, size: 22)),
                  ),
                  if (_isAutoBackupEnabled) ...[
                    Divider(height: 1, indent: 60, color: Colors.grey.shade100),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: const SizedBox(width: 38),
                      title: const Text('Account', style: TextStyle(fontSize: 14)),
                      trailing: Text(_autoBackupEmail, style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.bold)),
                    ),
                    Divider(height: 1, indent: 60, color: Colors.grey.shade100),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: const SizedBox(width: 38),
                      title: const Text('Scheduled Time', style: TextStyle(fontSize: 14)),
                      trailing: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Text(_autoBackupTime.format(context), style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                      ),
                      onTap: _pickAutoBackupTime,
                    ),
                    Divider(height: 1, indent: 60, color: Colors.grey.shade100),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
                      leading: const SizedBox(width: 38),
                      title: const Text('Backup over Wi-Fi only', style: TextStyle(fontSize: 14)),
                      trailing: Switch(
                        value: _requireWiFi,
                        activeColor: Colors.purple,
                        onChanged: _toggleRequireWiFi,
                      ),
                    ),
                    Divider(height: 1, indent: 60, color: Colors.grey.shade100),
                    ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      leading: const SizedBox(width: 38),
                      title: const Text('Last Auto Backup', style: TextStyle(fontSize: 14)),
                      subtitle: Text(
                          _lastAutoBackupStatus,
                          style: TextStyle(
                              fontSize: 12,
                              color: _lastAutoBackupStatus.startsWith('Success')
                                  ? Colors.green
                                  : _lastAutoBackupStatus.startsWith('Scheduled')
                                  ? Colors.blue
                                  : Colors.red
                          )
                      ),
                    ),
                  ]
                ],
              ),
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

            const SizedBox(height: 20),
            Center(child: Text('Version 1.1.0', style: TextStyle(color: Colors.grey.shade400, fontWeight: FontWeight.bold))),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class GoogleAuthClient extends http.BaseClient {
  final Map<String, String> _headers;
  final http.Client _client = http.Client();
  GoogleAuthClient(this._headers);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    return _client.send(request..headers.addAll(_headers));
  }
}

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
    _nameCtrl.addListener(() => setState(() => _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty));
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _addCategory() async {
    if (!_isButtonEnabled) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('Categories', {'name': _nameCtrl.text.trim(), 'icon': '📁', 'color': '#4CAF50'});
      if (!mounted) return;
      _nameCtrl.clear();
      Provider.of<ExpenseProvider>(context, listen: false).refreshData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                IconButton(icon: Icon(Icons.add_circle, color: _isButtonEnabled ? Colors.blue : Colors.grey, size: 30), onPressed: _isButtonEnabled ? _addCategory : null),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: expProvider.categories.length,
                itemBuilder: (ctx, i) => ListTile(leading: Text(expProvider.categories[i]['icon'] ?? '📁', style: const TextStyle(fontSize: 20)), title: Text(expProvider.categories[i]['name'])),
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
    _nameCtrl.addListener(() => setState(() => _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty && _selectedCatId != null));
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _addSubcat() async {
    if (!_isButtonEnabled) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('Subcategories', {'category_id': _selectedCatId, 'name': _nameCtrl.text.trim()});
      if (!mounted) return;
      _nameCtrl.clear();
      Provider.of<ExpenseProvider>(context, listen: false).refreshData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
              onChanged: (val) => setState(() { _selectedCatId = val; _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty && _selectedCatId != null; }),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: TextField(controller: _nameCtrl, decoration: const InputDecoration(hintText: 'New Subcategory Name', isDense: true))),
                const SizedBox(width: 8),
                IconButton(icon: Icon(Icons.add_circle, color: _isButtonEnabled ? Colors.blue : Colors.grey, size: 30), onPressed: _isButtonEnabled ? _addSubcat : null),
              ],
            ),
            const Divider(),
            Expanded(
              child: subcats.isEmpty ? const Center(child: Text('No subcategories yet.', style: TextStyle(color: Colors.grey))) : ListView.builder(itemCount: subcats.length, itemBuilder: (ctx, i) => ListTile(title: Text(subcats[i]['name']))),
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
    _nameCtrl.addListener(() => setState(() => _isButtonEnabled = _nameCtrl.text.trim().isNotEmpty));
  }

  @override
  void dispose() { _nameCtrl.dispose(); super.dispose(); }

  Future<void> _addSource() async {
    if (!_isButtonEnabled) return;
    try {
      final db = await DatabaseHelper.instance.database;
      await db.insert('Payment_Sources', {'name': _nameCtrl.text.trim(), 'icon': '💳'});
      if (!mounted) return;
      _nameCtrl.clear();
      Provider.of<ExpenseProvider>(context, listen: false).refreshData();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
                IconButton(icon: Icon(Icons.add_circle, color: _isButtonEnabled ? Colors.blue : Colors.grey, size: 30), onPressed: _isButtonEnabled ? _addSource : null),
              ],
            ),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: expProvider.paymentSources.length,
                itemBuilder: (ctx, i) => ListTile(leading: Text(expProvider.paymentSources[i]['icon'] ?? '💳', style: const TextStyle(fontSize: 20)), title: Text(expProvider.paymentSources[i]['name'])),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
