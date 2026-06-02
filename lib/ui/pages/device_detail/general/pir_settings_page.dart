import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../../../ble/lw007.dart';
import '../../../../ble/lw007_device_session.dart';
import '../../../../ui/theme/device_detail_theme.dart';
import '../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../viewmodels/ble_scan_view_model.dart';
import '../device_detail_utils.dart';

class PirSettingsPage extends StatefulWidget {
  const PirSettingsPage({super.key, required this.session});

  final Lw007DeviceSession session;

  @override
  State<PirSettingsPage> createState() => _PirSettingsPageState();
}

class _PirSettingsPageState extends State<PirSettingsPage> {
  final _reportInterval = TextEditingController();
  StreamSubscription<Lw007PirStatusUpdate>? _pirStatusSub;

  bool _enabled = false;
  int _sensitivityIndex = 0;
  int _delayIndex = 0;
  bool _showPirStatus = false;
  bool _motionDetected = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      await widget.session.client.enablePirNotify();
    } catch (_) {
      // PIR notify is optional; status read still works when enabled.
    }
    _pirStatusSub = widget.session.client.pirStatusEvents.listen(_onPirStatusUpdate);
    await _load();
  }

  void _onPirStatusUpdate(Lw007PirStatusUpdate update) {
    if (!mounted) return;
    setState(() => _applyPirStatusUpdate(update));
  }

  void _applyPirStatusUpdate(Lw007PirStatusUpdate update) {
    _showPirStatus = _enabled && update.visible;
    _motionDetected = update.motionDetected;
  }

  void _applyPirStatusByte(int status) {
    _applyPirStatusUpdate(Lw007PirStatusUpdate.fromStatusByte(status));
  }

  Future<void> _load() async {
    if (!widget.session.client.isConnected) {
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final results = await Future.wait([
        api.readPir(),
        api.readPirEnable(),
        api.readPirReportInterval(),
        api.readPirSensitivity(),
        api.readPirDelayTime(),
      ]);
      if (!mounted) return;
      final pirStatus = Lw007ParamHelpers.uint8(results[0].data);
      _enabled = Lw007ParamHelpers.uint8(results[1].data) == 1;
      _reportInterval.text = Lw007ParamHelpers.uint8(results[2].data).toString();
      final sensitivity = Lw007ParamHelpers.uint8(results[3].data);
      final delay = Lw007ParamHelpers.uint8(results[4].data);
      _sensitivityIndex = (sensitivity - 1).clamp(0, Lw007OptionLists.pirLevels.length - 1);
      _delayIndex = (delay - 1).clamp(0, Lw007OptionLists.pirLevels.length - 1);
      if (_enabled) {
        _applyPirStatusByte(pirStatus);
      } else {
        _showPirStatus = false;
      }
      setState(() {});
    });
  }

  bool _validate() {
    final interval = int.tryParse(_reportInterval.text.trim());
    return interval != null && interval >= 1 && interval <= 60;
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
      final interval = int.parse(_reportInterval.text.trim());
      final saved = (await Future.wait([
        api.writePirReportInterval([interval]),
        api.writePirSensitivity([_sensitivityIndex + 1]),
        api.writePirDelayTime([_delayIndex + 1]),
        api.writePirEnable([_enabled ? 1 : 0]),
      ])).every((result) => result);
      if (!saved || !mounted) {
        return false;
      }
      if (_enabled) {
        final pir = await api.readPir();
        if (mounted) {
          setState(() => _applyPirStatusByte(Lw007ParamHelpers.uint8(pir.data)));
        }
      } else {
        setState(() => _showPirStatus = false);
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
    await widget.session.client.disablePirNotify();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Widget _wheelPicker({
    required int selectedIndex,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return Container(
      width: 150,
      height: 130,
      decoration: BoxDecoration(
        border: Border.all(color: DeviceDetailTheme.primary),
        borderRadius: BorderRadius.circular(4),
      ),
      child: CupertinoPicker(
        key: ValueKey('pir-wheel-$selectedIndex'),
        scrollController: FixedExtentScrollController(initialItem: selectedIndex),
        itemExtent: 36,
        magnification: 1.08,
        useMagnifier: true,
        onSelectedItemChanged: onSelectedItemChanged,
        children: Lw007OptionLists.pirLevels
            .map(
              (label) => Center(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 15,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _wheelPickerRow({
    required String label,
    required int selectedIndex,
    required ValueChanged<int> onSelectedItemChanged,
  }) {
    return SizedBox(
      height: 130,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
          _wheelPicker(
            selectedIndex: selectedIndex,
            onSelectedItemChanged: onSelectedItemChanged,
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pirStatusSub?.cancel();
    unawaited(widget.session.client.disablePirNotify());
    _reportInterval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'PIR Settings',
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
                        _showPirStatus = false;
                      }
                    });
                  },
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Report Interval',
                  child: SettingsTextField(
                    controller: _reportInterval,
                    hint: '1~60',
                    maxLength: 2,
                    suffix: 'Mins',
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  '*Information Payload reporting interval when PIR is continuously triggered.',
                  style: TextStyle(
                    fontSize: 12,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _wheelPickerRow(
                  label: 'PIR Sensitivity',
                  selectedIndex: _sensitivityIndex,
                  onSelectedItemChanged: (index) => setState(() => _sensitivityIndex = index),
                ),
                const SizedBox(height: 20),
                _wheelPickerRow(
                  label: 'PIR Delay Time',
                  selectedIndex: _delayIndex,
                  onSelectedItemChanged: (index) => setState(() => _delayIndex = index),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Row(
              children: [
                Image.asset(
                  'assets/images/lw007_pir_status.png',
                  width: 24,
                  height: 24,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'PIR Status',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DeviceDetailTheme.textPrimary,
                    ),
                  ),
                ),
                if (_showPirStatus)
                  Text(
                    _motionDetected ? 'Motion detected' : 'Motion not detected',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: DeviceDetailTheme.textPrimary,
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
