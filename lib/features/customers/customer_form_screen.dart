import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/database/app_database.dart';
import '../../core/database/daos/dao_providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({this.customerId, super.key});

  /// `null` when creating, otherwise the id of the customer being edited.
  final String? customerId;

  @override
  ConsumerState<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();

  CustomerRow? _existing;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _errorName;
  String? _errorPhone;
  String? _errorEmail;

  bool get _isEditing => widget.customerId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) _loadExisting();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExisting() async {
    setState(() => _isLoading = true);
    final row = await ref.read(customerDaoProvider).getById(widget.customerId!);
    if (!mounted) return;
    setState(() {
      _existing = row;
      _isLoading = false;
      if (row != null) {
        _nameCtrl.text = row.name;
        _phoneCtrl.text = row.phone ?? '';
        _emailCtrl.text = row.email ?? '';
      }
    });
  }

  Future<void> _save() async {
    if (_isSaving) return;
    setState(() {
      _isSaving = true;
      _errorName = null;
      _errorPhone = null;
      _errorEmail = null;
    });

    final name = _nameCtrl.text.trim();
    final phone =
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
    final email =
        _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();

    // ── Validation ──
    if (name.isEmpty) {
      setState(() {
        _isSaving = false;
        _errorName = 'Nama wajib diisi';
      });
      return;
    }
    if (email != null && !_isLikelyEmail(email)) {
      setState(() {
        _isSaving = false;
        _errorEmail = 'Format email tidak valid';
      });
      return;
    }
    if (phone != null) {
      final dao = ref.read(customerDaoProvider);
      final existing = await dao.getByPhone(phone);
      if (!mounted) return;
      if (existing != null && existing.id != _existing?.id) {
        setState(() {
          _isSaving = false;
          _errorPhone = 'Nomor telepon sudah dipakai pelanggan lain';
        });
        return;
      }
    }

    final now = DateTime.now();
    final dao = ref.read(customerDaoProvider);
    late final String savedCustomerId;
    if (_existing == null) {
      savedCustomerId = const Uuid().v7();
      await dao.upsertCustomer(CustomersCompanion.insert(
        id: savedCustomerId,
        name: name,
        phone: Value(phone),
        email: Value(email),
        createdAt: now,
        updatedAt: now,
      ));
    } else {
      savedCustomerId = _existing!.id;
      await dao.updateById(
        savedCustomerId,
        CustomersCompanion(
          name: Value(name),
          phone: Value(phone),
          email: Value(email),
          updatedAt: Value(now),
        ),
      );
    }
    final savedCustomer = await dao.getById(savedCustomerId);
    if (!mounted) return;
    Navigator.of(context).pop(savedCustomer);
  }

  static bool _isLikelyEmail(String value) {
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Memuat…')),
        body: const Center(child: AppLoadingIndicator()),
      );
    }
    if (_isEditing && _existing == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pelanggan')),
        body: const AppEmptyState(
          title: 'Pelanggan tidak ditemukan',
          icon: Icons.search_off_outlined,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Ubah Pelanggan' : 'Tambah Pelanggan'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _Field(
            label: 'Nama',
            controller: _nameCtrl,
            hint: 'Nama lengkap pelanggan',
            errorText: _errorName,
            autofocus: !_isEditing,
            required: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Telepon',
            controller: _phoneCtrl,
            hint: 'Opsional · +62…',
            errorText: _errorPhone,
            keyboardType: TextInputType.phone,
          ),
          const SizedBox(height: AppSpacing.lg),
          _Field(
            label: 'Email',
            controller: _emailCtrl,
            hint: 'Opsional',
            errorText: _errorEmail,
            keyboardType: TextInputType.emailAddress,
          ),
          if (_isEditing && _existing != null) ...[
            const SizedBox(height: AppSpacing.xl),
            Text(
              'Poin loyalti: ${_existing!.loyaltyPoints}',
              style: AppTypography.bodySm
                  .copyWith(color: context.colors.textSecondary),
            ),
          ],
          const SizedBox(height: AppSpacing.xxl),
          AppButton(
            label: _isEditing ? 'Simpan Perubahan' : 'Tambah Pelanggan',
            icon: Icons.save_outlined,
            onPressed: _isSaving ? null : _save,
            isLoading: _isSaving,
            size: AppButtonSize.primary,
            fullWidth: true,
          ),
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    this.hint,
    this.errorText,
    this.keyboardType,
    this.autofocus = false,
    this.required = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? errorText;
  final TextInputType? keyboardType;
  final bool autofocus;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.xs),
          child: RichText(
            text: TextSpan(
              text: label,
              style: AppTypography.labelSm
                  .copyWith(color: context.colors.textSecondary),
              children: [
                if (required)
                  const TextSpan(
                    text: ' *',
                    style: TextStyle(color: AppColors.danger),
                  ),
              ],
            ),
          ),
        ),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          autofocus: autofocus,
          decoration: InputDecoration(
            hintText: hint,
            errorText: errorText,
          ),
        ),
      ],
    );
  }
}
