import 'dart:async';
import 'package:arkit_plugin/src/models/ar_frame.dart';
import 'package:flutter/services.dart';

class ARKitCameraStream {
  static const EventChannel _cameraStreamChannel =
      EventChannel('arkit/cameraStream');

  static bool get isStreamActive => _subscription != null;

  static Stream<ARFrameData> get cameraImages {
    return _cameraStreamChannel.receiveBroadcastStream().map((event) {
      final data = ARFrameData.fromMap(event);

      return data;
    });
  }

  static StreamSubscription<ARFrameData>? _subscription;

  static void listen({
    required void Function(ARFrameData data) onData,
    void Function(Object error)? onError,
  }) {
    _subscription?.cancel();
    _subscription = cameraImages.listen(
      onData,
      onError: onError,
    );
  }

  static void dispose() {
    _subscription?.cancel();
    _subscription = null;
  }
}
