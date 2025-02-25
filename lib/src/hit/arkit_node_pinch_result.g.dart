// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_node_pinch_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitNodePinchResult _$ARKitNodePinchResultFromJson(Map json) =>
    ARKitNodePinchResult(
      json['nodeName'] as String?,
      (json['scale'] as num).toDouble(),
    );

Map<String, dynamic> _$ARKitNodePinchResultToJson(
        ARKitNodePinchResult instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'scale': instance.scale,
    };
