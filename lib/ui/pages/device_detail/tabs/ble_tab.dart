import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../../ble/lw007.dart';
import '../../../../../ble/lw007_device_session.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_change_password_dialog.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';

class BleTab extends StatefulWidget {
  const BleTab({
    super.key,
    required this.session,
    required this.onSaveReady,
  });

  final Lw007DeviceSession session;
  final void Function(Future<bool> Function() save) onSaveReady;

  @override
  State<BleTab> createState() => BleTabState();
}

class BleTabState extends State<BleTab> {
  final _advName = TextEditingController();
  final _advInterval = TextEditingController();
  final _timeout = TextEditingController();

  bool _beaconMode = false;
  bool _connectable = false;
  bool _loginPassword = false;
  bool _loginPasswordOnDevice = false;
  int _txPowerIndex = 6;

  @override
  void initState() {
    super.initState();
    widget.onSaveReady(_save);
  }

  Future<void> load({bool showOverlay = true}) async {
    if (!widget.session.client.isConnected) {
      return;
    }
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final results = await Future.wait([
          api.readBleAdvName(),
          api.readBleAdvInterval(),
          api.readBleEnable(),
          api.readBleConnectable(),
          api.readBleTimeoutDuration(),
          api.readBleLoginMode(),
          api.readBleTxPower(),
        ]);
        if (!mounted) return;
        _advName.text = Lw007ParamHelpers.bytesToString(results[0].data);
        _advInterval.text = Lw007ParamHelpers.uint8(results[1].data).toString();
        _beaconMode = Lw007ParamHelpers.uint8(results[2].data) == 1;
        _connectable = Lw007ParamHelpers.uint8(results[3].data) == 1;
        _timeout.text = Lw007ParamHelpers.uint8(results[4].data).toString();
        _loginPassword = Lw007ParamHelpers.uint8(results[5].data) == 1;
        _loginPasswordOnDevice = _loginPassword;
        final txPower = Lw007ParamHelpers.byte0(results[6].data);
        _txPowerIndex = Lw007OptionLists.txPowerLevels.indexOf(txPower);
        if (_txPowerIndex < 0) _txPowerIndex = 6;
        setState(() {});
      },
      showOverlay: showOverlay,
    );
  }

  bool _validate() {
    final interval = int.tryParse(_advInterval.text.trim());
    if (interval == null || interval < 1 || interval > 100) {
      return false;
    }
    if (!_beaconMode) {
      final timeout = int.tryParse(_timeout.text.trim());
      if (timeout == null || timeout < 1 || timeout > 60) {
        return false;
      }
    }
    return true;
  }

  Future<bool> _save() async {
    if (!_validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Opps！Save failed. Please check the input characters and try again.',
            ),
          ),
        );
      }
      return false;
    }
    final api = widget.session.protocol;
    final interval = int.parse(_advInterval.text.trim());
    final writes = <Future<bool>>[
      api.writeBleEnable([_beaconMode ? 1 : 0]),
      if (_beaconMode)
        api.writeBleConnectable([_connectable ? 1 : 0])
      else
        api.writeBleTimeoutDuration([int.parse(_timeout.text.trim())]),
      api.writeBleAdvName(utf8.encode(_advName.text)),
      api.writeBleAdvInterval([interval]),
      api.writeBleTxPower([Lw007OptionLists.txPowerLevels[_txPowerIndex]]),
      api.writeBleLoginMode([_loginPassword ? 1 : 0]),
    ];
    return (await Future.wait(writes)).every((result) => result);
  }

  Future<void> _changePassword() async {
    if (!_loginPasswordOnDevice && !_loginPassword) {
      return;
    }
    final password = await showBleChangePasswordDialog(context: context);
    if (password == null || !mounted) return;
    await runWithBleLoading(context, () async {
      final ok = await widget.session.protocol.changePassword(utf8.encode(password));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok ? 'Save Successfully！' : 'Opps！Save failed. Please check the input characters and try again.',
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _advName.dispose();
    _advInterval.dispose();
    _timeout.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final txPower = Lw007OptionLists.txPowerLevels[_txPowerIndex];
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsLabelRow(
                label: 'ADV Name',
                child: Expanded(
                  child: TextField(
                    controller: _advName,
                    maxLength: 16,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[ -~]')),
                    ],
                    decoration: const InputDecoration(
                      hintText: '0 ~ 16Characters',
                      counterText: '',
                      border: UnderlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
              ),
              const SettingsDivider(),
              SettingsLabelRow(
                label: 'ADV Interval',
                child: SettingsTextField(
                  controller: _advInterval,
                  hint: '1~100',
                  maxLength: 3,
                  suffix: ' x 100ms',
                ),
              ),
            ],
          ),
        ),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsSwitchRow(
                label: 'Beacon Mode',
                value: _beaconMode,
                onChanged: (value) => setState(() => _beaconMode = value),
              ),
              if (_beaconMode) ...[
                const SettingsDivider(),
                SettingsSwitchRow(
                  label: 'Connectable',
                  value: _connectable,
                  onChanged: (value) => setState(() => _connectable = value),
                ),
              ] else ...[
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Broadcast Timeout',
                  child: SettingsTextField(
                    controller: _timeout,
                    hint: '1~60',
                    maxLength: 3,
                    suffix: 'Mins',
                  ),
                ),
              ],
              const SettingsDivider(),
              SettingsSwitchRow(
                label: 'Login Password',
                value: _loginPassword,
                onChanged: (value) => setState(() => _loginPassword = value),
              ),
              if (_loginPassword) ...[
                const SettingsDivider(),
                SettingsNavRow(
                  title: 'Change Password',
                  onTap: _changePassword,
                ),
              ],
            ],
          ),
        ),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Tx Power',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: DeviceDetailTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                Lw007OptionLists.txPowerRangeHint,
                style: TextStyle(
                  fontSize: 12,
                  color: DeviceDetailTheme.textSecondary,
                ),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _txPowerIndex.toDouble(),
                      min: 0,
                      max: (Lw007OptionLists.txPowerLevels.length - 1).toDouble(),
                      activeColor: DeviceDetailTheme.primary,
                      onChanged: (value) => setState(() => _txPowerIndex = value.round()),
                    ),
                  ),
                  SizedBox(
                    width: 70,
                    child: Text(
                      '${txPower}dBm',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DeviceDetailTheme.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
