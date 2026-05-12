import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/freecell/freecell_screen.dart';
import '../features/klondike/klondike_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/style/style_screen.dart';
import '../features/solitaire_selector/selector_screen.dart';
import '../features/spider/spider_screen.dart';
import '../features/stats/stats_screen.dart';
import 'l10n/app_strings.dart';
import 'providers.dart';

/// Корневой виджет приложения.
class SolitaireApp extends ConsumerWidget {
  const SolitaireApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );
    final sys = WidgetsBinding.instance.platformDispatcher.locale;
    final locale = settings?.languageCode == null ? sys : Locale(settings!.languageCode!);

    return MaterialApp(
      title: AppStrings.of(locale).t('appTitle'),
      locale: locale,
      supportedLocales: AppStrings.supportedLocales,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      themeMode: settings?.themeMode ?? ThemeMode.system,
      // Единая визуальная система в стиле "карточный стол".
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF156A4B),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF156A4B),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF091913),
        useMaterial3: true,
        cardTheme: const CardThemeData(
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
        ),
      ),
      routes: {
        '/': (_) => const SelectorScreen(),
        '/klondike': (_) => const KlondikeScreen(),
        '/spider': (_) => const SpiderScreen(),
        '/freecell': (_) => const FreecellScreen(),
        '/stats': (_) => const StatsScreen(),
        '/settings': (_) => const SettingsScreen(),
        '/style': (_) => const StyleScreen(),
      },
    );
  }
}
