import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../ble/lw007.dart';
import '../../../../ble/lw007_device_session.dart';
import '../../../../ui/theme/device_detail_theme.dart';
import '../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../viewmodels/ble_scan_view_model.dart';
import '../device_detail_utils.dart';

class ThSettingsPage extends StatefulWidget {
  const ThSettingsPage({super.key, required this.session});

  final Lw007DeviceSession session;

  @override
  State<ThSettingsPage> createState() => _ThSettingsPageState();
}

class _ThSettingsPageState extends State<ThSettingsPage> {
  final _sampleRate = TextEditingController();
  final _tempThresholdMax = TextEditingController();
  final _tempThresholdMin = TextEditingController();
  final _tempDuration = TextEditingController();
  final _tempChangeThreshold = TextEditingController();
  final _humidityThresholdMax = TextEditingController();
  final _humidityThresholdMin = TextEditingController();
  final _humidityDuration = TextEditingController();
  final _humidityChangeThreshold = TextEditingController();

  StreamSubscription<Lw007ThStatusUpdate>? _thStatusSub;

  bool _enabled = false;
  bool _tempThresholdAlarm = false;
  bool _tempChangeAlarm = false;
  bool _humidityThresholdAlarm = false;
  bool _humidityChangeAlarm = false;
  bool _showValues = false;
  String _tempLabel = '';
  String _humidityLabel = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      await widget.session.client.enableThNotify();
    } catch (_) {
      // T&H notify is optional; status read still works when enabled.
    }
    _thStatusSub = widget.session.client.thStatusEvents.listen(_onThStatusUpdate);
    await _load();
  }

  void _onThStatusUpdate(Lw007ThStatusUpdate update) {
    if (!mounted) return;
    setState(() => _applyThStatusUpdate(update));
  }

  void _applyThStatusUpdate(Lw007ThStatusUpdate update) {
    _showValues = _enabled && update.visible;
    if (update.visible && update.temperature != null && update.humidity != null) {
      _tempLabel = update.temperatureLabel;
      _humidityLabel = update.humidityLabel;
    }
  }

  Future<void> _load() async {
    if (!widget.session.client.isConnected) {
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final results = await Future.wait([
        api.readThData(),
        api.readThEnable(),
        api.readThSampleRate(),
        api.readTempThresholdAlarmEnable(),
        api.readTempThresholdAlarm(),
        api.readTempChangeAlarmEnable(),
        api.readTempChangeAlarmDuration(),
        api.readTempChangeAlarmValue(),
        api.readHumidityThresholdAlarmEnable(),
        api.readHumidityThresholdAlarm(),
        api.readHumidityChangeAlarmEnable(),
        api.readHumidityChangeAlarmDuration(),
        api.readHumidityChangeAlarmValue(),
      ]);
      if (!mounted) return;
      _enabled = Lw007ParamHelpers.uint8(results[1].data) == 1;
      _sampleRate.text = Lw007ParamHelpers.uint8(results[2].data).toString();
      _tempThresholdAlarm = Lw007ParamHelpers.uint8(results[3].data) == 1;
      final tempThreshold = results[4].data;
      if (tempThreshold.length >= 2) {
        _tempThresholdMin.text = Lw007ParamHelpers.byte0(tempThreshold).toString();
        _tempThresholdMax.text = Lw007ParamHelpers.byte0(tempThreshold.sublist(1)).toString();
      }
      _tempChangeAlarm = Lw007ParamHelpers.uint8(results[5].data) == 1;
      _tempDuration.text = Lw007ParamHelpers.uint8(results[6].data).toString();
      _tempChangeThreshold.text = Lw007ParamHelpers.uint8(results[7].data).toString();
      _humidityThresholdAlarm = Lw007ParamHelpers.uint8(results[8].data) == 1;
      final humidityThreshold = results[9].data;
      if (humidityThreshold.length >= 2) {
        _humidityThresholdMin.text = Lw007ParamHelpers.uint8(humidityThreshold).toString();
        _humidityThresholdMax.text = humidityThreshold.length >= 2
            ? Lw007ParamHelpers.uint8(humidityThreshold.sublist(1)).toString()
            : '';
      }
      _humidityChangeAlarm = Lw007ParamHelpers.uint8(results[10].data) == 1;
      _humidityDuration.text = Lw007ParamHelpers.uint8(results[11].data).toString();
      _humidityChangeThreshold.text = Lw007ParamHelpers.uint8(results[12].data).toString();
      final update = Lw007ThStatusUpdate.fromPayload(results[0].data);
      if (_enabled && update != null) {
        _applyThStatusUpdate(update);
      } else {
        _showValues = false;
      }
      setState(() {});
    });
  }

  int? _intInRange(String text, int min, int max) {
    final value = int.tryParse(text.trim());
    if (value == null || value < min || value > max) {
      return null;
    }
    return value;
  }

  bool _validate() {
    if (_intInRange(_sampleRate.text, 1, 60) == null) return false;
    final tempMin = _intInRange(_tempThresholdMin.text, -30, 60);
    final tempMax = _intInRange(_tempThresholdMax.text, -30, 60);
    if (tempMin == null || tempMax == null || tempMin >= tempMax) return false;
    if (_intInRange(_tempDuration.text, 1, 24) == null) return false;
    if (_intInRange(_tempChangeThreshold.text, 1, 20) == null) return false;
    final humidityMin = int.tryParse(_humidityThresholdMin.text.trim());
    final humidityMax = int.tryParse(_humidityThresholdMax.text.trim());
    if (humidityMin == null ||
        humidityMax == null ||
        humidityMin < 0 ||
        humidityMax > 100 ||
        humidityMin >= humidityMax) {
      return false;
    }
    if (_intInRange(_humidityDuration.text, 1, 24) == null) return false;
    if (_intInRange(_humidityChangeThreshold.text, 1, 100) == null) return false;
    return true;
  }

  Future<void> _save() async {
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
      return;
    }
    final ok = await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final saved = (await Future.wait([
        api.writeThSampleRate([int.parse(_sampleRate.text.trim())]),
        api.writeTempThresholdAlarmEnable([_tempThresholdAlarm ? 1 : 0]),
        api.writeTempThresholdAlarm([
          int.parse(_tempThresholdMin.text.trim()) & 0xFF,
          int.parse(_tempThresholdMax.text.trim()) & 0xFF,
        ]),
        api.writeTempChangeAlarmEnable([_tempChangeAlarm ? 1 : 0]),
        api.writeTempChangeAlarmDuration([int.parse(_tempDuration.text.trim())]),
        api.writeTempChangeAlarmValue([int.parse(_tempChangeThreshold.text.trim())]),
        api.writeHumidityThresholdAlarmEnable([_humidityThresholdAlarm ? 1 : 0]),
        api.writeHumidityThresholdAlarm([
          int.parse(_humidityThresholdMin.text.trim()),
          int.parse(_humidityThresholdMax.text.trim()),
        ]),
        api.writeHumidityChangeAlarmEnable([_humidityChangeAlarm ? 1 : 0]),
        api.writeHumidityChangeAlarmDuration([int.parse(_humidityDuration.text.trim())]),
        api.writeHumidityChangeAlarmValue([int.parse(_humidityChangeThreshold.text.trim())]),
        api.writeThEnable([_enabled ? 1 : 0]),
      ])).every((result) => result);
      if (!saved || !mounted) {
        return false;
      }
      if (_enabled) {
        final result = await api.readThData();
        if (mounted) {
          final update = Lw007ThStatusUpdate.fromPayload(result.data);
          if (update != null) {
            setState(() => _applyThStatusUpdate(update));
          }
        }
      } else {
        setState(() => _showValues = false);
      }
      return true;
    });
    if (!mounted) return;
    if (ok == true) {
      await showCommonConfirmDialog(
        context: context,
        message: 'Saved Successfully！',
        confirmText: 'OK',
        showCancel: false,
        actionColor: BleScanViewModel.titleBarColor,
      );
    } else if (ok == false) {
      showProtocolResultToast(context, ok: false);
    }
  }

  Future<void> _onBack() async {
    await widget.session.client.disableThNotify();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _signedField({
    required TextEditingController controller,
    required String hint,
    required int maxLength,
    required String suffix,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 120,
          child: TextField(
            controller: controller,
            textAlign: TextAlign.center,
            keyboardType: const TextInputType.numberWithOptions(signed: true),
            maxLength: maxLength,
            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'-?\d*'))],
            decoration: InputDecoration(
              hintText: hint,
              counterText: '',
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: const UnderlineInputBorder(),
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          suffix,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: DeviceDetailTheme.textPrimary,
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _thStatusSub?.cancel();
    unawaited(widget.session.client.disableThNotify());
    _sampleRate.dispose();
    _tempThresholdMax.dispose();
    _tempThresholdMin.dispose();
    _tempDuration.dispose();
    _tempChangeThreshold.dispose();
    _humidityThresholdMax.dispose();
    _humidityThresholdMin.dispose();
    _humidityDuration.dispose();
    _humidityChangeThreshold.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'T&H Settings',
      showSave: true,
      onSave: _save,
      onBack: _onBack,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SettingsSwitchRow(
                  label: 'Function Switch',
                  value: _enabled,
                  onChanged: (value) {
                    setState(() {
                      _enabled = value;
                      if (!value) {
                        _showValues = false;
                      }
                    });
                  },
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Sample Rate',
                  child: SettingsTextField(
                    controller: _sampleRate,
                    hint: '1~60',
                    maxLength: 2,
                    suffix: 'S',
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      const Text(
                        'Temp:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Image.asset(
                        'assets/images/lw007_ic_temp.png',
                        width: 20,
                        height: 20,
                      ),
                      if (_showValues) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _tempLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: DeviceDetailTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      const Text(
                        'Humidity:',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Image.asset(
                        'assets/images/lw007_ic_humidity.png',
                        width: 20,
                        height: 20,
                      ),
                      if (_showValues) ...[
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            _humidityLabel,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: DeviceDetailTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ],
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
                  label: 'Temp Threshold Alarm',
                  value: _tempThresholdAlarm,
                  onChanged: (value) => setState(() => _tempThresholdAlarm = value),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Max.',
                  child: _signedField(
                    controller: _tempThresholdMax,
                    hint: '-30~60',
                    maxLength: 3,
                    suffix: '℃',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Min.',
                  child: _signedField(
                    controller: _tempThresholdMin,
                    hint: '-30~60',
                    maxLength: 3,
                    suffix: '℃',
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
                  label: 'Temp Change Alarm',
                  value: _tempChangeAlarm,
                  onChanged: (value) => setState(() => _tempChangeAlarm = value),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Duration Condition',
                  child: SettingsTextField(
                    controller: _tempDuration,
                    hint: '1~24',
                    maxLength: 2,
                    suffix: 'H',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Change Value Threshold',
                  child: SettingsTextField(
                    controller: _tempChangeThreshold,
                    hint: '1~20',
                    maxLength: 2,
                    suffix: '℃',
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
                  label: 'RH Threshold Alarm',
                  value: _humidityThresholdAlarm,
                  onChanged: (value) => setState(() => _humidityThresholdAlarm = value),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Max.',
                  child: SettingsTextField(
                    controller: _humidityThresholdMax,
                    hint: '0~100',
                    maxLength: 3,
                    suffix: '%',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Min.',
                  child: SettingsTextField(
                    controller: _humidityThresholdMin,
                    hint: '0~100',
                    maxLength: 3,
                    suffix: '%',
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
                  label: 'RH Change Alarm',
                  value: _humidityChangeAlarm,
                  onChanged: (value) => setState(() => _humidityChangeAlarm = value),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Duration Condition',
                  child: SettingsTextField(
                    controller: _humidityDuration,
                    hint: '1~24',
                    maxLength: 2,
                    suffix: 'H',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Change Value Threshold',
                  child: SettingsTextField(
                    controller: _humidityChangeThreshold,
                    hint: '1~100',
                    maxLength: 3,
                    suffix: '%',
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
