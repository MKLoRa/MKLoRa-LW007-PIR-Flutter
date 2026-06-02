import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

import 'lw007_constants.dart';
import 'lw007_disconnect_event.dart';
import 'lw007_hall_status_event.dart';
import 'lw007_pir_status_event.dart';
import 'lw007_th_status_event.dart';
import 'lw007_protocol_codec.dart';
import 'lw007_protocol_logger.dart';

class Lw007BleClient {
  BluetoothDevice? _device;
  BluetoothCharacteristic? _passwordChar;
  BluetoothCharacteristic? _disconnectChar;
  BluetoothCharacteristic? _paramsChar;
  BluetoothCharacteristic? _controlChar;
  BluetoothCharacteristic? _logNotifyChar;
  BluetoothCharacteristic? _pirChar;
  BluetoothCharacteristic? _hallChar;
  BluetoothCharacteristic? _thChar;
  BluetoothCharacteristic? _modelNumberChar;
  BluetoothCharacteristic? _serialNumberChar;
  BluetoothCharacteristic? _firmwareRevisionChar;
  BluetoothCharacteristic? _hardwareRevisionChar;
  BluetoothCharacteristic? _softwareRevisionChar;
  BluetoothCharacteristic? _manufacturerNameChar;

  final Map<String, StreamSubscription<List<int>>> _notifySubscriptions = {};
  final Map<String, Completer<List<int>>> _pendingRequests = {};
  final Map<String, List<List<int>>> _packetBuffers = {};
  final _disconnectController = StreamController<Lw007DisconnectEvent>.broadcast();
  final _logNotifyController = StreamController<String>.broadcast();
  final _pirStatusController = StreamController<Lw007PirStatusUpdate>.broadcast();
  final _hallStatusController = StreamController<Lw007HallStatusUpdate>.broadcast();
  final _thStatusController = StreamController<Lw007ThStatusUpdate>.broadcast();
  var _logNotifySubscribed = false;
  var _pirNotifySubscribed = false;
  var _hallNotifySubscribed = false;
  var _thNotifySubscribed = false;
  StreamSubscription<BluetoothConnectionState>? _connectionStateSubscription;
  Future<void> _requestChain = Future<void>.value();

  Stream<Lw007DisconnectEvent> get disconnectEvents => _disconnectController.stream;

  Stream<String> get logNotifyEvents => _logNotifyController.stream;

  Stream<Lw007PirStatusUpdate> get pirStatusEvents => _pirStatusController.stream;

  Stream<Lw007HallStatusUpdate> get hallStatusEvents => _hallStatusController.stream;

  Stream<Lw007ThStatusUpdate> get thStatusEvents => _thStatusController.stream;

  bool get isLogNotifyEnabled => _logNotifySubscribed;

  bool get isPirNotifyEnabled => _pirNotifySubscribed;

  bool get isHallNotifyEnabled => _hallNotifySubscribed;

  bool get isThNotifyEnabled => _thNotifySubscribed;

  BluetoothDevice? get device => _device;
  bool get isConnected => _device?.isConnected ?? false;

  Future<void> connectWithRetry(BluetoothDevice device) async {
    _device = device;
    final deadline = DateTime.now().add(Lw007ProtocolConstants.connectTotalTimeout);
    Object? lastError;

    for (var attempt = 0; attempt < Lw007ProtocolConstants.connectMaxAttempts; attempt++) {
      final remaining = deadline.difference(DateTime.now());
      if (remaining <= Duration.zero) {
        throw TimeoutException(
          'Connection timed out after ${Lw007ProtocolConstants.connectTotalTimeout.inSeconds}s',
        );
      }

      try {
        if (device.isConnected) {
          await device.disconnect();
        }
        await device.connect(
          timeout: remaining,
          autoConnect: false,
        );
        if (Platform.isAndroid) {
          await device.requestMtu(247);
        }
        await _discoverServices(device);
        await _enableNotifications();
        await Future<void>.delayed(const Duration(milliseconds: 500));
        _listenConnectionState(device);
        return;
      } catch (error) {
        lastError = error;
        debugPrint('LW007 connect attempt ${attempt + 1} failed: $error');
        if (attempt < Lw007ProtocolConstants.connectMaxAttempts - 1) {
          await Future<void>.delayed(
            const Duration(milliseconds: Lw007ProtocolConstants.connectRetryDelayMs),
          );
        }
      }
    }

    throw lastError ?? Exception('Connection failed');
  }

