import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';
import 'package:niya_equb/core/service/shared_preference_service.dart';
import 'package:niya_equb/core/util/logger.dart';
import 'package:niya_equb/features/auth/models/user.dart';
import 'package:niya_equb/features/member/home/models/home_promotions.dart';
import 'package:niya_equb/features/member/packages/data/repository/ekub_packages_repository.dart';

class EkubHomeRepository {
  final Dio dio;

  EkubHomeRepository({required this.dio});

  UserModel? getCachedUser() => PreferencesService.getUser();

  /// Banners and company facts from the last successful fetch, so the home
  /// screen is not empty above the fold while the request is in flight.
  HomePromotions? cachedPromotions() {
    final cached = AppCache.read<Map<String, dynamic>>(CacheKeys.promotions);
    if (cached == null) return null;
    try {
      return HomePromotions.fromJson(cached);
    } catch (_) {
      return null;
    }
  }

  ResultFuture<HomePromotions> fetchPromotions() async {
    try {
      final response = await dio.get(MemberEndpoints.banners());
      final data = response.data;
      logger(data);

      if (data is Map<String, dynamic>) {
        unawaited(AppCache.write(CacheKeys.promotions, data));
        return Right(HomePromotions.fromJson(data));
      }
      return Right(HomePromotions());
    } on DioException catch (e) {
      logger(e.response?.data);
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  EkubHomeData getHomeData() {
    return const EkubHomeData(
      totalSaved: 1250,
      activePackageLabel: '100 Birr/day',
      activePackageDurationLabel: '3y 3m duration',
      todayDueLabel: '100 Birr',
      todayDueSubtitle: 'Pay before midnight',
      nextDrawLabel: 'Category A',
      nextDrawSubtitle: 'In 5 days',
      referralCode: 'NIYA-4821',
      activities: [
        EkubHomeActivity(
          icon: Icons.payments_rounded,
          title: 'Contribution marked as paid',
          subtitle: '100 Birr/day • Today',
        ),
        EkubHomeActivity(
          icon: Icons.emoji_events_rounded,
          title: 'Lucky draw winners announced',
          subtitle: 'Category A • Yesterday',
        ),
        EkubHomeActivity(
          icon: Icons.policy_rounded,
          title: 'Terms & Conditions updated',
          subtitle: 'Please review the latest terms',
        ),
      ],
    );
  }
}

class EkubHomeData {
  final int totalSaved;
  final String activePackageLabel;
  final String activePackageDurationLabel;
  final String todayDueLabel;
  final String todayDueSubtitle;
  final String nextDrawLabel;
  final String nextDrawSubtitle;
  final String referralCode;
  final List<EkubHomeActivity> activities;

  const EkubHomeData({
    required this.totalSaved,
    required this.activePackageLabel,
    required this.activePackageDurationLabel,
    required this.todayDueLabel,
    required this.todayDueSubtitle,
    required this.nextDrawLabel,
    required this.nextDrawSubtitle,
    required this.referralCode,
    required this.activities,
  });
}

class EkubHomeActivity {
  final IconData icon;
  final String title;
  final String subtitle;

  const EkubHomeActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
  });
}
