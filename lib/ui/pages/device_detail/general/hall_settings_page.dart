import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../ble/lw007.dart';
import '../../../../ble/lw007_device_session.dart';
import '../../../../ui/theme/device_detail_theme.dart';
import '../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../ui/widgets/common_confirm_dialog.dart';
import '../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../../../../viewmodels/ble_scan_view_model.dart';
import '../device_detail_utils.dart';

class HallSettingsPage extends StatefulWidget {
  const HallSettingsPage({super.key, required this.session});

  final Lw007DeviceSession session;

  @override
  State<HallSettingsPage> createState() => _HallSettingsPageState();
}

class _HallSettingsPageState extends State<HallSettingsPage> {
  StreamSubscription<Lw007HallStatusUpdate>? _hallStatusSub;

  bool _enabled = false;
  bool _showStatus = false;
  bool _isOpen = false;
  int _triggerTimes = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _init());
  }

  Future<void> _init() async {
    try {
      await widget.session.client.enableHallNotify();
    } catch (_) {
      // Hall notify is optional; status read still works when enabled.
    }
    _hallStatusSub = widget.session.client.hallStatusEvents.listen(_onHallStatusUpdate);
    await _load();
  }

  void _onHallStatusUpdate(Lw007HallStatusUpdate update) {
    if (!mounted) return;
    setState(() => _applyHallStatusUpdate(update));
  }

  void _applyHallStatusUpdate(Lw007HallStatusUpdate update) {
    _showStatus = _enabled && update.visible;
    _isOpen = update.isOpen;
    _triggerTimes = update.triggerTimes;
  }

  Future<void> _load() async {
    if (!widget.session.client.isConnected) {
      return;
    }
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      await Future<void>.delayed(const Duration(milliseconds: 500));
      final results = await Future.wait([
        api.readHallStatusEnable(),
        api.readHallStatusSum(),
      ]);
      if (!mounted) return;
      _enabled = Lw007ParamHelpers.uint8(results[0].data) == 1;
      final update = Lw007HallStatusUpdate.fromPayload(results[1].data);
      if (_enabled && update != null) {
        _applyHallStatusUpdate(update);
      } else {
        _showStatus = false;
        _triggerTimes = 0;
      }
      setState(() {});
    });
  }

  Future<void> _save() async {
    final ok = await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final saved = await api.writeHallStatusEnable([_enabled ? 1 : 0]);
      if (!saved || !mounted) {
        return false;
      }
      if (_enabled) {
        final result = await api.readHallStatusSum();
        if (mounted) {
          final update = Lw007HallStatusUpdate.fromPayload(result.data);
          if (update != null) {
            setState(() => _applyHallStatusUpdate(update));
          }
        }
      } else {
        setState(() => _showStatus = false);
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
    await widget.session.client.disableHallNotify();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _hallStatusSub?.cancel();
    unawaited(widget.session.client.disableHallNotify());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DetailScaffold(
      title: 'Hall Settings',
      showSave: true,
      onSave: _save,
      onBack: _onBack,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: SettingsSwitchRow(
              label: 'Function Switch',
              value: _enabled,
              onChanged: (value) {
                setState(() {
                  _enabled = value;
                  if (!value) {
                    _showStatus = false;
                  }
                });
              },
            ),
          ),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Image.asset(
                      'assets/images/lw007_door_status.png',
                      width: 24,
                      height: 24,
                    ),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: Text(
                        'Door Status',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (_showStatus)
                      Text(
                        _isOpen ? 'Open' : 'Closed',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                  ],
                ),
                const SettingsDivider(),
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Total Trigger Times',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (_showStatus)
                      Text(
                        '$_triggerTimes',
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