  Future<void> disconnect() async {
    await disableLogNotify();
    await disablePirNotify();
    await disableHallNotify();
    await disableThNotify();
    await _clearSubscriptions();
    final device = _device;
    _device = null;
    if (device != null && device.isConnected) {
      await device.disconnect();
    }
  }

  Future<bool> verifyPassword(String password) async {
    final characteristic = _requireCharacteristic(_passwordChar, 'password');
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw007ProtocolCodec.buildPasswordFrame(password),
      key: Lw007ProtocolConstants.passwordCmd,
      matcher: Lw007ProtocolCodec.isPasswordSuccess,
    );
    return Lw007ProtocolCodec.isPasswordSuccess(response);
  }

  Future<Lw007ParamResult> readParam({
    required int key,
    Lw007ParamChannel channel = Lw007ParamChannel.params,
    bool packet = false,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw007ProtocolCodec.buildReadFrame(key: key, packet: packet),
      key: key,
    );
    final parsed = Lw007ProtocolCodec.parseReadResponse(response);
    if (parsed == null) {
      throw Lw007ProtocolException(
        'Invalid read response for 0x${key.toRadixString(16)}',
      );
    }
    return Lw007ParamResult(
      key: parsed.key,
      data: parsed.data,
      raw: response,
    );
  }

  Future<bool> writeParam({
    required int key,
    required List<int> data,
    Lw007ParamChannel channel = Lw007ParamChannel.params,
    bool packet = false,
    int packetCount = 1,
    int packetIndex = 0,
  }) async {
    final characteristic = _characteristicForChannel(channel);
    final response = await _sendFrame(
      characteristic: characteristic,
      payload: Lw007ProtocolCodec.buildWriteFrame(
        key: key,
        data: data,
        packet: packet,
        packetCount: packetCount,
        packetIndex: packetIndex,
      ),
      key: key,
      matcher: (value) => Lw007ProtocolCodec.isWriteAck(value, key),
    );
    return Lw007ProtocolCodec.isWriteSuccess(response, key);
  }

  Future<String> readDeviceInfoString(
    BluetoothCharacteristic characteristic, {
    required String name,
  }) async {
    final value = await characteristic.read();
    Lw007ProtocolLogger.logGattRead(name: name, value: value);
    return String.fromCharCodes(value.where((b) => b != 0)).trim();
  }

  Future<String> readModelNumber() => readDeviceInfoString(
        _requireCharacteristic(_modelNumberChar, 'model number'),
        name: 'modelNumber',
      );
  Future<String> readSerialNumber() => readDeviceInfoString(
        _requireCharacteristic(_serialNumberChar, 'serial number'),
        name: 'serialNumber',
      );
  Future<String> readFirmwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_firmwareRevisionChar, 'firmware revision'),
        name: 'firmwareRevision',
      );
  Future<String> readHardwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_hardwareRevisionChar, 'hardware revision'),
        name: 'hardwareRevision',
      );
  Future<String> readSoftwareRevision() => readDeviceInfoString(
        _requireCharacteristic(_softwareRevisionChar, 'software revision'),
        name: 'softwareRevision',
      );
  Future<String> readManufacturerName() => readDeviceInfoString(
        _requireCharacteristic(_manufacturerNameChar, 'manufacturer name'),
        name: 'manufacturerName',
      );

  Future<void> enableLogNotify() async {
    final characteristic = _logNotifyChar;
    if (characteristic == null) {
      throw Lw007ProtocolException('Log notify characteristic unavailable');
    }
    if (_logNotifySubscribed) {
      return;
    }
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions['log']?.cancel();
    _notifySubscriptions['log'] = characteristic.onValueReceived.listen(
      (value) => _handleNotification('log', value),
    );
    _logNotifySubscribed = true;
  }

  Future<void> disableLogNotify() async {
    final characteristic = _logNotifyChar;
    if (characteristic == null || !_logNotifySubscribed) {
      return;
    }
    await _notifySubscriptions['log']?.cancel();
    _notifySubscriptions.remove('log');
    await characteristic.setNotifyValue(false);
    _logNotifySubscribed = false;
  }

  Future<void> enablePirNotify() async {
    final characteristic = _pirChar;
    if (characteristic == null) {
      throw Lw007ProtocolException('PIR notify characteristic unavailable');
    }
    if (_pirNotifySubscribed) {
      return;
    }
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions['pir']?.cancel();
    _notifySubscriptions['pir'] = characteristic.onValueReceived.listen(
      (value) => _handleNotification('pir', value),
    );
    _pirNotifySubscribed = true;
  }

  Future<void> disablePirNotify() async {
    final characteristic = _pirChar;
    if (characteristic == null || !_pirNotifySubscribed) {
      return;
    }
    await _notifySubscriptions['pir']?.cancel();
    _notifySubscriptions.remove('pir');
    await characteristic.setNotifyValue(false);
    _pirNotifySubscribed = false;
  }

  Future<void> enableHallNotify() async {
    final characteristic = _hallChar;
    if (characteristic == null) {
      throw Lw007ProtocolException('Hall notify characteristic unavailable');
    }
    if (_hallNotifySubscribed) {
      return;
    }
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions['hall']?.cancel();
    _notifySubscriptions['hall'] = characteristic.onValueReceived.listen(
      (value) => _handleNotification('hall', value),
    );
    _hallNotifySubscribed = true;
  }

  Future<void> disableHallNotify() async {
    final characteristic = _hallChar;
    if (characteristic == null || !_hallNotifySubscribed) {
      return;
    }
    await _notifySubscriptions['hall']?.cancel();
    _notifySubscriptions.remove('hall');
    await characteristic.setNotifyValue(false);
    _hallNotifySubscribed = false;
  }

  Future<void> enableThNotify() async {
    final characteristic = _thChar;
    if (characteristic == null) {
      throw Lw007ProtocolException('T&H notify characteristic unavailable');
    }
    if (_thNotifySubscribed) {
      return;
    }
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions['th']?.cancel();
    _notifySubscriptions['th'] = characteristic.onValueReceived.listen(
      (value) => _handleNotification('th', value),
    );
    _thNotifySubscribed = true;
  }

  Future<void> disableThNotify() async {
    final characteristic = _thChar;
    if (characteristic == null || !_thNotifySubscribed) {
      return;
    }
    await _notifySubscriptions['th']?.cancel();
    _notifySubscriptions.remove('th');
    await characteristic.setNotifyValue(false);
    _thNotifySubscribed = false;
  }

  Future<void> _discoverServices(BluetoothDevice device) async {
    final services = await device.discoverServices();
    final deviceInfo = _findService(services, Lw007Uuids.deviceInfoService);
    final custom = _findService(services, Lw007Uuids.customService);

    if (deviceInfo == null) {
      throw Lw007ProtocolException('Device Information Service not found');
    }
    if (custom == null) {
      throw Lw007ProtocolException('Custom service 0xAA00 not found');
    }

    _modelNumberChar = _findCharacteristic(deviceInfo, Lw007Uuids.modelNumber);
    _serialNumberChar = _findCharacteristic(deviceInfo, Lw007Uuids.serialNumber);
    _firmwareRevisionChar = _findCharacteristic(deviceInfo, Lw007Uuids.firmwareRevision);
    _hardwareRevisionChar = _findCharacteristic(deviceInfo, Lw007Uuids.hardwareRevision);
    _softwareRevisionChar = _findCharacteristic(deviceInfo, Lw007Uuids.softwareRevision);
    _manufacturerNameChar = _findCharacteristic(deviceInfo, Lw007Uuids.manufacturerName);

    _passwordChar = _findCharacteristic(custom, Lw007Uuids.password);
    _disconnectChar = _findCharacteristic(custom, Lw007Uuids.disconnectNotify);
    _paramsChar = _findCharacteristic(custom, Lw007Uuids.params);
    _controlChar = _findCharacteristic(custom, Lw007Uuids.control);
    _logNotifyChar = _findCharacteristic(custom, Lw007Uuids.logNotify);
    _pirChar = _findCharacteristic(custom, Lw007Uuids.pirNotify);
    _hallChar = _findCharacteristic(custom, Lw007Uuids.hallNotify);
    _thChar = _findCharacteristic(custom, Lw007Uuids.thNotify);

    if (_passwordChar == null ||
        _paramsChar == null ||
        _controlChar == null ||
        _disconnectChar == null) {
      throw Lw007ProtocolException('Required custom characteristics not found');
    }
  }

  Future<void> _enableNotifications() async {
    await _subscribeCharacteristic(_passwordChar!, 'password');
    await _subscribeCharacteristic(_disconnectChar!, 'disconnect');
    await _subscribeCharacteristic(_paramsChar!, 'params');
    await _subscribeCharacteristic(_controlChar!, 'control');
  }

  Future<void> _subscribeCharacteristic(
    BluetoothCharacteristic characteristic,
    String channelKey,
  ) async {
    await characteristic.setNotifyValue(true);
    await _notifySubscriptions[channelKey]?.cancel();
    _notifySubscriptions[channelKey] = characteristic.onValueReceived.listen(
      (value) => _handleNotification(channelKey, value),
    );
  }

  void _handleNotification(String channelKey, List<int> value) {
    if (value.isEmpty) {
      return;
    }

    if (channelKey == 'disconnect') {
      Lw007ProtocolLogger.logDisconnectNotify(value);
      final event = Lw007DisconnectEvent.fromNotificationBytes(value);
      if (event != null) {
        _disconnectController.add(event);
      }
      return;
    }

    if (channelKey == 'log') {
      Lw007ProtocolLogger.logRx(channel: channelKey, payload: value);
      if (value.isNotEmpty) {
        _logNotifyController.add(String.fromCharCodes(value));
      }
      return;
    }

    if (channelKey == 'pir') {
      Lw007ProtocolLogger.logRx(channel: channelKey, payload: value);
      final update = Lw007PirStatusUpdate.fromNotificationBytes(value);
      if (update != null) {
        _pirStatusController.add(update);
      }
      return;
    }

    if (channelKey == 'hall') {
      Lw007ProtocolLogger.logRx(channel: channelKey, payload: value);
      final update = Lw007HallStatusUpdate.fromNotificationBytes(value);
      if (update != null) {
        _hallStatusController.add(update);
      }
      return;
    }

    if (channelKey == 'th') {
      Lw007ProtocolLogger.logRx(channel: channelKey, payload: value);
      final update = Lw007ThStatusUpdate.fromNotificationBytes(value);
      if (update != null) {
        _thStatusController.add(update);
      }
      return;
    }

    if (value[0] == Lw007ProtocolConstants.headPacket) {
      Lw007ProtocolLogger.logRx(channel: channelKey, payload: value, partialPacket: true);
      final requestKey = _requestKeyFromPacket(value);
      _packetBuffers.putIfAbsent(requestKey, () => []).add(value);
      final packets = _packetBuffers[requestKey]!;
      final expectedCount = value[3];
      if (packets.length >= expectedCount) {
        final merged = Lw007ProtocolCodec.reassemblePacketResponses(packets);
        _packetBuffers.remove(requestKey);
        Lw007ProtocolLogger.logRx(channel: channelKey, payload: merged);
        _completeRequest(requestKey, merged);
      }
      return;
    }

    Lw007ProtocolLogger.logRx(channel: channelKey, payload: value);
    final requestKey = _requestKeyFromFrame(value);
    _completeRequest(requestKey, value);
  }

  Future<List<int>> _sendFrame({
    required BluetoothCharacteristic characteristic,
    required List<int> payload,
    required int key,
    bool Function(List<int> value)? matcher,
  }) {
    return _enqueueRequest(() async {
      final requestKey = _requestKey(key);
      final completer = Completer<List<int>>();
      _pendingRequests[requestKey] = completer;

      try {
        Lw007ProtocolLogger.logTx(
          channel: _channelNameForCharacteristic(characteristic),
          key: key,
          payload: payload,
        );
        if (!isConnected) {
          throw Lw007ProtocolException('Device is not connected');
        }
        final withoutResponse = _shouldWriteWithoutResponse(characteristic);
        try {
          await characteristic.write(payload, withoutResponse: withoutResponse);
        } on FlutterBluePlusException catch (error) {
          throw Lw007ProtocolException(error.toString());
        }
        final response = await completer.future.timeout(
          Lw007ProtocolConstants.requestTimeout,
          onTimeout: () {
            Lw007ProtocolLogger.logError('Request timeout for $requestKey');
            throw Lw007ProtocolTimeoutException(requestKey);
          },
        );
        if (matcher != null && !matcher(response)) {
          Lw007ProtocolLogger.logError('Unexpected response for $requestKey');
          throw Lw007ProtocolException('Unexpected response for $requestKey');
        }
        return response;
      } finally {
        _pendingRequests.remove(requestKey);
        _packetBuffers.remove(requestKey);
      }
    });
  }

  Future<T> _enqueueRequest<T>(Future<T> Function() action) {
    final task = _requestChain.then((_) => action());
    _requestChain = task.then((_) {}, onError: (_) {});
    return task;
  }

  bool _shouldWriteWithoutResponse(BluetoothCharacteristic characteristic) {
    final properties = characteristic.properties;
    if (properties.write) {
      return false;
    }
    return properties.writeWithoutResponse;
  }

  void _completeRequest(String requestKey, List<int> value) {
    final completer = _pendingRequests[requestKey];
    if (completer != null && !completer.isCompleted) {
      completer.complete(value);
    }
  }

  BluetoothCharacteristic _characteristicForChannel(Lw007ParamChannel channel) {
    switch (channel) {
      case Lw007ParamChannel.params:
        return _requireCharacteristic(_paramsChar, 'params');
      case Lw007ParamChannel.control:
        return _requireCharacteristic(_controlChar, 'control');
    }
  }

  BluetoothService? _findService(List<BluetoothService> services, String uuid) {
    final target = Guid(uuid);
    for (final service in services) {
      if (service.uuid == target) {
        return service;
      }
    }
    return null;
  }

  BluetoothCharacteristic? _findCharacteristic(
    BluetoothService service,
    String uuid,
  ) {
    final target = Guid(uuid);
    for (final characteristic in service.characteristics) {
      if (characteristic.uuid == target) {
        return characteristic;
      }
    }
    return null;
  }

  BluetoothCharacteristic _requireCharacteristic(
    BluetoothCharacteristic? characteristic,
    String name,
  ) {
    if (characteristic == null) {
      throw Lw007ProtocolException('$name characteristic unavailable');
    }
    return characteristic;
  }

  String _channelNameForCharacteristic(BluetoothCharacteristic characteristic) {
    if (identical(characteristic, _passwordChar)) return 'password';
    if (identical(characteristic, _paramsChar)) return 'params';
    if (identical(characteristic, _controlChar)) return 'control';
    if (identical(characteristic, _logNotifyChar)) return 'log';
    return characteristic.uuid.toString();
  }

  String _requestKey(int key) => key.toRadixString(16);

  String _requestKeyFromFrame(List<int> value) {
    if (value.length < 3) {
      return 'unknown';
    }
    return _requestKey(value[2] & 0xFF);
  }

  String _requestKeyFromPacket(List<int> value) {
    if (value.length < 3) {
      return 'unknown';
    }
    return _requestKey(value[2] & 0xFF);
  }

  void _listenConnectionState(BluetoothDevice device) {
    _connectionStateSubscription?.cancel();
    _connectionStateSubscription = device.connectionState.listen((state) {
      if (state == BluetoothConnectionState.disconnected) {
        _disconnectController.add(Lw007DisconnectEvent.generic);
      }
    });
  }

  Future<void> _clearSubscriptions() async {
    await _connectionStateSubscription?.cancel();
    _connectionStateSubscription = null;
    for (final subscription in _notifySubscriptions.values) {
      await subscription.cancel();
    }
    _notifySubscriptions.clear();
    for (final completer in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(
          Lw007ProtocolException('Connection closed'),
        );
      }
    }
    _pendingRequests.clear();
    _packetBuffers.clear();
  }
}

enum Lw007ParamChannel {
  params,
  control,
}

class Lw007ParamResult {
  const Lw007ParamResult({
    required this.key,
    required this.data,
    required this.raw,
  });

  final int key;
  final List<int> data;
  final List<int> raw;
}

class Lw007ProtocolException implements Exception {
  Lw007ProtocolException(this.message);

  final String message;

  @override
  String toString() => 'Lw007ProtocolException: $message';
}

bool isLw007ConnectionError(Object error) {
  if (error is Lw007ProtocolException) {
    final message = error.message.toLowerCase();
    return message.contains('not connected') ||
        message.contains('connection closed') ||
        message.contains('disconnected');
  }
  final message = error.toString().toLowerCase();
  return message.contains('device is not connected') ||
      message.contains('fbp-code: 6') ||
      message.contains('connection closed') ||
      message.contains('disconnected');
}

class Lw007ProtocolTimeoutException extends TimeoutException {
  Lw007ProtocolTimeoutException(String requestKey)
      : super(requestKey, Lw007ProtocolConstants.requestTimeout);

  static const userMessage = 'Failed';
}
