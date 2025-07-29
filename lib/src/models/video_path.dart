class ARVideoPath {
  final String recordingId;

  ARVideoPath({
    required this.recordingId,
  });

  factory ARVideoPath.fromMap(Map<String, dynamic> map) {
    return ARVideoPath(
      recordingId: map['recordingId'] as String,
    );
  }
}
