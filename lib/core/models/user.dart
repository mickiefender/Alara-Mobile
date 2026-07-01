class User {
  final String id;
  final String email;
  final String name;
  final String role;
  final String? profileImage;
  final String? phone;
  final String? classId;
  final String? schoolName;
  final String? schoolLogo;
  final DateTime createdAt;
  final DateTime updatedAt;

  User({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.profileImage,
    this.phone,
    this.classId,
    this.schoolName,
    this.schoolLogo,
    required this.createdAt,
    required this.updatedAt,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final firstName = (json['first_name'] ?? '').toString().trim();
    final lastName = (json['last_name'] ?? '').toString().trim();
    final fullName = '$firstName $lastName'.trim();

    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      return DateTime.tryParse(value.toString()) ?? DateTime.now();
    }

    String? parseSchoolName(Map<String, dynamic> source) {
      final directSchoolName = source['school_name']?.toString().trim();
      if (directSchoolName != null && directSchoolName.isNotEmpty) {
        return directSchoolName;
      }

      final school = source['school'];
      if (school is Map<String, dynamic>) {
        final nestedName = school['name']?.toString().trim();
        if (nestedName != null && nestedName.isNotEmpty) {
          return nestedName;
        }
      }

      final nestedSchoolName = source['user'] is Map<String, dynamic>
          ? parseSchoolName(source['user'] as Map<String, dynamic>)
          : null;
      if (nestedSchoolName != null && nestedSchoolName.isNotEmpty) {
        return nestedSchoolName;
      }

      return null;
    }

    String? parseSchoolLogo(Map<String, dynamic> source) {
      // Try direct field
      final directLogo = source['school_logo']?.toString().trim();
      if (directLogo != null && directLogo.isNotEmpty) {
        return directLogo;
      }

      // Try nested school object
      final school = source['school'];
      if (school is Map<String, dynamic>) {
        final nestedLogo = school['logo']?.toString().trim();
        if (nestedLogo != null && nestedLogo.isNotEmpty) {
          return nestedLogo;
        }
      }

      return null;
    }

    return User(
      id: json['id'].toString(),
      email: (json['email'] ?? '').toString(),
      name: (json['name']?.toString().trim().isNotEmpty ?? false)
          ? json['name'].toString()
          : (fullName.isNotEmpty ? fullName : ''),
      role: (json['role'] ?? '').toString(),
      profileImage: (json['profile_image'] ?? json['profile_picture'])?.toString(),
      phone: json['phone']?.toString(),
      classId: json['class_id']?.toString(),
      schoolName: parseSchoolName(json),
      schoolLogo: parseSchoolLogo(json),
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'name': name,
    'role': role,
    'profile_image': profileImage,
    'profile_picture': profileImage,
    'phone': phone,
    'class_id': classId,
    'school_name': schoolName,
    'school_logo': schoolLogo,
    'created_at': createdAt.toIso8601String(),
    'updated_at': updatedAt.toIso8601String(),
  };

  User copyWith({
    String? id,
    String? email,
    String? name,
    String? role,
    String? profileImage,
    String? phone,
    String? classId,
    String? schoolName,
    String? schoolLogo,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => User(
    id: id ?? this.id,
    email: email ?? this.email,
    name: name ?? this.name,
    role: role ?? this.role,
    profileImage: profileImage ?? this.profileImage,
    phone: phone ?? this.phone,
    classId: classId ?? this.classId,
    schoolName: schoolName ?? this.schoolName,
    schoolLogo: schoolLogo ?? this.schoolLogo,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
}
