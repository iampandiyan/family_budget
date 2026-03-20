// lib/core/services/background_backup_service.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:workmanager/workmanager.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';
import 'package:intl/intl.dart';

const String autoBackupTaskKey = "auto_backup_task";

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final secureStorage = const FlutterSecureStorage();

      String? accessToken = await secureStorage.read(key: 'drive_access_token');
      if (accessToken == null) {
        await prefs.setString('last_auto_backup_status', 'Failed: No Auth Token. Please re-login.');
        return Future.value(false);
      }

      final authClient = _BackgroundAuthClient(accessToken);
      final driveApi = drive.DriveApi(authClient);

      final dbPath = p.join(await getDatabasesPath(), 'family_budget.db');
      final file = File(dbPath);
      if (!file.existsSync()) {
        await prefs.setString('last_auto_backup_status', 'Failed: Database not found.');
        return Future.value(false);
      }

      final fileList = await driveApi.files.list(q: "name = 'family_budget_backup.db'");
      var driveFile = drive.File()..name = 'family_budget_backup.db';

      if (fileList.files != null && fileList.files!.isNotEmpty) {
        final fileId = fileList.files!.first.id!;
        await driveApi.files.update(driveFile, fileId, uploadMedia: drive.Media(file.openRead(), file.lengthSync()));
      } else {
        await driveApi.files.create(driveFile, uploadMedia: drive.Media(file.openRead(), file.lengthSync()));
      }

      String timeStr = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now());
      await prefs.setString('last_auto_backup_status', 'Success: $timeStr');

      return Future.value(true);
    } catch (e) {
      final prefs = await SharedPreferences.getInstance();
      String timeStr = DateFormat('MMM dd, yyyy - hh:mm a').format(DateTime.now());
      await prefs.setString('last_auto_backup_status', 'Failed at $timeStr: ${e.toString().split('\n')[0]}');
      return Future.value(false);
    }
  });
}

class _BackgroundAuthClient extends http.BaseClient {
  final String _accessToken;
  final http.Client _client = http.Client();
  _BackgroundAuthClient(this._accessToken);
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) {
    request.headers['Authorization'] = 'Bearer $_accessToken';
    return _client.send(request);
  }
}

class BackgroundBackupHelper {
  static Future<void> scheduleDailyBackup(TimeOfDay time, bool requireWiFi) async {
    DateTime now = DateTime.now();
    DateTime scheduledTime = DateTime(now.year, now.month, now.day, time.hour, time.minute);

    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    Duration initialDelay = scheduledTime.difference(now);
    final networkConstraint = requireWiFi ? NetworkType.unmetered : NetworkType.connected;

    await Workmanager().registerPeriodicTask(
      autoBackupTaskKey,
      autoBackupTaskKey,
      frequency: const Duration(hours: 24),
      initialDelay: initialDelay,
      constraints: Constraints(
        networkType: networkConstraint,
        requiresBatteryNotLow: true,
      ),
      existingWorkPolicy: ExistingPeriodicWorkPolicy.replace,
    );
  }

  static Future<void> cancelAutoBackup() async {
    await Workmanager().cancelByUniqueName(autoBackupTaskKey);
  }
}
