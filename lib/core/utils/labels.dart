import '../domain/enums.dart';

/// Centralised enum → Indonesian display label mappings.
/// One file so translation drift can't happen across screens.

String paymentMethodLabel(PaymentMethod method) => switch (method) {
      PaymentMethod.cash => 'Tunai',
      PaymentMethod.qris => 'QRIS',
      PaymentMethod.debit => 'Debit',
      PaymentMethod.credit => 'Kredit',
      PaymentMethod.transfer => 'Transfer',
      PaymentMethod.other => 'Lainnya',
    };

String movementTypeLabel(MovementType type) => switch (type) {
      MovementType.purchase => 'Pembelian',
      MovementType.sale => 'Penjualan',
      MovementType.adjustment => 'Penyesuaian',
      MovementType.waste => 'Limbah',
      MovementType.transfer => 'Transfer',
    };

String stockUnitLabel(StockUnit unit) => switch (unit) {
      StockUnit.gram => 'g',
      StockUnit.kg => 'kg',
      StockUnit.ml => 'ml',
      StockUnit.liter => 'L',
      StockUnit.pcs => 'pcs',
    };

String transactionStatusLabel(TransactionStatus status) => switch (status) {
      TransactionStatus.completed => 'Selesai',
      TransactionStatus.voided => 'Dibatalkan',
    };

/// Compact stock quantity formatter. Uses up to 3 decimal places, trimmed.
String formatStock(double qty, StockUnit unit) {
  final s = qty == qty.roundToDouble()
      ? qty.toStringAsFixed(0)
      : qty.toStringAsFixed(3).replaceAll(RegExp(r'\.?0+$'), '');
  return '$s ${stockUnitLabel(unit)}';
}
