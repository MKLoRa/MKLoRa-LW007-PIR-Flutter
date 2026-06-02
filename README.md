# MKLoRa LW007 PIR Flutter

Flutter client for **LW007-PIR** devices. Supports BLE scanning, connection, protocol parameter read/write, device-initiated disconnect notifications, LoRa configuration, PIR / Hall / T&H settings, BLE advertising settings, battery consumption (deviceType 1), debug log export, and Nordic DFU firmware updates on Android and iOS physical devices.

Native Android reference: `LW007_Android`

---

## Requirements

- Flutter SDK `^3.12.0`
- Android / iOS **physical device** (simulators do not support BLE)
- iOS: grant Bluetooth permission on first launch; run `pod install` in `ios/` when using CocoaPods

---

## Quick Start

```bash
flutter pub get
flutter run
```

The app opens on the scan page. Tap **CONNECT** on a device to connect and open the detail page.

---

## Project Structure

```
lib/
├── ble/                         # BLE connection and LW007 protocol layer
│   ├── lw007_ble_client.dart          # Connect, read/write frames, Notify handling
│   ├── lw007_protocol_api.dart        # Generic readParam / writeParam
│   ├── lw007_protocol_named_api.dart  # Named helpers (readPirEnable, writeAdvName, …)
│   ├── lw007_param_key.dart           # Parameter keys (ParamsKeyEnum / ControlKeyEnum mirror)
│   ├── lw007_param_helpers.dart       # Byte helpers + syncTime()
│   ├── lw007_data_codec.dart          # PIR/Hall/TH/indicator/battery encode-decode
│   ├── lw007_device_session.dart      # Session wrapper (connection + API entry)
│   ├── lw007_pir_status_event.dart    # PIR notify parse
│   ├── lw007_hall_status_event.dart   # Hall notify parse
│   ├── lw007_th_status_event.dart     # T&H notify parse
│   ├── lw007_disconnect_event.dart    # Disconnect notify parse
│   ├── lw007_debug_log_file.dart      # Debug log file persistence
│   ├── lw007_export_data_store.dart   # In-memory export cache (reserved)
│   ├── lw007_tracked_file.dart        # tracked.txt helper (reserved)
│   └── lw007_constants.dart           # GATT UUIDs and protocol constants
├── dfu/                         # Nordic DFU upgrade
├── models/                      # Scan result models (BleDeviceInfo)
├── viewmodels/                  # Scan page ViewModel
└── ui/                          # Pages and widgets
    └── pages/
        ├── ble_scan_page.dart
        ├── device_detail_page.dart
        └── device_detail/       # LoRa / General / BLE / Device tabs & sub-pages
packages/
└── nordic_dfu/                  # Local fork with Android disableMtuRequest support
```

---

## 1. Scanning for Devices

Scanning is handled by `BleScanViewModel` via `flutter_blue_plus`, filtering LW007 advertisements by Service Data UUID `0000aa05-0000-1000-8000-00805f9b34fb`.

Manufacturer data (AD type 0xFF, 14 bytes) and Service Data are both required. Parsed fields (aligned with native `BeaconInfoParseableImpl` / `BleDeviceInfo`):

| Field | Source |
|-------|--------|
| `deviceType` | Service Data byte 0 |
| `lowPower` | Bit 6 of manufacturer byte 0 |
| `passwordEnabled` | Manufacturer byte 13 (`1` = required) |
| `temperature` / `humidity` | Manufacturer bytes 1–4 (when not `0xFFFF`) |
| `showTempHumidity` | Valid T&H values present in advertisement |
| `txPowerLevel` | Manufacturer byte 6 |
| `macAddress` | Manufacturer bytes 8–13 (used for display and Android DFU) |
| `scanIntervalMs` | Derived from successive advertisement timestamps |

### Usage

```dart
final vm = BleScanViewModel();
await vm.init(context);
await vm.startScan(context: context, clearDevices: true);
vm.stopScan();

final devices = vm.filteredDevices;   // Sorted by RSSI
await vm.applyFilter(context: context, keyword: 'LW007', rssiDbm: -80);
```

### Scan Result Model

```dart
for (final device in vm.filteredDevices) {
  print(device.name);
  print(device.advMacAddress);
  print('${device.rssi} dBm');
  print(device.scanIntervalLabel);    // "<->N/A" or "<->1234ms"
  print(device.passwordEnabled);
  print(device.deviceType);           // 0 = LW007 PIR, 1 = extended variant
  if (device.showTempHumidity) {
    print('${device.temperature}°C / ${device.humidity}%');
  }
}
```

---

## 2. Connecting to a Device

Scanning stops before connecting. A GATT connection is established and the password is verified when required. Returns a `Lw007DeviceSession`.

