import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/catalog_dao.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/pricing/pricing.dart';
import '../../core/utils/formatters.dart';
import '../settings/menu_image_settings.dart';

const shareMenuImageEncodeFailedCode = 'share_menu_image_encode_failed';

class ShareMenuImageUseCase {
  ShareMenuImageUseCase(this._ref);

  final Ref _ref;
  static final Map<String, Uint8List> _imageCache = {};

  Future<bool> share({
    required BranchRow branch,
    Rect? sharePositionOrigin,
  }) async {
    final rows = await _ref
        .read(catalogDaoProvider)
        .watchAvailableProducts(branch.id)
        .first;
    if (rows.isEmpty) return false;

    final companySettings = await _ref.read(companySettingsDaoProvider).get();
    final menuImageSettings =
        await _ref.read(menuImageSettingsRepositoryProvider).getForBranch(
              branch.id,
            );
    final logoBytes = await _fetchImage(
      companySettings?.showReceiptLogo == true
          ? companySettings?.receiptLogoUrl
          : null,
    );
    final items = await Future.wait(
      rows.map(
        (row) async => _ShareMenuItem.fromRow(
          row,
          imageBytes: await _fetchImage(row.product.imageUrl),
        ),
      ),
    );

    items.sort((a, b) {
      final categoryCompare = a.category.compareTo(b.category);
      if (categoryCompare != 0) return categoryCompare;
      return a.name.compareTo(b.name);
    });

    final payload = _ShareMenuPayload(
      branchName: branch.name,
      branchAddress: branch.address,
      branchWhatsapp: branch.phone,
      logoBytes: logoBytes,
      items: items,
      settings: menuImageSettings,
    );
    final bytes = await const _ShareMenuImageRenderer().renderPng(payload);
    final dir = await getTemporaryDirectory();
    final fileName =
        'menu-${branch.name.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '-')}-${menuImageSettings.imageWidthPx}px-${DateTime.now().millisecondsSinceEpoch}.png';
    final file = File(p.join(dir.path, fileName));
    await file.writeAsBytes(bytes, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'image/png', name: fileName)],
      subject: 'Menu ${branch.name}',
      text: 'Menu ${branch.name}',
      sharePositionOrigin: sharePositionOrigin,
    );
    return true;
  }

  Future<Uint8List?> _fetchImage(String? url) async {
    if (url == null || url.isEmpty) return null;
    if (_imageCache.containsKey(url)) return _imageCache[url];
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) return null;
      final bytes = response.bodyBytes;
      _imageCache[url] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }
}

class _ShareMenuPayload {
  const _ShareMenuPayload({
    required this.branchName,
    required this.branchAddress,
    required this.branchWhatsapp,
    required this.logoBytes,
    required this.items,
    required this.settings,
  });

  final String branchName;
  final String? branchAddress;
  final String? branchWhatsapp;
  final Uint8List? logoBytes;
  final List<_ShareMenuItem> items;
  final MenuImageSettings settings;
}

class _ShareMenuItem {
  const _ShareMenuItem({
    required this.name,
    required this.category,
    required this.price,
    required this.imageBytes,
  });

  final String name;
  final String category;
  final double price;
  final Uint8List? imageBytes;

  factory _ShareMenuItem.fromRow(
    BranchProductWithProductRow row, {
    required Uint8List? imageBytes,
  }) {
    final product = row.product;
    final branchProduct = row.branchProduct;
    return _ShareMenuItem(
      name: branchProduct.customName ?? product.name,
      category: product.category ?? '',
      price: effectiveUnitPrice(
        basePrice: product.basePrice,
        priceOverride: branchProduct.priceOverride,
        discountPercentage: branchProduct.discountPercentage,
        discountValidUntil: branchProduct.discountValidUntil,
        now: DateTime.now(),
      ),
      imageBytes: imageBytes,
    );
  }
}

class _ShareMenuImageRenderer {
  const _ShareMenuImageRenderer();

