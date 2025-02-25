// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_torus.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitTorus _$ARKitTorusFromJson(Map json) => ARKitTorus(
      ringRadius: (json['ringRadius'] as num?)?.toDouble() ?? 0.5,
      pipeRadius: (json['pipeRadius'] as num?)?.toDouble() ?? 0.25,
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => ARKitMaterial.fromJson(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ARKitTorusToJson(ARKitTorus instance) =>
    <String, dynamic>{
      if (const ListMaterialsValueNotifierConverter().toJson(instance.materials)
          case final value?)
        'materials': value,
      'ringRadius':
          const DoubleValueNotifierConverter().toJson(instance.ringRadius),
      'pipeRadius':
          const DoubleValueNotifierConverter().toJson(instance.pipeRadius),
    };
