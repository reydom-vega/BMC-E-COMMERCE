import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  ThemeController() {
    ready = _restore();
  }
  static const preferenceKey = 'trendkicks.theme';
  ThemeMode mode = ThemeMode.system;
  late final Future<void> ready;
  SharedPreferences? _preferences;
  bool _chosen = false, _disposed = false;
  Future<void> _restore() async {
    try {
      _preferences = await SharedPreferences.getInstance();
      final saved = _preferences!.getString(preferenceKey);
      if (!_disposed && !_chosen) {
        mode =
            ThemeMode.values
                .where((value) => value.name == saved)
                .firstOrNull ??
            ThemeMode.system;
        notifyListeners();
      }
    } catch (_) {
      /* Keep system appearance if device storage is unavailable. */
    }
  }

  Future<void> setMode(ThemeMode value) async {
    _chosen = true;
    mode = value;
    notifyListeners();
    await ready;
    await _preferences?.setString(preferenceKey, value.name);
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
