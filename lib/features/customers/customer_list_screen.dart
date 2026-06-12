import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import '../../l10n/generated/app_localizations.dart';
import 'customer_providers.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  _CustomerSort _sort = _CustomerSort.latestTransaction;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    final customersAsync = ref.watch(allCustomersProvider);
    final latestTransactionAt =
        ref.watch(customerLatestTransactionAtProvider).valueOrNull ?? const {};

    return Scaffold(
      appBar: AppBar(title: Text(l10n.navCustomers)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_customers',
        onPressed: () => context.push('/more/customers/new'),
        icon: const Icon(Icons.person_add_outlined),
        label: Text(l10n.actionAdd),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: l10n.customersSearchHint,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _query.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _query = '');
                            },
                          ),
                  ),
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
                const SizedBox(height: AppSpacing.sm),
                SegmentedButton<_CustomerSort>(
                  segments: [
                    ButtonSegment(
                      value: _CustomerSort.latestTransaction,
                      icon: const Icon(Icons.schedule_outlined),
                      label: Text(l10n.customersSortLatest),
                    ),
                    ButtonSegment(
                      value: _CustomerSort.points,
                      icon: const Icon(Icons.stars_outlined),
                      label: Text(l10n.receiptPoints),
                    ),
                  ],
                  selected: {_sort},
                  onSelectionChanged: (value) =>
                      setState(() => _sort = value.first),
                ),
              ],
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppEmptyState(
                title: l10n.customersLoadFailed,
                icon: Icons.error_outline,
                message: e.toString(),
              ),
              data: (customers) {
                final filtered = _sortCustomers(
                  _filter(customers, _query),
                  latestTransactionAt,
                );
                if (filtered.isEmpty) {
                  return AppEmptyState(
                    title: _query.isEmpty
                        ? l10n.customersEmptyTitle
                        : l10n.customersNotFound,
                    icon: _query.isEmpty
                        ? Icons.people_outline
                        : Icons.search_off_outlined,
                    message: _query.isEmpty ? l10n.customersEmptyMessage : null,
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    0,
                    AppSpacing.lg,
                    AppSpacing.xxxxl,
                  ),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(height: AppSpacing.sm),
                  itemBuilder: (_, i) => _CustomerTile(
                    customer: filtered[i],
                    latestTransactionAt: latestTransactionAt[filtered[i].id],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  List<CustomerRow> _filter(List<CustomerRow> list, String query) {
    if (query.isEmpty) return list;
    return list.where((c) {
      final inName = c.name.toLowerCase().contains(query);
      final inPhone = (c.phone ?? '').toLowerCase().contains(query);
      return inName || inPhone;
    }).toList();
  }

  List<CustomerRow> _sortCustomers(
    List<CustomerRow> list,
    Map<String, DateTime> latestTransactionAt,
  ) {
    final sorted = list.toList();
    sorted.sort((a, b) {
      final primary = switch (_sort) {
        _CustomerSort.latestTransaction => _compareNullableDateDesc(
            latestTransactionAt[a.id],
            latestTransactionAt[b.id],
          ),
        _CustomerSort.points => b.loyaltyPoints.compareTo(a.loyaltyPoints),
      };
      if (primary != 0) return primary;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return sorted;
  }

  int _compareNullableDateDesc(DateTime? a, DateTime? b) {
    if (a == null && b == null) return 0;
    if (a == null) return 1;
    if (b == null) return -1;
    return b.compareTo(a);
  }
}

enum _CustomerSort { latestTransaction, points }

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.latestTransactionAt,
  });

  final CustomerRow customer;
  final DateTime? latestTransactionAt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.of(context);
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: () => context.push('/more/customers/${customer.id}'),
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primarySurface,
                child: Text(
                  customer.name.isEmpty ? '?' : customer.name[0].toUpperCase(),
                  style: AppTypography.titleMd
                      .copyWith(color: AppColors.primaryDark),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(customer.name, style: AppTypography.titleMd),
                    if (customer.phone != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        customer.phone!,
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                    if (latestTransactionAt != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        l10n.customersLastTransaction(
                          formatDateTime(latestTransactionAt!),
                        ),
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (customer.loyaltyPoints > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                    vertical: AppSpacing.xs,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.accentSurface,
                    borderRadius: AppRadius.radiusSm,
                  ),
                  child: Text(
                    l10n.transactionsPoints(customer.loyaltyPoints),
                    style:
                        AppTypography.labelSm.copyWith(color: AppColors.accent),
                  ),
                ),
              const SizedBox(width: AppSpacing.sm),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: context.colors.textTertiary,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
