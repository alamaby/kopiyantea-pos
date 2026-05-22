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
  bool _printQrisOnReceipt = false;

  bool _loaded = false;
  bool _saving = false;
  bool _uploadingLogo = false;
  ReceiptSettingRow? _existing;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _headerCtrl.dispose();
    _footerCtrl.dispose();
    super.dispose();
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
