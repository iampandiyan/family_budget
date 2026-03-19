// lib/core/app_state.dart
import 'package:flutter/material.dart';

class AppState extends ChangeNotifier {
  int _currentTabIndex = 0;

  int get currentTabIndex => _currentTabIndex;

  void updateTabIndex(int index) {
    _currentTabIndex = index;
    notifyListeners(); // Tells the UI to update
  }
}
