// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'arkit_anchor.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ARKitUnkownAnchor _$ARKitUnkownAnchorFromJson(Map json) => ARKitUnkownAnchor(
      json['anchorType'] as String,
      json['nodeName'] as String?,
      json['identifier'] as String,
      const MatrixConverter().fromJson(json['transform'] as List),
    );

Map<String, dynamic> _$ARKitUnkownAnchorToJson(ARKitUnkownAnchor instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'identifier': instance.identifier,
      'transform': const MatrixConverter().toJson(instance.transform),
      'anchorType': instance.anchorType,
    };

ARKitPlaneAnchor _$ARKitPlaneAnchorFromJson(Map json) => ARKitPlaneAnchor(
      const Vector3Converter().fromJson(json['center'] as List),
      const Vector3Converter().fromJson(json['extent'] as List),
      json['nodeName'] as String?,
      json['identifier'] as String,
      const MatrixConverter().fromJson(json['transform'] as List),
    );

Map<String, dynamic> _$ARKitPlaneAnchorToJson(ARKitPlaneAnchor instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'identifier': instance.identifier,
      'transform': const MatrixConverter().toJson(instance.transform),
      'center': const Vector3Converter().toJson(instance.center),
      'extent': const Vector3Converter().toJson(instance.extent),
    };

ARKitImageAnchor _$ARKitImageAnchorFromJson(Map json) => ARKitImageAnchor(
      json['referenceImageName'] as String?,
      const Vector2Converter()
          .fromJson(json['referenceImagePhysicalSize'] as List),
      json['isTracked'] as bool,
      json['nodeName'] as String?,
      json['identifier'] as String,
      const MatrixConverter().fromJson(json['transform'] as List),
    );

Map<String, dynamic> _$ARKitImageAnchorToJson(ARKitImageAnchor instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'identifier': instance.identifier,
      'transform': const MatrixConverter().toJson(instance.transform),
      if (instance.referenceImageName case final value?)
        'referenceImageName': value,
      'referenceImagePhysicalSize':
          const Vector2Converter().toJson(instance.referenceImagePhysicalSize),
      'isTracked': instance.isTracked,
    };

ARKitFaceAnchor _$ARKitFaceAnchorFromJson(Map json) => ARKitFaceAnchor(
      ARKitFace.fromJson(json['geometry'] as Map),
      (json['blendShapes'] as Map).map(
        (k, e) => MapEntry(k as String, (e as num).toDouble()),
      ),
      json['isTracked'] as bool,
      json['nodeName'] as String?,
      json['identifier'] as String,
      const MatrixConverter().fromJson(json['transform'] as List),
      const MatrixConverter().fromJson(json['leftEyeTransform'] as List),
      const MatrixConverter().fromJson(json['rightEyeTransform'] as List),
      const Vector3ListConverter().fromJson(json['geometryVertices'] as List),
    );

Map<String, dynamic> _$ARKitFaceAnchorToJson(ARKitFaceAnchor instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'identifier': instance.identifier,
      'transform': const MatrixConverter().toJson(instance.transform),
      'geometry': instance.geometry,
      'leftEyeTransform':
          const MatrixConverter().toJson(instance.leftEyeTransform),
      'rightEyeTransform':
          const MatrixConverter().toJson(instance.rightEyeTransform),
      'geometryVertices':
          const Vector3ListConverter().toJson(instance.geometryVertices),
      'blendShapes': instance.blendShapes,
      'isTracked': instance.isTracked,
    };

ARKitBodyAnchor _$ARKitBodyAnchorFromJson(Map json) => ARKitBodyAnchor(
      ARKitSkeleton.fromJson(json['skeleton'] as Map),
      json['isTracked'] as bool,
      json['nodeName'] as String?,
      json['identifier'] as String,
      const MatrixConverter().fromJson(json['transform'] as List),
    );

Map<String, dynamic> _$ARKitBodyAnchorToJson(ARKitBodyAnchor instance) =>
    <String, dynamic>{
      if (instance.nodeName case final value?) 'nodeName': value,
      'identifier': instance.identifier,
      'transform': const MatrixConverter().toJson(instance.transform),
      'skeleton': instance.skeleton,
      'isTracked': instance.isTracked,
    };
