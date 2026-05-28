import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'customer_form_screen.dart';
import 'customer_providers.dart';

/// Bottom sheet for selecting (or clearing) the cart's customer.
///
/// Pops with the selected [CustomerRow] (or `null` for "tanpa pelanggan").
/// Returns no value when dismissed without choosing.
class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  static Future<CustomerPick?> show(BuildContext context) {
    return showModalBottomSheet<CustomerPick>(
      context: context,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const CustomerPickerSheet(),
    );
  }

  @override
  ConsumerState<CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

/// Tristate pick result — distinguished from "dismissed without choosing".
class CustomerPick {
  const CustomerPick(this.customer);
  final CustomerRow? customer;
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
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

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: AppSpacing.md),
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.colors.border,
                    borderRadius: BorderRadius.circular(AppRadius.sm),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
                child: Row(
                  children: [
                    Text('Pilih Pelanggan', style: AppTypography.headlineLg),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.person_add_outlined),
                      tooltip: 'Tambah Pelanggan',
                      onPressed: () => _createCustomer(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xl),
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
                  onChanged: (v) =>
                      setState(() => _query = v.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(
                child: customersAsync.when(
                  loading: () => const Center(child: AppLoadingIndicator()),
                  error: (e, _) => AppEmptyState(
                    title: 'Gagal memuat',
                    icon: Icons.error_outline,
                    message: e.toString(),
                  ),
                  data: (customers) => _List(
                    query: _query,
                    customers: customers,
                    onPick: (c) => Navigator.of(context).pop(CustomerPick(c)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _createCustomer(BuildContext context) async {
    final created =
        await Navigator.of(context, rootNavigator: true).push<CustomerRow>(
      MaterialPageRoute(
        builder: (_) => const CustomerFormScreen(),
        fullscreenDialog: true,
      ),
    );
    if (!mounted || created == null) return;
    Navigator.of(context).pop(CustomerPick(created));
  }
}

class _List extends StatelessWidget {
  const _List({
    required this.query,
    required this.customers,
    required this.onPick,
  });

  final String query;
  final List<CustomerRow> customers;
  final void Function(CustomerRow? customer) onPick;

  @override
  Widget build(BuildContext context) {
    final filtered = query.isEmpty
        ? customers
        : customers.where((c) {
            final inName = c.name.toLowerCase().contains(query);
            final inPhone = (c.phone ?? '').toLowerCase().contains(query);
            return inName || inPhone;
          }).toList();

    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xl,
        0,
        AppSpacing.xl,
        AppSpacing.xl,
      ),
      children: [
        // Always-available "no customer" option
        _Tile(
          name: 'Tanpa pelanggan',
          subtitle: 'Transaksi tidak terkait pelanggan',
          icon: Icons.person_off_outlined,
          onTap: () => onPick(null),
        ),
        if (filtered.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'PELANGGAN'.toUpperCase(),
            style: AppTypography.labelSm.copyWith(
              color: context.colors.textSecondary,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final c in filtered) ...[
            _Tile(
              name: c.name,
              subtitle: c.phone,
              icon: Icons.person_outline,
              trailing: c.loyaltyPoints > 0 ? '${c.loyaltyPoints} poin' : null,
              onTap: () => onPick(c),
            ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ] else if (query.isNotEmpty) ...[
          const SizedBox(height: AppSpacing.xl),
          Center(
            child: Text(
              'Tidak ada hasil untuk "$query"',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.name,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.trailing,
  });

  final String name;
  final String? subtitle;
  final String? trailing;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: context.colors.border),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: AppTypography.titleMd),
                    if (subtitle != null) ...[
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        subtitle!,
                        style: AppTypography.bodySm.copyWith(
                          color: context.colors.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null)
                Text(
                  trailing!,
                  style:
                      AppTypography.labelSm.copyWith(color: AppColors.accent),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
