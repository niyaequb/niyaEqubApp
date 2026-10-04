import 'dart:convert';
import 'package:niya_equb/features/auth/models/user.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static SharedPreferences? _prefs;
  static const String _userKey = 'cached_user';
  static const String _tokenKey = 'access_token';
  static const String _refreshTokenKey = 'refresh_token';

  static Future<void> initialize() async {
    _prefs ??= await SharedPreferences.getInstance();
  }

  static Future<void> saveUser(UserModel user) async {
    await initialize();
    String userJson = jsonEncode(user.toJson());
    await _prefs?.setString(_userKey, userJson);
  }

  /// The cached user, or null when there isn't one that can be read.
  ///
  /// The try/catch is the upgrade guard, and it is not theoretical. This runs
  /// on the splash screen before a single frame is painted, against JSON that
  /// may have been written by ANY previous version of the app still installed
  /// out there — including builds predating the agent_profile and city fields.
  /// `UserModel.fromJson` does `id: json['id']` with no cast and no default,
  /// so one stored record missing an id, or holding it as a String, throws
  /// before there is any UI to show an error in. The process dies, the user
  /// sees "keeps stopping", and it happens on exactly the devices that had the
  /// old version — never on a clean install, which is why it survives testing.
  ///
  /// Returning null degrades to the login screen. Being asked to sign in again
  /// after an update is a minor annoyance; an app that cannot open is not.
  static UserModel? getUser() {
    final userJson = _prefs?.getString(_userKey);
    if (userJson == null) return null;

    try {
      final decoded = jsonDecode(userJson);
      if (decoded is! Map<String, dynamic>) return null;
      return UserModel.fromJson(decoded);
    } catch (_) {
      // Unreadable, so drop it rather than fail this way again on every
      // subsequent launch.
      _prefs?.remove(_userKey);
      return null;
    }
  }

  static Future<void> writeAccessToken(String token) async {
    await initialize();
    await _prefs?.setString(_tokenKey, token);
  }

  static Future<String?> getAccessToken() async {
    await initialize();
    return _prefs?.getString(_tokenKey);
  }

  static Future<void> writeRefreshToken(String token) async {
    await initialize();
    await _prefs?.setString(_refreshTokenKey, token);
  }

  static Future<String?> getRefreshToken() async {
    await initialize();
    return _prefs?.getString(_refreshTokenKey);
  }

  static Future<void> clearUserData() async {
    await initialize();
    await _prefs?.remove(_tokenKey);
    await _prefs?.remove(_refreshTokenKey);
    await _prefs?.remove(_userKey);
    await _prefs?.remove('fcm_token');
    // A half-finished payment belongs to whoever started it. Left behind, the
    // next person to sign in on this device would be dropped into that Equb.
    await _prefs?.remove(_paymentReturnKey);
  }

  /// An empty string counts as signed out, the same way the network layer
  /// reads it. `writeAccessToken('')` on a malformed login response used to
  /// leave the app thinking it had a session, which then failed on the first
  /// authenticated call.
  static Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.trim().isNotEmpty;
  }

  static Future<void> saveActiveDraw(
    int groupId,
    List<String> candidates,
    DateTime time,
  ) async {
    await initialize();
    final data = {'candidates': candidates, 'time': time.toIso8601String()};
    await _prefs?.setString('active_draw_$groupId', jsonEncode(data));
  }

  static Future<Map<String, dynamic>?> getActiveDraw(int groupId) async {
    await initialize();
    await _prefs
        ?.reload(); // Crucial for reading data written by background isolates
    final jsonStr = _prefs?.getString('active_draw_$groupId');
    if (jsonStr == null) return null;
    try {
      final data = jsonDecode(jsonStr);
      final time = DateTime.parse(data['time']);
      if (DateTime.now().toUtc().difference(time).inSeconds > 60) {
        await clearActiveDraw(groupId);
        return null;
      }
      return {
        'candidates': List<String>.from(data['candidates']),
        'time': time,
      };
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearActiveDraw(int groupId) async {
    await initialize();
    await _prefs?.remove('active_draw_$groupId');
  }

  // ---------------------------------------------------------------------------
  // Coming back from the bank app
  // ---------------------------------------------------------------------------

  static const String _paymentReturnKey = 'payment_return';

  /// How long a breadcrumb stays good. The bank's order expires after 120
  /// minutes, but a member who reopens the app hours later is not "coming
  /// back from paying" and should land on the home screen as usual.
  static const Duration _paymentReturnTtl = Duration(minutes: 30);

  /// Remembers which Equb the member was paying from, and for which order.
  ///
  /// The Dashen SuperApp reloads the mini app when it hands back after a
  /// payment. A reload wipes everything in memory — the screen stack, the
  /// bloc that was going to confirm the payment — and without this the member
  /// lands on the home screen with no sign that anything is happening.
  /// SplashScreen reads it back and reopens the Equb, still confirming.
  static Future<void> savePaymentReturn({
    required int groupId,
    required String reference,
  }) async {
    await initialize();
    await _prefs?.setString(
      _paymentReturnKey,
      jsonEncode({
        'group_id': groupId,
        'reference': reference,
        // Whose payment this is. Checked on the way back, so a different
        // member signing in on the same device is never dropped into it.
        'user_id': getUser()?.id,
        'at': DateTime.now().toUtc().toIso8601String(),
      }),
    );
  }

  static Future<void> clearPaymentReturn() async {
    await initialize();
    await _prefs?.remove(_paymentReturnKey);
  }

  /// The breadcrumb, if there is a recent one — and removes it either way.
  ///
  /// Consumed on read so it can only ever resume once. A breadcrumb that
  /// survived would reopen the same Equb on every launch for half an hour.
  static Future<({int groupId, String reference})?> takePaymentReturn() async {
    await initialize();
    final raw = _prefs?.getString(_paymentReturnKey);
    await _prefs?.remove(_paymentReturnKey);
    if (raw == null) return null;

    try {
      final data = jsonDecode(raw);
      if (data is! Map) return null;

      final groupId = data['group_id'];
      final reference = data['reference']?.toString() ?? '';
      final at = DateTime.tryParse(data['at']?.toString() ?? '');
      final owner = data['user_id'];

      if (groupId is! int || reference.isEmpty || at == null) return null;

      // Someone else's half-finished payment is not ours to resume.
      final me = getUser()?.id;
      if (owner is int && me != null && owner != me) return null;
      if (DateTime.now().toUtc().difference(at) > _paymentReturnTtl) {
        return null;
      }

      return (groupId: groupId, reference: reference);
    } catch (_) {
      return null;
    }
  }
}
