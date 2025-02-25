// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_pyramid.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitPyramid _$ARKitPyramidFromJson(Map json) => ARKitPyramid(
      height: (json['height'] as num?)?.toDouble() ?? 1,
      width: (json['width'] as num?)?.toDouble() ?? 1,
      length: (json['length'] as num?)?.toDouble() ?? 1,
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => ARKitMaterial.fromJson(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ARKitPyramidToJson(ARKitPyramid instance) =>
    <String, dynamic>{
      if (const ListMaterialsValueNotifierConverter().toJson(instance.materials)
          case final value?)
        'materials': value,
      'height': const DoubleValueNotifierConverter().toJson(instance.height),
      'width': const DoubleValueNotifierConverter().toJson(instance.width),
      'length': const DoubleValueNotifierConverter().toJson(instance.length),
    };
