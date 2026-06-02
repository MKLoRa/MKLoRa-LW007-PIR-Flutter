class Lw007HallStatusUpdate {
  const Lw007HallStatusUpdate({
    required this.visible,
    required this.isOpen,
    required this.triggerTimes,
  });

  final bool visible;
  final bool isOpen;
  final int triggerTimes;

  static Lw007HallStatusUpdate? fromNotificationBytes(List<int> value) {
    if (value.length < 7) {
      return null;
    }
    final header = value[0];
    final flag = value[1];
    final cmd = value[2] & 0xFF;
    final length = value[3];
    if (header != 0xED || flag != 0x02 || cmd != 0x01 || length != 0x03) {
      return null;
    }
    return fromPayload(value.sublist(4, 7));
  }

  static Lw007HallStatusUpdate? fromPayload(List<int> data) {
    if (data.isEmpty) {
      return null;
    }
    final hallStatus = data[0] & 0xFF;
    if (hallStatus == 0xFF) {
      return const Lw007HallStatusUpdate(
        visible: false,
        isOpen: false,
        triggerTimes: 0,
      );
    }
    final triggerTimes = data.length >= 3 ? ((data[1] << 8) | data[2]) : 0;
    return Lw007HallStatusUpdate(
      visible: true,
      isOpen: hallStatus == 1,
      triggerTimes: triggerTimes,
    );
  }
}
