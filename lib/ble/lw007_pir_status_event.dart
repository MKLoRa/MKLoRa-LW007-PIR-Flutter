class Lw007PirStatusUpdate {
  const Lw007PirStatusUpdate({required this.visible, required this.motionDetected});

  final bool visible;
  final bool motionDetected;

  static Lw007PirStatusUpdate? fromNotificationBytes(List<int> value) {
    if (value.length < 5) {
      return null;
    }
    final header = value[0];
    final flag = value[1];
    final cmd = value[2] & 0xFF;
    final length = value[3];
    final status = value[4] & 0xFF;
    if (header != 0xED || flag != 0x02 || cmd != 0x01 || length != 0x01) {
      return null;
    }
    if (status == 0xFF) {
      return const Lw007PirStatusUpdate(visible: false, motionDetected: false);
    }
    return Lw007PirStatusUpdate(
      visible: true,
      motionDetected: status == 1,
    );
  }

  static Lw007PirStatusUpdate fromStatusByte(int status) {
    if (status == 0xFF) {
      return const Lw007PirStatusUpdate(visible: false, motionDetected: false);
    }
    return Lw007PirStatusUpdate(
      visible: true,
      motionDetected: status == 1,
    );
  }
}
