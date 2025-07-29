import 'dart:typed_data';

class ARFrameData {
  final Uint8List frameBytes;
  final int width;
  final int height;

  ARFrameData({
    required this.frameBytes,
    required this.width,
    required this.height,
  });

  factory ARFrameData.fromMap(Map<dynamic, dynamic> map) {
    final frameBytes = map['frameBytes'] as Uint8List;
    final width = map['width'] as int;
    final height = map['height'] as int;

    return ARFrameData(
      frameBytes: frameBytes,
      width: width,
      height: height,
    );
  }

  @override
  String toString() {
    return 'ARFrameData: image=${width}x$height, bytes=${frameBytes.length}';
  }
}
