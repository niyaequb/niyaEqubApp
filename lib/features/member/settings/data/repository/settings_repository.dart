import 'dart:async';

import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/service/app_cache.dart';
import 'package:niya_equb/features/member/settings/data/models/settings_model.dart';
import 'package:niya_equb/features/member/settings/data/models/faq_model.dart';
import 'package:niya_equb/core/init/network_constant.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class SettingsRepository {
  final Dio dio;

  SettingsRepository({required this.dio});

  /// Settings change rarely, so the cached copy is what the profile and legal
  /// screens open with; the network answer just keeps it honest.
  SettingsModel? cachedSettings() {
    final cached = AppCache.read<Map<String, dynamic>>(CacheKeys.appSettings);
    if (cached == null) return null;
    try {
      return SettingsModel.fromJson(cached);
    } catch (_) {
      return null;
    }
  }

  List<FaqModel>? cachedFaqs() {
    final cached = AppCache.read<List<dynamic>>(CacheKeys.faqs);
    if (cached == null) return null;
    try {
      return cached
          .whereType<Map<String, dynamic>>()
          .map(FaqModel.fromJson)
          .toList();
    } catch (_) {
      return null;
    }
  }

  ResultFuture<SettingsModel> getSettings() async {
    try {
      final response = await dio.get('/settings');
      final raw = response.data;
      if (raw is Map<String, dynamic>) {
        unawaited(AppCache.write(CacheKeys.appSettings, raw));
      }
      final settings = SettingsModel.fromJson(
        raw is Map<String, dynamic> ? raw : {},
      );
      return Right(settings);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ??
          e.message ??
          'Failed to load settings';
      return Left(ServerFailure(message, e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  ResultFuture<List<FaqModel>> getFaqs() async {
    try {
      final response = await dio.get(MemberEndpoints.faqs());
      final raw = response.data;

      List<dynamic> list = [];
      if (raw is List) {
        list = raw;
      } else if (raw is Map && raw['data'] is List) {
        list = raw['data'] as List;
      } else if (raw is Map && raw['faqs'] is List) {
        list = raw['faqs'] as List;
      }

      unawaited(AppCache.write(CacheKeys.faqs, list));

      final faqs = list
          .whereType<Map<String, dynamic>>()
          .map(FaqModel.fromJson)
          .toList();
      return Right(faqs);
    } on DioException catch (e) {
      final message =
          e.response?.data?['message'] as String? ??
          e.message ??
          'Failed to load FAQs';
      return Left(ServerFailure(message, e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }
}