  static const double _width = 2160;
  static const double _padding = 112;
  static const double _gap = 48;
  static const double _cardGap = 36;
  static const Color _surface = Colors.white;
  static const Color _surfaceAlt = Color(0xFFEFF6F4);
  static const Color _primary = Color(0xFF0F766E);
  static const Color _accent = Color(0xFFF59E0B);
  static const Color _text = Color(0xFF111827);
  static const Color _muted = Color(0xFF64748B);
  static const Color _border = Color(0xFFE2E8F0);

  Future<Uint8List> renderPng(_ShareMenuPayload payload) async {
    final logo = await _decode(payload.logoBytes);
    final images = <_ShareMenuItem, ui.Image?>{};
    for (final item in payload.items) {
      images[item] = await _decode(item.imageBytes);
    }

    final layout = _ShareMenuImageLayout(
      payload: payload,
      logo: logo,
      images: images,
    );
    final logicalHeight = layout.measure();
    final outputWidth =
        normalizeMenuImageWidthPx(payload.settings.imageWidthPx);
    final scale = outputWidth / _width;
    final outputHeight = (logicalHeight * scale).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.scale(scale);
    layout.paint(canvas, logicalHeight);
    final image = await recorder.endRecording().toImage(
          outputWidth,
          outputHeight,
        );
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    if (data == null) throw StateError(shareMenuImageEncodeFailedCode);
    return data.buffer.asUint8List();
  }

  static Future<ui.Image?> _decode(Uint8List? bytes) async {
    if (bytes == null) return null;
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }
}

class _ShareMenuImageLayout {
  _ShareMenuImageLayout({
    required this.payload,
    required this.logo,
    required this.images,
  });

  final _ShareMenuPayload payload;
  final ui.Image? logo;
  final Map<_ShareMenuItem, ui.Image?> images;

  var _y = _ShareMenuImageRenderer._padding;

  double get _contentWidth =>
      _ShareMenuImageRenderer._width - (_ShareMenuImageRenderer._padding * 2);

  double get _cardWidth =>
      (_contentWidth -
          (_ShareMenuImageRenderer._cardGap *
              (payload.settings.columns - 1).toDouble())) /
      payload.settings.columns.toDouble();

  double get _cardHeight => payload.settings.columns == 2 ? 820 : 696;

  double measure() {
    _y = _ShareMenuImageRenderer._padding;
    _layout(null);
    return _y + _ShareMenuImageRenderer._padding;
  }

