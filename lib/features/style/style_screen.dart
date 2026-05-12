import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers.dart';
import '../../shared/widgets/game_ui_common.dart';

/// Экран "Стиль": внешний вид стола и карт.
class StyleScreen extends ConsumerStatefulWidget {
  const StyleScreen({super.key});

  @override
  ConsumerState<StyleScreen> createState() => _StyleScreenState();
}

class _StyleScreenState extends ConsumerState<StyleScreen> {
  // 0 = фон, 1 = рубашка, 2 = стиль карт, 3 = декор (заглушка).
  int _tabIndex = 0;

  @override
  Widget build(BuildContext context) {
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
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    Future<void> save(AppSettings v) =>
        ref.read(settingsProvider.notifier).save(v);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: DecoratedBox(
        decoration: tableBackgroundDecoration(data),
        child: SafeArea(
          child: Column(
            children: [
              // Верхняя шапка как в референсе: крестик + заголовок.
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                child: Row(
                  children: [
                    topCircleButton(Icons.close_rounded, () => Navigator.pop(context)),
                    const SizedBox(width: 10),
                    Text(
                      'персональные настройки',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 30 / 2,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Превью карт.
              _StylePreview(settings: data),
              const Spacer(),
              // Нижняя панель выбора "как в макете".
              Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: Color(0xFFE8E8E8),
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD9D9D9),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        children: [
                          _tabButton(0, Icons.image, const Color(0xFF0E8E5A)),
                          _tabButton(1, Icons.style_rounded, const Color(0xFF7A7A7A)),
                          _tabButton(2, Icons.grid_3x3_rounded, const Color(0xFF7A7A7A)),
                          _tabButton(3, Icons.auto_awesome, const Color(0xFF7A7A7A)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    if (_tabIndex == 0)
                      _tableChoices(data, save, s)
                    else if (_tabIndex == 1)
                      _backChoices(data, save, s)
                    else if (_tabIndex == 2)
                      _faceChoices(data, save, s)
                    else
                      const Text(
                        'Скоро: эффекты и анимации',
                        style: TextStyle(
                          color: Color(0xFF525252),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tabButton(int index, IconData icon, Color iconColor) {
    final selected = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tabIndex = index),
        child: Container(
          height: 40,
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF0E8E5A) : Colors.transparent,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Icon(icon, color: selected ? Colors.white : iconColor),
        ),
      ),
    );
  }

  Widget _tableChoices(
    AppSettings data,
    Future<void> Function(AppSettings) save,
    AppStrings s,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _swatchTile(
          selected: data.tableBackgroundStyle == TableBackgroundStyle.green,
          label: s.t('styleTableGreen'),
          child: const _BgPreview(
            colors: [Color(0xFF1C7E3D), Color(0xFF0F5F34)],
          ),
          onTap: () => save(
            data.copyWith(tableBackgroundStyle: TableBackgroundStyle.green),
          ),
        ),
        _swatchTile(
          selected: data.tableBackgroundStyle == TableBackgroundStyle.blue,
          label: s.t('styleTableBlue'),
          child: const _BgPreview(
            colors: [Color(0xFF1B4F8A), Color(0xFF0E2E56)],
          ),
          onTap: () => save(
            data.copyWith(tableBackgroundStyle: TableBackgroundStyle.blue),
          ),
        ),
        _swatchTile(
          selected: data.tableBackgroundStyle == TableBackgroundStyle.dark,
          label: s.t('styleTableDark'),
          child: const _BgPreview(
            colors: [Color(0xFF111418), Color(0xFF07090B)],
          ),
          onTap: () => save(
            data.copyWith(tableBackgroundStyle: TableBackgroundStyle.dark),
          ),
        ),
      ],
    );
  }

  Widget _backChoices(
    AppSettings data,
    Future<void> Function(AppSettings) save,
    AppStrings s,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _swatchTile(
          selected: data.cardBack == 'blue',
          label: s.t('styleBackBlue'),
          child: const _BgPreview(
            colors: [Color(0xFF2E5EA8), Color(0xFF1D4178)],
          ),
          onTap: () => save(data.copyWith(cardBack: 'blue')),
        ),
        _swatchTile(
          selected: data.cardBack == 'red',
          label: s.t('styleBackRed'),
          child: const _BgPreview(
            colors: [Color(0xFFA83A3A), Color(0xFF7A1D1D)],
          ),
          onTap: () => save(data.copyWith(cardBack: 'red')),
        ),
      ],
    );
  }

  Widget _faceChoices(
    AppSettings data,
    Future<void> Function(AppSettings) save,
    AppStrings s,
  ) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _swatchTile(
          selected: data.cardFaceStyle == CardFaceStyle.classic,
          label: s.t('styleFaceClassic'),
          child: const _CardFacePreview(classic: true),
          onTap: () => save(
            data.copyWith(cardFaceStyle: CardFaceStyle.classic),
          ),
        ),
        _swatchTile(
          selected: data.cardFaceStyle == CardFaceStyle.minimal,
          label: s.t('styleFaceMinimal'),
          child: const _CardFacePreview(classic: false),
          onTap: () => save(
            data.copyWith(cardFaceStyle: CardFaceStyle.minimal),
          ),
        ),
      ],
    );
  }

