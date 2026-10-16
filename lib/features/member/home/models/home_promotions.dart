import 'package:niya_equb/features/member/home/models/banner.dart';
export 'package:niya_equb/features/member/home/models/banner.dart';

class HomePromotions {
  /// How long each banner stays on screen before the carousel slides on.
  ///
  /// Set in the admin panel (Banners > Slide duration) and sent with the
  /// banners as `banner_slide_duration`, in seconds. The server keeps it
  /// between 2 and 60; the same limits are applied here as well, so a reply
  /// cached before the setting existed, a missing field or a bad value can
  /// never make the carousel flip every frame or stop moving.
  static const int defaultSlideSeconds = 5;
  static const int minSlideSeconds = 2;
  static const int maxSlideSeconds = 60;

  final List<EqubBanner> banners;
  final List<CompanyFact> companyFacts;

  /// Seconds per banner, always within [minSlideSeconds]..[maxSlideSeconds].
  final int slideSeconds;

  HomePromotions({
    this.banners = const [],
    this.companyFacts = const [],
    int slideSeconds = defaultSlideSeconds,
  }) : slideSeconds = parseSlideSeconds(slideSeconds);

  /// Turns whatever the API sent into a usable number of seconds: a number, a
  /// numeric string ("20"), or nothing at all.
  static int parseSlideSeconds(Object? raw) {
    final num? value = switch (raw) {
      num n => n,
      String s => num.tryParse(s.trim()),
      _ => null,
    };
    if (value == null || !value.isFinite) return defaultSlideSeconds;
    if (value <= minSlideSeconds) return minSlideSeconds;
    if (value >= maxSlideSeconds) return maxSlideSeconds;
    return value.round();
  }

  factory HomePromotions.fromJson(Map<String, dynamic> json) {
    return HomePromotions(
      banners: (json['banners'] as List?)
              ?.map((e) => EqubBanner.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      companyFacts: (json['company_facts'] as List?)
              ?.map((e) => CompanyFact.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      slideSeconds: parseSlideSeconds(json['banner_slide_duration']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'banner_slide_duration': slideSeconds,
      'banners': banners.map((e) => e.toJson()).toList(),
      'company_facts': companyFacts.map((e) => e.toJson()).toList(),
    };
  }
}

class CompanyFact {
  final int? id;
  final String? label;
  final String? value;

  CompanyFact({
    this.id,
    this.label,
    this.value,
  });

  factory CompanyFact.fromJson(Map<String, dynamic> json) {
    return CompanyFact(
      id: json['id'] as int?,
      label: json['label']?.toString(),
      value: json['value']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'value': value,
    };
  }
}
