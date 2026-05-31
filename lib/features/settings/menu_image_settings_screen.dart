import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_card.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'branch_selection_provider.dart';
import 'menu_image_settings.dart';

class MenuImageSettingsScreen extends ConsumerWidget {
  const MenuImageSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(allBranchesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Image Menu')),
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
            itemBuilder: (_, i) => _BranchMenuImageCard(branch: branches[i]),
          );
        },
      ),
    );
  }
}

class _BranchMenuImageCard extends ConsumerStatefulWidget {
  const _BranchMenuImageCard({required this.branch});

  final BranchRow branch;

  @override
  ConsumerState<_BranchMenuImageCard> createState() =>
      _BranchMenuImageCardState();
}

class _BranchMenuImageCardState extends ConsumerState<_BranchMenuImageCard> {
  final _hexCtrl = TextEditingController();
  final _widthCtrl = TextEditingController();
  var _showBranchName = true;
  var _showBranchAddress = true;
  var _showBranchPhone = true;
  var _columns = 3;
  var _headerLayout = MenuImageHeaderLayout.stacked;
  var _loaded = false;
  var _saving = false;
  String? _hexError;
  String? _widthError;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _hexCtrl.dispose();
    _widthCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final settings = await ref
        .read(menuImageSettingsRepositoryProvider)
        .getForBranch(widget.branch.id);
    if (!mounted) return;
    setState(() {
      _showBranchName = settings.showBranchName;
      _showBranchAddress = settings.showBranchAddress;
      _showBranchPhone = settings.showBranchPhone;
      _columns = settings.columns;
      _headerLayout = settings.headerLayout;
      _widthCtrl.text = settings.imageWidthPx.toString();
      _hexCtrl.text = settings.backgroundColorHex;
      _hexError = null;
      _widthError = null;
      _loaded = true;
    });
  }

  Future<void> _save() async {
    final normalized = normalizeMenuImageHex(_hexCtrl.text);
    final parsedImageWidth = int.tryParse(_widthCtrl.text.trim());
    if (!isValidMenuImageHex(normalized)) {
      setState(() => _hexError = 'Gunakan format #RRGGBB');
      return;
    }
    if (parsedImageWidth == null ||
        parsedImageWidth < 1080 ||
        parsedImageWidth > 4096) {
      setState(() => _widthError = 'Gunakan angka 1080-4096');
      return;
    }
    final imageWidth = normalizeMenuImageWidthPx(parsedImageWidth);
    setState(() {
      _saving = true;
      _hexError = null;
      _widthError = null;
      _hexCtrl.text = normalized;
      _widthCtrl.text = imageWidth.toString();
    });
    await ref.read(menuImageSettingsRepositoryProvider).save(
          widget.branch.id,
          MenuImageSettings(
            showBranchName: _showBranchName,
            showBranchAddress: _showBranchAddress,
            showBranchPhone: _showBranchPhone,
            columns: _columns,
            imageWidthPx: imageWidth,
            headerLayout: _headerLayout,
            backgroundColorHex: normalized,
          ),
        );
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content:
              Text('Pengaturan image menu ${widget.branch.name} tersimpan')),
    );
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
    final previewColor = colorFromMenuImageHex(_hexCtrl.text);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.branch.name, style: AppTypography.titleMd),
          const SizedBox(height: AppSpacing.md),
          _Preview(
            branch: widget.branch,
            showBranchName: _showBranchName,
            showBranchAddress: _showBranchAddress,
            showBranchPhone: _showBranchPhone,
            columns: _columns,
            headerLayout: _headerLayout,
            backgroundColor: previewColor,
          ),
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            value: _showBranchName,
            onChanged: (v) => setState(() => _showBranchName = v),
            title: Text('Tampilkan nama cabang', style: AppTypography.titleMd),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          SwitchListTile(
            value: _showBranchAddress,
            onChanged: (v) => setState(() => _showBranchAddress = v),
            title:
                Text('Tampilkan alamat cabang', style: AppTypography.titleMd),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          SwitchListTile(
            value: _showBranchPhone,
            onChanged: (v) => setState(() => _showBranchPhone = v),
            title: Text('Tampilkan nomor cabang', style: AppTypography.titleMd),
            contentPadding: EdgeInsets.zero,
            activeColor: AppColors.primary,
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Layout header', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<MenuImageHeaderLayout>(
            segments: [
              for (final layout in MenuImageHeaderLayout.values)
                ButtonSegment(
                  value: layout,
                  label: Text(layout.label),
                  icon: Icon(
                    layout == MenuImageHeaderLayout.stacked
                        ? Icons.view_stream_outlined
                        : Icons.view_sidebar_outlined,
                  ),
                ),
            ],
            selected: {_headerLayout},
            onSelectionChanged: (value) =>
                setState(() => _headerLayout = value.first),
          ),
          const SizedBox(height: AppSpacing.md),
          Text('Jumlah card per baris', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(
                value: 2,
                label: Text('2'),
                icon: Icon(Icons.view_agenda_outlined),
              ),
              ButtonSegment(
                value: 3,
                label: Text('3'),
                icon: Icon(Icons.grid_view_outlined),
              ),
            ],
            selected: {_columns},
            onSelectionChanged: (value) =>
                setState(() => _columns = value.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Lebar image menu (px)', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.sm),
          TextField(
            controller: _widthCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(4),
            ],
            decoration: InputDecoration(
              hintText: '3240',
              helperText: 'Rekomendasi 3240 atau 4096 untuk hasil lebih tajam.',
              errorText: _widthError,
            ),
            onChanged: (_) => setState(() => _widthError = null),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Background warna menu', style: AppTypography.labelSm),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: previewColor,
                  borderRadius: AppRadius.radiusSm,
                  border: Border.all(color: context.colors.border),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: _hexCtrl,
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9a-fA-F#]')),
                    LengthLimitingTextInputFormatter(7),
                  ],
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    hintText: '#F8FAFC',
                    errorText: _hexError,
                  ),
                  onChanged: (_) => setState(() => _hexError = null),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final hex in const [
                '#F8FAFC',
                '#FFF7ED',
                '#F0FDF4',
                '#FDF2F8',
                '#111827',
              ])
                _ColorChip(
                  hex: hex,
                  onSelected: () {
                    setState(() {
                      _hexCtrl.text = hex;
                      _hexError = null;
                    });
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: _saving ? 'Menyimpan...' : 'Simpan',
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

class _ColorChip extends StatelessWidget {
  const _ColorChip({required this.hex, required this.onSelected});

  final String hex;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelected,
      borderRadius: AppRadius.radiusSm,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: colorFromMenuImageHex(hex),
          borderRadius: AppRadius.radiusSm,
          border: Border.all(color: context.colors.border),
        ),
      ),
    );
  }
}

