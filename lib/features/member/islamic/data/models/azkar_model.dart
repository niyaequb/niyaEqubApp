import 'package:flutter/material.dart';

/// A single dhikr within a category.
class Dhikr {
  final String arabic;
  final String transliteration;
  final String translation;

  /// How many times it is recited.
  final int repeat;

  /// Where it comes from — always shown, so the user can verify.
  final String reference;

  /// Optional note on the reward or occasion.
  final String? virtue;

  const Dhikr({
    required this.arabic,
    required this.transliteration,
    required this.translation,
    this.repeat = 1,
    required this.reference,
    this.virtue,
  });
}

/// A themed collection: morning, evening, after prayer and so on.
class AzkarCategory {
  final String id;
  final String titleEn;
  final String titleAr;
  final String subtitleEn;
  final String imagePath;
  final Color accent;
  final List<Dhikr> items;

  const AzkarCategory({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.imagePath,
    required this.accent,
    required this.items,
  });

  /// Total recitations including repeats — shown as the progress denominator.
  int get totalRepeats =>
      items.fold<int>(0, (sum, item) => sum + item.repeat);
}