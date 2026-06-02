import 'lw007_ble_client.dart';
import 'lw007_param_key.dart';
import 'lw007_protocol_api.dart';

extension Lw007ProtocolNamedReadApi on Lw007ProtocolApi {
  Future<Lw007ParamResult> readLoraRegion() => readParam(Lw007ParamKey.loraRegion);
  Future<Lw007ParamResult> readLoraMode() => readParam(Lw007ParamKey.loraMode);
  Future<Lw007ParamResult> readLoraDevEui() => readParam(Lw007ParamKey.loraDevEui);
  Future<Lw007ParamResult> readLoraAppEui() => readParam(Lw007ParamKey.loraAppEui);
  Future<Lw007ParamResult> readLoraAppKey() => readParam(Lw007ParamKey.loraAppKey);
  Future<Lw007ParamResult> readLoraDevAddr() => readParam(Lw007ParamKey.loraDevAddr);
  Future<Lw007ParamResult> readLoraAppSkey() => readParam(Lw007ParamKey.loraAppSkey);
  Future<Lw007ParamResult> readLoraNwkSkey() => readParam(Lw007ParamKey.loraNwkSkey);
  Future<Lw007ParamResult> readLoraMessageType() => readParam(Lw007ParamKey.loraMessageType);
  Future<Lw007ParamResult> readLoraMaxRetransmissionTimes() =>
      readParam(Lw007ParamKey.loraMaxRetransmissionTimes);
  Future<Lw007ParamResult> readLoraCh() => readParam(Lw007ParamKey.loraCh);
  Future<Lw007ParamResult> readLoraDr() => readParam(Lw007ParamKey.loraDr);
  Future<Lw007ParamResult> readLoraUplinkStrategy() => readParam(Lw007ParamKey.loraUplinkStrategy);
  Future<Lw007ParamResult> readLoraDutycycle() => readParam(Lw007ParamKey.loraDutycycle);
  Future<Lw007ParamResult> readLoraTimeSyncInterval() => readParam(Lw007ParamKey.loraTimeSyncInterval);
  Future<Lw007ParamResult> readLoraNetworkCheckInterval() =>
      readParam(Lw007ParamKey.loraNetworkCheckInterval);
  Future<Lw007ParamResult> readLoraSingleChannelFunction() =>
      readParam(Lw007ParamKey.loraSingleChannelFunction);
  Future<Lw007ParamResult> readLoraSingleChannelSelection() =>
      readParam(Lw007ParamKey.loraSingleChannelSelection);
  Future<Lw007ParamResult> readLoraNetworkStatus() => readParam(Lw007ParamKey.networkStatus);

  Future<Lw007ParamResult> readBleEnable() => readParam(Lw007ParamKey.bleEnable);
  Future<Lw007ParamResult> readBleAdvInterval() => readParam(Lw007ParamKey.bleAdvInterval);
  Future<Lw007ParamResult> readBleConnectable() => readParam(Lw007ParamKey.bleConnectable);
  Future<Lw007ParamResult> readBleTimeoutDuration() => readParam(Lw007ParamKey.bleTimeoutDuration);
  Future<Lw007ParamResult> readBleLoginMode() => readParam(Lw007ParamKey.bleLoginMode);
  Future<Lw007ParamResult> readBleTxPower() => readParam(Lw007ParamKey.bleTxPower);
  Future<Lw007ParamResult> readBleAdvName() => readParam(Lw007ParamKey.bleAdvName);

