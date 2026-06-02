class Lw007ThStatusUpdate {
  const Lw007ThStatusUpdate({
    required this.visible,
    this.temperature,
    this.humidity,
  });

  final bool visible;
  final double? temperature;
  final double? humidity;

  static Lw007ThStatusUpdate? fromNotificationBytes(List<int> value) {
    if (value.length < 8) {
      return null;
    }
    final header = value[0];
    final flag = value[1];
    final cmd = value[2] & 0xFF;
    final length = value[3];
    if (header != 0xED || flag != 0x02 || cmd != 0x01 || length != 0x04) {
      return null;
    }
    return fromPayload(value.sublist(4, 8));
  }

  static Lw007ThStatusUpdate? fromPayload(List<int> data) {
    if (data.length < 4) {
      return null;
    }
    final tempRaw = (data[0] << 8) | data[1];
    final humRaw = (data[2] << 8) | data[3];
    if (tempRaw == 0xFFFF && humRaw == 0xFFFF) {
      return const Lw007ThStatusUpdate(visible: false);
    }
    return Lw007ThStatusUpdate(
      visible: true,
      temperature: tempRaw * 0.1 - 30,
      humidity: humRaw * 0.1,
    );
  }

  String get temperatureLabel => '${temperature!.toStringAsFixed(1)} ℃';

  String get humidityLabel => '${humidity!.toStringAsFixed(1)}%RH';
}
