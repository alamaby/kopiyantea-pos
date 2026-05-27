import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/database/database_provider.dart';
import '../../core/domain/enums.dart';
import '../../core/storage/image_upload_service.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'branch_selection_provider.dart';

/// FEAT-014 — per-branch receipt template configuration.
class ReceiptSettingsScreen extends ConsumerWidget {
  const ReceiptSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(allBranchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tampilan Struk')),
      body: branchesAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal memuat cabang',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (branches) {
          if (branches.isEmpty) {
            return const AppEmptyState(
              title: 'Belum ada cabang',
              icon: Icons.store_outlined,
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(AppSpacing.lg),
            itemCount: branches.length,
            separatorBuilder: (_, __) => const SizedBox(height: AppSpacing.lg),
            itemBuilder: (_, i) => _BranchReceiptCard(branch: branches[i]),
          );
        },
      ),
    );
  }
}

class _BranchReceiptCard extends ConsumerStatefulWidget {
  const _BranchReceiptCard({required this.branch});
  final BranchRow branch;

  @override
  ConsumerState<_BranchReceiptCard> createState() => _BranchReceiptCardState();
}

class _BranchReceiptCardState extends ConsumerState<_BranchReceiptCard> {
  final _headerCtrl = TextEditingController();
  final _footerCtrl = TextEditingController();
  int _paperWidth = 58;
  bool _showLogo = false;
  String? _logoUrl;
  String _logoPosition = 'top';
  bool _showCashierName = true;
  bool _showCustomerName = true;
  bool _showBranchName = true;
  bool _printQrisOnReceipt = false;

  bool _loaded = false;
  bool _saving = false;
  bool _uploadingLogo = false;
  ReceiptSettingRow? _existing;

  @override
  void initState() {
    super.initState();
    _headerCtrl.addListener(_onTemplateChanged);
    _footerCtrl.addListener(_onTemplateChanged);
    _load();
  }

  @override
  void dispose() {
    _headerCtrl.removeListener(_onTemplateChanged);
    _footerCtrl.removeListener(_onTemplateChanged);
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
  }

  void _onTemplateChanged() {
    if (mounted && _loaded) setState(() {});
  }

  Future<void> _load() async {
    final db = ref.read(databaseProvider);
    final row = await (db.select(db.receiptSettings)
          ..where((s) => s.branchId.equals(widget.branch.id)))
        .getSingleOrNull();
    if (!mounted) return;
    setState(() {
      _existing = row;
      if (row != null) {
        _headerCtrl.text = row.headerText ?? '';
        _footerCtrl.text = row.footerText ?? '';
        _paperWidth = row.paperWidthMm;
        _showLogo = row.showLogo;
        _logoUrl = row.logoUrl;
        _logoPosition = row.logoPosition;
        _showCashierName = row.showCashierName;
        _showCustomerName = row.showCustomerName;
        _showBranchName = row.showBranchName;
        _printQrisOnReceipt = row.printQrisOnReceipt;
      }
      _loaded = true;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final companion = ReceiptSettingsCompanion(
      id: Value(_existing?.id ?? const Uuid().v7()),
      branchId: Value(widget.branch.id),
      headerText: Value(
          _headerCtrl.text.trim().isEmpty ? null : _headerCtrl.text.trim()),
      footerText: Value(
          _footerCtrl.text.trim().isEmpty ? null : _footerCtrl.text.trim()),
      logoUrl: Value(_logoUrl),
      logoPosition: Value(_logoPosition),
      paperWidthMm: Value(_paperWidth),
      showLogo: Value(_showLogo),
      showCashierName: Value(_showCashierName),
      showCustomerName: Value(_showCustomerName),
      showBranchName: Value(_showBranchName),
      printQrisOnReceipt: Value(_printQrisOnReceipt),
      updatedAt: Value(now),
    );
    await db.into(db.receiptSettings).insertOnConflictUpdate(companion);
    await ref.read(outboxDaoProvider).enqueue(OutboxItemsCompanion.insert(
          id: const Uuid().v7(),
          entityType: OutboxEntityType.receiptSetting,
          payload: jsonEncode({'id': companion.id.value}),
          createdAt: now,
        ));
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Tersimpan untuk ${widget.branch.name}')),
    );
    _load();
  }

  Future<void> _uploadLogo() async {
    final source = await showModalBottomSheet<ImageSource_>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, ImageSource_.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, ImageSource_.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final svc = ref.read(imageUploadServiceProvider);
    setState(() => _uploadingLogo = true);
    final result = await svc.pickAndUpload(
      source: source,
      bucket: ImageBuckets.logos,
      pathPrefix: 'branches/',
    );
    if (!mounted) return;
    setState(() => _uploadingLogo = false);
    switch (result) {
      case Ok(:final value):
        final old = _logoUrl;
        setState(() {
          _logoUrl = value;
          _showLogo = true;
        });
        if (old != null && old.isNotEmpty) {
          await svc.deleteByUrl(old, bucket: ImageBuckets.logos);
        }
      case Err(:final error):
        if (error == ImageUploadError.cancelled) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal upload: ${error.name}')),
        );
    }
  }

