import 'package:flutter/material.dart';

import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';

/// Экран «Политика конфиденциальности»: текст из ассетов приложения.
/// Русская версия — `privacy_policy.txt`, английская — `privacy_policy_en.txt`.
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String _assetRu = 'assets/legal/privacy_policy.txt';
  static const String _assetEn = 'assets/legal/privacy_policy_en.txt';

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(Localizations.localeOf(context));
    final isRu = Localizations.localeOf(context).languageCode == 'ru';
    final asset = isRu ? _assetRu : _assetEn;

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: Text(s.t('privacyPolicy'))),
      body: DecoratedBox(
        decoration: kAppTableBackgroundDecoration,
        child: SafeArea(
          child: FutureBuilder<String>(
            future: DefaultAssetBundle.of(context).loadString(asset),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const SizedBox.shrink();
              }
              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.white70),
                );
              }
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: SelectableText(
                  snapshot.data!,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    height: 1.45,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
