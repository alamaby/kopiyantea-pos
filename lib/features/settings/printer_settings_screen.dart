import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/printer_service.dart';
import '../../core/services/service_providers.dart';
import '../../core/theme/colors.dart';
import '../../core/theme/radius.dart';
import '../../core/theme/spacing.dart';
import '../../core/theme/typography.dart';
import '../../core/utils/result.dart';
import '../../core/widgets/app_badge.dart';
import '../../core/widgets/app_button.dart';
import '../../core/widgets/app_empty_state.dart';
import '../../core/widgets/app_loading_indicator.dart';
import 'settings_provider.dart';

/// Bluetooth thermal printer connection management.
///
/// User must pair the printer via the system Bluetooth settings first.
/// This screen lists paired devices, lets the user pick one, and persists
/// the address via [SettingsNotifier.setLastPrinterAddress].
class PrinterSettingsScreen extends ConsumerStatefulWidget {
  const PrinterSettingsScreen({super.key});

  @override
  ConsumerState<PrinterSettingsScreen> createState() =>
      _PrinterSettingsScreenState();
}

class _PrinterSettingsScreenState extends ConsumerState<PrinterSettingsScreen> {
  List<PrinterDevice>? _devices;
  bool _isScanning = false;
  bool _isConnecting = false;
  String? _busyAddress;
  String? _statusMessage;
  bool _statusIsError = false;

  Future<void> _scan() async {
    setState(() {
      _isScanning = true;
      _statusMessage = null;
    });
    final printer = ref.read(printerServiceProvider);
    final devices = await printer.scanDevices();
    if (!mounted) return;
    setState(() {
      _devices = devices;
      _isScanning = false;
      if (devices.isEmpty) {
        _statusIsError = true;
        _statusMessage =
            'Tidak ada printer terpasang. Pastikan printer sudah dipair lewat Pengaturan Bluetooth perangkat.';
      }
    });
  }

  Future<void> _connect(PrinterDevice device) async {
    setState(() {
      _isConnecting = true;
      _busyAddress = device.address;
      _statusMessage = null;
    });
    final printer = ref.read(printerServiceProvider);
    final result = await printer.connect(device.address);
    if (!mounted) return;
    setState(() {
      _isConnecting = false;
      _busyAddress = null;
    });
    switch (result) {
      case Ok():
        await ref
            .read(settingsNotifierProvider.notifier)
            .setLastPrinterAddress(device.address);
        if (!mounted) return;
        setState(() {
          _statusIsError = false;
          _statusMessage = 'Terhubung ke ${device.name}';
        });
      case Err(:final error):
        setState(() {
          _statusIsError = true;
          _statusMessage = _errorLabel(error);
        });
    }
  }

  Future<void> _disconnect() async {
    final printer = ref.read(printerServiceProvider);
    await printer.disconnect();
    if (!mounted) return;
    setState(() {
      _statusIsError = false;
      _statusMessage = 'Printer terputus';
    });
  }

  Future<void> _testPrint() async {
    final printer = ref.read(printerServiceProvider);
    setState(() {
      _statusMessage = null;
    });
    final ready = await _ensureConnectedToSavedPrinter(printer);
    if (!mounted) return;
    if (ready case Err(:final error)) {
      setState(() {
        _statusIsError = true;
        _statusMessage = _errorLabel(error);
      });
      return;
    }
    final payload = ReceiptPayload(
      transactionId: '00000000-0000-0000-0000-000000000000',
      timestamp: DateTime.now(),
      branchName: 'KopiyanteaPOS',
      branchAddress: 'Test Print',
      items: const [
        ReceiptItem(
          name: 'Tes Cetak',
          quantity: 1,
          priceSnapshot: 1000,
          subtotal: 1000,
        ),
      ],
      subtotal: 1000,
      discountAmount: 0,
      taxLabel: 'PB1',
      taxAmount: 100,
      total: 1100,
      paymentMethodLabel: 'Tunai',
    );
    final result = await printer.printReceipt(payload);
    if (!mounted) return;
    switch (result) {
      case Ok():
        setState(() {
          _statusIsError = false;
          _statusMessage = 'Tes cetak terkirim';
        });
      case Err(:final error):
        setState(() {
          _statusIsError = true;
          _statusMessage = _errorLabel(error);
        });
    }
  }

  Future<Result<Unit, PrinterError>> _ensureConnectedToSavedPrinter(
    PrinterService printer,
  ) async {
    if (printer.isConnected) return Ok(Unit.instance);
    final settings = await ref.read(settingsNotifierProvider.future);
    final address = settings.lastPrinterAddress;
    if (address == null || address.isEmpty) {
      return const Err(PrinterError.notConnected);
    }
    return printer.connect(address);
  }

  String _errorLabel(PrinterError e) => switch (e) {
        PrinterError.notConnected => 'Printer belum terhubung',
        PrinterError.deviceNotFound => 'Printer tidak ditemukan',
        PrinterError.permissionDenied => 'Izin Bluetooth ditolak',
        PrinterError.bluetoothOff =>
          'Bluetooth perangkat tidak aktif — nyalakan dulu',
        PrinterError.printFailed => 'Gagal mencetak',
      };

