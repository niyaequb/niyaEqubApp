// Package and plan names as a member reads them, in the app's language.
//
// WHY THIS EXISTS
//
// The six packages are fixed — Al-Sabr, Al-Nur, Iman, Raha, Special Ramadan
// Ekub and Hajj Ekub — but their names come from the server exactly as an
// admin typed them, in one language and with stray spaces ('ኢማን ', 'Raha
// Daily'). A member who had switched the app to English or Afaan Oromoo still
// read them in Amharic, and the list came back in whatever order they were
// created in.
//
// Each fixed package is recognised here by the words it is known by, in any
// of the three languages, and shown under its official name in the app's
// language (assets/lang/*.json, keys pkg_name_*), in the official order. A
// package or plan that is none of the six keeps the name it was given.
//
// The server orders the list the same way (EqubPackageController::LIST_ORDER);
// doing it here as well keeps a cached list, or an older server, in order.

import 'package:get/get.dart';

/// The six fixed packages. [FixedPackage.listOrder] sets the order the Equb
/// list shows them in.
enum FixedPackage {
  alSabr('pkg_name_al_sabr', 'Al-Sabr', [
    'sabr',
    'sabir',
    'sabrii',
    'alsabr',
    'ሰብር',
    'ሶብር',
  ]),
  alNur('pkg_name_al_nur', 'Al-Nur', ['nur', 'nuur', 'noor', 'alnur', 'ኑር']),
  iman('pkg_name_iman', 'Iman', [
    'iman',
    'eman',
    'imaana',
    'ኢማን',
    'ኢማን',
    'ኤማን',
  ]),
  raha('pkg_name_raha', 'Raha', [
    'raha',
    'rahaa',
    'ረሀ',
    'ራሀ',
    'ረሐ',
    'ራሐ',
    'ረሃ',
    'ራሃ',
  ]),
  ramadan('pkg_name_ramadan', 'Special Ramadan Ekub', [
    'ramadan',
    'ramadhan',
    'ramadaana',
    'ረመዳን',
    'ረመዷን',
    'ረማዳን',
  ]),
  hajj('pkg_name_hajj', 'Hajj Ekub', ['hajj', 'hajjii', 'ሀጅ', 'ሐጅ', 'ሃጅ']);

  const FixedPackage(this.key, this.englishName, this.words);

  /// Translation key of the official name.
  final String key;

  /// Shown when the language file has no entry for [key].
  final String englishName;

  /// What it is called, in any of the three languages. Latin words are matched
  /// as whole words, so "Suleiman" is not "iman"; Ethiopic ones anywhere in
  /// the name, because Amharic joins words onto them ("የሀጅ", of Hajj).
  final List<String> words;

  /// The official name in the app's current language.
  String get label {
    final text = key.tr;
    return text == key ? englishName : text;
  }

  // ==================================================================
  //  THE ORDER OF THE EQUB LIST
  //
  //  Move the lines below to change the order the packages appear in,
  //  on the Equb tab and everywhere else the app lists them. This is the
  //  only place it is set on the phone. Shortest term first:
  //
  //      Raha        3 months
  //      Iman        6 months
  //      Al-Nur     12 months
  //      Al-Sabr    24 months
  //      Ramadan    (seasonal)
  //      Hajj       (seasonal)
  //
  //  Group Equb ("Family") is not a package; the Equb tab always puts it
  //  last, under the list.
  //
  //  The server sorts its answer the same way, in
  //  Backend/app/Http/Controllers/Api/EqubPackageController.php (LIST_ORDER).
  //  Change both, or a freshly loaded list will be re-sorted here anyway.
  // ==================================================================
  static const List<FixedPackage> listOrder = [
    raha,
    iman,
    alNur,
    alSabr,
    ramadan,
    hajj,
  ];

  /// Checked in this order, so a name that mentions two packages resolves the
  /// way the server does when a name mentions more than one: Hajj first,
  /// Raha last. This is NOT the order of the list — that is [listOrder].
  static const List<FixedPackage> _matchOrder = [
    hajj,
    alSabr,
    alNur,
    iman,
    ramadan,
    raha,
  ];

  /// The fixed package [name] refers to, or null for any other name.
  static FixedPackage? of(String? name) {
    final text = (name ?? '').toLowerCase().trim();
    if (text.isEmpty) return null;

    final tokens = _tokens(text);
    for (final candidate in _matchOrder) {
      if (_knownBy(text, tokens, candidate.words)) return candidate;
    }
    return null;
  }
}

/// What to call a package: its official name in the app's language when it
/// is one of the six, otherwise the name it was given.
String packageDisplayName(String? name) {
  final fixed = FixedPackage.of(name);
  if (fixed != null) return fixed.label;

  final typed = name?.trim() ?? '';
  return typed.isEmpty ? 'Equb' : typed;
}

