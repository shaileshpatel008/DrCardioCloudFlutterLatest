import 'ecg_data.dart';

/// Port of `SupportClass.parseData`, including this repo's later fix that
/// lets one payload carry multiple back-to-back samples (`offset`), needed
/// once a transport batches samples instead of framing one-per-message.
class ParseData {
  ParseData._();

  /// Bytes making up one full 12-channel sample: 24 for hwVersion 2
  /// (3 bytes x 8 acquired channels), 16 for hwVersion 1 (2 bytes x 8).
  static int bytesPerSample() => EcgData.instance.hwVersion == 2 ? 24 : 16;

  static List<double> charArrayToChannels(List<int> data, bool testMode, {int offset = 0}) {
    final channels = List<double>.filled(12, 0);
    for (var i = 0; i < 8; i++) {
      if (EcgData.instance.hwVersion == 2) {
        channels[i] = joinBytes(data[offset + 3 * i], data[offset + 3 * i + 1], data[offset + 3 * i + 2]);
      } else {
        channels[i] = joinMsbLsb(data[offset + 2 * i], data[offset + 2 * i + 1]).toDouble();
      }
    }
    generateAuxChannels(channels);
    return channels;
  }

  static List<double> generateAuxChannels(List<double> channels) {
    channels[8] = channels[2] - channels[1];
    channels[9] = -1 * (channels[1] + channels[2]) / 2.0;
    channels[10] = channels[1] - (channels[2] / 2.0);
    channels[11] = channels[2] - (channels[1] / 2.0);
    return channels;
  }

  static double joinBytes(int b1, int b2, int b3) {
    final joined = ((b1 & 0xff) << 24) | ((b2 & 0xff) << 16) | ((b3 & 0xff) << 8);
    return joined.toSigned(32) / 256;
  }

  static int joinMsbLsb(int msb, int lsb) {
    final joined = ((msb & 0xff) << 8) | (lsb & 0xff);
    return joined.toSigned(16);
  }

  /// Decodes the 3 status bytes into per-electrode lead-off status
  /// (true = attached). Index meaning: V1,V2,V3,V4,V5,V6,LeftLeg,RightLeg,
  /// LeftArm,RightArm — same order the original app uses to warn the user
  /// which electrode has come loose.
  static List<bool> byteArrayToLeadStatus(List<int> statusBytes) {
    final leadStatus = List<bool>.filled(10, true);
    if (statusBytes.length < 3) return leadStatus;
    leadStatus[0] = (statusBytes[0] & 0x08) == 0; // V1
    leadStatus[1] = (statusBytes[1] & 0x80) == 0; // V2
    leadStatus[2] = (statusBytes[0] & 0x02) == 0; // V3
    leadStatus[3] = (statusBytes[0] & 0x01) == 0; // V4
    leadStatus[4] = (statusBytes[0] & 0x04) == 0; // V5
    leadStatus[5] = (statusBytes[1] & 0x10) == 0; // V6
    leadStatus[6] = (statusBytes[1] & 0x40) == 0; // Left Leg
    leadStatus[7] = (statusBytes[0] & 0x08) == 0; // Right Leg
    leadStatus[8] = (statusBytes[1] & 0x20) == 0; // Left Arm
    leadStatus[9] = (statusBytes[2] & 0x20) == 0; // Right Arm
    return leadStatus;
  }
}
