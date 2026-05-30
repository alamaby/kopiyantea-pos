import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/labels.dart';
import 'report_providers.dart';

class ShareReportImageUseCase {
  const ShareReportImageUseCase();

  Future<void> share({
    required DailyReport report,
    required String branchName,
    Rect? sharePositionOrigin,
  }) async {
    final generatedAt = DateTime.now();
    final bytes = await ReportImageRenderer().renderPng(
      report: report,
      branchName: branchName,
      generatedAt: generatedAt,
    );
    final dir = await getTemporaryDirectory();
    final fileName =
        'laporan-${generatedAt.millisecondsSinceEpoch.toString()}.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png', name: fileName)],
      subject: 'Laporan $branchName',
      text: 'Laporan $branchName (${_rangeLabel(report.range)})',
      sharePositionOrigin: sharePositionOrigin,
    );
  }
}

class ReportImageRenderer {
  static const double _width = 1080;
  static const double _padding = 56;
  static const double _gap = 24;
  static const double _cardRadius = 18;
  static const Color _background = Color(0xFFF8FAFC);
  static const Color _surface = Colors.white;
  static const Color _surfaceAlt = Color(0xFFF1F5F9);
  static const Color _primary = Color(0xFF0F766E);
  static const Color _accent = Color(0xFFF59E0B);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  Future<Uint8List> renderPng({
    required DailyReport report,
    required String branchName,
    required DateTime generatedAt,
  }) async {
    final height = _ReportImageLayout(
      report: report,
      branchName: branchName,
      generatedAt: generatedAt,
    ).paint(null).ceil();

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    _ReportImageLayout(
      report: report,
      branchName: branchName,
      generatedAt: generatedAt,
    ).paint(canvas);
    final image = await recorder.endRecording().toImage(_width.toInt(), height);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) {
      throw StateError('Gagal membuat gambar laporan');
    }
    return data.buffer.asUint8List();
  }

  static String _rangeLabel(DateTimeRange range) {
    if (_sameDay(range.start, range.end)) return formatDayDate(range.start);
    return '${formatDayDate(range.start)} - ${formatDayDate(range.end)}';
  }

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

class _ReportImageLayout {
  _ReportImageLayout({
    required this.report,
    required this.branchName,
    required this.generatedAt,
  });

  final DailyReport report;
  final String branchName;
  final DateTime generatedAt;

  double _y = ReportImageRenderer._padding;

  double paint(Canvas? canvas) {
    canvas?.drawRect(
      const Rect.fromLTWH(0, 0, ReportImageRenderer._width, 20000),
      Paint()..color = ReportImageRenderer._background,
    );
    _header(canvas);
    _revenue(canvas);
    _payment(canvas);
    _bankAccounts(canvas);
    _topItems(canvas);
    _generatedAt(canvas);
    return _y + ReportImageRenderer._padding;
  }

  double get _contentWidth =>
      ReportImageRenderer._width - (ReportImageRenderer._padding * 2);

  void _header(Canvas? canvas) {
    _text(
      canvas,
      'Laporan Penjualan',
      x: ReportImageRenderer._padding,
      y: _y,
      maxWidth: _contentWidth,
      style: const TextStyle(
        color: ReportImageRenderer._text,
        fontSize: 48,
        fontWeight: FontWeight.w800,
      ),
    );
    _y += 62;
    _text(
      canvas,
      branchName,
      x: ReportImageRenderer._padding,
      y: _y,
      maxWidth: _contentWidth,
      style: const TextStyle(
        color: ReportImageRenderer._muted,
        fontSize: 28,
        fontWeight: FontWeight.w600,
      ),
    );
    _y += 38;
    _text(
      canvas,
      ReportImageRenderer._rangeLabel(report.range),
      x: ReportImageRenderer._padding,
      y: _y,
      maxWidth: _contentWidth,
      style: const TextStyle(
        color: ReportImageRenderer._muted,
        fontSize: 24,
      ),
    );
    _y += 56;
  }

  void _revenue(Canvas? canvas) {
    _card(canvas, (c, x, y, w) {
      var cursor = y;
      cursor += _label(c, 'Pendapatan', x, cursor, w);
      cursor += 12;
      cursor += _text(
        c,
        formatRupiah(report.totalRevenue),
        x: x,
        y: cursor,
        maxWidth: w,
        style: const TextStyle(
          color: ReportImageRenderer._primary,
          fontSize: 58,
          fontWeight: FontWeight.w800,
        ),
      );
      cursor += 28;
      final statWidth = (w - 20) / 2;
      final h1 = _stat(
          c, x, cursor, statWidth, 'Transaksi', '${report.transactionCount}');
      final h2 = _stat(c, x + statWidth + 20, cursor, statWidth, 'Rata-rata',
          formatRupiah(report.averageOrderValue));
      return cursor + math.max(h1, h2) - y;
    });
  }

