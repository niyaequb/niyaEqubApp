import 'package:flutter_test/flutter_test.dart';
import 'package:niya_equb/features/member/home/models/home_promotions.dart';

void main() {
  group('HomePromotions slide duration', () {
    test('reads banner_slide_duration from the API reply', () {
      final promotions = HomePromotions.fromJson({
        'banner_slide_duration': 20,
        'banners': [],
        'company_facts': [],
      });

      expect(promotions.slideSeconds, 20);
    });

    test('falls back to 5 seconds when the field is missing', () {
      // An older server, or a reply cached before the setting existed.
      expect(HomePromotions.fromJson({'banners': []}).slideSeconds, 5);
      expect(HomePromotions().slideSeconds, 5);
    });

    test('accepts numeric strings and decimals', () {
      expect(HomePromotions.parseSlideSeconds('12'), 12);
      expect(HomePromotions.parseSlideSeconds(' 12 '), 12);
      expect(HomePromotions.parseSlideSeconds(7.6), 8);
    });

    test('keeps the value between 2 and 60 seconds', () {
      expect(HomePromotions.parseSlideSeconds(0), 2);
      expect(HomePromotions.parseSlideSeconds(1), 2);
      expect(HomePromotions.parseSlideSeconds(-30), 2);
      expect(HomePromotions.parseSlideSeconds(2), 2);
      expect(HomePromotions.parseSlideSeconds(60), 60);
      expect(HomePromotions.parseSlideSeconds(61), 60);
      expect(HomePromotions.parseSlideSeconds(100000), 60);
    });

    test('ignores values that are not numbers', () {
      expect(HomePromotions.parseSlideSeconds(null), 5);
      expect(HomePromotions.parseSlideSeconds('soon'), 5);
      expect(HomePromotions.parseSlideSeconds(''), 5);
      expect(HomePromotions.parseSlideSeconds(true), 5);
      expect(HomePromotions.parseSlideSeconds(double.nan), 5);
      expect(HomePromotions.parseSlideSeconds(double.infinity), 5);
      expect(HomePromotions.parseSlideSeconds([20]), 5);
    });

    test('survives a round trip through the cache', () {
      final saved = HomePromotions(slideSeconds: 30).toJson();

      expect(HomePromotions.fromJson(saved).slideSeconds, 30);
    });
  });
}
