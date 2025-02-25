// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_raycast_hit_test_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitRaycastHitTestResult _$ARKitRaycastHitTestResultFromJson(Map json) =>
    ARKitRaycastHitTestResult(
      const MatrixConverter().fromJson(json['worldTransform'] as List),
      const ARKitAnchorConverter().fromJson(json['anchor'] as Map?),
    );

Map<String, dynamic> _$ARKitRaycastHitTestResultToJson(
        ARKitRaycastHitTestResult instance) =>
    <String, dynamic>{
      'worldTransform': const MatrixConverter().toJson(instance.worldTransform),
      if (const ARKitAnchorConverter().toJson(instance.anchor)
          case final value?)
        'anchor': value,
    };