```dart
import 'package:lw007_pir_flutter/ble/lw007.dart';

final device = vm.filteredDevices.first;

final session = await vm.connectDevice(
  context: context,
  device: device,
  password: device.passwordEnabled ? '123456' : null,
);

// Or use the lower-level API directly
final session = await Lw007DeviceSession.connect(
  deviceInfo: device,
  password: '123456',
);
```

After a successful connection:

| Member | Description |
|--------|-------------|
| `session.protocol` | Parameter read/write API |
| `session.deviceInfoApi` | Standard Device Information characteristics |
| `session.client.disconnectEvents` | Device-initiated disconnect notifications (AA01) |
| `session.client.pirStatusEvents` | PIR status notify stream (AA02) |
| `session.client.hallStatusEvents` | Hall status notify stream (AA03) |
| `session.client.thStatusEvents` | T&H status notify stream (AA04) |
| `session.client.logNotifyEvents` | Debug log notify stream (AA07) |

Connection details (`Lw007BleClient.connectWithRetry`):

- Up to 5 retries, 50 s total timeout
- Android requests MTU 247; iOS negotiates MTU automatically
- Waits 500 ms after connect before sending protocol frames

Entering the detail page automatically calls `protocol.syncTime()` (UTC epoch seconds, control key `0x53`).

---

## 3. Reading and Writing Protocol Parameters

Frame format: `ED [flag] [cmd] [len] [data…]`

- `flag=0x00` read, `flag=0x01` write, `flag=0x02` notify
- Params channel (AA05): keys `< 0x50`
- Control channel (AA06): keys `>= 0x50`
- Multi-packet responses use head `0xEE` and are reassembled automatically

Parameter keys are defined in `lib/ble/lw007_param_key.dart` (mirror of native `ParamsKeyEnum` / `ControlKeyEnum`).

### 3.1 Named API (Recommended)

`Lw007ProtocolNamedReadApi` / `Lw007ProtocolNamedWriteApi` extensions on `Lw007ProtocolApi`:

```dart
final api = session.protocol;

// Read LoRa mode (ABP=1, OTAA=2)
final mode = await api.readLoraMode();
print(Lw007ParamHelpers.uint8(mode.data));

// Read PIR enable
final pirEnable = await api.readPirEnable();

// Read advertisement name
final advName = await api.readBleAdvName();
print(Lw007ParamHelpers.bytesToString(advName.data));

// Write time zone (picker index → device byte)
final ok = await api.writeTimeZone(Lw007ParamHelpers.timeZoneBytesFromIndex(32));

// Write LoRa OTAA mode
await api.writeLoraMode([2]);

// Sync UTC time (also called on detail page entry)
final synced = await api.syncTime();

// Trigger reboot
await api.writeRebootEmpty();
```

Integer payloads use **big-endian** byte order (`Lw007ParamHelpers.int32Bytes`, `uint16Bytes`, `bytesToInt`), matching native `MokoUtils.toInt` / `toByteArray`.

Some LW007 fields are **1 byte** on the wire (e.g. PIR report interval, T&H sample rate); use `uint8` / single-byte writes where the protocol specifies it.

### 3.2 Generic API

```dart
final result = await api.readParam(Lw007ParamKey.bleTxPower);
final txPower = Lw007ParamHelpers.byte0(result.data);

await api.writeParam(
  Lw007ParamKey.heartbeat,
  Lw007ParamHelpers.int32Bytes(300),
);
```

### 3.3 GATT Device Information

```dart
final info = session.deviceInfoApi;
final model = await info.readModelNumber();
final firmware = await info.readFirmwareRevision();
final serial = await info.readSerialNumber();
```

### 3.4 Return Values

| Type | Field | Description |
|------|-------|-------------|
| `Lw007ParamResult` | `data` | Parsed payload bytes |
| | `raw` | Full frame returned by the device |
| | `key` | Parameter command byte |
| `writeParam` | returns `bool` | `true` when write ACK byte is `0x01` |

Common parsing helpers: `Lw007ParamHelpers.uint8`, `uint16`, `int32`, `bytesToInt`, `bytesToString`, `formatMac`, etc.

---

## 4. Receiving Data (Notify)

Device responses and push data are delivered via BLE Notify. `Lw007BleClient` matches incoming frames to pending requests and completes the corresponding `Future`.

### 4.1 Protocol Responses (AA05 params / AA06 control)

Each `readParam` / `writeParam` call:

1. Writes a request frame to the params or control characteristic
2. Waits for a Notify response with the same key
3. Reassembles multi-packet responses when `head=0xEE`

You do not need to subscribe to the params/control characteristics manually.

### 4.2 Disconnect Notifications (AA01)

