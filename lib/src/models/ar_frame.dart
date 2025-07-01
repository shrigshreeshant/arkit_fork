import 'dart:typed_data';

class ARFrameData {
  final Uint8List cameraImage;
  final int imageWidth;
  final int imageHeight;

  final Float32List? depthMap;
  final int? depthWidth;
  final int? depthHeight;
  final String? depthFormat;

  ARFrameData({
    required this.cameraImage,
    required this.imageWidth,
    required this.imageHeight,
    this.depthMap,
    this.depthWidth,
    this.depthHeight,
    this.depthFormat,
  });

  factory ARFrameData.fromMap(Map<dynamic, dynamic> map) {
    final cameraImage = map['cameraImage'] as Uint8List;
    final imageWidth = map['imageWidth'] as int;
    final imageHeight = map['imageHeight'] as int;

    Float32List? depthMap;
    int? depthWidth;
    int? depthHeight;
    String? depthFormat;

    try {
      if (map['depthMap'] != null &&
          map['depthWidth'] != null &&
          map['depthHeight'] != null) {
        final depthBytes = map['depthMap'] as Uint8List;
        depthMap = depthBytes.buffer.asFloat32List();
        depthWidth = map['depthWidth'] as int;
        depthHeight = map['depthHeight'] as int;
        depthFormat = map['depthFormat'] as String;
      }
    } catch (e) {
      print('Warning: Failed to parse depth map: $e');
    }

    return ARFrameData(
      cameraImage: cameraImage,
      imageWidth: imageWidth,
      imageHeight: imageHeight,
      depthMap: depthMap,
      depthWidth: depthWidth,
      depthHeight: depthHeight,
      depthFormat: depthFormat,
    );
  }

  /// Access depth at (x, y)
  double depthAt(int x, int y) {
    if (depthMap == null || depthWidth == null || depthHeight == null) return 0.0;
    if (x < 0 || x >= depthWidth! || y < 0 || y >= depthHeight!) return 0.0;

    final index = y * depthWidth! + x;
    return (index >= 0 && index < depthMap!.length) ? depthMap![index] : 0.0;
  }

  /// Debug info
  @override
  String toString() {
    final depthInfo = (depthMap != null)
        ? 'depth=${depthWidth}x$depthHeight format=$depthFormat'
        : 'depth=none';

    return 'ARFrameData: image=${imageWidth}x$imageHeight, $depthInfo';
  }
}