  Future<void> _removeLogo() async {
    final svc = ref.read(imageUploadServiceProvider);
    final old = _logoUrl;
    setState(() {
      _logoUrl = null;
      _showLogo = false;
    });
    if (old != null && old.isNotEmpty) {
      await svc.deleteByUrl(old, bucket: ImageBuckets.logos);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const AppCard(
        child: SizedBox(
          height: 120,
          child: Center(child: AppLoadingIndicator()),
        ),
      );
    }
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.branch.name, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.md),
          _ReceiptPreview(
            branch: widget.branch,
            headerText: _headerCtrl.text.trim(),
            footerText: _footerCtrl.text.trim(),
            paperWidthMm: _paperWidth,
            showLogo: _showLogo,
            logoUrl: _logoUrl,
            logoPosition: _logoPosition,
            showCashierName: _showCashierName,
            showCustomerName: _showCustomerName,
            showBranchName: _showBranchName,
            printQrisOnReceipt: _printQrisOnReceipt,
          ),
          const SizedBox(height: AppSpacing.lg),

          // Logo
          _LabelRow(label: 'Logo'),
          if (_logoUrl != null && _logoUrl!.isNotEmpty) ...[
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: Colors.white, // logo dirender di kertas putih
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: context.colors.border),
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 120),
                  child: CachedNetworkImage(
                    imageUrl: _logoUrl!,
                    fit: BoxFit.contain,
                    placeholder: (_, __) => const SizedBox(
                        height: 80, child: AppLoadingIndicator()),
                    errorWidget: (_, __, ___) => const Icon(
                      Icons.broken_image_outlined,
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ),
            ),
          ] else
            Container(
              padding: const EdgeInsets.all(AppSpacing.xl),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(color: context.colors.border),
              ),
              child: Column(
                children: [
                  Icon(Icons.image_outlined,
                      size: 36, color: context.colors.textTertiary),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Belum ada logo',
                    style: AppTypography.bodySm.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: _logoUrl == null ? 'Unggah Logo' : 'Ganti Logo',
                  icon: Icons.upload_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _uploadingLogo ? null : _uploadLogo,
                  isLoading: _uploadingLogo,
                ),
              ),
              if (_logoUrl != null) ...[
                const SizedBox(width: AppSpacing.sm),
                IconButton(
                  onPressed: _uploadingLogo ? null : _removeLogo,
                  icon: const Icon(Icons.delete_outline),
                  tooltip: 'Hapus logo',
                  color: AppColors.danger,
                ),
              ],
            ],
          ),
          if (_logoUrl != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: AppRadius.radiusSm,
              ),
              child: Text(
                'Format ideal: PNG hitam-putih, latar putih, max 384px '
                'lebar (58mm) atau 576px (80mm). Logo dengan gradasi/warna '
                'akan di-dither ke B&W oleh printer.',
                style: AppTypography.labelSm
                    .copyWith(color: context.colors.textSecondary),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            SwitchListTile(
              value: _showLogo,
              onChanged: (v) => setState(() => _showLogo = v),
              title: Text('Tampilkan di struk', style: AppTypography.titleMd),
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
            ),
            if (_showLogo) ...[
              _LabelRow(label: 'Posisi logo'),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'top',
                    label: Text('Atas'),
                    icon: Icon(Icons.vertical_align_top),
                  ),
                  ButtonSegment(
                    value: 'bottom',
                    label: Text('Bawah'),
                    icon: Icon(Icons.vertical_align_bottom),
                  ),
                ],
                selected: {_logoPosition},
                onSelectionChanged: (s) =>
                    setState(() => _logoPosition = s.first),
              ),
            ],
          ],

          const SizedBox(height: AppSpacing.lg),
          // Header
          _LabelRow(label: 'Teks header (opsional)'),
          TextField(
            controller: _headerCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              hintText: 'mis. Selamat datang di Kopiyantea!',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Muncul di bawah nama+alamat cabang.',
            style: AppTypography.labelXs
                .copyWith(color: context.colors.textSecondary),
          ),

          const SizedBox(height: AppSpacing.lg),
          // Footer
          _LabelRow(label: 'Teks footer (opsional)'),
          TextField(
            controller: _footerCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText:
                  'mis. Barang yang sudah dibeli tidak dapat ditukar/dikembalikan',
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            'Muncul setelah "Terima Kasih".',
            style: AppTypography.labelXs
                .copyWith(color: context.colors.textSecondary),
          ),

          const SizedBox(height: AppSpacing.lg),
          // FEAT-014b — cashier accountability toggle.
          SwitchListTile(
            value: _showBranchName,
            onChanged: (v) => setState(() => _showBranchName = v),
            title: Text('Tampilkan nama cabang', style: AppTypography.titleMd),
            subtitle: Text(
              'Cetak nama cabang seperti "${widget.branch.name}" di bagian atas struk',
              style: AppTypography.bodySm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),

          SwitchListTile(
            value: _showCashierName,
            onChanged: (v) => setState(() => _showCashierName = v),
            title: Text('Tampilkan nama kasir', style: AppTypography.titleMd),
            subtitle: Text(
              'Cetak "Kasir: Nama" di header struk untuk audit',
              style: AppTypography.bodySm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),

          SwitchListTile(
            value: _showCustomerName,
            onChanged: (v) => setState(() => _showCustomerName = v),
            title:
                Text('Tampilkan nama pelanggan', style: AppTypography.titleMd),
            subtitle: Text(
              'Cetak nama pelanggan dan nomor telepon yang dimasking jika transaksi punya pelanggan',
              style: AppTypography.bodySm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),

          // ENH-004 — print static QRIS on receipt.
          SwitchListTile(
            value: _printQrisOnReceipt,
            onChanged: (v) => setState(() => _printQrisOnReceipt = v),
            title: Text('Cetak QRIS di struk', style: AppTypography.titleMd),
            subtitle: Text(
              'Untuk transaksi QRIS, cetak QR cabang di struk. Berguna '
              'untuk skenario bayar belakangan (takeaway, delivery, '
              'pro-forma invoice). Customer scan QR + masukkan nominal '
              'manual sesuai TOTAL.',
              style: AppTypography.bodySm.copyWith(
                color: context.colors.textSecondary,
              ),
            ),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),

          const SizedBox(height: AppSpacing.lg),
          // Paper width
          _LabelRow(label: 'Lebar kertas'),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 58, label: Text('58mm')),
              ButtonSegment(value: 80, label: Text('80mm')),
            ],
            selected: {_paperWidth},
            onSelectionChanged: (s) => setState(() => _paperWidth = s.first),
          ),

          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _saving ? 'Menyimpan…' : 'Simpan',
            icon: Icons.save_outlined,
            onPressed: _saving ? null : _save,
            isLoading: _saving,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _ReceiptPreview extends StatelessWidget {
  const _ReceiptPreview({
    required this.branch,
    required this.headerText,
    required this.footerText,
    required this.paperWidthMm,
    required this.showLogo,
    required this.logoUrl,
    required this.logoPosition,
    required this.showCashierName,
    required this.showCustomerName,
    required this.showBranchName,
    required this.printQrisOnReceipt,
  });

  final BranchRow branch;
  final String headerText;
  final String footerText;
  final int paperWidthMm;
  final bool showLogo;
  final String? logoUrl;
  final String logoPosition;
  final bool showCashierName;
  final bool showCustomerName;
  final bool showBranchName;
  final bool printQrisOnReceipt;

  @override
  Widget build(BuildContext context) {
    final paperWidth = paperWidthMm == 80 ? 360.0 : 288.0;
    final now = DateTime.now();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const _LabelRow(label: 'Preview struk'),
        Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: context.colors.surfaceAlt,
            borderRadius: AppRadius.radiusMd,
            border: Border.all(color: context.colors.border),
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: paperWidth),
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Color(0x22000000),
                      blurRadius: 10,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: DefaultTextStyle(
                    style: const TextStyle(
                      color: Colors.black,
                      fontFamily: 'monospace',
                      fontSize: 12,
                      height: 1.25,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_shouldShowLogo && logoPosition == 'top') ...[
                          _PreviewLogo(logoUrl: logoUrl!),
                          const SizedBox(height: AppSpacing.sm),
                        ],
                        if (showBranchName)
                          _CenterText(
                            branch.name,
                            bold: true,
                            size: 16,
                          ),
                        if (branch.address?.isNotEmpty ?? false)
                          _CenterText(branch.address!),
                        if (branch.phone?.isNotEmpty ?? false)
                          _CenterText(branch.phone!),
                        if (headerText.isNotEmpty) _CenterText(headerText),
                        const _ReceiptRule(),
                        _PreviewRow(label: 'No:', value: '#PREVIEW'),
                        _PreviewRow(
                          label: 'Tanggal:',
                          value: formatDateTime(now),
                        ),
                        if (showCustomerName)
                          const _PreviewRow(
                            label: 'Pelanggan:',
                            value: 'Contoh (081******379)',
                          ),
                        if (showCashierName)
                          const _PreviewRow(
                            label: 'Kasir:',
                            value: 'Kasir Demo',
                          ),
                        const _ReceiptRule(),
                        const Text('Kopi Susu Aren x 1'),
                        _PreviewRow(
                          label: '  ${formatRupiah(22000)}',
                          value: formatRupiah(22000),
                        ),
                        const Text('Nasi Goreng x 1'),
                        _PreviewRow(
                          label: '  ${formatRupiah(28000)}',
                          value: formatRupiah(28000),
                        ),
                        const Text('  - Level Pedas: Normal'),
                        const _ReceiptRule(),
                        _PreviewRow(
                          label: 'Subtotal',
                          value: formatRupiah(50000),
                        ),
                        _PreviewRow(
                          label: 'Diskon',
                          value: '-${formatRupiah(5000)}',
                        ),
                        _PreviewRow(
                          label: 'Pajak (${branch.taxLabel})',
                          value: formatRupiah(4500),
                        ),
                        const _ReceiptRule(),
                        _PreviewRow(
                          label: 'TOTAL',
                          value: formatRupiah(49500),
                          bold: true,
                          size: 15,
                        ),
                        const _ReceiptRule(),
                        const _PreviewRow(label: 'Bayar', value: 'Tunai'),
                        _PreviewRow(
                          label: 'Diterima',
                          value: formatRupiah(50000),
                        ),
                        _PreviewRow(
                          label: 'Kembalian',
                          value: formatRupiah(500),
                        ),
                        if (printQrisOnReceipt) ...[
                          const SizedBox(height: AppSpacing.sm),
                          const _CenterText(
                            'SCAN QRIS UNTUK BAYAR',
                            bold: true,
                          ),
                          const _CenterText(
                            'Masukkan nominal sesuai TOTAL di atas',
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Center(
                            child: Container(
                              width: 84,
                              height: 84,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.black),
                              ),
                              child: const Icon(
                                Icons.qr_code_2,
                                color: Colors.black,
                                size: 56,
                              ),
                            ),
                          ),
                        ],
                        const SizedBox(height: AppSpacing.sm),
                        const _CenterText('Terima Kasih', bold: true),
                        if (footerText.isNotEmpty) _CenterText(footerText),
                        if (_shouldShowLogo && logoPosition == 'bottom') ...[
                          const SizedBox(height: AppSpacing.sm),
                          _PreviewLogo(logoUrl: logoUrl!),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  bool get _shouldShowLogo =>
      showLogo && logoUrl != null && logoUrl!.isNotEmpty;
}

class _PreviewLogo extends StatelessWidget {
  const _PreviewLogo({required this.logoUrl});

  final String logoUrl;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxHeight: 64, maxWidth: 180),
        child: CachedNetworkImage(
          imageUrl: logoUrl,
          fit: BoxFit.contain,
          placeholder: (_, __) => const SizedBox(
            width: 96,
            height: 48,
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          ),
          errorWidget: (_, __, ___) => const Icon(
            Icons.broken_image_outlined,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _CenterText extends StatelessWidget {
  const _CenterText(this.text, {this.bold = false, this.size});

  final String text;
  final bool bold;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      textAlign: TextAlign.center,
      style: TextStyle(
        fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
        fontSize: size,
      ),
    );
  }
}

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.size,
  });

  final String label;
  final String value;
  final bool bold;
  final double? size;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
      fontSize: size,
    );
    return Row(
      children: [
        Expanded(child: Text(label, style: style)),
        const SizedBox(width: AppSpacing.sm),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            overflow: TextOverflow.ellipsis,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _ReceiptRule extends StatelessWidget {
  const _ReceiptRule();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Text(
        '--------------------------------',
        textAlign: TextAlign.center,
        overflow: TextOverflow.clip,
        maxLines: 1,
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.xs),
      child: Text(
        label.toUpperCase(),
        style: AppTypography.labelSm.copyWith(
          color: context.colors.textSecondary,
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}
