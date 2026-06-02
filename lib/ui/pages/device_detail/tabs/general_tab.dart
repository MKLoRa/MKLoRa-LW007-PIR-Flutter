import 'package:flutter/material.dart';

import '../../../../../ble/lw007.dart';
import '../../../../../ble/lw007_device_session.dart';
import '../../../../../ble/lw007_param_helpers.dart';
import '../../../../../ble/lw007_protocol_named_api.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../general/pir_settings_page.dart';
import '../general/hall_settings_page.dart';
import '../general/th_settings_page.dart';

class GeneralTab extends StatefulWidget {
  const GeneralTab({super.key, required this.session, required this.onSaveReady});

  final Lw007DeviceSession session;
  final void Function(Future<bool> Function() save) onSaveReady;

  @override
  State<GeneralTab> createState() => GeneralTabState();
}

class GeneralTabState extends State<GeneralTab> {
  final _heartbeatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    widget.onSaveReady(_save);
  }

  Future<void> load({bool showOverlay = true}) async {
    await runWithBleLoading(
      context,
      () async {
        final api = widget.session.protocol;
        final heartbeat = await api.readHeartbeatInterval();
        if (!mounted) return;
        _heartbeatController.text = Lw007ParamHelpers.bytesToInt(heartbeat.data).toString();
        setState(() {});
      },
      showOverlay: showOverlay,
    );
  }

  Future<bool> _save() async {
    final text = _heartbeatController.text.trim();
    final value = int.tryParse(text);
    if (value == null || value < 1 || value > 14400) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Heartbeat interval must be 1~14400')),
        );
      }
      return false;
    }
    return widget.session.protocol.writeHeartbeatInterval(
      Lw007ParamHelpers.int32Bytes(value),
    );
  }

  @override
  void dispose() {
    _heartbeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(10),
      children: [
        SettingsCard(
          child: SettingsLabelRow(
            label: 'Heartbeat Interval',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _heartbeatController,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    decoration: const InputDecoration(
                      hintText: '1~14400',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                const Text(
                  'Mins',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'PIR Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => PirSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: SettingsNavRow(
            title: 'Hall Settings',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => HallSettingsPage(session: widget.session),
              ),
            ),
          ),
        ),
        SettingsCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsNavRow(
                title: 'T&H Settings',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ThSettingsPage(session: widget.session),
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  '*Temperature and humidity monitoring settings',
                  style: TextStyle(fontSize: 12, color: Color(0xFF666666)),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