  Future<Lw007ParamResult> readPirEnable() => readParam(Lw007ParamKey.pirEnable);
  Future<Lw007ParamResult> readPirReportInterval() => readParam(Lw007ParamKey.pirReportInterval);
  Future<Lw007ParamResult> readPirSensitivity() => readParam(Lw007ParamKey.pirSensitivity);
  Future<Lw007ParamResult> readPirDelayTime() => readParam(Lw007ParamKey.pirDelayTime);
  Future<Lw007ParamResult> readPir() => readParam(Lw007ParamKey.pir);
  Future<Lw007ParamResult> readHallStatusEnable() => readParam(Lw007ParamKey.hallStatusEnable);
  Future<Lw007ParamResult> readHallStatusSum() => readParam(Lw007ParamKey.hallStatusSum);
  Future<Lw007ParamResult> readThEnable() => readParam(Lw007ParamKey.thEnable);
  Future<Lw007ParamResult> readThSampleRate() => readParam(Lw007ParamKey.thSampleRate);
  Future<Lw007ParamResult> readThData() => readParam(Lw007ParamKey.thData);
  Future<Lw007ParamResult> readTempThresholdAlarmEnable() =>
      readParam(Lw007ParamKey.tempThresholdAlarmEnable);
  Future<Lw007ParamResult> readTempThresholdAlarm() => readParam(Lw007ParamKey.tempThresholdAlarm);
  Future<Lw007ParamResult> readTempChangeAlarmEnable() => readParam(Lw007ParamKey.tempChangeAlarmEnable);
  Future<Lw007ParamResult> readTempChangeAlarmDuration() =>
      readParam(Lw007ParamKey.tempChangeAlarmDuration);
  Future<Lw007ParamResult> readTempChangeAlarmValue() => readParam(Lw007ParamKey.tempChangeAlarmValue);
  Future<Lw007ParamResult> readHumidityThresholdAlarmEnable() =>
      readParam(Lw007ParamKey.humidityThresholdAlarmEnable);
  Future<Lw007ParamResult> readHumidityThresholdAlarm() =>
      readParam(Lw007ParamKey.humidityThresholdAlarm);
  Future<Lw007ParamResult> readHumidityChangeAlarmEnable() =>
      readParam(Lw007ParamKey.humidityChangeAlarmEnable);
  Future<Lw007ParamResult> readHumidityChangeAlarmDuration() =>
      readParam(Lw007ParamKey.humidityChangeAlarmDuration);
  Future<Lw007ParamResult> readHumidityChangeAlarmValue() =>
      readParam(Lw007ParamKey.humidityChangeAlarmValue);

  Future<Lw007ParamResult> readTimeZone() => readParam(Lw007ParamKey.timeZone);
  Future<Lw007ParamResult> readHeartbeatInterval() => readParam(Lw007ParamKey.heartbeat);
  Future<Lw007ParamResult> readLowPowerPayloadEnable() => readParam(Lw007ParamKey.lowPowerPayload);
  Future<Lw007ParamResult> readIndicatorStatus() => readParam(Lw007ParamKey.ledIndicatorStatus);
  Future<Lw007ParamResult> readCondition1VoltageThreshold() =>
      readParam(Lw007ParamKey.condition1VoltageThreshold);
  Future<Lw007ParamResult> readCondition1MinSampleInterval() =>
      readParam(Lw007ParamKey.condition1MinSampleInterval);
  Future<Lw007ParamResult> readCondition1SampleTimes() =>
      readParam(Lw007ParamKey.condition1SampleTimes);

  Future<Lw007ParamResult> readChipMac() => readParam(Lw007ParamKey.mac);
  Future<Lw007ParamResult> readBatteryPower() => readParam(Lw007ParamKey.battery);
  Future<Lw007ParamResult> readPcbaStatus() => readParam(Lw007ParamKey.pcbaStatus);
  Future<Lw007ParamResult> readSelftestStatus() => readParam(Lw007ParamKey.selftestStatus);
  Future<Lw007ParamResult> readBatteryInfo() => readParam(Lw007ParamKey.batteryInfo);
  Future<Lw007ParamResult> readBatteryInfoLast() => readParam(Lw007ParamKey.batteryInfoLast);
  Future<Lw007ParamResult> readBatteryInfoAll() => readParam(Lw007ParamKey.batteryInfoAll);
  Future<Lw007ParamResult> readBatteryInfoNew() => readBatteryInfo();

  Future<Lw007ParamResult> readAdvName() => readBleAdvName();
  Future<Lw007ParamResult> readAdvTxPower() => readBleTxPower();
  Future<Lw007ParamResult> readAdvTimeout() => readBleTimeoutDuration();
  Future<Lw007ParamResult> readPasswordVerifyEnable() => readBleLoginMode();
}

