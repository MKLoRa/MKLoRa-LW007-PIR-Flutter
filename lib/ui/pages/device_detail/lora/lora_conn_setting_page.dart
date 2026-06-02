import 'package:flutter/material.dart';

import '../../../../../ble/lw007.dart';
import '../../../../../ble/lw007_data_codec.dart';
import '../../../../../ble/lw007_device_session.dart';
import '../../../../../ble/lw007_lora_conn_helpers.dart';
import '../../../../../ble/lw007_param_helpers.dart';
import '../../../../../ble/lw007_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';

class LoRaConnSettingPage extends StatefulWidget {
  const LoRaConnSettingPage({super.key, required this.session});
  final Lw007DeviceSession session;

  @override
  State<LoRaConnSettingPage> createState() => _LoRaConnSettingPageState();
}

class _LoRaConnSettingPageState extends State<LoRaConnSettingPage> {
  final _state = Lw007LoraConnState();
  final _devEui = TextEditingController();
  final _appEui = TextEditingController();
  final _appKey = TextEditingController();
  final _devAddr = TextEditingController();
  final _appSkey = TextEditingController();
  final _nwkSkey = TextEditingController();

  int _modeIndex = 1;
  int _regionPicker = 5;
  int _messageTypeIndex = 0;
  int _maxRetransIndex = 0;
  bool _advanced = false;
  bool _adr = true;
  bool _dutyCycle = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readLoraMode(),
        api.readLoraDevEui(),
        api.readLoraAppEui(),
        api.readLoraAppKey(),
        api.readLoraDevAddr(),
        api.readLoraAppSkey(),
        api.readLoraNwkSkey(),
        api.readLoraRegion(),
        api.readLoraCh(),
        api.readLoraDutycycle(),
        api.readLoraDr(),
        api.readLoraUplinkStrategy(),
        api.readLoraMessageType(),
        api.readLoraMaxRetransmissionTimes(),
      ]);
      if (!mounted) return;
      final mode = Lw007ParamHelpers.uint8(results[0].data);
      _modeIndex = (mode - 1).clamp(0, 1);
      _devEui.text = Lw007ParamHelpers.bytesToHex(results[1].data);
      _appEui.text = Lw007ParamHelpers.bytesToHex(results[2].data);
      _appKey.text = Lw007ParamHelpers.bytesToHex(results[3].data);
      _devAddr.text = Lw007ParamHelpers.bytesToHex(results[4].data);
      _appSkey.text = Lw007ParamHelpers.bytesToHex(results[5].data);
      _nwkSkey.text = Lw007ParamHelpers.bytesToHex(results[6].data);
      final region = Lw007ParamHelpers.uint8(results[7].data);
      _regionPicker = Lw007LoraConnHelpers.pickerFromRegion(region);
      Lw007LoraConnHelpers.applyRegion(_state, region);
      final ch = results[8].data;
      if (ch.length >= 2) {
        _state.ch1 = ch[0];
        _state.ch2 = ch[1];
      }
      _dutyCycle = Lw007ParamHelpers.uint8(results[9].data) == 1;
      _state.dr = Lw007ParamHelpers.uint8(results[10].data);
      final strategy = results[11].data;
      if (strategy.isNotEmpty) {
        _adr = Lw007ParamHelpers.uint8(strategy) == 1;
      }
      if (strategy.length >= 3) {
        _state.dr1 = strategy[1];
        _state.dr2 = strategy[2];
      }
      _messageTypeIndex = Lw007ParamHelpers.uint8(results[12].data).clamp(0, 1);
      final retrans = Lw007ParamHelpers.uint8(results[13].data);
      _maxRetransIndex = (retrans - 1).clamp(0, 7);
      setState(() {});
    });
  }

  Future<void> _pickMessageType() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw007OptionLists.payloadTypes,
      selectedIndex: _messageTypeIndex,
    );
    if (index != null) setState(() => _messageTypeIndex = index);
  }

  Future<void> _pickMaxRetransmission() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw007OptionLists.retransmissionTimes,
      selectedIndex: _maxRetransIndex,
    );
    if (index != null) setState(() => _maxRetransIndex = index);
  }

  Future<void> _pickMode() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw007OptionLists.loraUploadMode,
      selectedIndex: _modeIndex,
    );
    if (index != null) setState(() => _modeIndex = index);
  }

  Future<void> _pickRegion() async {
    final index = await showBottomPicker(
      context: context,
      options: Lw007OptionLists.loraRegions,
      selectedIndex: _regionPicker,
    );
    if (index == null) return;
    final region = Lw007LoraConnHelpers.regionFromPicker(index);
    setState(() {
      _regionPicker = index;
      _adr = true;
      Lw007LoraConnHelpers.applyRegion(_state, region, resetValues: true);
    });
  }

  Future<void> _pickCh1() async {
    final options = Lw007LoraConnHelpers.chOptions(_state);
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: _state.ch1,
    );
    if (index == null) return;
    setState(() {
      _state.ch1 = index;
      if (_state.ch2 < _state.ch1) _state.ch2 = _state.ch1;
    });
  }

  Future<void> _pickCh2() async {
    final options = List.generate(_state.maxCh - _state.ch1 + 1, (i) => '${_state.ch1 + i}');
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: _state.ch2 - _state.ch1,
    );
    if (index == null) return;
    setState(() => _state.ch2 = _state.ch1 + index);
  }

  Future<void> _pickDr() async {
    final options = Lw007LoraConnHelpers.drOptions(_state);
    final selected = _state.dr - _state.minDr;
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: selected.clamp(0, options.length - 1),
    );
    if (index == null) return;
    setState(() => _state.dr = _state.minDr + index);
  }

  Future<void> _pickDr1() async {
    final options = Lw007LoraConnHelpers.drOptions(_state);
    final selected = _state.dr1 - _state.minDr;
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: selected.clamp(0, options.length - 1),
    );
    if (index == null) return;
    setState(() {
      _state.dr1 = _state.minDr + index;
      if (_state.dr2 < _state.dr1) _state.dr2 = _state.dr1;
    });
  }

  Future<void> _pickDr2() async {
    final options = List.generate(_state.maxDr - _state.dr1 + 1, (i) => '${_state.dr1 + i}');
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: _state.dr2 - _state.dr1,
    );
    if (index == null) return;
    setState(() => _state.dr2 = _state.dr1 + index);
  }

  bool _validate() {
    if (_devEui.text.length != 16 || _appEui.text.length != 16) return false;
    if (_modeIndex == 0) {
      return _devAddr.text.length == 8 &&
          _appSkey.text.length == 32 &&
          _nwkSkey.text.length == 32;
    }
    return _appKey.text.length == 32;
  }

  Future<bool> _writeAll(Lw007ProtocolApi api) async {
    final region = _state.region;
    if (_modeIndex == 0) {
      if (!await api.writeLoraDevEui(Lw007ParamHelpers.hexToBytes(_devEui.text))) return false;
      if (!await api.writeLoraAppEui(Lw007ParamHelpers.hexToBytes(_appEui.text))) return false;
      if (!await api.writeLoraDevAddr(Lw007ParamHelpers.hexToBytes(_devAddr.text))) return false;
      if (!await api.writeLoraAppSkey(Lw007ParamHelpers.hexToBytes(_appSkey.text))) return false;
      if (!await api.writeLoraNwkSkey(Lw007ParamHelpers.hexToBytes(_nwkSkey.text))) return false;
    } else {
      if (!await api.writeLoraDevEui(Lw007ParamHelpers.hexToBytes(_devEui.text))) return false;
      if (!await api.writeLoraAppEui(Lw007ParamHelpers.hexToBytes(_appEui.text))) return false;
      if (!await api.writeLoraAppKey(Lw007ParamHelpers.hexToBytes(_appKey.text))) return false;
    }
    if (!await api.writeLoraMode([_modeIndex + 1])) return false;
    if (!await api.writeLoraMessageType([_messageTypeIndex])) return false;
    if (_messageTypeIndex == 1) {
      if (!await api.writeLoraMaxRetransmissionTimes([_maxRetransIndex + 1])) return false;
    }
    if (!await api.writeLoraRegion([region])) return false;
    if (Lw007LoraConnHelpers.shouldWriteCh(region)) {
      if (!await api.writeLoraCh([_state.ch1, _state.ch2])) return false;
    }
    if (Lw007LoraConnHelpers.shouldWriteDutyCycle(region)) {
      if (!await api.writeLoraDutycycle([_dutyCycle ? 1 : 0])) return false;
    }
    if (Lw007LoraConnHelpers.shouldWriteDr(region)) {
      if (!await api.writeLoraDr([_state.dr])) return false;
    }
    if (!await api.writeLoraUplinkStrategy(
      Lw007DataCodec.encodeLoraUplinkStrategy(
        adr: _adr,
        dr1: _state.dr1,
        dr2: _state.dr2,
      ),
    )) {
      return false;
    }
    return api.writeRestartEmpty();
  }

  Future<void> _save() async {
    if (!_validate()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    await runWithBleLoading(context, () async {
      final ok = await _writeAll(widget.session.protocol);
      if (!mounted) return;
      showProtocolResultToast(context, ok: ok);
      if (ok) {
        Navigator.of(context).pop(true);
      }
    });
  }

  @override
  void dispose() {
    _devEui.dispose();
    _appEui.dispose();
    _appKey.dispose();
    _devAddr.dispose();
    _appSkey.dispose();
    _nwkSkey.dispose();
    super.dispose();
  }

  Widget _dualPickerRow({
    required String label,
    required String leftValue,
    required String rightValue,
    required VoidCallback onLeft,
    required VoidCallback onRight,
  }) {
    return Row(
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
        BlueValueButton(text: leftValue, minWidth: 90, onTap: onLeft),
        const SizedBox(width: 10),
        BlueValueButton(text: rightValue, minWidth: 90, onTap: onRight),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Connection Setting',
      showSave: true,
      onSave: _save,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            margin: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsLabelRow(
                  label: 'LoRaWAN Mode',
                  child: BlueValueButton(
                    text: Lw007OptionLists.loraUploadMode[_modeIndex],
                    onTap: _pickMode,
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'DevEUI',
                  child: Expanded(
                    child: SettingsHexField(
                      controller: _devEui,
                      hint: '16 hex chars',
                      maxLength: 16,
                    ),
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'AppEUI',
                  child: Expanded(
                    child: SettingsHexField(
                      controller: _appEui,
                      hint: '16 hex chars',
                      maxLength: 16,
                    ),
                  ),
                ),
                if (_modeIndex == 0) ...[
                  const SettingsDivider(),
                  SettingsLabelRow(
                    label: 'DevAddr',
                    child: Expanded(
                      child: SettingsHexField(
                        controller: _devAddr,
                        hint: '8 hex chars',
                        maxLength: 8,
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsLabelRow(
                    label: 'AppSKey',
                    child: Expanded(
                      child: SettingsHexField(
                        controller: _appSkey,
                        hint: '32 hex chars',
                        maxLength: 32,
                      ),
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsLabelRow(
                    label: 'NwkSKey',
                    child: Expanded(
                      child: SettingsHexField(
                        controller: _nwkSkey,
                        hint: '32 hex chars',
                        maxLength: 32,
                      ),
                    ),
                  ),
                ] else ...[
                  const SettingsDivider(),
                  SettingsLabelRow(
                    label: 'AppKey',
                    child: Expanded(
                      child: SettingsHexField(
                        controller: _appKey,
                        hint: '32 hex chars',
                        maxLength: 32,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Region/Subnet',
              child: BlueValueButton(
                text: Lw007OptionLists.loraRegions[_regionPicker],
                onTap: _pickRegion,
              ),
            ),
          ),
          SettingsCard(
            child: SettingsLabelRow(
              label: 'Message Type',
              child: BlueValueButton(
                text: Lw007OptionLists.payloadTypes[_messageTypeIndex],
                onTap: _pickMessageType,
              ),
            ),
          ),
          SwitchListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            title: const Text(
              'Advanced Setting(Optional)',
              style: TextStyle(
                color: DeviceDetailTheme.primary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            value: _advanced,
            onChanged: (value) => setState(() => _advanced = value),
          ),
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 10),
            child: Text(
              'Note:Please do not modify advanced settings unless necessary.',
              style: TextStyle(fontSize: 15, color: DeviceDetailTheme.textPrimary),
            ),
          ),
          if (_advanced) ...[
            if (_state.showCh)
              SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _dualPickerRow(
                      label: 'CH',
                      leftValue: '${_state.ch1}',
                      rightValue: '${_state.ch2}',
                      onLeft: _pickCh1,
                      onRight: _pickCh2,
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '*It is only used for US915,AU915,CN470',
                      style: TextStyle(fontSize: 15, color: DeviceDetailTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            if (_state.showDutyCycle)
              SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsSwitchRow(
                      label: 'Duty-cycle',
                      value: _dutyCycle,
                      onChanged: (value) => setState(() => _dutyCycle = value),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '*It is only used for EU868,CN779,EU433 and RU864.\n'
                      'Off: The uplink report interval will not be limit by region freqency.\n'
                      'On:The uplink report interval will be limit by region freqency.',
                      style: TextStyle(fontSize: 15, color: DeviceDetailTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            if (_state.showDr)
              SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SettingsLabelRow(
                      label: 'DR For Join',
                      child: BlueValueButton(
                        text: '${_state.dr}',
                        onTap: _pickDr,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      '*It is only used for CN470, CN779, EU433, EU868,KR920, IN865, RU864',
                      style: TextStyle(fontSize: 15, color: DeviceDetailTheme.textPrimary),
                    ),
                  ],
                ),
              ),
            SettingsCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Uplink Strategy',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DeviceDetailTheme.textPrimary,
                    ),
                  ),
                  const SettingsDivider(),
                  SettingsSwitchRow(
                    label: 'ADR',
                    value: _adr,
                    onChanged: (value) => setState(() => _adr = value),
                  ),
                  if (!_adr) ...[
                    const SettingsDivider(),
                    _dualPickerRow(
                      label: 'DR For Payload',
                      leftValue: '${_state.dr1}',
                      rightValue: '${_state.dr2}',
                      onLeft: _pickDr1,
                      onRight: _pickDr2,
                    ),
                  ],
                ],
              ),
            ),
            if (_messageTypeIndex == 1)
              SettingsCard(
                child: SettingsNavRow(
                  title: 'Max retransmission times',
                  trailing: Lw007OptionLists.retransmissionTimes[_maxRetransIndex],
                  onTap: _pickMaxRetransmission,
                ),
              ),
          ],
        ],
      ),
    );
  }
}
