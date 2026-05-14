import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.freezed.dart';
part 'settings_provider.g.dart';

// ── Keys ─────────────────────────────────────────────────────────────────────

abstract final class _Keys {
  static const selectedBranchId = 'selectedBranchId';
  static const themeMode = 'themeMode'; // 'system' | 'light' | 'dark'
  static const printEnabled = 'printEnabled';
  static const lastPrinterAddress = 'lastPrinterAddress';
}

// ── State ─────────────────────────────────────────────────────────────────────

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    String? selectedBranchId,
    @Default('system') String themeMode,
    @Default(true) bool printEnabled,
    String? lastPrinterAddress,
  }) = _AppSettings;
}

// ── Notifier ──────────────────────────────────────────────────────────────────

@riverpod
class SettingsNotifier extends _$SettingsNotifier {
  @override
  Future<AppSettings> build() async {
    final prefs = await SharedPreferences.getInstance();
    return AppSettings(
      selectedBranchId: prefs.getString(_Keys.selectedBranchId),
      themeMode: prefs.getString(_Keys.themeMode) ?? 'system',
      printEnabled: prefs.getBool(_Keys.printEnabled) ?? true,
      lastPrinterAddress: prefs.getString(_Keys.lastPrinterAddress),
    );
  }

  Future<void> setSelectedBranch(String? branchId) =>
      _update((prefs) async {
        if (branchId == null) {
          await prefs.remove(_Keys.selectedBranchId);
        } else {
          await prefs.setString(_Keys.selectedBranchId, branchId);
        }
      });

  Future<void> setThemeMode(String mode) =>
      _update((prefs) => prefs.setString(_Keys.themeMode, mode));

  Future<void> setPrintEnabled(bool enabled) =>
      _update((prefs) => prefs.setBool(_Keys.printEnabled, enabled));

  Future<void> setLastPrinterAddress(String? address) =>
      _update((prefs) async {
        if (address == null) {
          await prefs.remove(_Keys.lastPrinterAddress);
        } else {
          await prefs.setString(_Keys.lastPrinterAddress, address);
        }
      });

  Future<void> _update(
    Future<void> Function(SharedPreferences) action,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await action(prefs);
    ref.invalidateSelf();
  }
}
