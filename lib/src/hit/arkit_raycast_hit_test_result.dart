import 'package:arkit_plugin/arkit_plugin.dart';
import 'package:arkit_plugin/src/utils/json_converters.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:vector_math/vector_math_64.dart';

part 'arkit_raycast_hit_test_result.g.dart';

/// A result of an intersection found during a hit-test.
@JsonSerializable()
class ARKitRaycastHitTestResult {
  ARKitRaycastHitTestResult(this.worldTransform, this.anchor);

  /// The transformation matrix that defines the intersection’s rotation, translation and scale
  /// relative to the world.
  @MatrixConverter()
  final Matrix4 worldTransform;

  /// The anchor that the hit-test intersected.
  /// An anchor will only be provided for existing plane result types.
  @ARKitAnchorConverter()
  final ARKitAnchor? anchor;

  static ARKitRaycastHitTestResult fromJson(Map<String, dynamic> json) =>
      _$ARKitRaycastHitTestResultFromJson(json);

  Map<String, dynamic> toJson() => _$ARKitRaycastHitTestResultToJson(this);
}
