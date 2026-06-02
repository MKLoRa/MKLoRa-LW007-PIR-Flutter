import 'package:flutter/material.dart';

import '../../../../../ble/lw007_data_codec.dart';
import '../../../../../ble/lw007_device_session.dart';
import '../../../../../ble/lw007_option_lists.dart';
import '../../../../../ble/lw007_param_helpers.dart';
import '../../../../../ble/lw007_protocol_named_api.dart';
import '../../../../../ui/theme/device_detail_theme.dart';
import '../../../../../ui/widgets/ble_loading_overlay.dart';
import '../../../../../ui/widgets/device_detail/bottom_picker_dialog.dart';
import '../../../../../ui/widgets/device_detail/settings_widgets.dart';
import '../device_detail_utils.dart';

class SelfTestNewPage extends StatefulWidget {
  const SelfTestNewPage({super.key, required this.session});
  final Lw007DeviceSession session;

  @override
  State<SelfTestNewPage> createState() => _SelfTestNewPageState();
}

class _SelfTestNewPageState extends State<SelfTestNewPage> {
  var _showSelftestZero = false;
  var _showThStatus = false;
  int _pcbaStatus = 0;

  int _condition1ThresholdIndex = 0;
  final _condition1MinInterval = TextEditingController();
  final _condition1SampleTimes = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final results = await Future.wait([
        api.readSelftestStatus(),
        api.readPcbaStatus(),
        api.readCondition1VoltageThreshold(),
        api.readCondition1MinSampleInterval(),
        api.readCondition1SampleTimes(),
      ]);
      if (!mounted) return;
      final status = Lw007DataCodec.decodeSelftestStatusValue(results[0].data);
      setState(() {
        _showSelftestZero = status == 0;
        _showThStatus = (status & 0x01) == 0x01;
        _pcbaStatus = Lw007ParamHelpers.uint8(results[1].data);
        _condition1ThresholdIndex = Lw007OptionLists.voltageThresholdPickerIndex(
          Lw007ParamHelpers.uint8(results[2].data),
        );
        _condition1MinInterval.text =
            Lw007ParamHelpers.uint16(results[3].data).toString();
        _condition1SampleTimes.text =
            Lw007ParamHelpers.uint8(results[4].data).toString();
      });
    });
  }

  bool _validateConditions() {
    final c1Interval = int.tryParse(_condition1MinInterval.text.trim());
    final c1Times = int.tryParse(_condition1SampleTimes.text.trim());
    if (c1Interval == null || c1Interval < 1 || c1Interval > 1440) return false;
    if (c1Times == null || c1Times < 1 || c1Times > 100) return false;
    return true;
  }

  Future<void> _saveConditions() async {
    if (!_validateConditions()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Para error!')),
        );
      }
      return;
    }
    final c1Interval = int.parse(_condition1MinInterval.text.trim());
    final c1Times = int.parse(_condition1SampleTimes.text.trim());
    await runWithBleLoading(context, () async {
      final api = widget.session.protocol;
      final ok = (await Future.wait([
        api.writeCondition1VoltageThreshold([
          Lw007OptionLists.voltageThresholdDeviceValue(_condition1ThresholdIndex),
        ]),
        api.writeCondition1MinSampleInterval(Lw007ParamHelpers.uint16Bytes(c1Interval)),
        api.writeCondition1SampleTimes([c1Times]),
      ])).every((r) => r);
      if (mounted) await saveWithToast(context, () async => ok);
    });
  }

  Future<void> _pickThreshold() async {
    final options = Lw007OptionLists.voltageThresholdOptions();
    final index = await showBottomPicker(
      context: context,
      options: options,
      selectedIndex: _condition1ThresholdIndex,
    );
    if (index != null) {
      setState(() => _condition1ThresholdIndex = index);
    }
  }

  @override
  void dispose() {
    _condition1MinInterval.dispose();
    _condition1SampleTimes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final options = Lw007OptionLists.voltageThresholdOptions();
    return DetailScaffold(
      title: 'Selftest Interface',
      showSave: true,
      onSave: _saveConditions,
      body: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          SettingsCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Selftest Status:',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: DeviceDetailTheme.textPrimary,
                      ),
                    ),
                    if (_showSelftestZero) ...[
                      const SizedBox(width: 20),
                      const Text(
                        '0',
                        style: TextStyle(
                          fontSize: 15,
                          color: DeviceDetailTheme.textPrimary,
                        ),
                      ),
                    ],
                  ],
                ),
                if (_showThStatus)
                  const Padding(
                    padding: EdgeInsets.only(left: 20, top: 4),
                    child: Text(
                      '1',
                      style: TextStyle(
                        fontSize: 15,
                        color: DeviceDetailTheme.textPrimary,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
              children: [
                SettingsLabelRow(
                  label: 'Condition 1 Voltage Threshold',
                  child: BlueValueButton(
                    text: '${options[_condition1ThresholdIndex]}V',
                    onTap: _pickThreshold,
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Min. Sample Interval',
                  child: SettingsTextField(
                    controller: _condition1MinInterval,
                    hint: '1~1440',
                    maxLength: 4,
                    suffix: 'Mins',
                  ),
                ),
                const SettingsDivider(),
                SettingsLabelRow(
                  label: 'Sample Times',
                  child: SettingsTextField(
                    controller: _condition1SampleTimes,
                    hint: '1~100',
                    maxLength: 3,
                    suffix: 'Times',
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
