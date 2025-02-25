// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_light.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitLight _$ARKitLightFromJson(Map json) => ARKitLight(
      type: json['type'] == null
          ? ARKitLightType.omni
          : const ARKitLightTypeConverter()
              .fromJson((json['type'] as num).toInt()),
      color: json['color'] == null
          ? Colors.white
          : const NullableColorConverter()
              .fromJson((json['color'] as num?)?.toInt()),
      temperature: (json['temperature'] as num?)?.toDouble() ?? 6500,
      intensity: (json['intensity'] as num?)?.toDouble(),
      spotInnerAngle: (json['spotInnerAngle'] as num?)?.toDouble() ?? 0,
      spotOuterAngle: (json['spotOuterAngle'] as num?)?.toDouble() ?? 45,
    );

Map<String, dynamic> _$ARKitLightToJson(ARKitLight instance) =>
    <String, dynamic>{
      'type': const ARKitLightTypeConverter().toJson(instance.type),
      if (const NullableColorConverter().toJson(instance.color)
          case final value?)
        'color': value,
      'temperature': instance.temperature,
      'intensity':
          const DoubleValueNotifierConverter().toJson(instance.intensity),
      'spotInnerAngle': instance.spotInnerAngle,
      'spotOuterAngle': instance.spotOuterAngle,
    };
