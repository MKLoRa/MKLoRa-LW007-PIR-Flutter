import 'package:flutter/material.dart';

import '../../models/ble_device_info.dart';
import '../../viewmodels/ble_scan_view_model.dart';

class DeviceItem extends StatelessWidget {
  final BleDeviceInfo device;
  final VoidCallback onConnect;

  const DeviceItem({super.key, required this.device, required this.onConnect});

  static const _labelStyle = TextStyle(
    fontSize: 14,
    color: Color(0xFF666666),
  );

  static const _smallLabelStyle = TextStyle(
    fontSize: 10,
    color: Color(0xFF666666),
  );

  @override
  Widget build(BuildContext context) {
    final name = device.name.isNotEmpty ? device.name : device.id.str;
    final txPowerLabel = device.txPowerLevel == null
        ? 'Tx Power:N/A'
        : 'Tx Power:${device.txPowerLevel}dBm';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Material(
        color: Colors.white,
        elevation: 1,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {},
          child: Padding(
            padding: const EdgeInsets.fromLTRB(0, 15, 15, 15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.signal_cellular_alt,
                            color: BleScanViewModel.titleBarColor,
                            size: 20,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            '${device.rssi}dBm',
                            style: _smallLabelStyle,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            'MAC:${device.macAddress.isNotEmpty ? device.macAddress : 'N/A'}',
                            style: _labelStyle,
                          ),
                        ],
                      ),
                    ),
                    if (device.connectable)
                      SizedBox(
                        height: 35,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: BleScanViewModel.titleBarColor,
                            shape: const StadiumBorder(),
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            elevation: 0,
                          ),
                          onPressed: onConnect,
                          child: const Text(
                            'CONNECT',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 13),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 52,
                      child: Column(
                        children: [
                          Image.asset(
                            device.lowPower
                                ? 'assets/images/lw007_low_battery.png'
                                : 'assets/images/ic_battery.png',
                            width: 24,
                            height: 24,
                            fit: BoxFit.contain,
                          ),
                          const SizedBox(height: 5),
                          Text(
                            device.lowPower ? 'Low' : 'Normal',
                            textAlign: TextAlign.center,
                            style: _smallLabelStyle,
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Text(
                        txPowerLabel,
                        style: _labelStyle,
                      ),
                    ),
                    SizedBox(
                      width: 72,
                      child: Text(
                        device.scanIntervalLabel,
                        textAlign: TextAlign.center,
                        style: _smallLabelStyle,
                      ),
                    ),
                  ],
                ),
                if (device.showTempHumidity) ...[
                  const SizedBox(height: 13),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const SizedBox(width: 52),
                      Expanded(
                        child: _metricLabel(
                          iconAsset: 'assets/images/lw007_ic_temp.png',
                          text:
                              '${device.temperature?.toStringAsFixed(1) ?? '--'} ℃',
                        ),
                      ),
                      _metricLabel(
                        iconAsset: 'assets/images/lw007_ic_humidity.png',
                        text:
                            '${device.humidity?.toStringAsFixed(1) ?? '--'}%RH',
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _metricLabel({
    required String iconAsset,
    required String text,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          iconAsset,
          width: 16,
          height: 16,
          fit: BoxFit.contain,
        ),
        const SizedBox(width: 5),
        Text(text, style: _labelStyle),
      ],
    );
  }
}
