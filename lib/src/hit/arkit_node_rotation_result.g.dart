// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_node_rotation_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitNodeRotationResult _$ARKitNodeRotationResultFromJson(Map json) =>
    ARKitNodeRotationResult(
      json['nodeName'] as String?,
      (json['rotation'] as num).toDouble(),
    );

Map<String, dynamic> _$ARKitNodeRotationResultToJson(
        ARKitNodeRotationResult instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'rotation': instance.rotation,
    };
