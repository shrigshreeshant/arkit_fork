import 'package:arkit_plugin/src/widget/arkit_configuration.dart';
import 'package:flutter/services.dart';

class ARKitPlugin {
  static const MethodChannel _channel = MethodChannel('arkit_configuration');
  static const EventChannel _cameraStreamChannel =
      EventChannel('arkit/cameraStream');

  ARKitPlugin._();

  static Future<bool> checkConfiguration(ARKitConfiguration configuration) {
    return _channel.invokeMethod<bool>('checkConfiguration', {
      'configuration': configuration.index,
    }).then((value) => value!);
  }

  static Stream<Uint8List> getCameraImageStream() {
    return _cameraStreamChannel
        .receiveBroadcastStream()
        .map<Uint8List>((event) {
      return event as Uint8List;
    });
  }

  static Future<bool> checkLidarAvailability() {
    return _channel
        .invokeMethod<bool>('checkLidarAvailability')
        .then((value) => value!);
  }
}
