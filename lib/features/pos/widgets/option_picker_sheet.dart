import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/daos/option_dao.dart';
import '../../../core/theme/colors.dart';
import '../../../core/theme/radius.dart';
import '../../../core/theme/spacing.dart';
import '../../../core/theme/typography.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_empty_state.dart';
import '../../../core/widgets/app_loading_indicator.dart';
import '../../modifiers/modifier_providers.dart';
import '../cart_state.dart';

/// FEAT-001 — modal sheet that collects modifier selections for a product
/// before it lands in the cart.
///
/// Returns `List<CartItemOption>?` — null on cancel; an empty list is a
/// valid "no extras" confirmation when all groups are optional.
class OptionPickerSheet extends ConsumerStatefulWidget {
  const OptionPickerSheet({required this.productId, required this.productName, super.key});

  final String productId;
  final String productName;

  static Future<List<CartItemOption>?> show(
    BuildContext context, {
    required String productId,
    required String productName,
  }) {
    return showModalBottomSheet<List<CartItemOption>>(
      context: context,
      isScrollControlled: true,
      builder: (_) => OptionPickerSheet(
        productId: productId,
        productName: productName,
      ),
    );
  }

  @override
  ConsumerState<OptionPickerSheet> createState() => _OptionPickerSheetState();
}

class _OptionPickerSheetState extends ConsumerState<OptionPickerSheet> {
  /// groupId → set of selected optionIds (multi or single).
  final Map<String, Set<String>> _picked = {};
  bool _initialized = false;

  void _seedDefaults(List<OptionGroupWithOptions> groups) {
    if (_initialized) return;
    _initialized = true;
    for (final g in groups) {
      final defaults =
          g.options.where((o) => o.isDefault).map((o) => o.id).toSet();
      if (defaults.isNotEmpty) {
        _picked[g.group.id] =
            g.group.isMultiSelect ? defaults : {defaults.first};
      }
    }
  }

  bool _validate(List<OptionGroupWithOptions> groups) {
    for (final g in groups) {
      if (g.group.isRequired) {
        final selected = _picked[g.group.id] ?? const {};
        if (selected.isEmpty) return false;
      }
    }
    return true;
  }

  List<CartItemOption> _build(List<OptionGroupWithOptions> groups) {
    final out = <CartItemOption>[];
    for (final g in groups) {
      final selected = _picked[g.group.id] ?? const {};
      for (final optId in selected) {
        final opt = g.options.firstWhere((o) => o.id == optId);
        out.add(CartItemOption(
          optionGroupId: g.group.id,
          optionId: opt.id,
          groupName: g.group.name,
          optionName: opt.name,
          priceDelta: opt.priceDelta,
        ));
      }
    }
    return out;
  }

  double _totalDelta(List<OptionGroupWithOptions> groups) {
    var sum = 0.0;
    for (final g in groups) {
      final selected = _picked[g.group.id] ?? const {};
      for (final id in selected) {
        final opt = g.options.firstWhere(
          (o) => o.id == id,
          orElse: () => OptionRow(
            id: '',
            groupId: '',
            name: '',
            priceDelta: 0,
            sortOrder: 0,
            isDefault: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        sum += opt.priceDelta;
      }
    }
    return sum;
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(productOptionGroupsProvider(widget.productId));
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        builder: (_, scrollCtrl) => Column(
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              decoration: BoxDecoration(
                color: context.colors.border,
                borderRadius: AppRadius.radiusSm,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: Row(
                children: [
                  Expanded(
                    child: Text(widget.productName,
                        style: AppTypography.headlineMd),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context, null),
                  ),
                ],
              ),
            ),
            Expanded(
              child: groupsAsync.when(
                loading: () =>
                    const Center(child: AppLoadingIndicator()),
                error: (e, _) => AppEmptyState(
                  title: 'Gagal',
                  icon: Icons.error_outline,
                  message: e.toString(),
                ),
                data: (groups) {
                  if (groups.isEmpty) {
                    // No groups bound — caller shouldn't have opened sheet,
                    // but just confirm with empty list.
                    WidgetsBinding.instance.addPostFrameCallback(
                      (_) => Navigator.pop<List<CartItemOption>>(
                          context, const []),
                    );
                    return const SizedBox.shrink();
                  }
                  _seedDefaults(groups);
                  return ListView(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    children: [
                      for (final g in groups) _GroupBlock(
                        group: g,
                        selected: _picked[g.group.id] ?? const {},
                        onToggle: (optId) {
                          setState(() {
                            final cur = _picked[g.group.id] ?? <String>{};
                            if (g.group.isMultiSelect) {
                              final next = {...cur};
                              if (next.contains(optId)) {
                                next.remove(optId);
                              } else {
                                next.add(optId);
                              }
                              _picked[g.group.id] = next;
                            } else {
                              _picked[g.group.id] = {optId};
                            }
                          });
                        },
                      ),
                    ],
                  );
                },
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: groupsAsync.maybeWhen(
                  data: (groups) {
                    final delta = _totalDelta(groups);
                    final valid = _validate(groups);
                    return Row(
                      children: [
                        if (delta != 0)
                          Padding(
                            padding: const EdgeInsets.only(right: AppSpacing.md),
                            child: Text(
                              '+${formatRupiah(delta)}',
                              style: AppTypography.titleMd
                                  .copyWith(color: AppColors.accent),
                            ),
                          ),
                        Expanded(
                          child: AppButton(
                            label: 'Tambahkan ke Keranjang',
                            icon: Icons.add_shopping_cart_outlined,
                            onPressed: valid
                                ? () => Navigator.pop(
                                      context,
                                      _build(groups),
                                    )
                                : null,
                            fullWidth: true,
                          ),
                        ),
                      ],
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupBlock extends StatelessWidget {
  const _GroupBlock({
    required this.group,
    required this.selected,
    required this.onToggle,
  });
  final OptionGroupWithOptions group;
  final Set<String> selected;
  final void Function(String optionId) onToggle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(group.group.name, style: AppTypography.titleMd),
              const SizedBox(width: AppSpacing.sm),
              if (group.group.isRequired)
                Text(
                  '· wajib',
                  style: AppTypography.labelSm
                      .copyWith(color: AppColors.danger),
                ),
              if (group.group.isMultiSelect)
                Text(
                  '· boleh multi',
                  style: AppTypography.labelSm
                      .copyWith(color: context.colors.textSecondary),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ...group.options.map(
            (o) => InkWell(
              onTap: () => onToggle(o.id),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: [
                    if (group.group.isMultiSelect)
                      Checkbox(
                        value: selected.contains(o.id),
                        onChanged: (_) => onToggle(o.id),
                      )
                    else
                      Radio<String>(
                        value: o.id,
                        groupValue: selected.firstOrNull,
                        onChanged: (_) => onToggle(o.id),
                      ),
                    Expanded(
                      child: Text(o.name, style: AppTypography.bodyMd),
                    ),
                    if (o.priceDelta != 0)
                      Text(
                        '+${formatRupiah(o.priceDelta)}',
                        style: AppTypography.bodySm
                            .copyWith(color: AppColors.accent),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

extension on Set<String> {
  String? get firstOrNull => isEmpty ? null : first;
}
