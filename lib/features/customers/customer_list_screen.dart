import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'customer_providers.dart';

class CustomerListScreen extends ConsumerStatefulWidget {
  const CustomerListScreen({super.key});

  @override
  ConsumerState<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends ConsumerState<CustomerListScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final customersAsync = ref.watch(allCustomersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pelanggan')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/more/customers/new'),
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: TextField(
              controller: _searchCtrl,
              decoration: InputDecoration(
                hintText: 'Cari nama atau telepon…',
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
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: AppLoadingIndicator()),
              error: (e, _) => AppEmptyState(
                title: 'Gagal memuat pelanggan',
                icon: Icons.error_outline,
                message: e.toString(),
              ),
              data: (customers) {
                final filtered = _filter(customers, _query);
                if (filtered.isEmpty) {
                  return AppEmptyState(
                    title: _query.isEmpty
                        ? 'Belum ada pelanggan'
                        : 'Tidak ditemukan',
                    icon: _query.isEmpty
                        ? Icons.people_outline
                        : Icons.search_off_outlined,
                    message: _query.isEmpty
                        ? 'Tap "Tambah" untuk mendaftarkan pelanggan baru.'
                        : null,
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
                  itemBuilder: (_, i) => _CustomerTile(customer: filtered[i]),
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
}

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({required this.customer});

  final CustomerRow customer;

  @override
  Widget build(BuildContext context) {
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
                    '${customer.loyaltyPoints} poin',
                    style: AppTypography.labelSm
                        .copyWith(color: AppColors.accent),
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
