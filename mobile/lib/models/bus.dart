/// Bus — fleet vehicle model.
///
/// FleetController returns { bus_id, name, plate, lat, lng, speed, ... }
/// BusController  returns  { id,     name, plate, latitude, longitude, ... }
///
/// fromJson handles both shapes — no separate FleetBus model needed.
///
/// Path: lib/models/bus.dart
class Bus {
  final int     id;
  final String  name;
  final String  plate;
  final String  status;
  final String? type;       // 'bus' | 'minibus' | 'van'
  final int?    capacity;
  final String? deviceId;
  final int?    driverId;
  final int?    routeId;
  final int?    schoolId;
  final double  latitude;
  final double  longitude;
  final double? speed;
  final double? heading;
  final String? timestamp;

  const Bus({
    required this.id,
    required this.name,
    required this.plate,
    required this.status,
    this.type,
    this.capacity,
    this.deviceId,
    this.driverId,
    this.routeId,
    this.schoolId,
    required this.latitude,
    required this.longitude,
    this.speed,
    this.heading,
    this.timestamp,
  });

  factory Bus.fromJson(Map<String, dynamic> json) => Bus(
    // FleetController uses "bus_id"; BusController uses "id"
    id:        (json['id'] ?? json['bus_id'] ?? 0) as int,
    name:      json['name']  as String? ?? 'Unknown',
    plate:     (json['plate'] ?? json['plate_number'] ?? 'No Plate') as String,
    status:    json['status'] as String? ?? 'idle',
    type:      json['type']   as String?,
    capacity:  json['capacity'] as int?,
    deviceId:  json['device_id']?.toString(),
    driverId:  json['driver_id'] as int?,
    routeId:   json['route_id']  as int?,
    schoolId:  json['school_id'] as int?,
    // FleetController uses "lat"/"lng"; BusController may use "latitude"/"longitude"
    latitude:  ((json['latitude']  ?? json['lat']  ?? 0) as num).toDouble(),
    longitude: ((json['longitude'] ?? json['lng']  ?? 0) as num).toDouble(),
    speed:     (json['speed']   as num?)?.toDouble(),
    heading:   (json['heading'] as num?)?.toDouble(),
    timestamp: json['timestamp']?.toString(),
  );

  Bus copyWith({
    String? status,
    double? latitude,
    double? longitude,
    double? speed,
    double? heading,
    String? timestamp,
  }) => Bus(
    id: id, name: name, plate: plate, type: type,
    capacity: capacity, deviceId: deviceId, driverId: driverId,
    routeId: routeId, schoolId: schoolId,
    status:    status    ?? this.status,
    latitude:  latitude  ?? this.latitude,
    longitude: longitude ?? this.longitude,
    speed:     speed     ?? this.speed,
    heading:   heading   ?? this.heading,
    timestamp: timestamp ?? this.timestamp,
  );

  bool get hasGps    => latitude != 0.0 && longitude != 0.0;
  bool get isActive  => status == 'active';
  bool get isEmergency => status == 'sos';
}