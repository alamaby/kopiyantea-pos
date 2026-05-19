import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/domain/enums.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../catalog/catalog_providers.dart';
import 'modifier_providers.dart';

/// FEAT-001 — pick which modifier groups apply to a product.
class ProductOptionsScreen extends ConsumerWidget {
  const ProductOptionsScreen({required this.productId, super.key});
  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productAsync = ref.watch(productByIdProvider(productId));
    final groupsAsync = ref.watch(allOptionGroupsProvider);
    final boundAsync = ref.watch(productOptionGroupsProvider(productId));

    return Scaffold(
      appBar: AppBar(
        title: productAsync.maybeWhen(
          data: (p) =>
              Text(p == null ? 'Modifier' : 'Modifier · ${p.name}'),
          orElse: () => const Text('Modifier'),
        ),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: 'Gagal',
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return const AppEmptyState(
              title: 'Belum ada grup modifier',
              icon: Icons.tune_outlined,
              message:
                  'Buat grup terlebih dahulu di Pengaturan → Modifier Produk.',
            );
          }
          final bound = boundAsync.maybeWhen(
            data: (list) => list.map((g) => g.group.id).toSet(),
            orElse: () => <String>{},
          );
          return ListView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            children: [
              Text(
                'Centang grup yang dipakai produk ini. Pelanggan akan melihat '
                'picker modifier saat menambahkan item ke keranjang.',
                style: AppTypography.bodySm
                    .copyWith(color: context.colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.lg),
              for (final g in groups)
                _GroupCheckbox(
                  group: g,
                  productId: productId,
                  initiallyBound: bound.contains(g.id),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _GroupCheckbox extends ConsumerWidget {
  const _GroupCheckbox({
    required this.group,
    required this.productId,
    required this.initiallyBound,
  });
  final OptionGroupRow group;
  final String productId;
  final bool initiallyBound;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CheckboxListTile(
      value: initiallyBound,
      onChanged: (v) async {
        final dao = ref.read(optionDaoProvider);
        final outbox = ref.read(outboxDaoProvider);
        if (v == true) {
          await dao.linkProductGroup(
            productId: productId,
            optionGroupId: group.id,
          );
          await outbox.enqueue(OutboxItemsCompanion.insert(
            id: const Uuid().v7(),
            entityType: OutboxEntityType.productOptionGroup,
            payload: jsonEncode({
              'product_id': productId,
              'option_group_id': group.id,
              'action': 'upsert',
            }),
            createdAt: DateTime.now(),
          ));
        } else {
          await dao.unlinkProductGroup(
            productId: productId,
            optionGroupId: group.id,
          );
          await outbox.enqueue(OutboxItemsCompanion.insert(
            id: const Uuid().v7(),
            entityType: OutboxEntityType.productOptionGroup,
            payload: jsonEncode({
              'product_id': productId,
              'option_group_id': group.id,
              'action': 'delete',
            }),
            createdAt: DateTime.now(),
          ));
        }
      },
      title: Text(group.name, style: AppTypography.titleMd),
      subtitle: Text(
        '${group.isRequired ? "Wajib" : "Opsional"} · '
        '${group.isMultiSelect ? "Multi" : "Tunggal"}',
        style: AppTypography.bodySm
            .copyWith(color: context.colors.textSecondary),
      ),
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.primary,
    );
  }
}
