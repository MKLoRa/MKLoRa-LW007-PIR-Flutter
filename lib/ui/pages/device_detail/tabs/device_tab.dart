import 'package:flutter/material.dart';

import '../../../../../ble/lw007.dart';
import '../../../../../ble/lw007_device_session.dart';
import '../../../../../ble/lw007_param_helpers.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../../viewmodels/ble_scan_view_model.dart';
import '../device/system_info_page.dart';

class DeviceTab extends StatefulWidget {
  const DeviceTab({super.key, required this.session});

  final Lw007DeviceSession session;

  @override
  State<DeviceTab> createState() => DeviceTabState();
}

class DeviceTabState extends State<DeviceTab> {
  int _timeZoneIndex = 40;
  bool _lowPowerPayload = false;

  Future<void> reload({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final results = await Future.wait([
          api.readTimeZone(),
          api.readLowPowerPayloadEnable(),
        ]);
        if (!mounted) return;
        setState(() {
          _timeZoneIndex = Lw007ParamHelpers.timeZoneIndexFromBytes(results[0].data);
          _lowPowerPayload = Lw007ParamHelpers.uint8(results[1].data) == 1;
        });
      },
      showOverlay: showOverlay,
    );
  }

  Future<void> _pickTimeZone() async {
    final zones = Lw007OptionLists.timeZones();
    final index = await showBottomPicker(
      context: context,
      options: zones,
      selectedIndex: _timeZoneIndex,
    );
    if (index == null || !mounted) return;
    setState(() => _timeZoneIndex = index);
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      await api.writeTimeZone(Lw007ParamHelpers.timeZoneBytesFromIndex(index));
      await reload(showOverlay: false);
    });
  }

  Future<void> _toggleLowPowerPayload(bool value) async {
    setState(() => _lowPowerPayload = value);
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = await api.writeLowPowerPayloadEnable([value ? 1 : 0]);
      if (!mounted) return;
      if (!ok) {
        setState(() => _lowPowerPayload = !value);
        return;
      }
      await reload(showOverlay: false);
    });
  }

  Future<void> _factoryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Factory Reset!',
      message: 'After factory reset,all the data will be reseted to the factory values.',
      confirmText: 'OK',
      showCancel: false,
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () => widget.session.protocol.writeResetEmpty());
  }

  Future<void> _powerOff() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning!',
      message:
          'Are you sure to turn off the device? Please make sure the device has a button to turn on!',
      cancelText: 'Cancel',
      confirmText: 'OK',
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () => widget.session.protocol.writeCloseEmpty());
  }

  Future<void> _batteryReset() async {
    final ok = await showCommonConfirmDialog(
      context: context,
      title: 'Warning！',
      message: 'Are you sure to reset battery?',
      confirmText: 'OK',
      showCancel: false,
      actionColor: BleScanViewModel.titleBarColor,
    );
    if (!ok || !mounted) return;
    await runWithBleLoading(context, () => widget.session.protocol.writeBatteryResetEmpty());
  }

  @override
  Widget build(BuildContext context) {
    final zones = Lw007OptionLists.timeZones();
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Current Time Zone',
            child: BlueValueButton(
              text: zones[_timeZoneIndex.clamp(0, zones.length - 1)],
              onTap: _pickTimeZone,
            ),
          ),
        ),
        SettingsCard(
          child: SettingsSwitchRow(
            label: 'Low-power Payload',
            value: _lowPowerPayload,
            onChanged: _toggleLowPowerPayload,
          ),
        ),
        SettingsCard(
          child: SettingsSwitchRow(
            label: 'Power Off',
            value: false,
            onChanged: (_) => _powerOff(),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Factory Reset',
            onTap: _factoryReset,
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Device Information',
            onTap: () async {
              final result = await Navigator.of(context).push<SystemInfoDfuResult>(
                MaterialPageRoute(
                  builder: (_) => SystemInfoPage(session: widget.session),
                ),
              );
              if (!context.mounted) return;
              if (result == SystemInfoDfuResult.success ||
                  result == SystemInfoDfuResult.failed) {
                Navigator.of(context).pop(true);
              }
            },
          ),
        ),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsLabelRow(
                label: 'Battery Reset',
                child: BlueValueButton(
                  text: 'Reset',
                  onTap: _batteryReset,
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '*After replace with the new battery, need to click "Reset", otherwise the low power prompt will be unnormal.',
                  style: TextStyle(
                    fontSize: 12,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
