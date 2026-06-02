import 'package:flutter/material.dart';

import '../../../../../ble/lw007_data_codec.dart';
import '../../../../../ble/lw007_device_session.dart';
import '../../../../../ble/lw007_param_helpers.dart';
import '../../../../../ble/lw007_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';

class SelfTestPage extends StatefulWidget {
  const SelfTestPage({super.key, required this.session});
  final Lw007DeviceSession session;

  @override
  State<SelfTestPage> createState() => _SelfTestPageState();
}

class _SelfTestPageState extends State<SelfTestPage> {
  int _pcbaStatus = 0;
  Map<String, dynamic>? _batteryInfo;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readPcbaStatus(),
        api.readBatteryInfo(),
      ]);
      if (!mounted) return;
      setState(() {
        _pcbaStatus = Lw007ParamHelpers.uint8(results[0].data);
        _batteryInfo = Lw007DataCodec.decodeSelfTestBatteryInfo(results[1].data);
      });
    });
  }

  Widget _batteryLine(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 13,
          color: DeviceDetailTheme.textPrimary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final battery = _batteryInfo;
    return DetailScaffold(
      title: 'Selftest Interface',
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Row(
              children: [
                const Text(
                  'PCBA Status:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
                const SizedBox(width: 20),
                Text(
                  '$_pcbaStatus',
                  style: const TextStyle(
                    fontSize: 15,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Battery information:',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: DeviceDetailTheme.textPrimary,
                  ),
                ),
                if (battery != null) ...[
                  _batteryLine('${battery['runtime']} s'),
                  _batteryLine('${battery['advTimes']} times'),
                  _batteryLine('${battery['thSampleRate']} times'),
                  _batteryLine('${battery['loraPower']} mAS'),
                  _batteryLine('${battery['loraTransmissionTimes']} times'),
                  _batteryLine(
                    '${Lw007DataCodec.formatBatteryConsumeMah(battery['batteryConsumeMah'] as double)} mAH',
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
