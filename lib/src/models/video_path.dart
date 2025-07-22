class ARVideoPath {
  final String path;
  final String recordingId;

  ARVideoPath({
    required this.path,
    required this.recordingId,
  });

  factory ARVideoPath.fromMap(Map<String, dynamic> map) {
    return ARVideoPath(
      path: map['recordingPath'] as String,
      recordingId: map['recordingId'] as String,
    );
  }
}
