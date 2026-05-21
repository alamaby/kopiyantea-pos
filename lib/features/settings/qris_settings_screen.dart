import 'dart:convert';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
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

/// FEAT-013 — per-branch static QRIS image upload.
class QrisSettingsScreen extends ConsumerWidget {
  const QrisSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(allBranchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('QRIS Statis')),
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
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppSpacing.lg),
            itemBuilder: (_, i) => _BranchQrisCard(branch: branches[i]),
          );
        },
      ),
    );
  }
}

class _BranchQrisCard extends ConsumerStatefulWidget {
  const _BranchQrisCard({required this.branch});
  final BranchRow branch;

  @override
  ConsumerState<_BranchQrisCard> createState() => _BranchQrisCardState();
}

class _BranchQrisCardState extends ConsumerState<_BranchQrisCard> {
  bool _uploading = false;

  Future<void> _upload(ImageSource_ source) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _uploading = true);
    final svc = ref.read(imageUploadServiceProvider);
    final result = await svc.pickAndUpload(
      source: source,
      bucket: ImageBuckets.qris,
      pathPrefix: 'branches/',
    );
    if (!mounted) return;
    setState(() => _uploading = false);
    switch (result) {
      case Ok(:final value):
        await _saveUrl(value);
        // Best-effort cleanup of previous image.
        final old = widget.branch.qrisImageUrl;
        if (old != null && old.isNotEmpty) {
          await svc.deleteByUrl(old, bucket: ImageBuckets.qris);
        }
        if (!mounted) return;
        messenger.showSnackBar(
          const SnackBar(content: Text('QRIS diperbarui')),
        );
      case Err(:final error):
        if (error == ImageUploadError.cancelled) return;
        messenger.showSnackBar(
          SnackBar(content: Text('Gagal upload: ${error.name}')),
        );
    }
  }

  Future<void> _saveUrl(String? url) async {
    final dao = ref.read(branchDaoProvider);
    final outboxDao = ref.read(outboxDaoProvider);
    final now = DateTime.now();
    await dao.updateById(
      widget.branch.id,
      BranchesCompanion(
        qrisImageUrl: Value(url),
        updatedAt: Value(now),
      ),
    );
    await outboxDao.enqueue(OutboxItemsCompanion.insert(
      id: const Uuid().v7(),
      entityType: OutboxEntityType.branch,
      payload: jsonEncode({'id': widget.branch.id}),
      createdAt: now,
    ));
    ref.invalidate(allBranchesProvider);
  }

  Future<void> _remove() async {
    final messenger = ScaffoldMessenger.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus QRIS?'),
        content: Text(
          'QRIS untuk ${widget.branch.name} akan dihapus. Customer tidak '
          'bisa scan QRIS sampai diunggah ulang.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final old = widget.branch.qrisImageUrl;
    await _saveUrl(null);
    if (old != null && old.isNotEmpty) {
      await ref
          .read(imageUploadServiceProvider)
          .deleteByUrl(old, bucket: ImageBuckets.qris);
    }
    if (!mounted) return;
    messenger.showSnackBar(const SnackBar(content: Text('QRIS dihapus')));
  }

  @override
  Widget build(BuildContext context) {
    final hasImage = widget.branch.qrisImageUrl != null &&
        widget.branch.qrisImageUrl!.isNotEmpty;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.branch.name, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.md),
          if (hasImage)
            ClipRRect(
              borderRadius: AppRadius.radiusMd,
              child: AspectRatio(
                aspectRatio: 1,
                child: CachedNetworkImage(
                  imageUrl: widget.branch.qrisImageUrl!,
                  fit: BoxFit.contain,
                  placeholder: (_, __) =>
                      const Center(child: AppLoadingIndicator()),
                  errorWidget: (_, __, ___) => Container(
                    color: context.colors.surfaceAlt,
                    child: const Center(
                      child: Icon(Icons.broken_image_outlined,
                          color: AppColors.danger),
                    ),
                  ),
                ),
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(AppSpacing.xxl),
              decoration: BoxDecoration(
                color: context.colors.surfaceAlt,
                borderRadius: AppRadius.radiusMd,
                border: Border.all(
                  color: context.colors.border,
                  style: BorderStyle.solid,
                ),
              ),
              child: Column(
                children: [
                  Icon(Icons.qr_code_2_outlined,
                      size: 56, color: context.colors.textTertiary),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Belum ada QRIS terunggah',
                    style: AppTypography.bodySm
                        .copyWith(color: context.colors.textSecondary),
                  ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  label: hasImage ? 'Ganti dari Galeri' : 'Galeri',
                  icon: Icons.photo_library_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _uploading
                      ? null
                      : () => _upload(ImageSource_.gallery),
                  isLoading: _uploading,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: AppButton(
                  label: 'Kamera',
                  icon: Icons.camera_alt_outlined,
                  variant: AppButtonVariant.secondary,
                  onPressed: _uploading
                      ? null
                      : () => _upload(ImageSource_.camera),
                ),
              ),
            ],
          ),
          if (hasImage) ...[
            const SizedBox(height: AppSpacing.sm),
            AppButton(
              label: 'Hapus QRIS',
              icon: Icons.delete_outline,
              variant: AppButtonVariant.danger,
              onPressed: _uploading ? null : _remove,
              fullWidth: true,
            ),
          ],
        ],
      ),
    );
  }
}
