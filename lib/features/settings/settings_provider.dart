import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'settings_provider.freezed.dart';
part 'settings_provider.g.dart';

/// ENH-011 — magic header on exported settings blobs. Bumped when the
/// schema breaks; importer rejects mismatched envelopes.
const String kSettingsExportApp = 'kopiyantea-pos';
const int kSettingsExportVersion = 1;

// ── Keys ─────────────────────────────────────────────────────────────────────

abstract final class _Keys {
  static const selectedBranchId = 'selectedBranchId';
  static const themeMode = 'themeMode'; // 'system' | 'light' | 'dark'
  static const printEnabled = 'printEnabled';
  static const lastPrinterAddress = 'lastPrinterAddress';
  // FEAT-007 — remember-me at login.
  static const rememberMe = 'rememberMe';
  static const lastLoginEmail = 'lastLoginEmail';
}

// ── State ─────────────────────────────────────────────────────────────────────

@freezed
class AppSettings with _$AppSettings {
  const factory AppSettings({
    String? selectedBranchId,
    @Default('system') String themeMode,
    @Default(true) bool printEnabled,
    String? lastPrinterAddress,
    // FEAT-007 — when true, last successful login email is pre-filled at the
    // next LoginScreen open. Default ON so kasir di shift sibuk gak ngetik
    // ulang. Toggle OFF di settings untuk perangkat bersama.
    @Default(true) bool rememberMe,
    String? lastLoginEmail,
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
      rememberMe: prefs.getBool(_Keys.rememberMe) ?? true,
      lastLoginEmail: prefs.getString(_Keys.lastLoginEmail),
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

  Future<void> setRememberMe(bool enabled) =>
      _update((prefs) async {
        await prefs.setBool(_Keys.rememberMe, enabled);
        if (!enabled) {
          await prefs.remove(_Keys.lastLoginEmail);
        }
      });

  Future<void> setLastLoginEmail(String? email) =>
      _update((prefs) async {
        if (email == null || email.isEmpty) {
          await prefs.remove(_Keys.lastLoginEmail);
        } else {
          await prefs.setString(_Keys.lastLoginEmail, email);
        }
      });

  Future<void> _update(
    Future<void> Function(SharedPreferences) action,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await action(prefs);
    ref.invalidateSelf();
  }

  /// ENH-011 — serialize current settings as a portable JSON string for
  /// clipboard export. Excludes ephemeral/credential fields.
  Future<String> exportToJson() async {
    final s = await future;
    return const JsonEncoder.withIndent('  ').convert({
      'app': kSettingsExportApp,
      'version': kSettingsExportVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'settings': {
        _Keys.selectedBranchId: s.selectedBranchId,
        _Keys.themeMode: s.themeMode,
        _Keys.printEnabled: s.printEnabled,
        _Keys.lastPrinterAddress: s.lastPrinterAddress,
        _Keys.rememberMe: s.rememberMe,
        _Keys.lastLoginEmail: s.lastLoginEmail,
      },
    });
  }

  /// Applies a previously exported blob. Throws [FormatException] on
  /// malformed input or wrong envelope; otherwise applies fields per-key
  /// (unknown keys ignored, missing keys keep current value).
  Future<int> applyFromJson(String raw) async {
    final Map<String, dynamic> decoded;
    try {
      decoded = jsonDecode(raw) as Map<String, dynamic>;
    } catch (e) {
      throw const FormatException('JSON tidak valid');
    }
    if (decoded['app'] != kSettingsExportApp) {
      throw const FormatException('Bukan backup KopiyanteaPOS');
    }
    if (decoded['version'] != kSettingsExportVersion) {
      throw FormatException(
          'Versi backup tidak cocok (expect $kSettingsExportVersion)');
    }
    final m = decoded['settings'];
    if (m is! Map<String, dynamic>) {
      throw const FormatException('Field "settings" hilang/rusak');
    }

    final prefs = await SharedPreferences.getInstance();
    var applied = 0;

    if (m.containsKey(_Keys.selectedBranchId)) {
      final v = m[_Keys.selectedBranchId];
      if (v is String) {
        await prefs.setString(_Keys.selectedBranchId, v);
      } else {
        await prefs.remove(_Keys.selectedBranchId);
      }
      applied++;
    }
    if (m.containsKey(_Keys.themeMode)) {
      final v = m[_Keys.themeMode];
      if (v is String && (v == 'system' || v == 'light' || v == 'dark')) {
        await prefs.setString(_Keys.themeMode, v);
        applied++;
      }
    }
    if (m.containsKey(_Keys.printEnabled)) {
      final v = m[_Keys.printEnabled];
      if (v is bool) {
        await prefs.setBool(_Keys.printEnabled, v);
        applied++;
      }
    }
    if (m.containsKey(_Keys.lastPrinterAddress)) {
      final v = m[_Keys.lastPrinterAddress];
      if (v is String) {
        await prefs.setString(_Keys.lastPrinterAddress, v);
      } else {
        await prefs.remove(_Keys.lastPrinterAddress);
      }
      applied++;
    }
    if (m.containsKey(_Keys.rememberMe)) {
      final v = m[_Keys.rememberMe];
      if (v is bool) {
        await prefs.setBool(_Keys.rememberMe, v);
        applied++;
      }
    }
    if (m.containsKey(_Keys.lastLoginEmail)) {
      final v = m[_Keys.lastLoginEmail];
      if (v is String) {
        await prefs.setString(_Keys.lastLoginEmail, v);
      } else {
        await prefs.remove(_Keys.lastLoginEmail);
      }
      applied++;
    }

    ref.invalidateSelf();
    return applied;
  }
}
