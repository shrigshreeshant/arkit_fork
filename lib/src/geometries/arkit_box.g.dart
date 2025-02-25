// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_box.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitBox _$ARKitBoxFromJson(Map json) => ARKitBox(
      width: (json['width'] as num?)?.toDouble() ?? 1,
      height: (json['height'] as num?)?.toDouble() ?? 1,
      length: (json['length'] as num?)?.toDouble() ?? 1,
      chamferRadius: (json['chamferRadius'] as num?)?.toDouble() ?? 0,
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => ARKitMaterial.fromJson(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ARKitBoxToJson(ARKitBox instance) => <String, dynamic>{
      if (const ListMaterialsValueNotifierConverter().toJson(instance.materials)
          case final value?)
        'materials': value,
      'width': const DoubleValueNotifierConverter().toJson(instance.width),
      'height': const DoubleValueNotifierConverter().toJson(instance.height),
      'length': const DoubleValueNotifierConverter().toJson(instance.length),
      'chamferRadius': instance.chamferRadius,
    };
