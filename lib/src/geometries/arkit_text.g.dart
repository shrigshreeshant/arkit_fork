// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_text.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitText _$ARKitTextFromJson(Map json) => ARKitText(
      text: json['text'] as String,
      extrusionDepth: (json['extrusionDepth'] as num).toDouble(),
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => ARKitMaterial.fromJson(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ARKitTextToJson(ARKitText instance) => <String, dynamic>{
      if (const ListMaterialsValueNotifierConverter().toJson(instance.materials)
          case final value?)
        'materials': value,
      'text': const StringValueNotifierConverter().toJson(instance.text),
      'extrusionDepth': instance.extrusionDepth,
    };
