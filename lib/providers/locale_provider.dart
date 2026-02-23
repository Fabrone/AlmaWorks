import 'package:flutter/material.dart';

/// Supported app languages.
enum AppLanguage { english, swahili, italian }

/// Maps each language to its [Locale].
const Map<AppLanguage, Locale> kLanguageLocales = {
  AppLanguage.english: Locale('en'),
  AppLanguage.swahili: Locale('sw'),
  AppLanguage.italian: Locale('it'),
};

/// Display labels shown in the UI.
const Map<AppLanguage, String> kLanguageLabels = {
  AppLanguage.english: 'English',
  AppLanguage.swahili: 'Swahili',
  AppLanguage.italian: 'Italian',
};

/// Flag emoji for each language (optional, used in the picker).
const Map<AppLanguage, String> kLanguageFlags = {
  AppLanguage.english: '🇬🇧',
  AppLanguage.swahili: '🇰🇪',
  AppLanguage.italian: '🇮🇹',
};

/// A [ChangeNotifier] that holds the currently selected locale.
/// Wrap your [MaterialApp] with a [ListenableBuilder] (or use Provider/Riverpod)
/// and pass [localeProvider.locale] to [MaterialApp.locale].
///
/// Example setup in main.dart:
/// ```dart
/// final localeProvider = LocaleProvider();
///
/// runApp(
///   ListenableBuilder(
///     listenable: localeProvider,
///     builder: (context, _) => MaterialApp(
///       locale: localeProvider.locale,
///       supportedLocales: LocaleProvider.supportedLocales,
///       localizationsDelegates: AppLocalizations.localizationsDelegates,
///       home: const HomeScreen(),
///     ),
///   ),
/// );
/// ```
class LocaleProvider extends ChangeNotifier {
  AppLanguage _language = AppLanguage.english;

  AppLanguage get language => _language;
  Locale get locale => kLanguageLocales[_language]!;
  String get label => kLanguageLabels[_language]!;

  static List<Locale> get supportedLocales => kLanguageLocales.values.toList();

  /// Switch to a new language and notify all listeners.
  void setLanguage(AppLanguage language) {
    if (_language == language) return;
    _language = language;
    notifyListeners();
  }

  /// Convenience: set language from its display label string.
  void setLanguageByLabel(String label) {
    final entry = kLanguageLabels.entries.firstWhere(
      (e) => e.value == label,
      orElse: () => const MapEntry(AppLanguage.english, 'English'),
    );
    setLanguage(entry.key);
  }
}