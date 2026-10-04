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

  /// How many times the whole sequence of [items] is performed end to end.
  ///
  /// Almost every category is a flat list read once, which is why this
  /// defaults to 1. Tawaf is not: it is seven circuits of the Ka'bah, and
  /// within each circuit the same short sequence is said once — at the Black
  /// Stone, during the circuit, and between the Yamani corner and the Stone.
  ///
  /// Modelling that as "say the first dhikr seven times" was wrong in a way
  /// that matters: a pilgrim following the counter would stand at the Black
  /// Stone repeating the takbir seven times over and then walk one lap,
  /// instead of walking seven. The repetition belongs to the circuit, not to
  /// the dhikr.
  final int cycles;

  /// Translation key for the name of one cycle — 'circuit' for tawaf.
  /// Only read when [cycles] is greater than 1.
  final String? cycleLabelKey;

  const AzkarCategory({
    required this.id,
    required this.titleEn,
    required this.titleAr,
    required this.subtitleEn,
    required this.imagePath,
    required this.accent,
    required this.items,
    this.cycles = 1,
    this.cycleLabelKey,
  });

  /// True when this category is performed in repeated rounds.
  bool get hasCycles => cycles > 1;

  /// Recitations in a single pass through [items].
  int get repeatsPerCycle =>
      items.fold<int>(0, (sum, item) => sum + item.repeat);

  /// Every recitation required to finish the category, across all cycles —
  /// the denominator behind the progress bar.
  int get totalRepeats => repeatsPerCycle * cycles;
}