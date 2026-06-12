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
import '../../l10n/generated/app_localizations.dart';
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
    final l10n = AppL10n.of(context);

    return Scaffold(
      appBar: AppBar(
        title: productAsync.maybeWhen(
          data: (p) => Text(p == null
              ? l10n.modifiersTitle
              : l10n.modifiersProductTitleWithName(p.name)),
          orElse: () => Text(l10n.modifiersTitle),
        ),
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: AppLoadingIndicator()),
        error: (e, _) => AppEmptyState(
          title: l10n.modifiersGenericLoadFailed,
          icon: Icons.error_outline,
          message: e.toString(),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return AppEmptyState(
              title: l10n.modifiersEmptyGroupsTitle,
              icon: Icons.tune_outlined,
              message: l10n.modifiersEmptyProductGroupsMessage,
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
                l10n.modifiersProductHelp,
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
    final l10n = AppL10n.of(context);
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
        '${group.isRequired ? l10n.modifiersRequired : l10n.modifiersOptional} · '
        '${group.isMultiSelect ? l10n.modifiersMulti : l10n.modifiersSingle}',
        style:
            AppTypography.bodySm.copyWith(color: context.colors.textSecondary),
      ),
      contentPadding: EdgeInsets.zero,
      activeColor: AppColors.primary,
    );
  }
}
