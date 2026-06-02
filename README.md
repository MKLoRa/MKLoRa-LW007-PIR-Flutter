# MKLoRa LW007 PIR Flutter

Flutter client for **LW007-PIR** devices. Supports BLE scanning, connection, LoRa configuration, PIR/Hall/T&H settings, BLE advertising settings, battery consumption, system info, and Nordic DFU firmware updates on Android and iOS.

Native Android reference: `LW007_Android`

Protocol document: `LW007协议文档_V1.2.1`

## Scan

Scan filters Service Data UUID `0000aa05-0000-1000-8000-00805f9b34fb` and parses manufacturer response data (AD type 0xFF, 14 bytes). Device MAC is taken from response packet bytes 8–13 for iOS/Android compatibility.

## Package

- Dart package: `lw007_pir_flutter`
- Android applicationId: `com.moko.ft.lw007`
- App name: `LW007PIR_Flutter`
