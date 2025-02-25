// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_capsule.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitCapsule _$ARKitCapsuleFromJson(Map json) => ARKitCapsule(
      capRadius: (json['capRadius'] as num?)?.toDouble() ?? 0.5,
      height: (json['height'] as num?)?.toDouble() ?? 2,
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => ARKitMaterial.fromJson(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ARKitCapsuleToJson(ARKitCapsule instance) =>
    <String, dynamic>{
      if (const ListMaterialsValueNotifierConverter().toJson(instance.materials)
          case final value?)
        'materials': value,
      'capRadius':
          const DoubleValueNotifierConverter().toJson(instance.capRadius),
      'height': const DoubleValueNotifierConverter().toJson(instance.height),
    };
