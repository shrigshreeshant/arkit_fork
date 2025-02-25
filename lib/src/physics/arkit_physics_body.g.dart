// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_physics_body.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitPhysicsBody _$ARKitPhysicsBodyFromJson(Map json) => ARKitPhysicsBody(
      const ARKitPhysicsBodyTypeConverter()
          .fromJson((json['type'] as num).toInt()),
      shape: _$JsonConverterFromJson<Map<dynamic, dynamic>, ARKitPhysicsShape?>(
          json['shape'], const ARKitPhysicsShapeConverter().fromJson),
      categoryBitMask: (json['categoryBitMask'] as num?)?.toInt(),
    );

Map<String, dynamic> _$ARKitPhysicsBodyToJson(ARKitPhysicsBody instance) =>
    <String, dynamic>{
      'type': const ARKitPhysicsBodyTypeConverter().toJson(instance.type),
      if (const ARKitPhysicsShapeConverter().toJson(instance.shape)
          case final value?)
        'shape': value,
      if (instance.categoryBitMask case final value?) 'categoryBitMask': value,
    };

Value? _$JsonConverterFromJson<Json, Value>(
  Object? json,
  Value? Function(Json json) fromJson,
) =>
    json == null ? null : fromJson(json as Json);