```dart
session.client.disconnectEvents.listen((event) {
  print('type=${event.type}');
  print(event.message);
  // 1=password timeout  2=password changed  3=3-min idle
  // 4=reboot  5=factory reset
});
```

Example raw notify frame: `ED 02 01 01 04` → type 4, device rebooted.

The detail page handles this globally: a dialog is shown and the user is returned to the scan page.

### 4.3 PIR / Hall / T&H Status (AA02 / AA03 / AA04)

Settings sub-pages enable the corresponding notify on entry and disable on leave:

```dart
// PIR Settings page
await session.client.enablePirNotify(true);
session.client.pirStatusEvents.listen((event) {
  print('pirStatus=${event.pirStatus}');
});

// Hall Settings page
await session.client.enableHallNotify(true);
session.client.hallStatusEvents.listen((event) {
  print('doorStatus=${event.doorStatus} triggerTimes=${event.triggerTimes}');
});

// T&H Settings page
await session.client.enableThNotify(true);
session.client.thStatusEvents.listen((event) {
  print('temp=${event.temperature} humidity=${event.humidity}');
});
```

### 4.4 Debug Log (AA07)

**Device tab → Device Information → Debugger Mode** subscribes to `logNotifyEvents` and saves output under the app documents directory.

---

## 5. Disconnecting

### Manual Disconnect

```dart
await session.disconnect();
await vm.disconnectDevice();
await vm.onReturnedFromDetail(context);   // Disconnect + clear list and rescan
```

### Unexpected Disconnect

When the device sends a disconnect Notify or the BLE link drops, `disconnectEvents` emits an event. The detail page shows a dialog, calls `session.disconnect()`, and returns to the scan page.

Disconnect events are ignored during DFU to avoid false dialogs.

---

## 6. DFU Firmware Update

UI entry: **Device tab → Device Information → DFU**

Flow (`Lw007DfuService` + local `packages/nordic_dfu`):

1. User selects a `.zip` firmware package
2. Chip MAC is saved; current GATT connection is closed
3. DFU progress dialog is shown
4. Nordic DFU starts (Android uses chip MAC; iOS uses CoreBluetooth peripheral UUID)
5. Success: *Update firmware successfully! Please reconnect the device.* → return to scan page
6. Failure: error shown via SnackBar

```dart
import 'package:lw007_pir_flutter/dfu/lw007_dfu_coordinator.dart';
import 'package:lw007_pir_flutter/dfu/lw007_dfu_service.dart';

Lw007DfuCoordinator.begin(mac: chipMac);
await session.disconnect();

await Lw007DfuService.start(
  address: dfuAddress,
  filePath: '/path/to/firmware.zip',
  deviceType: device.deviceType,
  onStatus: (status) => print(status),
  onProgress: (percent) => print('$percent%'),
);

Lw007DfuCoordinator.end();
```

Notes:

- Firmware package must be a **ZIP** file
- Do not rely on the original GATT session during DFU; the device reboots when done
- **Android only** — MTU behaviour follows native `SystemInfoActivity` by `deviceType`:
  - `deviceType == 0`: `disableMtuRequest()` (LW007 PIR)
  - `deviceType == 1`: `setCurrentMtu(247)`
- iOS does not apply Android MTU settings
- Swift Package Manager is disabled in `pubspec.yaml` (`enable-swift-package-manager: false`) to use the CocoaPods NordicDFU build on iOS

---

## 7. Debug Protocol Logging

In debug builds, the console prints all TX/RX frames:

```
[LW007 TX] params | READ loraMode (0x02) | frame=ED 00 02 00
[LW007 RX] params | loraMode (0x02) | frame=ED 00 02 01 02 | data=02
```

Disable logging:

```dart
Lw007ProtocolLogger.enabled = false;
```

---

## 8. Permissions

| Platform | Permissions |
|----------|-------------|
| Android | `BLUETOOTH_SCAN`, `BLUETOOTH_CONNECT`, location (required for scanning) |
| iOS | `NSBluetoothAlwaysUsageDescription` (configured in `Info.plist`) |

---

## 9. Typical Flow

```
Scan page
  └─ startScan → device list (Service Data AA05 + manufacturer 0xFF)
  └─ connectDevice → Lw007DeviceSession
       └─ Detail page (LoRa / General / BLE / Device tabs)
            ├─ syncTime() on entry → "Time sync completed!"
            ├─ protocol.readXxx / writeXxx
            ├─ pirStatusEvents / hallStatusEvents / thStatusEvents → settings sub-pages
            ├─ disconnectEvents → dialog → back to scan page
            └─ DFU → pick zip → upgrade → back to scan page
```

---

## Repository

- GitHub: [MKLoRa/MKLoRa-LW007-Flutter](https://github.com/MKLoRa/MKLoRa-LW007-Flutter)
