class School {
  final int id;
  final String name;
  final String address;
  final double? lat;
  final double? lng;
  final String? phone;
  final String? email;
  final String? logoUrl;
  final String? subscriptionStatus;
  // Add these two lines:
  final int? studentsCount; 
  final int? busesCount;

  School({
    required this.id,
    required this.name,
    required this.address,
    this.lat,
    this.lng,
    this.phone,
    this.email,
    this.logoUrl,
    this.subscriptionStatus,
    this.studentsCount,
    this.busesCount,
  });

  factory School.fromJson(Map<String, dynamic> json) {
    return School(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      lat: json['lat'] != null ? double.parse(json['lat'].toString()) : null,
      lng: json['lng'] != null ? double.parse(json['lng'].toString()) : null,
      phone: json['phone'],
      email: json['email'],
      logoUrl: json['logo_url'],
      // Mapping the nested subscription status
      subscriptionStatus: json['active_subscription']?['status'],
      // Mapping the counts from Laravel's withCount
      studentsCount: json['students_count'], 
      busesCount: json['buses_count'],
    );
  }
}