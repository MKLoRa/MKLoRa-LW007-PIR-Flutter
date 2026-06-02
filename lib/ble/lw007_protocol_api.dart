import 'lw007_ble_client.dart';
import 'lw007_param_key.dart';

class Lw007ProtocolApi {
  Lw007ProtocolApi(this._client);

  final Lw007BleClient _client;

  Lw007BleClient get client => _client;

  Future<bool> verifyPassword(String password) {
    return _client.verifyPassword(password);
  }

  Future<Lw007ParamResult> readParam(
    Lw007ParamKey key, {
    Lw007ParamChannel? channel,
    bool packet = false,
  }) {
    if (!key.canRead) {
      throw Lw007ProtocolException('Parameter ${key.name} is write-only');
    }
    return _client.readParam(
      key: key.key,
      channel: channel ?? _channelForKey(key),
      packet: packet,
    );
  }

  Future<bool> writeParam(
    Lw007ParamKey key,
    List<int> data, {
    Lw007ParamChannel? channel,
    bool packet = false,
    int packetCount = 1,
    int packetIndex = 0,
  }) {
    if (!key.canWrite) {
      throw Lw007ProtocolException('Parameter ${key.name} is read-only');
    }
    return _client.writeParam(
      key: key.key,
      data: data,
      channel: channel ?? _channelForKey(key),
      packet: packet,
      packetCount: packetCount,
      packetIndex: packetIndex,
    );
  }

  Lw007ParamChannel _channelForKey(Lw007ParamKey key) {
    return key.isControl ? Lw007ParamChannel.control : Lw007ParamChannel.params;
  }
}

class Lw007DeviceInfoApi {
  Lw007DeviceInfoApi(this._client);

  final Lw007BleClient _client;

  Future<String> readModelNumber() => _client.readModelNumber();
  Future<String> readSerialNumber() => _client.readSerialNumber();
  Future<String> readFirmwareRevision() => _client.readFirmwareRevision();
  Future<String> readHardwareRevision() => _client.readHardwareRevision();
  Future<String> readSoftwareRevision() => _client.readSoftwareRevision();
  Future<String> readManufacturerName() => _client.readManufacturerName();
}