  void _payment(Canvas? canvas) {
    final entries = report.byPayment.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    _card(canvas, (c, x, y, w) {
      var cursor = y;
      cursor += _label(c, 'Metode Pembayaran', x, cursor, w);
      cursor += 18;
      for (final entry in entries) {
        cursor += _progressRow(
          c,
          x,
          cursor,
          w,
          paymentMethodLabel(entry.key),
          '${entry.value.count} tx',
          formatRupiah(entry.value.revenue),
          report.totalRevenue <= 0
              ? 0
              : entry.value.revenue / report.totalRevenue,
          ReportImageRenderer._primary,
        );
        cursor += 20;
      }
      return cursor - y - 20;
    });
  }

  void _bankAccounts(Canvas? canvas) {
    final entries = report.byBankAccount.entries.toList()
      ..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    final total = entries.fold<double>(0, (sum, e) => sum + e.value.revenue);
    _card(canvas, (c, x, y, w) {
      var cursor = y;
      cursor += _label(c, 'Transfer per Rekening', x, cursor, w);
      cursor += 18;
      if (entries.isEmpty) {
        cursor += _text(
          c,
          'Belum ada transaksi transfer pada periode ini',
          x: x,
          y: cursor,
          maxWidth: w,
          style: const TextStyle(
            color: ReportImageRenderer._muted,
            fontSize: 24,
          ),
        );
      } else {
        for (final entry in entries) {
          cursor += _progressRow(
            c,
            x,
            cursor,
            w,
            entry.key,
            '${entry.value.count} tx',
            formatRupiah(entry.value.revenue),
            total <= 0 ? 0 : entry.value.revenue / total,
            ReportImageRenderer._accent,
          );
          cursor += 20;
        }
      }
      return cursor - y - (entries.isEmpty ? 0 : 20);
    });
  }

  void _topItems(Canvas? canvas) {
    _card(canvas, (c, x, y, w) {
      var cursor = y;
      cursor += _label(c, 'Produk Terlaris', x, cursor, w);
      cursor += 18;
      if (report.topItems.isEmpty) {
        cursor += _text(
          c,
          'Belum ada item terjual',
          x: x,
          y: cursor,
          maxWidth: w,
          style: const TextStyle(
            color: ReportImageRenderer._muted,
            fontSize: 24,
          ),
        );
      } else {
        for (var i = 0; i < report.topItems.length; i++) {
          cursor += _topItem(c, x, cursor, w, i + 1, report.topItems[i]);
          if (i < report.topItems.length - 1) {
            cursor += 16;
            c?.drawLine(
              Offset(x, cursor),
              Offset(x + w, cursor),
              Paint()
                ..color = ReportImageRenderer._border
                ..strokeWidth = 1,
            );
            cursor += 16;
          }
        }
      }
      return cursor - y;
    });
  }

  void _generatedAt(Canvas? canvas) {
    _y += 8;
    _text(
      canvas,
      'Image dibuat: ${formatDateTimeSeconds(generatedAt)}',
      x: ReportImageRenderer._padding,
      y: _y,
      maxWidth: _contentWidth,
      style: const TextStyle(
        color: ReportImageRenderer._muted,
        fontSize: 22,
      ),
    );
    _y += 36;
  }

