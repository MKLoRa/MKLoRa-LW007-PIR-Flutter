import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../../ble/lw007.dart';
import '../../../../ble/lw007_device_session.dart';
import '../../../../ble/lw007_param_helpers.dart';
import '../../../../ble/lw007_protocol_named_api.dart';
import '../../../../dfu/lw007_dfu_coordinator.dart';
import '../../../../dfu/lw007_dfu_service.dart';
import '../../../../dfu/lw007_dfu_utils.dart';
import '../../../../ui/theme/device_detail_theme.dart';
import '../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../ui/widgets/dfu_progress_dialog.dart';
import '../../../../viewmodels/ble_scan_view_model.dart';
import 'log_data_page.dart';
import 'battery_consume_page.dart';
import 'self_test_new_page.dart';
import 'self_test_page.dart';

enum SystemInfoDfuResult {
  success,
  failed,
}

class SystemInfoPage extends StatefulWidget {
  const SystemInfoPage({super.key, required this.session});

  final Lw007DeviceSession session;

  @override
  State<SystemInfoPage> createState() => _SystemInfoPageState();
}

class _SystemInfoPageState extends State<SystemInfoPage> {
  String _software = '-';
  String _manufacturer = '-';
  String _firmware = '-';
  String _hardware = '-';
  String _model = '-';
  String _mac = '-';
  String _advName = '';
  String _batteryVoltage = '-';
  var _dfuRunning = false;
  int _selfTestTapCount = 0;
  int _selfTestLastTapMs = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final gatt = widget.session.deviceInfoApi;
      final deviceType = widget.session.deviceInfo.deviceType;
      final advName = await api.readAdvName();
      final mac = await api.readChipMac();
      final model = await gatt.readModelNumber();
      final software = await gatt.readSoftwareRevision();
      final firmware = await gatt.readFirmwareRevision();
      final hardware = await gatt.readHardwareRevision();
      final manufacturer = await gatt.readManufacturerName();
      var batteryVoltage = '-';
      if (deviceType == 1) {
        final battery = await api.readBatteryPower();
        if (battery.data.isNotEmpty) {
          batteryVoltage = '${Lw007ParamHelpers.bytesToInt(battery.data)}mV';
        }
      }
      if (!mounted) return;
      setState(() {
        _advName = Lw007ParamHelpers.bytesToString(advName.data);
        _mac = Lw007ParamHelpers.formatMac(mac.data);
        if (_mac.isEmpty) _mac = '-';
        _model = model.isEmpty ? '-' : model;
        _software = software.isEmpty ? '-' : software;
        _firmware = firmware.isEmpty ? '-' : firmware;
        _hardware = hardware.isEmpty ? '-' : hardware;
        _manufacturer = manufacturer.isEmpty ? '-' : manufacturer;
        _batteryVoltage = batteryVoltage;
      });
    });
  }

  bool get _showBatteryInfo => widget.session.deviceInfo.deviceType == 1;

  void _onHiddenSelfTestTap() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _selfTestLastTapMs > 500) {
      _selfTestTapCount = 0;
      _selfTestLastTapMs = now;
    } else {
      _selfTestTapCount++;
      if (_selfTestTapCount == 2) {
        _selfTestTapCount = 0;
        final deviceType = widget.session.deviceInfo.deviceType;
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => deviceType == 1
                ? SelfTestNewPage(session: widget.session)
                : SelfTestPage(session: widget.session),
          ),
        );
      }
    }
  }

  void _openDebuggerMode() {
    if (_mac == '-' || _mac.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => LogDataPage(
          session: widget.session,
          deviceMac: _mac,
        ),
      ),
    );
  }

  Future<void> _updateFirmware() async {
    if (_dfuRunning || _mac == '-' || _mac.isEmpty || _advName.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['zip'],
      withData: true,
    );
    if (!mounted || picked == null) return;

    late final String firmwarePath;
    try {
      firmwarePath = await lw007PrepareDfuFirmwarePath(picked.files.single);
    } on Lw007DfuFileException catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
      }
      return;
    }

    final dfuAddress = lw007DfuDeviceAddress(
      deviceInfo: widget.session.deviceInfo,
      chipMac: _mac,
    );

    setState(() => _dfuRunning = true);
    DfuProgressHandle? progress;
    try {
      Lw007DfuCoordinator.begin(mac: _mac);
      await widget.session.disconnect();

      progress = await showDfuProgressDialog(context);
      await Lw007DfuService.start(
        address: dfuAddress,
        filePath: firmwarePath,
        deviceType: widget.session.deviceInfo.deviceType,
        onStatus: progress.update,
      );

      if (!mounted) return;
      closeDfuProgressDialog(context);
      await showCommonConfirmDialog(
        context: context,
        message: 'Update firmware successfully!\nPlease reconnect the device.',
        confirmText: 'OK',
        actionColor: BleScanViewModel.titleBarColor,
        barrierDismissible: false,
        showCancel: false,
      );
      if (mounted) {
        Navigator.of(context).pop(SystemInfoDfuResult.success);
      }
    } on Lw007DfuException catch (error) {
      if (mounted) {
        closeDfuProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.message)),
        );
        Navigator.of(context).pop(SystemInfoDfuResult.failed);
      }
    } catch (error) {
      if (mounted) {
        closeDfuProgressDialog(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              error is Lw007DfuException
                  ? error.message
                  : 'Opps!DFU Failed. Please try again!',
            ),
          ),
        );
        Navigator.of(context).pop(SystemInfoDfuResult.failed);
      }
    } finally {
      Lw007DfuCoordinator.end();
      if (mounted) {
        setState(() => _dfuRunning = false);
      }
    }
  }

  Widget _infoRow(String label, String value, {Widget? trailing}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: DeviceDetailTheme.textPrimary,
              ),
            ),
          ),
          if (trailing == null)
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.end,
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            )
          else ...[
            Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Device Information',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoRow('Software Version', _software),
                const SettingsDivider(),
                _infoRow(
                  'Firmware Version',
                  _firmware,
                  trailing: SizedBox(
                    width: 70,
                    height: 40,
                    child: ElevatedButton(
                      onPressed: _dfuRunning ? null : _updateFirmware,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: DeviceDetailTheme.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.zero,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                      child: const Text('DFU', style: TextStyle(fontSize: 15)),
                    ),
                  ),
                ),
                const SettingsDivider(),
                _infoRow('Hardware Version', _hardware),
              ],
            ),
          ),
          if (_showBatteryInfo) ...[
            const SizedBox(height: 10),
            SettingsCard(
              child: _infoRow('Battery Voltage', _batteryVoltage),
            ),
          ],
          const SizedBox(height: 10),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _infoRow('MAC Address', _mac),
                const SettingsDivider(),
                _infoRow('Product Model', _model),
                const SettingsDivider(),
                _infoRow('Manufacturer', _manufacturer),
              ],
            ),
          ),
          if (_showBatteryInfo) ...[
            const SizedBox(height: 10),
            SettingsCard(
              child: SettingsNavRow(
                title: 'Battery Consumption Information',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => BatteryConsumePage(session: widget.session),
                  ),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          SettingsCard(
            child: SettingsNavRow(
              title: 'Debugger Mode',
              onTap: _openDebuggerMode,
            ),
          ),
          GestureDetector(
            onTap: _onHiddenSelfTestTap,
            behavior: HitTestBehavior.opaque,
            child: const SizedBox(height: 200),
          ),
        ],
      ),
    );
  }
}
