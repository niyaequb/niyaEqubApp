import 'package:niya_equb/features/member/home/models/banner.dart';
export 'package:niya_equb/features/member/home/models/banner.dart';

class HomePromotions {
  final List<EqubBanner> banners;
  final List<CompanyFact> companyFacts;

  HomePromotions({
    this.banners = const [],
    this.companyFacts = const [],
  });

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
    );
  }

  Map<String, dynamic> toJson() {
    return {
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
