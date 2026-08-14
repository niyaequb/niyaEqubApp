import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:niya_equb/core/init/failures.dart';
import 'package:niya_equb/core/init/network_constant.dart';
import 'package:niya_equb/core/service/dio_error_handler.dart';

typedef ResultFuture<T> = Future<Either<Failure, T>>;

class EkubDrawRepository {
  final Dio dio;

  EkubDrawRepository({required this.dio});

  ResultFuture<Map<String, dynamic>> fetchDrawData() async {
    try {
      final result = await dio.get(MemberEndpoints.equbDraws());

      final raw = result.data;
      if (raw == null) {
        return Left(
          ServerFailure("No data returned from server", result.statusCode),
        );
      }

      // Expected structure: { "categories": [...], "winners": [...] }
      final Map<String, dynamic> data = raw is Map<String, dynamic> ? raw : {};

      final categoriesList = (data['categories'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EkubDrawCategory.fromJson)
          .toList();

      final winnersList = (data['winners'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(EkubWinner.fromJson)
          .toList();

      return Right({'categories': categoriesList, 'winners': winnersList});
    } on DioException catch (e) {
      return Left(ServerFailure(handleDioError(e), e.response?.statusCode));
    } catch (e) {
      return Left(ServerFailure(e.toString(), null));
    }
  }

  // Keeping old methods for temporary backward compatibility or if needed as fallbacks
  List<EkubDrawCategory> getCategories() {
    return const <EkubDrawCategory>[
      EkubDrawCategory(
        name: '100 Birr/day',
        nextDrawLabel: 'Next draw in 5 days',
        icon: Icons.layers_rounded,
      ),
      EkubDrawCategory(
        name: '250 Birr/day',
        nextDrawLabel: 'Next draw in 12 days',
        icon: Icons.layers_rounded,
      ),
      EkubDrawCategory(
        name: '500 Birr/day',
        nextDrawLabel: 'Next draw in 20 days',
        icon: Icons.layers_rounded,
      ),
    ];
  }

  List<EkubWinner> getWinners() {
    final now = DateTime.now();
    return <EkubWinner>[
      EkubWinner(
        name: 'Bekele K.',
        category: '100 Birr/day',
        time: now.subtract(const Duration(days: 1)),
      ),
      EkubWinner(
        name: 'Sara T.',
        category: '250 Birr/day',
        time: now.subtract(const Duration(days: 6)),
      ),
      EkubWinner(
        name: 'Yared M.',
        category: '500 Birr/day',
        time: now.subtract(const Duration(days: 12)),
      ),
    ];
  }
}

class EkubDrawCategory {
  final String name;
  final String nextDrawLabel;
  final IconData icon;

  const EkubDrawCategory({
    required this.name,
    required this.nextDrawLabel,
    this.icon = Icons.layers_rounded,
  });

  factory EkubDrawCategory.fromJson(Map<String, dynamic> json) {
    return EkubDrawCategory(
      name: json['name']?.toString() ?? '',
      nextDrawLabel:
          json['next_draw_label']?.toString() ??
          json['nextDrawLabel']?.toString() ??
          '',
      // icon can be mapped if coming from API as string or int, defaulting for now
    );
  }
}

class EkubWinner {
  final String name;
  final String category;
  final DateTime time;

  EkubWinner({required this.name, required this.category, required this.time});

  factory EkubWinner.fromJson(Map<String, dynamic> json) {
    final timeStr = json['time']?.toString() ?? json['created_at']?.toString();
    return EkubWinner(
      name: json['name']?.toString() ?? '',
      category: json['category']?.toString() ?? '',
      time: timeStr != null
          ? DateTime.tryParse(timeStr) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