  void paint(Canvas canvas, double height) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, _ShareMenuImageRenderer._width, height),
      Paint()
        ..color = colorFromMenuImageHex(payload.settings.backgroundColorHex),
    );
    _y = _ShareMenuImageRenderer._padding;
    _layout(canvas);
  }

  void _layout(Canvas? canvas) {
    _header(canvas);
    _grid(canvas);
  }

  void _header(Canvas? canvas) {
    final hasText = payload.settings.showBranchName ||
        (payload.settings.showBranchAddress &&
            (payload.branchAddress?.isNotEmpty ?? false)) ||
        (payload.settings.showBranchPhone &&
            (payload.branchWhatsapp?.isNotEmpty ?? false));
    if (logo == null && !hasText) return;

    if (payload.settings.headerLayout == MenuImageHeaderLayout.split &&
        logo != null &&
        hasText) {
      _splitHeader(canvas);
      return;
    }

    final logoWidth = _contentWidth * 0.44;
    final logoHeight = logo == null ? 0.0 : math.min(300.0, logoWidth * 0.36);
    final headerHeight = logo == null
        ? 420.0
        : hasText
            ? 820.0
            : logoHeight + 96.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _ShareMenuImageRenderer._padding,
        _y,
        _contentWidth,
        headerHeight,
      ),
      const Radius.circular(56),
    );
    canvas?.drawRRect(rect, Paint()..color = _ShareMenuImageRenderer._surface);
    canvas?.drawRRect(
      rect,
      Paint()
        ..color = _ShareMenuImageRenderer._border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    var cursor = _y + 32;
    if (logo != null) {
      _drawImageFit(
        canvas,
        logo!,
        Rect.fromLTWH(
          (_ShareMenuImageRenderer._width - logoWidth) / 2,
          cursor,
          logoWidth,
          logoHeight,
        ),
        contain: true,
      );
      cursor += logoHeight + 42;
    }
    if (payload.settings.showBranchName) {
      cursor += _text(
        canvas,
        payload.branchName,
        x: _ShareMenuImageRenderer._padding + 64,
        y: cursor,
        maxWidth: _contentWidth - 128,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: const TextStyle(
          color: _ShareMenuImageRenderer._text,
          fontSize: 84,
          fontWeight: FontWeight.w800,
        ),
      );
      cursor += 16;
    }
    if (payload.settings.showBranchAddress &&
        (payload.branchAddress?.isNotEmpty ?? false)) {
      cursor += _text(
        canvas,
        payload.branchAddress!,
        x: _ShareMenuImageRenderer._padding + 96,
        y: cursor,
        maxWidth: _contentWidth - 192,
        textAlign: TextAlign.center,
        maxLines: 2,
        style: const TextStyle(
          color: _ShareMenuImageRenderer._muted,
          fontSize: 44,
          fontWeight: FontWeight.w500,
        ),
      );
      cursor += 12;
    }
    if (payload.settings.showBranchPhone &&
        (payload.branchWhatsapp?.isNotEmpty ?? false)) {
      _text(
        canvas,
        '📱 ${payload.branchWhatsapp!}',
        x: _ShareMenuImageRenderer._padding + 96,
        y: cursor,
        maxWidth: _contentWidth - 192,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: const TextStyle(
          color: _ShareMenuImageRenderer._primary,
          fontSize: 46,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    _y += headerHeight + 34;
  }

  void _splitHeader(Canvas? canvas) {
    const headerHeight = 460.0;
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        _ShareMenuImageRenderer._padding,
        _y,
        _contentWidth,
        headerHeight,
      ),
      const Radius.circular(56),
    );
    canvas?.drawRRect(rect, Paint()..color = _ShareMenuImageRenderer._surface);
    canvas?.drawRRect(
      rect,
      Paint()
        ..color = _ShareMenuImageRenderer._border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    final logoRect = Rect.fromLTWH(
      _ShareMenuImageRenderer._padding + 72,
      _y + 64,
      _contentWidth * 0.42,
      headerHeight - 128,
    );
    _drawImageFit(canvas, logo!, logoRect, contain: true);

    final textX = logoRect.right + 72;
    final textWidth = _ShareMenuImageRenderer._width -
        textX -
        _ShareMenuImageRenderer._padding -
        72;
    var cursor = _y + 78;
    if (payload.settings.showBranchName) {
      cursor += _text(
        canvas,
        payload.branchName,
        x: textX,
        y: cursor,
        maxWidth: textWidth,
        maxLines: 2,
        style: const TextStyle(
          color: _ShareMenuImageRenderer._text,
          fontSize: 72,
          fontWeight: FontWeight.w800,
        ),
      );
      cursor += 14;
    }
    if (payload.settings.showBranchAddress &&
        (payload.branchAddress?.isNotEmpty ?? false)) {
      cursor += _text(
        canvas,
        payload.branchAddress!,
        x: textX,
        y: cursor,
        maxWidth: textWidth,
        maxLines: 2,
        style: const TextStyle(
          color: _ShareMenuImageRenderer._muted,
          fontSize: 42,
          fontWeight: FontWeight.w500,
        ),
      );
      cursor += 10;
    }
    if (payload.settings.showBranchPhone &&
        (payload.branchWhatsapp?.isNotEmpty ?? false)) {
      _text(
        canvas,
        '📱 ${payload.branchWhatsapp!}',
        x: textX,
        y: cursor,
        maxWidth: textWidth,
        maxLines: 1,
        style: const TextStyle(
          color: _ShareMenuImageRenderer._primary,
          fontSize: 44,
          fontWeight: FontWeight.w700,
        ),
      );
    }
    _y += headerHeight + 34;
  }

  void _grid(Canvas? canvas) {
    for (var i = 0; i < payload.items.length; i++) {
      final row = i ~/ payload.settings.columns;
      final column = i % payload.settings.columns;
      final x = _ShareMenuImageRenderer._padding +
          column.toDouble() * (_cardWidth + _ShareMenuImageRenderer._cardGap);
      final y =
          _y + row.toDouble() * (_cardHeight + _ShareMenuImageRenderer._gap);
      _menuCard(canvas, payload.items[i], x, y, _cardWidth, _cardHeight);
    }
    final rows = (payload.items.length / payload.settings.columns).ceil();
    final rowGapCount = math.max(0, rows - 1).toDouble();
    _y += rows.toDouble() * _cardHeight +
        rowGapCount * _ShareMenuImageRenderer._gap;
  }

  void _menuCard(
    Canvas? canvas,
    _ShareMenuItem item,
    double x,
    double y,
    double width,
    double height,
  ) {
    final rect = RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, width, height),
      const Radius.circular(36),
    );
    canvas?.drawRRect(rect, Paint()..color = _ShareMenuImageRenderer._surface);
    canvas?.drawRRect(
      rect,
      Paint()
        ..color = _ShareMenuImageRenderer._border
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );

    final imageHeight = payload.settings.columns == 2 ? 460.0 : 376.0;
    final imageRect = Rect.fromLTWH(x + 28, y + 28, width - 56, imageHeight);
    final clip = RRect.fromRectAndRadius(imageRect, const Radius.circular(28));
    canvas?.save();
    canvas?.clipRRect(clip);
    final image = images[item];
    if (image == null) {
      canvas?.drawRect(
        imageRect,
        Paint()..color = _ShareMenuImageRenderer._surfaceAlt,
      );
      _text(
        canvas,
        'MENU',
        x: imageRect.left,
        y: imageRect.top + (imageRect.height / 2) - 28,
        maxWidth: imageRect.width,
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: _ShareMenuImageRenderer._primary,
          fontSize: 56,
          fontWeight: FontWeight.w800,
          letterSpacing: 2.8,
        ),
      );
    } else {
      _drawImageFit(canvas, image, imageRect);
    }
    canvas?.restore();

    final textTop = y + imageHeight + 64;
    final nameHeight = _text(
      canvas,
      item.name,
      x: x + 36,
      y: textTop,
      maxWidth: width - 72,
      maxLines: 1,
      style: const TextStyle(
        color: _ShareMenuImageRenderer._text,
        fontSize: 48,
        fontWeight: FontWeight.w800,
        height: 1.1,
      ),
    );
    _text(
      canvas,
      formatRupiah(item.price),
      x: x + 36,
      y: textTop + nameHeight + 16,
      maxWidth: width - 72,
      maxLines: 1,
      style: const TextStyle(
        color: _ShareMenuImageRenderer._accent,
        fontSize: 54,
        fontWeight: FontWeight.w900,
      ),
    );
  }

  void _drawImageFit(
    Canvas? canvas,
    ui.Image image,
    Rect dst, {
    bool contain = false,
  }) {
    if (canvas == null) return;
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();
    final scale = (contain
            ? math.min(dst.width / imageWidth, dst.height / imageHeight)
            : math.max(dst.width / imageWidth, dst.height / imageHeight))
        .toDouble();
    final sourceWidth = contain ? imageWidth : dst.width / scale;
    final sourceHeight = contain ? imageHeight : dst.height / scale;
    final source = Rect.fromLTWH(
      (imageWidth - sourceWidth) / 2,
      (imageHeight - sourceHeight) / 2,
      sourceWidth,
      sourceHeight,
    );
    final target = contain
        ? Rect.fromCenter(
            center: dst.center,
            width: imageWidth * scale,
            height: imageHeight * scale,
          )
        : dst;
    canvas.drawImageRect(
      image,
      source,
      target,
      Paint()..filterQuality = FilterQuality.high,
    );
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

final shareMenuImageUseCaseProvider = Provider<ShareMenuImageUseCase>(
  ShareMenuImageUseCase.new,
);