  Widget _swatchTile({
    required bool selected,
    required String label,
    required Widget child,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 92,
                  height: 132,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: selected ? const Color(0xFF0E8E5A) : Colors.transparent,
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.white,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: child,
                  ),
                ),
                if (selected)
                  const Positioned(
                    right: -2,
                    top: -2,
                    child: CircleAvatar(
                      radius: 13,
                      backgroundColor: Color(0xFF0E8E5A),
                      child: Icon(Icons.check, size: 16, color: Colors.white),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF525252),
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Верхнее превью: несколько карт и рубашка.
class _StylePreview extends StatelessWidget {
  const _StylePreview({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final red = const Color(0xFFB42020);
    final black = const Color(0xFF1B1B1B);
    return Material(
      color: Colors.transparent,
      child: SizedBox(
        height: 120,
        child: Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _previewFaceCard(
                label: 'K ♣',
                color: black,
                classic: settings.cardFaceStyle == CardFaceStyle.classic,
              ),
              const SizedBox(width: 8),
              _previewFaceCard(
                label: '10 ♥',
                color: red,
                classic: settings.cardFaceStyle == CardFaceStyle.classic,
              ),
              const SizedBox(width: 8),
              _previewFaceCard(
                label: '2 ♣',
                color: black,
                classic: settings.cardFaceStyle == CardFaceStyle.classic,
              ),
              const SizedBox(width: 8),
              _previewBackCard(settings.cardBack),
            ],
          ),
        ),
      ),
    );
  }

  Widget _previewFaceCard({
    required String label,
    required Color color,
    required bool classic,
  }) {
    final rank = label.split(' ').first;
    final suit = label.split(' ').last;
    return Container(
      width: 62,
      height: 88,
      // В превью дублируем отступы minimal как в игре.
      padding: classic
          ? const EdgeInsets.all(6)
          : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: classic
          ? Stack(
              children: [
                Text(
                  '$rank\n$suit',
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.0,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suit,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.28),
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: 3.1415926,
                    child: Text(
                      '$rank\n$suit',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                Positioned(
                  left: 4,
                  top: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rank,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 18,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Text(
                          suit,
                          style: TextStyle(
                            color: color,
                            fontWeight: FontWeight.w800,
                            fontSize: 19,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suit,
                    style: TextStyle(
                      color: color.withValues(alpha: 0.24),
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _previewBackCard(String back) {
    return Container(
      width: 62,
      height: 88,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: back == 'red'
              ? const [Color(0xFFA83A3A), Color(0xFF7A1D1D)]
              : const [Color(0xFF2E5EA8), Color(0xFF1D4178)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.white70, width: 1.1),
      ),
    );
  }
}

/// Маленький прямоугольный превью-фрагмент фона.
class _BgPreview extends StatelessWidget {
  const _BgPreview({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

/// Мини-превью лицевой карты в плитке.
class _CardFacePreview extends StatelessWidget {
  const _CardFacePreview({required this.classic});

  final bool classic;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFB42020);
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(8),
      child: classic
          ? Stack(
              children: [
                const Text(
                  'A\n♥',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    height: 1.0,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '♥',
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.28),
                      fontSize: 28,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: 3.1415926,
                    child: const Text(
                      'A\n♥',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                Positioned(
                  left: 4,
                  top: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'A',
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                      Padding(
                        padding: EdgeInsets.only(left: 3),
                        child: Text(
                          '♥',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    '♥',
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.24),
                      fontWeight: FontWeight.w800,
                      fontSize: 27,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

