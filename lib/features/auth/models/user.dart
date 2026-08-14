class UserModel {
  final int id;
  final String name;
  final String? email;
  final String? username;
  final String type;
  final String phone;
  final String? profilePicture;
  /// Agent bank details (API: bank_name, account_number, account_holder_name)
  final String? bankName;
  final String? accountNumber;
  final String? accountHolderName;
  final String? city;

  UserModel({
    required this.id,
    required this.name,
    this.email,
    this.username,
    required this.type,
    required this.phone,
    this.profilePicture,
    this.bankName,
    this.accountNumber,
    this.accountHolderName,
    this.city,
  });

  // Convert JSON Map to Model
  factory UserModel.fromJson(Map<String, dynamic> json) {
    final agentProfile = json['agent_profile'];
    final agentMap = agentProfile is Map
        ? Map<String, dynamic>.from(agentProfile)
        : <String, dynamic>{};

    return UserModel(
      // The only non-nullable, non-stringified field here, and the only one
      // that can throw. `json['id']` was assigned straight into an `int`, so a
      // payload where the API sends "42" instead of 42 — or a cached record
      // from an older build that never stored an id — threw a TypeError deep
      // inside a factory nobody wraps. Parse it defensively instead: an id of
      // 0 is visibly wrong and recoverable, an exception on the splash screen
      // is neither.
      id: _toId(json['id']),
      name: (json['full_name'] ?? json['name'] ?? '').toString(),
      username: json['username']?.toString(),
      email: json['email']?.toString(),
      type: (json['type'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      profilePicture:
          (json['profile_picture_url'] ?? json['profile_picture'])?.toString(),
      bankName: (agentMap['bank_name'] ?? json['bank_name'])?.toString(),
      accountNumber:
          (agentMap['account_number'] ?? json['account_number'])?.toString(),
      accountHolderName: (agentMap['account_holder_name'] ??
          json['account_holder_name'])?.toString(),
      city: json['city']?.toString(),
    );
  }

  // Convert Model to JSON Map for caching
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'username': username,
      'type': type,
      'phone': phone,
      'profile_picture': profilePicture,
      'bank_name': bankName,
      'account_number': accountNumber,
      'account_holder_name': accountHolderName,
      'city': city,
    };
  }

  static int _toId(Object? raw) {
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }
}
