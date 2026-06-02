import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import '../models/ble_device_info.dart';
import 'lw007_ble_client.dart';
import 'lw007_export_data_store.dart';
import 'lw007_protocol_api.dart';

class Lw007DeviceSession {
  Lw007DeviceSession._({
    required this.deviceInfo,
    required this.client,
    required this.protocol,
    required this.deviceInfoApi,
  });

  final BleDeviceInfo deviceInfo;
  final Lw007BleClient client;
  final Lw007ProtocolApi protocol;
  final Lw007DeviceInfoApi deviceInfoApi;
  final Lw007ExportDataStore exportData = Lw007ExportDataStore();

  static Lw007DeviceSession? _active;

  static Lw007DeviceSession? get active => _active;

  static Future<Lw007DeviceSession> connect({
    required BleDeviceInfo deviceInfo,
    String? password,
  }) async {
    final bluetoothDevice = BluetoothDevice.fromId(deviceInfo.id.str);
    final client = Lw007BleClient();

    await client.connectWithRetry(bluetoothDevice);

    if (password != null && password.isNotEmpty) {
      final verified = await client.verifyPassword(password);
      if (!verified) {
        await client.disconnect();
        throw Lw007ProtocolException('Password verification failed');
      }
    }

    final session = Lw007DeviceSession._(
      deviceInfo: deviceInfo,
      client: client,
      protocol: Lw007ProtocolApi(client),
      deviceInfoApi: Lw007DeviceInfoApi(client),
    );
    _active = session;
    return session;
  }

  Future<void> disconnect() async {
    await client.disconnect();
    clearActiveIfMatches(this);
  }

  static void clearActiveIfMatches(Lw007DeviceSession session) {
    if (_active == session) {
      _active = null;
    }
  }
}
