import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:niya_equb/core/constants/hive_constants.dart';

/// On-device response cache.
///
/// Screens read the last known payload from disk and paint straight away, then
/// the network response replaces it a moment later ("stale while revalidate").
/// The Equb list, packages and settings all come back instantly on a warm
/// start instead of sitting on a spinner.
///
/// Everything is a JSON string in a single Hive box. Hive is already a
/// dependency and is pure Dart, so this adds no plugin, no native code, no new
/// permission, and nothing that would change a Play Store or App Store
/// listing.
class AppCache {
  AppCache._();

  static Box? _box;

  static bool get isReady => _box?.isOpen == true;

  /// Opens the cache box. Call once from `main()` after `Hive.initFlutter()`.
  /// Failing to open must never block app start, so errors are swallowed and
  /// the cache simply stays disabled.
  static Future<void> initialize() async {
    if (isReady) return;
    try {
      _box = await Hive.openBox(HiveConstants.apiCacheBox);
    } catch (_) {
      _box = null;
    }
  }

  /// Reads a cached value, or null when it is missing, unreadable, or older
  /// than [maxAge]. Pass a null [maxAge] to accept an entry of any age — good
  /// for "show something immediately, refresh behind it" reads.
  static T? read<T>(String key, {Duration? maxAge}) {
    if (!isReady) return null;

    final raw = _box!.get(key);
    if (raw is! String) return null;

    try {
      final envelope = jsonDecode(raw);
      if (envelope is! Map) return null;

      final savedAt = DateTime.tryParse('${envelope['saved_at']}');
      if (savedAt == null) return null;
      if (maxAge != null && DateTime.now().difference(savedAt) > maxAge) {
        return null;
      }

      final value = envelope['value'];
      return value is T ? value : null;
    } catch (_) {
      return null;
    }
  }

  /// How long ago [key] was written, or null when nothing is stored.
  static Duration? ageOf(String key) {
    if (!isReady) return null;
    final raw = _box!.get(key);
    if (raw is! String) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final savedAt = DateTime.tryParse('${decoded['saved_at']}');
      return savedAt == null ? null : DateTime.now().difference(savedAt);
    } catch (_) {
      return null;
    }
  }

  /// Stores [value] (anything `jsonEncode` accepts) under [key].
  ///
  /// Deliberately fire-and-forget friendly: a cache write must never fail a
  /// request, so encode errors are ignored.
  static Future<void> write(String key, Object? value) async {
    if (!isReady) return;
    try {
      await _box!.put(
        key,
        jsonEncode({
          'saved_at': DateTime.now().toIso8601String(),
          'value': value,
        }),
      );
    } catch (_) {
      // Not cacheable — carry on with the live response.
    }
  }

  static Future<void> remove(String key) async {
    if (!isReady) return;
    try {
      await _box!.delete(key);
    } catch (_) {}
  }

  /// Wipes every cached response. Called on logout and account deletion so the
  /// next person to sign in on this phone never sees the previous account's
  /// groups, payments or settings.
  static Future<void> clear() async {
    if (!isReady) return;
    try {
      await _box!.clear();
    } catch (_) {}
  }
}

/// Cache keys, kept in one place so a rename can't silently orphan an entry.
class CacheKeys {
  const CacheKeys._();

  static const String equbPackages = 'member:equb-packages';
  static const String equbMemberships = 'member:equb-memberships';
  static const String promotions = 'member:promotions';
  static const String appSettings = 'app:settings';
  static const String faqs = 'app:faqs';
  static const String myGroupEqubs = 'member:my-equb-groups';
  static const String myEqubInvitations = 'member:equb-invitations';

  /// The running Equbs a member can build a group inside. Drives the "New
  /// Group Equb" picker, and changes rarely.
  static const String joinableEqubs = 'member:joinable-equb-groups';

  /// Groups are cached per package filter, plus one bucket for "all".
  static String equbGroups(int? packageId) =>
      'member:equb-groups:${packageId ?? 'all'}';

  // The three calls behind the group detail screen, cached per group so
  // reopening one paints immediately.
  static String groupEqub(int id) => 'member:group-equb:$id';
  static String groupLedger(int id) => 'member:group-ledger:$id';
  static String groupDraws(int id) => 'member:group-draws:$id';
}
