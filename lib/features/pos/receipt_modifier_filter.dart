import 'package:drift/drift.dart';

import '../../core/database/app_database.dart';
import 'cart_state.dart';

class ReceiptModifierFilter {
  const ReceiptModifierFilter._(this._defaultKeys);

  final Set<String> _defaultKeys;

  static Future<ReceiptModifierFilter> load(AppDatabase db) async {
    final query = db.select(db.optionGroups).join([
      innerJoin(
        db.menuOptions,
        db.menuOptions.groupId.equalsExp(db.optionGroups.id),
      ),
    ])
      ..where(db.menuOptions.isDefault.equals(true));

    final rows = await query.get();
    final keys = rows.map((row) {
      final group = row.readTable(db.optionGroups);
      final option = row.readTable(db.menuOptions);
      return _key(group.name, option.name);
    }).toSet();

    return ReceiptModifierFilter._(keys);
  }

  List<String> transactionOptionLabels(
    List<TransactionItemOptionRow>? options,
  ) {
    return (options ?? const <TransactionItemOptionRow>[])
        .where(
          (option) => !_isDefault(
            groupName: option.optionGroupNameSnapshot,
            optionName: option.optionNameSnapshot,
          ),
        )
        .map(
          (option) => _formatOption(
            groupName: option.optionGroupNameSnapshot,
            optionName: option.optionNameSnapshot,
            priceDelta: option.priceDeltaSnapshot,
          ),
        )
        .toList(growable: false);
  }

  List<String> cartOptionLabels(List<CartItemOption> options) {
    return options
        .where(
          (option) => !_isDefault(
            groupName: option.groupName,
            optionName: option.optionName,
          ),
        )
        .map(
          (option) => _formatOption(
            groupName: option.groupName,
            optionName: option.optionName,
            priceDelta: option.priceDelta,
          ),
        )
        .toList(growable: false);
  }

  bool _isDefault({
    required String groupName,
    required String optionName,
  }) =>
      _defaultKeys.contains(_key(groupName, optionName));

  static String _formatOption({
    required String groupName,
    required String optionName,
    required double priceDelta,
  }) {
    if (priceDelta == 0) return '$groupName: $optionName';
    return '$groupName: $optionName (+${priceDelta.toStringAsFixed(0)})';
  }

  static String _key(String groupName, String optionName) =>
      '${_normalize(groupName)}\u001f${_normalize(optionName)}';

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ').toLowerCase();
}
