import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers.dart';

/// Экран настроек приложения.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  static String _languageDisplay(AppStrings s, String? code) => switch (code) {
        null => s.t('system'),
        'ru' => s.t('langRu'),
        _ => s.t('langEn'),
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = AppStrings.of(Localizations.localeOf(context));
    final data = ref.watch(settingsProvider).maybeWhen(
          data: (v) => v,
          orElse: () => null,
        );
    if (data == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: kAppTableBackgroundDecoration,
            child: const Center(child: CircularProgressIndicator(color: Colors.white70)),
          ),
        ),
      );
    }

    Future<void> save(AppSettings v) => ref.read(settingsProvider.notifier).save(v);

    return DecoratedBox(
      decoration: kAppTableBackgroundDecoration,
      child: Theme(
        data: themeOnTable(context, formFields: true),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(title: Text(s.t('settings'))),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _ChoiceField(
                label: s.t('language'),
                valueText: _languageDisplay(s, data.languageCode),
                onTap: () async {
                  final r = await showTablePickerSheet<String?>(
                    context: context,
                    title: s.t('language'),
                    current: data.languageCode,
                    options: [
                      (value: null, label: s.t('system')),
                      (value: 'ru', label: s.t('langRu')),
                      (value: 'en', label: s.t('langEn')),
                    ],
                  );
                  if (r != null) save(data.copyWith(languageCode: r.value));
                },
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                title: Text(s.t('sound')),
                value: data.soundOn,
                onChanged: (v) => save(data.copyWith(soundOn: v)),
              ),
              const SizedBox(height: 6),
              SwitchListTile(
                title: Text(s.t('vibration')),
                value: data.vibrationOn,
                onChanged: (v) => save(data.copyWith(vibrationOn: v)),
              ),
              const SizedBox(height: 6),
              _ChoiceField(
                label: s.t('dealSpeed'),
                valueText: switch (data.dealSpeed) {
                  DealSpeed.fast => s.t('dealSpeedFast'),
                  DealSpeed.normal => s.t('dealSpeedNormal'),
                  DealSpeed.cinematic => s.t('dealSpeedCinematic'),
                },
                onTap: () async {
                  final r = await showTablePickerSheet<DealSpeed>(
                    context: context,
                    title: s.t('dealSpeed'),
                    current: data.dealSpeed,
                    options: [
                      (value: DealSpeed.fast, label: s.t('dealSpeedFast')),
                      (value: DealSpeed.normal, label: s.t('dealSpeedNormal')),
                      (value: DealSpeed.cinematic, label: s.t('dealSpeedCinematic')),
                    ],
                  );
                  if (r != null) save(data.copyWith(dealSpeed: r.value));
                },
              ),
              const SizedBox(height: 6),
              _ChoiceField(
                label: s.t('theme'),
                valueText: switch (data.themeMode) {
                  ThemeMode.system => s.t('system'),
                  ThemeMode.light => s.t('light'),
                  ThemeMode.dark => s.t('dark'),
                },
                onTap: () async {
                  final r = await showTablePickerSheet<ThemeMode>(
                    context: context,
                    title: s.t('theme'),
                    current: data.themeMode,
                    options: [
                      (value: ThemeMode.system, label: s.t('system')),
                      (value: ThemeMode.light, label: s.t('light')),
                      (value: ThemeMode.dark, label: s.t('dark')),
                    ],
                  );
                  if (r != null) save(data.copyWith(themeMode: r.value));
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Поле настроек: вид как у [InputDecorator], по тапу — выбор через нижний лист.
class _ChoiceField extends StatelessWidget {
  const _ChoiceField({
    required this.label,
    required this.valueText,
    required this.onTap,
  });

  final String label;
  final String valueText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: kTableFieldBorderRadius,
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: const Icon(Icons.unfold_more_rounded, color: Colors.white70),
          ),
          child: Text(valueText, style: const TextStyle(color: Colors.white, fontSize: 16)),
        ),
      ),
    );
  }
}
