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
}
