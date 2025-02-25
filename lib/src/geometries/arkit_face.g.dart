// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_face.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitFace _$ARKitFaceFromJson(Map json) => ARKitFace(
      materials: (json['materials'] as List<dynamic>?)
          ?.map((e) => ARKitMaterial.fromJson(e as Map))
          .toList(),
    );

Map<String, dynamic> _$ARKitFaceToJson(ARKitFace instance) => <String, dynamic>{
      if (const ListMaterialsValueNotifierConverter().toJson(instance.materials)
          case final value?)
        'materials': value,
    };