class _Preview extends StatelessWidget {
  const _Preview({
    required this.branch,
    required this.showBranchName,
    required this.showBranchAddress,
    required this.showBranchPhone,
    required this.columns,
    required this.headerLayout,
    required this.backgroundColor,
  });

  final BranchRow branch;
  final bool showBranchName;
  final bool showBranchAddress;
  final bool showBranchPhone;
  final int columns;
  final MenuImageHeaderLayout headerLayout;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: AppRadius.radiusMd,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        children: [
          if (headerLayout == MenuImageHeaderLayout.split)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  flex: 5,
                  child: Container(
                    height: 58,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.85),
                      borderRadius: AppRadius.radiusSm,
                      border: Border.all(color: context.colors.border),
                    ),
                    child: Text(
                      'Logo',
                      style: AppTypography.labelSm.copyWith(
                        color: _readableMutedColor(backgroundColor),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  flex: 6,
                  child: _PreviewBranchInfo(
                    branch: branch,
                    showBranchName: showBranchName,
                    showBranchAddress: showBranchAddress,
                    showBranchPhone: showBranchPhone,
                    backgroundColor: backgroundColor,
                    textAlign: TextAlign.left,
                  ),
                ),
              ],
            )
          else
            _PreviewBranchInfo(
              branch: branch,
              showBranchName: showBranchName,
              showBranchAddress: showBranchAddress,
              showBranchPhone: showBranchPhone,
              backgroundColor: backgroundColor,
              textAlign: TextAlign.center,
            ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              for (var i = 0; i < columns; i++) ...[
                if (i > 0) const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Container(
                    height: 88,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: AppRadius.radiusSm,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      children: [
                        Expanded(
                          child: Container(
                            margin: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEFF6F4),
                              borderRadius: AppRadius.radiusSm,
                            ),
                          ),
                        ),
                        const Padding(
                          padding: EdgeInsets.fromLTRB(6, 0, 6, 6),
                          child: Text(
                            'Menu',
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 11),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _PreviewBranchInfo extends StatelessWidget {
  const _PreviewBranchInfo({
    required this.branch,
    required this.showBranchName,
    required this.showBranchAddress,
    required this.showBranchPhone,
    required this.backgroundColor,
    required this.textAlign,
  });

  final BranchRow branch;
  final bool showBranchName;
  final bool showBranchAddress;
  final bool showBranchPhone;
  final Color backgroundColor;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    final alignment = textAlign == TextAlign.left
        ? CrossAxisAlignment.start
        : CrossAxisAlignment.center;
    return Column(
      crossAxisAlignment: alignment,
      children: [
        if (showBranchName)
          Text(
            branch.name,
            textAlign: textAlign,
            style: AppTypography.titleMd.copyWith(
              color: _readableTextColor(backgroundColor),
            ),
          ),
        if (showBranchAddress && (branch.address?.isNotEmpty ?? false))
          Text(
            branch.address!,
            textAlign: textAlign,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(
              color: _readableMutedColor(backgroundColor),
            ),
          ),
        if (showBranchPhone && (branch.phone?.isNotEmpty ?? false))
          Text(
            '📱 ${branch.phone!}',
            textAlign: textAlign,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.bodySm.copyWith(
              color: _readableTextColor(backgroundColor),
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}

Color _readableTextColor(Color background) {
  return background.computeLuminance() > 0.55
      ? const Color(0xFF111827)
      : Colors.white;
}

Color _readableMutedColor(Color background) {
  return background.computeLuminance() > 0.55
      ? const Color(0xFF4B5563)
      : const Color(0xFFE5E7EB);
}