  @override
  Widget build(BuildContext context) {
    final printer = ref.watch(printerServiceProvider);
    final settings = ref.watch(settingsNotifierProvider).valueOrNull;
    final rememberedAddress = settings?.lastPrinterAddress;
    final hasRememberedPrinter =
        rememberedAddress != null && rememberedAddress.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Printer')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          _StatusCard(
            isConnected: printer.isConnected,
            address: printer.connectedAddress,
            rememberedAddress: rememberedAddress,
            onDisconnect: printer.isConnected ? _disconnect : null,
            onTestPrint:
                printer.isConnected || hasRememberedPrinter ? _testPrint : null,
          ),
          const SizedBox(height: AppSpacing.lg),
          AppButton(
            label: 'Cari Printer',
            icon: Icons.bluetooth_searching,
            onPressed: _isScanning ? null : _scan,
            isLoading: _isScanning,
            size: AppButtonSize.primary,
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          if (_statusMessage != null)
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: _statusIsError
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFE0F2FE),
                borderRadius: AppRadius.radiusMd,
              ),
              child: Row(
                children: [
                  Icon(
                    _statusIsError
                        ? Icons.error_outline
                        : Icons.check_circle_outline,
                    color:
                        _statusIsError ? AppColors.danger : AppColors.success,
                    size: 18,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      _statusMessage!,
                      style: AppTypography.bodySm.copyWith(
                        color: _statusIsError
                            ? AppColors.danger
                            : AppColors.success,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (_statusMessage != null) const SizedBox(height: AppSpacing.lg),
          if (_devices != null) ...[
            Text(
              'PERANGKAT TERPASANG',
              style: AppTypography.labelSm.copyWith(
                color: context.colors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            if (_devices!.isEmpty)
              const AppEmptyState(
                title: 'Tidak ada printer',
                icon: Icons.bluetooth_disabled,
                message:
                    'Pair printer melalui Pengaturan Bluetooth perangkat dulu, lalu kembali ke sini.',
              )
            else
              for (final device in _devices!) ...[
                _DeviceTile(
                  device: device,
                  isConnected: printer.connectedAddress == device.address,
                  isBusy: _isConnecting && _busyAddress == device.address,
                  onTap: _isConnecting ? null : () => _connect(device),
                ),
                const SizedBox(height: AppSpacing.sm),
              ],
          ],
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.isConnected,
    required this.address,
    required this.rememberedAddress,
    required this.onDisconnect,
    required this.onTestPrint,
  });

  final bool isConnected;
  final String? address;
  final String? rememberedAddress;
  final VoidCallback? onDisconnect;
  final VoidCallback? onTestPrint;

  @override
  Widget build(BuildContext context) {
    final hasRememberedPrinter =
        rememberedAddress != null && rememberedAddress!.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadius.radiusLg,
        border: Border.all(color: context.colors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                'STATUS',
                style: AppTypography.labelSm.copyWith(
                  color: context.colors.textSecondary,
                  letterSpacing: 0.8,
                ),
              ),
              const Spacer(),
              if (isConnected)
                const AppBadge(
                  label: 'Terhubung',
                  icon: Icons.check_circle_outline,
                  tone: AppBadgeTone.success,
                )
              else
                const AppBadge(
                  label: 'Tidak terhubung',
                  icon: Icons.bluetooth_disabled,
                  tone: AppBadgeTone.neutral,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            isConnected
                ? (address ?? '-')
                : hasRememberedPrinter
                    ? 'Terakhir: $rememberedAddress'
                    : 'Belum ada printer aktif',
            style: AppTypography.titleMd,
          ),
          if (onTestPrint != null || onDisconnect != null) ...[
            const SizedBox(height: AppSpacing.md),
            Row(
              children: [
                Expanded(
                  child: AppButton(
                    label: 'Tes Cetak',
                    variant: AppButtonVariant.secondary,
                    icon: Icons.print_outlined,
                    onPressed: onTestPrint,
                    fullWidth: true,
                  ),
                ),
                if (onDisconnect != null) ...[
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: AppButton(
                      label: 'Putuskan',
                      variant: AppButtonVariant.ghost,
                      icon: Icons.link_off,
                      onPressed: onDisconnect,
                      fullWidth: true,
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _DeviceTile extends StatelessWidget {
  const _DeviceTile({
    required this.device,
    required this.isConnected,
    required this.isBusy,
    required this.onTap,
  });

  final PrinterDevice device;
  final bool isConnected;
  final bool isBusy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colors.surface,
      borderRadius: AppRadius.radiusLg,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadius.radiusLg,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            border: Border.all(
              color: isConnected ? AppColors.primary : context.colors.border,
              width: isConnected ? 2 : 1,
            ),
            borderRadius: AppRadius.radiusLg,
          ),
          child: Row(
            children: [
              Icon(
                Icons.print_outlined,
                color: isConnected
                    ? AppColors.primary
                    : context.colors.textSecondary,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(device.name, style: AppTypography.titleMd),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      device.address,
                      style: AppTypography.labelSm.copyWith(
                        color: context.colors.textSecondary,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (isBusy)
                const AppLoadingIndicator(size: 18)
              else if (isConnected)
                const Icon(Icons.check_circle, color: AppColors.primary)
              else
                Icon(
                  Icons.chevron_right,
                  color: context.colors.textTertiary,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
