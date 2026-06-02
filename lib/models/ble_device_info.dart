import 'package:flutter_blue_plus/flutter_blue_plus.dart';

String hexString(List<int> data) {
  return data
      .map((b) => b.toRadixString(16).padLeft(2, '0').toUpperCase())
      .join(' ');
}

/// LW007-PIR scan Service Data UUID (AD type 0x16, protocol v1.2.1).
const _lw007AdvServiceUuid = '0000aa05-0000-1000-8000-00805f9b34fb';

class BleDeviceInfo {
  final DeviceIdentifier id;
  final String name;
  final String macAddress;
  final int rssi;
  final int? txPowerLevel;
  final int deviceType;
  final bool lowPower;
  final bool passwordEnabled;
  final bool connectable;
  final bool showTempHumidity;
  final double? temperature;
  final double? humidity;
  final List<int> rawServiceData;
  final List<int> rawManufacturerData;
  final int lastScanMs;
  final int scanIntervalMs;

  BleDeviceInfo({
    required this.id,
    required this.name,
    required this.macAddress,
    required this.rssi,
    required this.txPowerLevel,
    required this.deviceType,
    required this.lowPower,
    required this.passwordEnabled,
    this.connectable = true,
    this.showTempHumidity = false,
    this.temperature,
    this.humidity,
    required this.rawServiceData,
    this.rawManufacturerData = const [],
    this.lastScanMs = 0,
    this.scanIntervalMs = 0,
  });

  /// MAC from AD type 0xFF response packet bytes 8-13 (0-based index 7-12).
  String get advMacAddress => macFromManufacturerData(rawManufacturerData);

  String get scanIntervalLabel =>
      scanIntervalMs == 0 ? '<->N/A' : '<->${scanIntervalMs}ms';

  BleDeviceInfo copyWith({
    DeviceIdentifier? id,
    String? name,
    String? macAddress,
    int? rssi,
    int? txPowerLevel,
    int? deviceType,
    bool? lowPower,
    bool? passwordEnabled,
    bool? connectable,
    bool? showTempHumidity,
    double? temperature,
    double? humidity,
    List<int>? rawServiceData,
    List<int>? rawManufacturerData,
    int? lastScanMs,
    int? scanIntervalMs,
  }) {
    return BleDeviceInfo(
      id: id ?? this.id,
      name: name ?? this.name,
      macAddress: macAddress ?? this.macAddress,
      rssi: rssi ?? this.rssi,
      txPowerLevel: txPowerLevel ?? this.txPowerLevel,
      deviceType: deviceType ?? this.deviceType,
      lowPower: lowPower ?? this.lowPower,
      passwordEnabled: passwordEnabled ?? this.passwordEnabled,
      connectable: connectable ?? this.connectable,
      showTempHumidity: showTempHumidity ?? this.showTempHumidity,
      temperature: temperature ?? this.temperature,
      humidity: humidity ?? this.humidity,
      rawServiceData: rawServiceData ?? this.rawServiceData,
      rawManufacturerData: rawManufacturerData ?? this.rawManufacturerData,
      lastScanMs: lastScanMs ?? this.lastScanMs,
      scanIntervalMs: scanIntervalMs ?? this.scanIntervalMs,
    );
  }

  static BleDeviceInfo mergeScanUpdate({
    required BleDeviceInfo? previous,
    required BleDeviceInfo parsed,
    required int lastScanMs,
    required int scanIntervalMs,
  }) {
    final serviceData = _preferLongerPayload(
      previous?.rawServiceData ?? const [],
      parsed.rawServiceData,
    );
    final manufacturerData = _preferLongerPayload(
      previous?.rawManufacturerData ?? const [],
      parsed.rawManufacturerData,
    );
    final mac = macFromManufacturerData(manufacturerData);
    return parsed.copyWith(
      macAddress: mac,
      rawServiceData: serviceData,
      rawManufacturerData: manufacturerData,
      lastScanMs: lastScanMs,
      scanIntervalMs: scanIntervalMs,
    );
  }

  static List<int> _preferLongerPayload(List<int> a, List<int> b) {
    if (b.length > a.length) {
      return b;
    }
    if (a.length > b.length) {
      return a;
    }
    final macA = macFromManufacturerData(a);
    final macB = macFromManufacturerData(b);
    if (macB.isNotEmpty && macA.isEmpty) {
      return b;
    }
    return a.isNotEmpty ? a : b;
  }

  static bool _isLw007AdvUuid(Guid uuid) {
    return uuid.toString().toLowerCase().contains('aa05');
  }

  static String macFromManufacturerData(List<int> data) {
    if (data.length < 13) {
      return '';
    }
    final macBytes = data.sublist(7, 13);
    if (macBytes.every((b) => b == 0)) {
      return '';
    }
    return _macFromBytes(macBytes);
  }

  static String _macFromBytes(List<int> macBytes) {
    return macBytes
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(':');
  }

  static List<int>? _lw007ServiceData(AdvertisementData adv) {
    final byUuid = adv.serviceData[Guid(_lw007AdvServiceUuid)];
    if (byUuid != null && byUuid.isNotEmpty) {
      return byUuid;
    }

    for (final entry in adv.serviceData.entries) {
      if (_isLw007AdvUuid(entry.key) && entry.value.isNotEmpty) {
        return entry.value;
      }
    }

    for (final data in adv.serviceData.values) {
      if (data.isNotEmpty) {
        return data;
      }
    }

    return null;
  }

  static List<int>? _lw007ManufacturerData(AdvertisementData adv) {
    if (adv.msd.isEmpty) {
      return null;
    }
    for (final bytes in adv.msd) {
      if (bytes.length == 14) {
        return bytes;
      }
      if (bytes.length > 14) {
        return bytes.sublist(bytes.length - 14);
      }
    }
    return adv.msd.first;
  }

  static int _uint16(List<int> data, int offset) {
    if (data.length < offset + 2) {
      return 0xFFFF;
    }
    return ((data[offset] & 0xFF) << 8) | (data[offset + 1] & 0xFF);
  }

  static BleDeviceInfo? fromScanResult(ScanResult result) {
    final adv = result.advertisementData;
    final serviceData = _lw007ServiceData(adv);
    final manufacturerData = _lw007ManufacturerData(adv);
    if (serviceData == null || manufacturerData == null) {
      return null;
    }
    if (manufacturerData.length != 14) {
      return null;
    }

    final deviceType = serviceData[0] & 0xFF;
    final lowPower = (manufacturerData[0] & 0x40) == 0x40;
    final tempInt = _uint16(manufacturerData, 1);
    final humidityInt = _uint16(manufacturerData, 3);
    var showTempHumidity = false;
    double? temperature;
    double? humidity;
    if (tempInt != 0xFFFF && humidityInt != 0xFFFF) {
      showTempHumidity = true;
      temperature = tempInt * 0.1 - 30;
      humidity = humidityInt * 0.1;
    }

    final txPower = manufacturerData[6];
    final passwordEnabled = manufacturerData[13] == 1;
    final macAddress = macFromManufacturerData(manufacturerData);

    return BleDeviceInfo(
      id: result.device.remoteId,
      name: adv.advName.isNotEmpty ? adv.advName : result.device.advName,
      macAddress: macAddress,
      rssi: result.rssi,
      txPowerLevel: txPower,
      deviceType: deviceType,
      lowPower: lowPower,
      passwordEnabled: passwordEnabled,
      connectable: adv.connectable,
      showTempHumidity: showTempHumidity,
      temperature: temperature,
      humidity: humidity,
      rawServiceData: serviceData,
      rawManufacturerData: manufacturerData,
    );
  }
}
