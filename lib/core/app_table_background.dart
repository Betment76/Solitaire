import 'package:flutter/material.dart';

import 'models/app_settings.dart';

/// Единый фон «зелёное сукно» (как на экране Косынки) — для всех экранов приложения.
const BoxDecoration kAppTableBackgroundDecoration = BoxDecoration(
  gradient: LinearGradient(
    colors: [Color(0xFF1C7E3D), Color(0xFF0F5F34)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  ),
);

/// Фон стола с учётом пользовательского стиля.
BoxDecoration tableBackgroundDecoration(AppSettings? s) {
  final style = s?.tableBackgroundStyle ?? TableBackgroundStyle.green;
  return switch (style) {
    TableBackgroundStyle.green => kAppTableBackgroundDecoration,
    TableBackgroundStyle.blue => const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1B4F8A), Color(0xFF0E2E56)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    TableBackgroundStyle.dark => const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF111418), Color(0xFF07090B)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
  };
}

/// Фон нижнего листа выбора (полупрозрачный, в тон сукну).
const Color kTableSheetSurface = Color(0xE6125A3D);

/// Скругление полей ввода на экране настроек.
const BorderRadius kTableFieldBorderRadius = BorderRadius.all(Radius.circular(8));

/// Длительность и кривые появления/схлопывания нижнего листа ([showModalBottomSheet] + [AnimationStyle]).
const AnimationStyle kTablePickerSheetAnimation = AnimationStyle(
  duration: Duration(milliseconds: 420),
  reverseDuration: Duration(milliseconds: 340),
  curve: Curves.easeOutCubic,
  reverseCurve: Curves.easeInCubic,
);

/// Результат выбора из [showTablePickerSheet] (отличается от закрытия по барьеру, когда возвращается null).
@immutable
class TablePickResult<T> {
  const TablePickResult(this.value);
  final T value;
}

/// Нижний модальный лист со списком вариантов в стиле стола.
Future<TablePickResult<T>?> showTablePickerSheet<T>({
  required BuildContext context,
  required String title,
  required List<({T value, String label})> options,
  required T current,
}) {
  return showModalBottomSheet<TablePickResult<T>>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    sheetAnimationStyle: kTablePickerSheetAnimation,
    builder: (ctx) {
      final bottom = MediaQuery.paddingOf(ctx).bottom;
      final routeAnim = ModalRoute.of(ctx)?.animation;
      final sheetChild = Theme(
        data: themeOnTable(ctx),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: kTableSheetSurface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(18), bottom: Radius.circular(12)),
                border: Border.all(color: Colors.white24),
                boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 14, offset: Offset(0, 4))],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      margin: const EdgeInsets.only(top: 10, bottom: 6),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(color: Colors.white30, borderRadius: BorderRadius.circular(999)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  const Divider(height: 1, color: Colors.white24),
                  for (final o in options)
                    ListTile(
                      selected: o.value == current,
                      selectedTileColor: Colors.white12,
                      title: Text(o.label),
                      trailing: o.value == current ? const Icon(Icons.check_rounded, color: Colors.white) : null,
                      onTap: () => Navigator.pop(ctx, TablePickResult(o.value)),
                    ),
                  SizedBox(height: bottom > 0 ? bottom : 8),
                ],
              ),
            ),
          ),
        ),
      );
      // Доп. плавность: затухание и лёгкий сдвиг вверх по ходу того же route.animation.
      if (routeAnim == null) return sheetChild;
      final curved = CurvedAnimation(
        parent: routeAnim,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero).animate(curved),
          child: sheetChild,
        ),
      );
    },
  );
}

/// Светлый текст и прозрачный AppBar поверх [kAppTableBackgroundDecoration].
ThemeData themeOnTable(BuildContext context, {bool formFields = false}) {
  var t = Theme.of(context).copyWith(
    scaffoldBackgroundColor: Colors.transparent,
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      foregroundColor: Colors.white,
      scrolledUnderElevation: 0,
    ),
    textTheme: Theme.of(context).textTheme.apply(bodyColor: Colors.white, displayColor: Colors.white),
    listTileTheme: const ListTileThemeData(textColor: Colors.white, iconColor: Colors.white),
  );
  if (!formFields) return t;
  return t.copyWith(
    inputDecorationTheme: InputDecorationTheme(
      labelStyle: const TextStyle(color: Colors.white70),
      floatingLabelStyle: const TextStyle(color: Colors.white),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white38)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white38)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: const BorderSide(color: Colors.white)),
      filled: true,
      fillColor: Colors.black26,
    ),
  );
}

/// Диалог оффера рекламы в стиле стола: выровненный текст, полноширинные кнопки.
Future<bool?> showTableAdOfferDialog(
  BuildContext context, {
  required String title,
  required String body,
  required String primaryLabel,
  required String secondaryLabel,
}) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black54,
    builder: (ctx) {
      return Theme(
        data: themeOnTable(ctx),
        child: Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: const Color(0xFF114C2F).withValues(alpha: 0.96),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 22, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    body,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      color: Colors.white.withValues(alpha: 0.88),
                    ),
                  ),
                  const SizedBox(height: 22),
                  FilledButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF1FA463),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      primaryLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white70,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: Text(
                      secondaryLabel,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}
