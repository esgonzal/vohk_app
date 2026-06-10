class Event {
  final String camera;
  final String timestamp;
  final String type;
  final double confidence;

  Event({
    required this.camera,
    required this.timestamp,
    required this.type,
    required this.confidence,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      camera: json['camera'],
      timestamp: json['timestamp'],
      type: json['type'],
      confidence: (json['confidence'] as num).toDouble(),
    );
  }
}
