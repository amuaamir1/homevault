class UserProfile {
  const UserProfile({
    required this.uid,
    required this.fullName,
    required this.phoneNumber,
    required this.addressLine1,
    required this.state,
    required this.city,
    required this.pinCode,
    this.email = '',
    this.addressLine2 = '',
    this.landmark = '',
    this.createdAt,
    this.updatedAt,
  });

  final String uid;
  final String fullName;
  final String phoneNumber;
  final String email;
  final String addressLine1;
  final String addressLine2;
  final String landmark;
  final String state;
  final String city;
  final String pinCode;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  String get firstName {
    final trimmed = fullName.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.split(RegExp(r'\s+')).first;
  }

  bool get isComplete {
    return uid.trim().isNotEmpty &&
        fullName.trim().isNotEmpty &&
        phoneNumber.trim().isNotEmpty &&
        addressLine1.trim().isNotEmpty &&
        state.trim().isNotEmpty &&
        city.trim().isNotEmpty &&
        isValidIndianPinCode(pinCode);
  }

  UserProfile copyWith({
    String? uid,
    String? fullName,
    String? phoneNumber,
    String? email,
    String? addressLine1,
    String? addressLine2,
    String? landmark,
    String? state,
    String? city,
    String? pinCode,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      landmark: landmark ?? this.landmark,
      state: state ?? this.state,
      city: city ?? this.city,
      pinCode: pinCode ?? this.pinCode,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'fullName': fullName.trim(),
      'phoneNumber': phoneNumber.trim(),
      'email': email.trim(),
      'addressLine1': addressLine1.trim(),
      'addressLine2': addressLine2.trim(),
      'landmark': landmark.trim(),
      'state': state.trim(),
      'city': city.trim(),
      'pinCode': pinCode.trim(),
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      uid: map['uid'] as String? ?? '',
      fullName: map['fullName'] as String? ?? '',
      phoneNumber: map['phoneNumber'] as String? ?? '',
      email: map['email'] as String? ?? '',
      addressLine1: map['addressLine1'] as String? ?? '',
      addressLine2: map['addressLine2'] as String? ?? '',
      landmark: map['landmark'] as String? ?? '',
      state: map['state'] as String? ?? '',
      city: map['city'] as String? ?? '',
      pinCode: map['pinCode'] as String? ?? '',
      createdAt: map['createdAt'] as DateTime?,
      updatedAt: map['updatedAt'] as DateTime?,
    );
  }

  static bool isValidIndianPinCode(String value) {
    return RegExp(r'^[1-9][0-9]{5}$').hasMatch(value.trim());
  }
}
