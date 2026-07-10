class Event {
  final String detectionId;
  final String deviceId;
  final String detectedClass;
  final double confidence;
  final String detectedAt;
  final String snapshotPath;

  Event({
    required this.detectionId,
    required this.deviceId,
    required this.detectedClass,
    required this.confidence,
    required this.detectedAt,
    required this.snapshotPath,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      detectionId: json['detection_id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      detectedClass: json['detected_class']?.toString() ?? '',
      confidence: double.tryParse(json['confidence'].toString()) ?? 0.0,
      detectedAt: json['detected_at']?.toString() ?? '',
      snapshotPath: json['snapshot_path']?.toString() ?? '',
    );
  }
}
