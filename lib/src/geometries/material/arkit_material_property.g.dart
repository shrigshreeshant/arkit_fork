// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_material_property.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitMaterialColor _$ARKitMaterialColorFromJson(Map json) => ARKitMaterialColor(
      const ColorConverter().fromJson((json['color'] as num).toInt()),
    );

Map<String, dynamic> _$ARKitMaterialColorToJson(ARKitMaterialColor instance) =>
    <String, dynamic>{
      'color': const ColorConverter().toJson(instance.color),
    };

ARKitMaterialImage _$ARKitMaterialImageFromJson(Map json) => ARKitMaterialImage(
      json['image'] as String,
    );

Map<String, dynamic> _$ARKitMaterialImageToJson(ARKitMaterialImage instance) =>
    <String, dynamic>{
      'image': instance.image,
    };

ARKitMaterialValue _$ARKitMaterialValueFromJson(Map json) => ARKitMaterialValue(
      (json['value'] as num).toDouble(),
    );

Map<String, dynamic> _$ARKitMaterialValueToJson(ARKitMaterialValue instance) =>
    <String, dynamic>{
      'value': instance.value,
    };

ARKitMaterialVideo _$ARKitMaterialVideoFromJson(Map json) => ARKitMaterialVideo(
      width: (json['width'] as num).toInt(),
      height: (json['height'] as num).toInt(),
      autoplay: json['autoplay'] as bool? ?? true,
      filename: json['filename'] as String?,
      url: json['url'] as String?,
    );

Map<String, dynamic> _$ARKitMaterialVideoToJson(ARKitMaterialVideo instance) =>
    <String, dynamic>{
      if (instance.filename case final value?) 'filename': value,
      if (instance.url case final value?) 'url': value,
      'width': instance.width,
      'height': instance.height,
      'autoplay': instance.autoplay,
    };
