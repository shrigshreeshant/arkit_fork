import 'dart:typed_data';

class ARFrameData {
  final Uint8List frameBytes;
  final int frameNumber;
  final double timeStamp;

  ARFrameData({
    required this.frameBytes,
    required this.frameNumber,
    required this.timeStamp,
  });

  factory ARFrameData.fromMap(Map<dynamic, dynamic> map) {
    final frameBytes = map['imageData'] as Uint8List;
    final timeStamp = map['timestamp'] as double;
    final frameNumber = map['frameNumber'] as int;

    return ARFrameData(
      frameBytes: frameBytes,
      timeStamp: timeStamp,
      frameNumber: frameNumber,
    );
  }

  @override
  String toString() {
    return 'ARFrameData: framenumber=$frameNumber timestamp=$timeStamp, bytes=${frameBytes.length}';
  }
}
