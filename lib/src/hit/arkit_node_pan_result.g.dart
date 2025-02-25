// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_node_pan_result.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitNodePanResult _$ARKitNodePanResultFromJson(Map json) => ARKitNodePanResult(
      json['nodeName'] as String?,
      const Vector2Converter().fromJson(json['translation'] as List),
    );

Map<String, dynamic> _$ARKitNodePanResultToJson(ARKitNodePanResult instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'translation': const Vector2Converter().toJson(instance.translation),
    };
