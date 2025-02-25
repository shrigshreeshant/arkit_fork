// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_plane.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitPlane _$ARKitPlaneFromJson(Map json) => ARKitPlane(
      width: (json['width'] as num?)?.toDouble() ?? 1,
      height: (json['height'] as num?)?.toDouble() ?? 1,
      widthSegmentCount: (json['widthSegmentCount'] as num?)?.toInt() ?? 1,
      heightSegmentCount: (json['heightSegmentCount'] as num?)?.toInt() ?? 1,
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => ARKitMaterial.fromJson(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ARKitPlaneToJson(ARKitPlane instance) =>
    <String, dynamic>{
      if (const ListMaterialsValueNotifierConverter().toJson(instance.materials)
          case final value?)
        'materials': value,
      'width': const DoubleValueNotifierConverter().toJson(instance.width),
      'height': const DoubleValueNotifierConverter().toJson(instance.height),
      'widthSegmentCount': instance.widthSegmentCount,
      'heightSegmentCount': instance.heightSegmentCount,
    };