/// Where a package goes in the Equb list: the six in [FixedPackage.listOrder],
/// then anything else.
int packageRank(String? name) {
  final fixed = FixedPackage.of(name);
  if (fixed == null) return FixedPackage.listOrder.length;
  // indexOf cannot miss while listOrder holds all six; the guard is what
  // keeps a package dropped from that list out of the way instead of
  // throwing.
  final rank = FixedPackage.listOrder.indexOf(fixed);
  return rank < 0 ? FixedPackage.listOrder.length : rank;
}

/// What to call one plan (an Equb group) of a package.
///
/// Plans are named after their package and cycle — "Al-Nur Daily", "Raha
/// weekly", "ኢማን ወርሃዊ". Such a name is rebuilt in the app's language from the
/// package and the plan's cycle: "አል ኑር · ዕለታዊ". A name that says anything
/// more ("Raha for teachers", "Raha 2027", "Bilal Family") is the admin's or
/// the member's own and is shown as typed. With no name at all, the package's
/// name stands in for it.
///
/// The package the plan BELONGS to decides which package it is called, not
/// the words in its name: a plan that kept its old package's name after the
/// packages were renamed ("Eman daily" inside Al-Nur) still reads as the
/// package it is really in.
String planDisplayName({
  String? name,
  String? packageName,
  Object? frequencyDays,
}) {
  final typed = name?.trim() ?? '';
  if (typed.isNotEmpty && !_onlyPlanWords(typed)) return typed;

  final fixed = FixedPackage.of(packageName) ?? FixedPackage.of(typed);
  if (fixed == null) {
    return typed.isEmpty ? packageDisplayName(packageName) : typed;
  }

  final cycle = _cycleKey(frequencyDays) ?? _cycleIn(typed);
  return cycle == null ? fixed.label : '${fixed.label} · ${cycle.tr}';
}

final RegExp _separators = RegExp(r'[^a-z0-9\u1200-\u135F]+');
final RegExp _latinWord = RegExp(r'^[a-z]+$');

List<String> _tokens(String lowerCased) =>
    lowerCased.split(_separators).where((t) => t.isNotEmpty).toList();

bool _knownBy(String text, List<String> tokens, Iterable<String> words) {
  for (final word in words) {
    if (_latinWord.hasMatch(word)) {
      if (tokens.any(
        (t) => t == word || (word.length > 4 && t.startsWith(word)),
      )) {
        return true;
      }
    } else if (text.contains(word)) {
      return true;
    }
  }
  return false;
}

/// Words a plan name may be made of and still be "package + cycle": the
/// package's own words, cycle words, and filler such as "Equb" or "Al".
const Set<String> _planWords = {
  // English
  'al', 'the', 'equb', 'ekub', 'iqub', 'plan', 'package', 'special',
  'daily', 'weekly', 'monthly', 'day', 'week', 'month',
  // Afaan Oromoo
  'iqubii', 'addaa', 'guyyaa', 'guyyaan', 'torban', 'torbaniin', 'ji', 'a',
  'aan',
  // Amharic
  'አል', 'እቁብ', 'ዕቁብ', 'ልዩ', 'ዕለታዊ', 'የቀን', 'ቀን', 'ሳምንታዊ', 'የሳምንት',
  'ሳምንት', 'ወርሃዊ', 'ወርሐዊ', 'የወር', 'ወር',
};

bool _onlyPlanWords(String name) {
  final text = name.toLowerCase();
  final packageWords = [for (final p in FixedPackage.values) ...p.words];

  for (final token in _tokens(text)) {
    if (_planWords.contains(token)) continue;
    if (_knownBy(token, [token], packageWords)) continue;
    return false;
  }
  return true;
}

/// The translation key of a plan's cycle, from its contribution frequency.
String? _cycleKey(Object? frequencyDays) =>
    switch ('${frequencyDays ?? ''}'.trim()) {
      '1' => 'daily',
      '7' => 'weekly',
      '30' || '31' => 'monthly',
      _ => null,
    };

/// The cycle a plan's own name states, when the frequency is not known.
String? _cycleIn(String name) {
  final tokens = _tokens(name.toLowerCase()).toSet();
  if (tokens.intersection(const {'daily', 'day', 'ዕለታዊ', 'የቀን'}).isNotEmpty) {
    return 'daily';
  }
  if (tokens.intersection(const {
    'weekly',
    'week',
    'ሳምንታዊ',
    'የሳምንት',
  }).isNotEmpty) {
    return 'weekly';
  }
  if (tokens.intersection(const {
    'monthly',
    'month',
    'ወርሃዊ',
    'ወርሐዊ',
    'የወር',
  }).isNotEmpty) {
    return 'monthly';
  }
  return null;
}
