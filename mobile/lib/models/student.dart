class StopModel {
  final int id;
  final String name;
  const StopModel({required this.id, required this.name});
  factory StopModel.fromJson(Map<String, dynamic> json) =>
      StopModel(id: json['id'] as int, name: json['name'] as String);
}

class RouteModel {
  final int id;
  final String name;
  const RouteModel({required this.id, required this.name});
  factory RouteModel.fromJson(Map<String, dynamic> json) =>
      RouteModel(id: json['id'] as int, name: json['name'] as String);
}

class StudentModel {
  final int id;
  final String name;
  final int? routeId;
  final int? pickupStopId;
  final int? dropoffStopId;
  final RouteModel? route;
  final StopModel? pickupStop;
  final StopModel? dropoffStop;

  const StudentModel({
    required this.id,
    required this.name,
    this.routeId,
    this.pickupStopId,
    this.dropoffStopId,
    this.route,
    this.pickupStop,
    this.dropoffStop,
  });

  factory StudentModel.fromJson(Map<String, dynamic> json) {
    return StudentModel(
      id:            json['id'] as int,
      name:          json['name'] as String,
      routeId:       json['route_id'] as int?,
      pickupStopId:  json['pickup_stop_id'] as int?,
      dropoffStopId: json['dropoff_stop_id'] as int?,
      route:       json['route'] != null
          ? RouteModel.fromJson(json['route']) : null,
      pickupStop:  json['pickup_stop'] != null
          ? StopModel.fromJson(json['pickup_stop']) : null,
      dropoffStop: json['dropoff_stop'] != null
          ? StopModel.fromJson(json['dropoff_stop']) : null,
    );
  }
}
