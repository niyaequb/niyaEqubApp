import 'package:shared_preferences/shared_preferences.dart';

/// Thin holder for the [SharedPreferences] instance, resolved through get_it.
///
/// The accessors this class used to expose now live on PreferencesService and
/// the Hive settings box. It is kept because it is still registered in the
/// injector and handed the shared SharedPreferences instance — [preferences]
/// is public so that instance is reachable rather than sitting unread behind a
/// private field.
class AppSharedPrefs {
  final SharedPreferences preferences;

  const AppSharedPrefs(this.preferences);
}
