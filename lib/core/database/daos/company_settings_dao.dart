import 'package:drift/drift.dart';

import '../app_database.dart';

const kCompanySettingsId = 'global';

class CompanySettingsRow {
  const CompanySettingsRow({
    required this.id,
    required this.showReceiptLogo,
    required this.receiptLogoPosition,
    required this.updatedAt,
    this.receiptLogoUrl,
  });

  final String id;
  final String? receiptLogoUrl;
  final bool showReceiptLogo;
  final String receiptLogoPosition;
  final DateTime updatedAt;

  Map<String, dynamic> toSupabaseJson() => {
        'id': id,
        'receipt_logo_url': receiptLogoUrl,
        'show_receipt_logo': showReceiptLogo,
        'receipt_logo_position': receiptLogoPosition,
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };
}

class CompanySettingsDao {
  CompanySettingsDao(this._db);

  final AppDatabase _db;

  Future<CompanySettingsRow?> get() async {
    final row = await _db.customSelect(
      'SELECT id, receipt_logo_url, show_receipt_logo, '
      'receipt_logo_position, updated_at '
      'FROM company_settings WHERE id = ?',
      variables: [const Variable<String>(kCompanySettingsId)],
    ).getSingleOrNull();
    if (row == null) return null;
    return _fromDriftRow(row);
  }

  Future<void> upsert(CompanySettingsRow row) {
    return _db.customStatement(
      'INSERT INTO company_settings '
      '(id, receipt_logo_url, show_receipt_logo, receipt_logo_position, '
      'updated_at) '
      'VALUES (?, ?, ?, ?, ?) '
      'ON CONFLICT(id) DO UPDATE SET '
      'receipt_logo_url = excluded.receipt_logo_url, '
      'show_receipt_logo = excluded.show_receipt_logo, '
      'receipt_logo_position = excluded.receipt_logo_position, '
      'updated_at = excluded.updated_at',
      [
        row.id,
        row.receiptLogoUrl,
        row.showReceiptLogo ? 1 : 0,
        row.receiptLogoPosition,
        row.updatedAt,
      ],
    );
  }

  CompanySettingsRow _fromDriftRow(QueryRow row) {
    return CompanySettingsRow(
      id: row.read<String>('id'),
      receiptLogoUrl: row.readNullable<String>('receipt_logo_url'),
      showReceiptLogo: row.read<int>('show_receipt_logo') == 1,
      receiptLogoPosition: row.read<String>('receipt_logo_position'),
      updatedAt: row.read<DateTime>('updated_at'),
    );
  }
}

CompanySettingsRow companySettingsFromJson(Map<String, dynamic> json) {
  final rawUpdatedAt = json['updated_at'];
  final updatedAt = rawUpdatedAt is DateTime
      ? rawUpdatedAt.toLocal()
      : DateTime.parse(rawUpdatedAt as String).toLocal();
  return CompanySettingsRow(
    id: json['id'] as String? ?? kCompanySettingsId,
    receiptLogoUrl: json['receipt_logo_url'] as String?,
    showReceiptLogo: json['show_receipt_logo'] as bool? ?? false,
    receiptLogoPosition: json['receipt_logo_position'] as String? ?? 'top',
    updatedAt: updatedAt,
  );
}
