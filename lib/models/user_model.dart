class DriverProfileModel {
  final String id;
  final String status;

  DriverProfileModel({
    required this.id,
    required this.status,
  });

  factory DriverProfileModel.fromJson(Map<String, dynamic> json) {
    String calculatedStatus = json['status']?.toString() ?? '';

    if (json['is_verified'] == true ||
        json['is_verified'] == 1 ||
        json['is_approved'] == true) {
      calculatedStatus = 'approved';
    }

    if (calculatedStatus.isEmpty) {
      calculatedStatus = 'pending';
    }

    return DriverProfileModel(
      id: json['id']?.toString() ?? '',
      status: calculatedStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'status': status,
    };
  }
}

class UserModel {
  final String uid;
  final String name;
  final String phone;
  final String email;
  final String role;
  final DateTime createdAt;
  final String? city;
  final String? birthDate;
  final String? gender;
  final String? fcmToken;
  final DriverProfileModel? driverProfile;

  UserModel({
    required this.uid,
    required this.name,
    required this.phone,
    required this.email,
    required this.role,
    required this.createdAt,
    this.city,
    this.birthDate,
    this.gender,
    this.fcmToken,
    this.driverProfile,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    // Parsing ultra-sécurisé de la date pour éviter le crash / chargement infini
    DateTime parsedDate = DateTime.now();
    try {
      if (json['created_at'] != null) {
        parsedDate = DateTime.parse(json['created_at'].toString());
      } else if (json['createdAt'] != null) {
        parsedDate = DateTime.parse(json['createdAt'].toString());
      }
    } catch (_) {
      parsedDate = DateTime.now();
    }

    // Détection flexible du profil chauffeur
    final profileData = json['driver_profile'] ??
        json['driverProfile'] ??
        json['driver'] ??
        json['profile'];

    DriverProfileModel? driverProfileObj;
    if (profileData != null && profileData is Map<String, dynamic>) {
      try {
        driverProfileObj = DriverProfileModel.fromJson(profileData);
      } catch (e) {
        print("⚠️ Erreur lors du parsing de driverProfile: $e");
      }
    }

    return UserModel(
      uid: json['id']?.toString() ?? json['uid']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: json['role']?.toString() ?? 'Client',
      createdAt: parsedDate,
      city: json['city']?.toString(),
      birthDate: (json['birth_date'] ?? json['birthDate'])?.toString(),
      gender: json['gender']?.toString(),
      fcmToken: (json['fcm_token'] ?? json['fcmToken'])?.toString(),
      driverProfile: driverProfileObj,
    );
  }

  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    DateTime parsedDate = DateTime.now();
    try {
      if (map['createdAt'] != null) {
        parsedDate = DateTime.parse(map['createdAt'].toString());
      } else if (map['created_at'] != null) {
        parsedDate = DateTime.parse(map['created_at'].toString());
      }
    } catch (_) {
      parsedDate = DateTime.now();
    }

    DriverProfileModel? driverProfileObj;
    final profileData = map['driverProfile'] ?? map['driver_profile'];
    if (profileData != null && profileData is Map<String, dynamic>) {
      try {
        driverProfileObj = DriverProfileModel.fromJson(profileData);
      } catch (_) {}
    }

    return UserModel(
      uid: documentId,
      name: map['name']?.toString() ?? '',
      phone: map['phone']?.toString() ?? '',
      email: map['email']?.toString() ?? '',
      role: map['role']?.toString() ?? 'Client',
      createdAt: parsedDate,
      city: map['city']?.toString(),
      birthDate: (map['birth_date'] ?? map['birthDate'])?.toString(),
      gender: map['gender']?.toString(),
      fcmToken: (map['fcm_token'] ?? map['fcmToken'])?.toString(),
      driverProfile: driverProfileObj,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (uid.isNotEmpty) 'id': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'created_at': createdAt.toIso8601String(),
      'city': city,
      'birth_date': birthDate,
      'gender': gender,
      'fcm_token': fcmToken,
      'driver_profile': driverProfile?.toJson(),
    };
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'name': name,
      'phone': phone,
      'email': email,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'city': city,
      'birthDate': birthDate,
      'gender': gender,
      'fcmToken': fcmToken,
      'driverProfile': driverProfile?.toJson(),
    };
  }
}