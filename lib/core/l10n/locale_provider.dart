import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String kAppLocalePreferenceKey = 'appLocale';
const String kDefaultAppLanguageCode = 'en';

const Set<String> kSupportedAppLanguageCodes = {'en', 'id'};

final localeControllerProvider =
    StateNotifierProvider<LocaleController, Locale>((ref) {
  return LocaleController();
});

class LocaleController extends StateNotifier<Locale> {
  LocaleController() : super(const Locale(kDefaultAppLanguageCode)) {
    _load();
  }

  Future<void> setLanguageCode(String languageCode) async {
    if (!kSupportedAppLanguageCodes.contains(languageCode)) return;
    state = Locale(languageCode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(kAppLocalePreferenceKey, languageCode);
  }

  Future<void> reload() => _load();

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(kAppLocalePreferenceKey);
    if (saved != null && kSupportedAppLanguageCodes.contains(saved)) {
      state = Locale(saved);
    }
  }
}
