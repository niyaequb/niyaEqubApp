class SettingsModel {
  final String? privacyPolicy;
  final String? termsAndConditions;
  final SupportSettings? support;
  final SocialSettings? social;

  const SettingsModel({
    this.privacyPolicy,
    this.termsAndConditions,
    this.support,
    this.social,
  });

  factory SettingsModel.fromJson(Map<String, dynamic> json) {
    // Response: { "data": { "legal": {...}, "support": {...}, "social": {...} } }
    final data = json['data'] is Map<String, dynamic>
        ? json['data'] as Map<String, dynamic>
        : json;

    final legal = data['legal'] as Map<String, dynamic>?;

    return SettingsModel(
      privacyPolicy: legal?['privacy_policy'] as String?,
      termsAndConditions: legal?['terms_conditions'] as String?,
      support: data['support'] is Map<String, dynamic>
          ? SupportSettings.fromJson(data['support'] as Map<String, dynamic>)
          : null,
      social: data['social'] is Map<String, dynamic>
          ? SocialSettings.fromJson(data['social'] as Map<String, dynamic>)
          : null,
    );
  }
}

class SupportSettings {
  final String? phone;
  final String? email;
  final String? website;
  final String? whatsapp;
  final String? address;

  const SupportSettings({
    this.phone,
    this.email,
    this.website,
    this.whatsapp,
    this.address,
  });

  factory SupportSettings.fromJson(Map<String, dynamic> json) {
    return SupportSettings(
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      website: json['website'] as String?,
      whatsapp: json['whatsapp'] as String?,
      address: json['address'] as String?,
    );
  }
}

class SocialSettings {
  final String? telegram;
  final String? tiktok;
  final String? instagram;
  final String? youtube;
  final String? twitter;
  final String? linkedin;

  const SocialSettings({
    this.telegram,
    this.tiktok,
    this.instagram,
    this.youtube,
    this.twitter,
    this.linkedin,
  });

  factory SocialSettings.fromJson(Map<String, dynamic> json) {
    return SocialSettings(
      telegram: json['telegram'] as String?,
      tiktok: json['tiktok'] as String?,
      instagram: json['instagram'] as String?,
      youtube: json['youtube'] as String?,
      twitter: json['twitter'] as String?,
      linkedin: json['linkedin'] as String?,
    );
  }

  /// Returns a list of non-null platform entries as (name, url) pairs
  List<({String name, String url})> get entries {
    return [
      if (telegram != null) (name: 'Telegram', url: telegram!),
      if (tiktok != null) (name: 'TikTok', url: tiktok!),
      if (instagram != null) (name: 'Instagram', url: instagram!),
      if (youtube != null) (name: 'YouTube', url: youtube!),
      if (twitter != null) (name: 'Twitter / X', url: twitter!),
      if (linkedin != null) (name: 'LinkedIn', url: linkedin!),
    ];
  }
}
