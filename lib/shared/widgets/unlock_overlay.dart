import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_table_background.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers.dart';

/// Оверлей «Разблокирован стиль!» после испытания или рекламы.
class UnlockOverlay extends ConsumerStatefulWidget {
  const UnlockOverlay({super.key});

  @override
  ConsumerState<UnlockOverlay> createState() => _UnlockOverlayState();
}

class _UnlockOverlayState extends ConsumerState<UnlockOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  String? _lastStyleId;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade = Tween(begin: 0.0, end: 1.0).animate(_ctrl);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final styleId = ref.watch(unlockFlashProvider);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (styleId != null && styleId != _lastStyleId) {
        _lastStyleId = styleId;
        _ctrl.forward(from: 0);
        Future.delayed(const Duration(seconds: 3), () {
          if (!mounted) return;
          _ctrl.reverse().then((_) {
            if (!mounted) return;
            ref.read(unlockFlashProvider.notifier).clear();
            _lastStyleId = null;
          });
        });
      }
    });

    if (styleId == null) return const SizedBox.shrink();

    final s = AppStrings.of(Localizations.localeOf(context));
    final styles = ref.watch(stylesProvider).asData?.value ?? [];
    final style = styles.where((st) => st.id == styleId).firstOrNull;
    final displayName = style != null && style.displayNameKey.isNotEmpty
        ? s.t(style.displayNameKey)
        : styleId;

    // Material обязателен — иначе в debug под текстом жёлтые полоски.
    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
        opacity: _fade,
        child: Container(
          color: Colors.black54,
          child: Center(
            child: ScaleTransition(
              scale: _scale,
              child: Theme(
                data: themeOnTable(context),
                child: Material(
                  color: const Color(0xFF1A3A2A),
                  elevation: 8,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 40),
                    padding: const EdgeInsets.symmetric(
                      vertical: 32,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.white24),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.lock_open_rounded,
                          color: Color(0xFFFFD700),
                          size: 56,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          s.t('unlock_title'),
                          style: const TextStyle(
                            color: Color(0xFFFFD700),
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          displayName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          s.t('unlock_hint'),
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.6),
                            fontSize: 13,
                            decoration: TextDecoration.none,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
