class UserModel {
  final int id;
  final String name;
  final String email;
  final String role;
  final String? phone;
  final String? fcmToken;
  final int? schoolId;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.phone,
    this.fcmToken,
    this.schoolId,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id:       json['id'] as int,
      name:     json['name'] as String,
      email:    json['email'] as String,
      role:     json['role'] as String,
      phone:    json['phone'] as String?,
      fcmToken: json['fcm_token'] as String?,
      schoolId: json['school_id'] as int?,
    );
  }

  bool get isDriver      => role == 'driver';
  bool get isParent      => role == 'parent';
  bool get isSchoolAdmin => role == 'school_admin';
  bool get isSuperAdmin  => role == 'super_admin';
  bool get isAdmin       => isSchoolAdmin || isSuperAdmin;
}