extension Lw007ProtocolNamedWriteApi on Lw007ProtocolApi {
  Future<bool> writeLoraRegion(List<int> data) => writeParam(Lw007ParamKey.loraRegion, data);
  Future<bool> writeLoraMode(List<int> data) => writeParam(Lw007ParamKey.loraMode, data);
  Future<bool> writeLoraDevEui(List<int> data) => writeParam(Lw007ParamKey.loraDevEui, data);
  Future<bool> writeLoraAppEui(List<int> data) => writeParam(Lw007ParamKey.loraAppEui, data);
  Future<bool> writeLoraAppKey(List<int> data) => writeParam(Lw007ParamKey.loraAppKey, data);
  Future<bool> writeLoraDevAddr(List<int> data) => writeParam(Lw007ParamKey.loraDevAddr, data);
  Future<bool> writeLoraAppSkey(List<int> data) => writeParam(Lw007ParamKey.loraAppSkey, data);
  Future<bool> writeLoraNwkSkey(List<int> data) => writeParam(Lw007ParamKey.loraNwkSkey, data);
  Future<bool> writeLoraMessageType(List<int> data) =>
      writeParam(Lw007ParamKey.loraMessageType, data);
  Future<bool> writeLoraMaxRetransmissionTimes(List<int> data) =>
      writeParam(Lw007ParamKey.loraMaxRetransmissionTimes, data);
  Future<bool> writeLoraCh(List<int> data) => writeParam(Lw007ParamKey.loraCh, data);
  Future<bool> writeLoraDr(List<int> data) => writeParam(Lw007ParamKey.loraDr, data);
  Future<bool> writeLoraUplinkStrategy(List<int> data) =>
      writeParam(Lw007ParamKey.loraUplinkStrategy, data);
  Future<bool> writeLoraDutycycle(List<int> data) => writeParam(Lw007ParamKey.loraDutycycle, data);
  Future<bool> writeLoraTimeSyncInterval(List<int> data) =>
      writeParam(Lw007ParamKey.loraTimeSyncInterval, data);
  Future<bool> writeLoraNetworkCheckInterval(List<int> data) =>
      writeParam(Lw007ParamKey.loraNetworkCheckInterval, data);
  Future<bool> writeLoraSingleChannelFunction(List<int> data) =>
      writeParam(Lw007ParamKey.loraSingleChannelFunction, data);
  Future<bool> writeLoraSingleChannelSelection(List<int> data) =>
      writeParam(Lw007ParamKey.loraSingleChannelSelection, data);

  Future<bool> writeBleEnable(List<int> data) => writeParam(Lw007ParamKey.bleEnable, data);
  Future<bool> writeBleAdvInterval(List<int> data) => writeParam(Lw007ParamKey.bleAdvInterval, data);
  Future<bool> writeBleConnectable(List<int> data) => writeParam(Lw007ParamKey.bleConnectable, data);
  Future<bool> writeBleTimeoutDuration(List<int> data) =>
      writeParam(Lw007ParamKey.bleTimeoutDuration, data);
  Future<bool> writeBleLoginMode(List<int> data) => writeParam(Lw007ParamKey.bleLoginMode, data);
  Future<bool> writeBleTxPower(List<int> data) => writeParam(Lw007ParamKey.bleTxPower, data);
  Future<bool> writeBleAdvName(List<int> data) => writeParam(Lw007ParamKey.bleAdvName, data);

