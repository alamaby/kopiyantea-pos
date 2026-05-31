import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/database/database_provider.dart';

enum MenuImageHeaderLayout { stacked, split }

class MenuImageSettings {
  const MenuImageSettings({
    required this.showBranchName,
    required this.showBranchAddress,
    required this.showBranchPhone,
    required this.columns,
    required this.imageWidthPx,
    required this.headerLayout,
    required this.backgroundColorHex,
  });

  final bool showBranchName;
  final bool showBranchAddress;
  final bool showBranchPhone;
  final int columns;
  final int imageWidthPx;
  final MenuImageHeaderLayout headerLayout;
  final String backgroundColorHex;

  static const defaults = MenuImageSettings(
    showBranchName: true,
    showBranchAddress: true,
    showBranchPhone: true,
    columns: 3,
    imageWidthPx: 3240,
    headerLayout: MenuImageHeaderLayout.stacked,
    backgroundColorHex: '#F8FAFC',
  );
}

class MenuImageSettingsRepository {
  const MenuImageSettingsRepository(this._db);

  final AppDatabase _db;

  Future<MenuImageSettings> getForBranch(String branchId) async {
    final row = await _db.customSelect(
      'SELECT show_branch_name, show_branch_address, show_branch_phone, '
      'columns, image_width_px, header_layout, background_color_hex '
      'FROM menu_image_settings WHERE branch_id = ?',
      variables: [Variable<String>(branchId)],
    ).getSingleOrNull();
    if (row == null) return MenuImageSettings.defaults;
    return MenuImageSettings(
      showBranchName: row.read<int>('show_branch_name') == 1,
      showBranchAddress: row.read<int>('show_branch_address') == 1,
      showBranchPhone: row.read<int>('show_branch_phone') == 1,
      columns: row.read<int>('columns').clamp(2, 3).toInt(),
      imageWidthPx: normalizeMenuImageWidthPx(
        row.read<int>('image_width_px'),
      ),
      headerLayout: menuImageHeaderLayoutFromDb(
        row.read<String>('header_layout'),
      ),
      backgroundColorHex: normalizeMenuImageHex(
        row.read<String>('background_color_hex'),
      ),
    );
  }

  Future<void> save(String branchId, MenuImageSettings settings) async {
    await _db.customStatement(
      'INSERT INTO menu_image_settings '
      '(branch_id, show_branch_name, show_branch_address, show_branch_phone, '
      'columns, image_width_px, header_layout, background_color_hex, '
      'updated_at) '
      'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?) '
      'ON CONFLICT(branch_id) DO UPDATE SET '
      'show_branch_name = excluded.show_branch_name, '
      'show_branch_address = excluded.show_branch_address, '
      'show_branch_phone = excluded.show_branch_phone, '
      'columns = excluded.columns, '
      'image_width_px = excluded.image_width_px, '
      'header_layout = excluded.header_layout, '
      'background_color_hex = excluded.background_color_hex, '
      'updated_at = excluded.updated_at',
      [
        branchId,
        settings.showBranchName ? 1 : 0,
        settings.showBranchAddress ? 1 : 0,
        settings.showBranchPhone ? 1 : 0,
        settings.columns.clamp(2, 3).toInt(),
        normalizeMenuImageWidthPx(settings.imageWidthPx),
        settings.headerLayout.dbValue,
        normalizeMenuImageHex(settings.backgroundColorHex),
        DateTime.now().toIso8601String(),
      ],
    );
  }
}

final menuImageSettingsRepositoryProvider =
    Provider<MenuImageSettingsRepository>(
  (ref) => MenuImageSettingsRepository(ref.watch(databaseProvider)),
);

String normalizeMenuImageHex(String value) {
  final trimmed = value.trim();
  final noPrefix = trimmed.startsWith('#') ? trimmed.substring(1) : trimmed;
  if (noPrefix.length != 6) return trimmed.toUpperCase();
  return '#${noPrefix.toUpperCase()}';
}

bool isValidMenuImageHex(String value) =>
    RegExp(r'^#[0-9A-Fa-f]{6}$').hasMatch(value);

int normalizeMenuImageWidthPx(int value) => value.clamp(1080, 4096).toInt();

MenuImageHeaderLayout menuImageHeaderLayoutFromDb(String value) =>
    switch (value) {
      'split' => MenuImageHeaderLayout.split,
      _ => MenuImageHeaderLayout.stacked,
    };

extension MenuImageHeaderLayoutX on MenuImageHeaderLayout {
  String get dbValue => switch (this) {
        MenuImageHeaderLayout.stacked => 'stacked',
        MenuImageHeaderLayout.split => 'split',
      };

  String get label => switch (this) {
        MenuImageHeaderLayout.stacked => 'Atas-bawah',
        MenuImageHeaderLayout.split => 'Logo kiri',
      };
}

Color colorFromMenuImageHex(String value) {
  final normalized = normalizeMenuImageHex(value);
  if (!isValidMenuImageHex(normalized)) {
    return colorFromMenuImageHex(MenuImageSettings.defaults.backgroundColorHex);
  }
  return Color(int.parse(normalized.substring(1), radix: 16) | 0xFF000000);
}
