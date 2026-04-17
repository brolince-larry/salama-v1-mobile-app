// lib/models/trip_model.dart

class TripModel {
  final int id;
  final int busId;
  final String status;
  final String? tripType;
  final String? startedAt;

  const TripModel({
    required this.id,
    required this.busId,
    required this.status,
    this.tripType,
    this.startedAt,
  });

  factory TripModel.fromJson(Map<String, dynamic> json) {
    return TripModel(
      // Support both 'id' and 'trip_id' depending on which endpoint returns it
      id: (json['id'] ?? json['trip_id']) as int,
      busId: json['bus_id'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      tripType: json['trip_type'] as String?,
      startedAt: json['started_at'] as String?,
    );
  }

  bool get isActive => status == 'active';
  bool get isPaused => status == 'paused';
  bool get isPending => status == 'pending';
}