  Future<bool> writePirEnable(List<int> data) => writeParam(Lw007ParamKey.pirEnable, data);
  Future<bool> writePirReportInterval(List<int> data) =>
      writeParam(Lw007ParamKey.pirReportInterval, data);
  Future<bool> writePirSensitivity(List<int> data) => writeParam(Lw007ParamKey.pirSensitivity, data);
  Future<bool> writePirDelayTime(List<int> data) => writeParam(Lw007ParamKey.pirDelayTime, data);
  Future<bool> writeHallStatusEnable(List<int> data) =>
      writeParam(Lw007ParamKey.hallStatusEnable, data);
  Future<bool> writeThEnable(List<int> data) => writeParam(Lw007ParamKey.thEnable, data);
  Future<bool> writeThSampleRate(List<int> data) => writeParam(Lw007ParamKey.thSampleRate, data);
  Future<bool> writeTempThresholdAlarmEnable(List<int> data) =>
      writeParam(Lw007ParamKey.tempThresholdAlarmEnable, data);
  Future<bool> writeTempThresholdAlarm(List<int> data) =>
      writeParam(Lw007ParamKey.tempThresholdAlarm, data);
  Future<bool> writeTempChangeAlarmEnable(List<int> data) =>
      writeParam(Lw007ParamKey.tempChangeAlarmEnable, data);
  Future<bool> writeTempChangeAlarmDuration(List<int> data) =>
      writeParam(Lw007ParamKey.tempChangeAlarmDuration, data);
  Future<bool> writeTempChangeAlarmValue(List<int> data) =>
      writeParam(Lw007ParamKey.tempChangeAlarmValue, data);
  Future<bool> writeHumidityThresholdAlarmEnable(List<int> data) =>
      writeParam(Lw007ParamKey.humidityThresholdAlarmEnable, data);
  Future<bool> writeHumidityThresholdAlarm(List<int> data) =>
      writeParam(Lw007ParamKey.humidityThresholdAlarm, data);
  Future<bool> writeHumidityChangeAlarmEnable(List<int> data) =>
      writeParam(Lw007ParamKey.humidityChangeAlarmEnable, data);
  Future<bool> writeHumidityChangeAlarmDuration(List<int> data) =>
      writeParam(Lw007ParamKey.humidityChangeAlarmDuration, data);
  Future<bool> writeHumidityChangeAlarmValue(List<int> data) =>
      writeParam(Lw007ParamKey.humidityChangeAlarmValue, data);

  Future<bool> writeTimeZone(List<int> data) => writeParam(Lw007ParamKey.timeZone, data);
  Future<bool> writeHeartbeatInterval(List<int> data) => writeParam(Lw007ParamKey.heartbeat, data);
  Future<bool> writeLowPowerPayloadEnable(List<int> data) =>
      writeParam(Lw007ParamKey.lowPowerPayload, data);
  Future<bool> writeIndicatorStatus(List<int> data) =>
      writeParam(Lw007ParamKey.ledIndicatorStatus, data);
  Future<bool> writeCondition1VoltageThreshold(List<int> data) =>
      writeParam(Lw007ParamKey.condition1VoltageThreshold, data);
  Future<bool> writeCondition1MinSampleInterval(List<int> data) =>
      writeParam(Lw007ParamKey.condition1MinSampleInterval, data);
  Future<bool> writeCondition1SampleTimes(List<int> data) =>
      writeParam(Lw007ParamKey.condition1SampleTimes, data);
  Future<bool> writePcbaStatus(List<int> data) => writeParam(Lw007ParamKey.pcbaStatus, data);

  Future<bool> writeRestoreEmpty() => writeParam(Lw007ParamKey.restore, const []);
  Future<bool> writeResetEmpty() => writeRestoreEmpty();
  Future<bool> writeRestartEmpty() => writeParam(Lw007ParamKey.restart, const []);
  Future<bool> writeRebootEmpty() => writeRestartEmpty();
  Future<bool> writePowerOffEmpty() => writeParam(Lw007ParamKey.powerOff, const []);
  Future<bool> writeCloseEmpty() => writePowerOffEmpty();
  Future<bool> writeBatteryResetEmpty() => writeParam(Lw007ParamKey.batteryReset, const []);
  Future<bool> writeBatteryResetNewEmpty() => writeBatteryResetEmpty();

  Future<bool> writeAdvName(List<int> data) => writeBleAdvName(data);
  Future<bool> writeAdvTxPower(List<int> data) => writeBleTxPower(data);
  Future<bool> writeAdvTimeout(List<int> data) => writeBleTimeoutDuration(data);
  Future<bool> writePasswordVerifyEnable(List<int> data) => writeBleLoginMode(data);
  Future<bool> changePassword(List<int> data) => writeParam(Lw007ParamKey.changePassword, data);
}
