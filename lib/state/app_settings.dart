import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global, persisted user-facing preferences.
///
/// Treat this as the single source of truth for settings the UI can toggle
/// (theme, save folder, account). Consumers should listen via
/// [AppSettingsScope] so UI updates automatically when a value changes.
class AppSettings extends ChangeNotifier {
  AppSettings._(this._prefs);

  static const _kThemeMode = 'pinnacle.themeMode';
  static const _kSaveFolder = 'pinnacle.saveFolderName';
  static const _kAccountEmail = 'pinnacle.accountEmail';
  static const _kNotifyOnReceive = 'pinnacle.notifyOnReceive';
  static const _kAutoStartReceive = 'pinnacle.autoStartReceive';
  static const _kAlwaysOnTop = 'pinnacle.alwaysOnTop';

  final SharedPreferences _prefs;

  static Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings._(prefs);
  }

  ThemeMode get themeMode {
    switch (_prefs.getString(_kThemeMode)) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      case 'system':
      default:
        return ThemeMode.system;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setString(_kThemeMode, mode.name);
    notifyListeners();
  }

  /// Folder name (no slashes) under which received files are grouped inside
  /// the OS's Downloads / Documents / home Downloads directory.
  String get saveFolderName =>
      _prefs.getString(_kSaveFolder)?.trim().isNotEmpty == true
          ? _prefs.getString(_kSaveFolder)!.trim()
          : 'Pinnacle';

  Future<void> setSaveFolderName(String value) async {
    final sanitized = value
        .trim()
        .replaceAll(RegExp(r'[\\/:*?"<>|]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');
    await _prefs.setString(
      _kSaveFolder,
      sanitized.isEmpty ? 'Pinnacle' : sanitized,
    );
    notifyListeners();
  }

  String? get accountEmail {
    final v = _prefs.getString(_kAccountEmail);
    return v == null || v.isEmpty ? null : v;
  }

  bool get isSignedIn => accountEmail != null;

  Future<void> setAccountEmail(String? email) async {
    if (email == null || email.isEmpty) {
      await _prefs.remove(_kAccountEmail);
    } else {
      await _prefs.setString(_kAccountEmail, email);
    }
    notifyListeners();
  }

  bool get notifyOnReceive => _prefs.getBool(_kNotifyOnReceive) ?? true;
  Future<void> setNotifyOnReceive(bool value) async {
    await _prefs.setBool(_kNotifyOnReceive, value);
    notifyListeners();
  }

  bool get autoStartReceive => _prefs.getBool(_kAutoStartReceive) ?? false;
  Future<void> setAutoStartReceive(bool value) async {
    await _prefs.setBool(_kAutoStartReceive, value);
    notifyListeners();
  }

  /// Desktop-only: keep the Pinnacle window above other apps.
  bool get alwaysOnTop => _prefs.getBool(_kAlwaysOnTop) ?? false;
  Future<void> setAlwaysOnTop(bool value) async {
    await _prefs.setBool(_kAlwaysOnTop, value);
    notifyListeners();
  }
}

/// Makes [AppSettings] available via `AppSettingsScope.of(context)` and
/// automatically rebuilds dependents when the settings notify.
class AppSettingsScope extends InheritedNotifier<AppSettings> {
  const AppSettingsScope({
    super.key,
    required AppSettings settings,
    required super.child,
  }) : super(notifier: settings);

  static AppSettings of(BuildContext context) {
    final scope = context
        .dependOnInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'No AppSettingsScope found in widget tree');
    return scope!.notifier!;
  }

  /// Read without registering a dependency (for one-shot reads in callbacks).
  static AppSettings read(BuildContext context) {
    final scope =
        context.getInheritedWidgetOfExactType<AppSettingsScope>();
    assert(scope != null, 'No AppSettingsScope found in widget tree');
    return scope!.notifier!;
  }
}