  void _card(
    Canvas? canvas,
    double Function(Canvas? canvas, double x, double y, double width) content,
  ) {
    final x = ReportImageRenderer._padding;
    final innerX = x + 32;
    final innerY = _y + 32;
    final width = _contentWidth;
    final innerWidth = width - 64;
    final contentHeight = content(null, innerX, innerY, innerWidth);
    final height = contentHeight + 64;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, _y, width, height),
      const Radius.circular(ReportImageRenderer._cardRadius),
    );
    canvas?.drawRRect(rect, Paint()..color = ReportImageRenderer._surface);
    canvas?.drawRRect(
      rect,
      Paint()
        ..color = ReportImageRenderer._border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    content(canvas, innerX, innerY, innerWidth);
    _y += height + ReportImageRenderer._gap;
  }

  double _label(
          Canvas? canvas, String text, double x, double y, double width) =>
      _text(
        canvas,
        text.toUpperCase(),
        x: x,
        y: y,
        maxWidth: width,
        style: const TextStyle(
          color: ReportImageRenderer._muted,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      );

  double _stat(
    Canvas? canvas,
    double x,
    double y,
    double width,
    String label,
    String value,
  ) {
    final labelHeight = _text(
      null,
      label.toUpperCase(),
      x: x + 22,
      y: y + 18,
      maxWidth: width - 44,
      style: const TextStyle(
        color: ReportImageRenderer._muted,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
    final valueHeight = _text(
      null,
      value,
      x: x + 22,
      y: y + 18 + labelHeight + 8,
      maxWidth: width - 44,
      style: const TextStyle(
        color: ReportImageRenderer._text,
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
    );
    final height = labelHeight + valueHeight + 44;
    canvas?.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, width, height),
        const Radius.circular(14),
      ),
      Paint()..color = ReportImageRenderer._surfaceAlt,
    );
    _text(
      canvas,
      label.toUpperCase(),
      x: x + 22,
      y: y + 18,
      maxWidth: width - 44,
      style: const TextStyle(
        color: ReportImageRenderer._muted,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: 1,
      ),
    );
    _text(
      canvas,
      value,
      x: x + 22,
      y: y + 18 + labelHeight + 8,
      maxWidth: width - 44,
      style: const TextStyle(
        color: ReportImageRenderer._text,
        fontSize: 26,
        fontWeight: FontWeight.w700,
      ),
    );
    return height;
  }

  double _progressRow(
    Canvas? canvas,
    double x,
    double y,
    double width,
    String title,
    String count,
    String amount,
    double fraction,
    Color color,
  ) {
    final titleWidth = width * 0.52;
    final titleHeight = _text(
      canvas,
      title,
      x: x,
      y: y,
      maxWidth: titleWidth,
      maxLines: 2,
      style: const TextStyle(
        color: ReportImageRenderer._text,
        fontSize: 25,
        fontWeight: FontWeight.w700,
      ),
    );
    _text(
      canvas,
      count,
      x: x + titleWidth + 18,
      y: y + 3,
      maxWidth: 120,
      style: const TextStyle(
        color: ReportImageRenderer._muted,
        fontSize: 21,
      ),
    );
    _text(
      canvas,
      amount,
      x: x + titleWidth + 138,
      y: y,
      maxWidth: width - titleWidth - 138,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: ReportImageRenderer._text,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
    final barY = y + math.max(titleHeight, 32) + 12;
    final bg = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, barY, width, 10),
      const Radius.circular(8),
    );
    canvas?.drawRRect(bg, Paint()..color = ReportImageRenderer._surfaceAlt);
    canvas?.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          x,
          barY,
          width * fraction.clamp(0.0, 1.0).toDouble(),
          10,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = color,
    );
    return math.max(titleHeight, 32) + 22;
  }

  double _topItem(
    Canvas? canvas,
    double x,
    double y,
    double width,
    int rank,
    TopItem item,
  ) {
    final qty = item.totalQty == item.totalQty.roundToDouble()
        ? item.totalQty.toStringAsFixed(0)
        : item.totalQty.toStringAsFixed(1);
    final circle = Rect.fromLTWH(x, y + 3, 34, 34);
    canvas?.drawOval(
      circle,
      Paint()..color = ReportImageRenderer._surfaceAlt,
    );
    _text(
      canvas,
      '$rank',
      x: x,
      y: y + 6,
      maxWidth: 34,
      textAlign: TextAlign.center,
      style: const TextStyle(
        color: ReportImageRenderer._primary,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
    final titleHeight = _text(
      canvas,
      item.name,
      x: x + 52,
      y: y,
      maxWidth: width - 300,
      maxLines: 2,
      style: const TextStyle(
        color: ReportImageRenderer._text,
        fontSize: 25,
        fontWeight: FontWeight.w700,
      ),
    );
    _text(
      canvas,
      '$qty terjual',
      x: x + 52,
      y: y + titleHeight + 4,
      maxWidth: width - 300,
      style: const TextStyle(
        color: ReportImageRenderer._muted,
        fontSize: 20,
      ),
    );
    _text(
      canvas,
      formatRupiah(item.totalRevenue),
      x: x + width - 240,
      y: y,
      maxWidth: 240,
      textAlign: TextAlign.right,
      style: const TextStyle(
        color: ReportImageRenderer._text,
        fontSize: 24,
        fontWeight: FontWeight.w700,
      ),
    );
    return math.max(titleHeight + 28, 44);
  }

  double _text(
    Canvas? canvas,
    String text, {
    required double x,
    required double y,
    required double maxWidth,
    required TextStyle style,
    TextAlign textAlign = TextAlign.left,
    int? maxLines,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
      maxLines: maxLines,
      ellipsis: maxLines == null ? null : '...',
    )..layout(maxWidth: maxWidth);
    if (canvas != null) {
      painter.paint(canvas, Offset(x, y));
    }
    return painter.height;
  }
}

String _rangeLabel(DateTimeRange range) {
  if (range.start.year == range.end.year &&
      range.start.month == range.end.month &&
      range.start.day == range.end.day) {
    return formatDate(range.start);
  }
  return '${formatDate(range.start)} - ${formatDate(range.end)}';
}
