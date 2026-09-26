import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/yandex_rewarded.dart';
import '../../core/app_table_background.dart';
import '../../core/audio/sound_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/providers.dart';
import '../../shared/widgets/game_ui_common.dart';
import '../../shared/widgets/legal_drop_glow.dart';
import '../../shared/widgets/playing_card_view.dart';
import '../../shared/widgets/win_celebration.dart';
import '../../shared/widgets/yandex_sticky_banner.dart';
import 'domain/card.dart';
import 'domain/klondike_engine.dart';
import 'domain/klondike_state.dart';
import 'klondike_controller.dart';

/// Экран режима Косынка с базовой реальной логикой движка.
class KlondikeScreen extends ConsumerStatefulWidget {
  const KlondikeScreen({super.key});

  @override
  ConsumerState<KlondikeScreen> createState() => _KlondikeScreenState();
}

class _KlondikeScreenState extends ConsumerState<KlondikeScreen> {
  static const double _baseCardWidth = 56;
  static const double _baseCardHeight = 84;
  static const double _tableauStep = 20;
  double get _cardWidth => _baseCardWidth * _cardScale;
  double get _cardHeight => _baseCardHeight * _cardScale;
  /// Масштаб карт из настроек, инициализируется в build().
  double _cardScale = 1.0;
  static const double _boardHorizontalPadding = 2;
  static const Duration _cardMoveDuration = Duration(milliseconds: 260);
  static const Duration _dragFadeDuration = Duration(milliseconds: 180);

  int? _dragFromColumn;
  int? _dragFromCardIndex;
  /// Активный payload перетаскивания для подсветки легальных целей.
  _DragPayload? _activeDragPayload;
  int? _dropPulseColumn;
  int _seconds = 0;
  bool _secondsHydrated = false;
  late final Timer _timer;

  /// Ключи слотов подсказки (stock / waste / foundation / колонка табло).
  Set<String> _hintKeys = {};
  /// Фаза «жёлтый слой вкл» для моргания подсказки.
  bool _hintYellowOn = false;

  KlondikeState get _state =>
      ref.read(klondikeControllerProvider).asData!.value;
  KlondikeController get _controller =>
      ref.read(klondikeControllerProvider.notifier);

  /// Единая точка сброса состояния перетаскивания.
  void _resetDragState() {
    _dragFromColumn = null;
    _dragFromCardIndex = null;
    _activeDragPayload = null;
  }

  // Короткий "инерционный довод" целевой колонки после удачного дропа.
  void _triggerDropPulse(int columnIndex) {
    setState(() => _dropPulseColumn = columnIndex);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _dropPulseColumn != columnIndex) return;
      setState(() => _dropPulseColumn = null);
    });
  }

  /// Выход в меню: сначала сохраняем время, потом закрываем экран.
  Future<void> _exitToMenu() async {
    await _controller.saveElapsedSeconds(_seconds);
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final showTimer = ref.read(settingsProvider).asData?.value.showTimer ?? true;
      if (!showTimer) return;
      final st = ref.read(klondikeControllerProvider).asData?.value;
      if (st == null || st.isWin) return;
      setState(() => _seconds++);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ref.read(klondikeOpenDailyProvider)) {
        ref.read(klondikeOpenDailyProvider.notifier).consume();
        ref.read(klondikeControllerProvider.notifier).startDailyChallenge();
        setState(() {
          _seconds = 0;
          _secondsHydrated = true;
        });
        final s = AppStrings.of(Localizations.localeOf(context));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.t('dailyStarted')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  /// Жёлтая подложка для подсказки.
  Widget _hintYellowOverlay(Widget child) {
    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.passthrough,
      children: [
        child,
        Positioned.fill(
          child: IgnorePointer(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: const Color(0xFFFFEB3B).withValues(alpha: 0.55),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// Жёлтая вспышка по ключу слота (`hint_stock`, `hint_waste`, `hint_f:*`, `hint_t:*`, `hint_card:*`).
  Widget _hintGlow(String slotKey, Widget child) {
    if (!_hintKeys.contains(slotKey) || !_hintYellowOn) return child;
    return _hintYellowOverlay(child);
  }

  /// Подсветка карты в колонке табло: верх слота или конкретная позиция в стопке подсказки.
  Widget _hintWrapTableauCard(
    int columnIndex,
    int idx,
    List<PlayingCard> pile,
    Widget child,
  ) {
    if (!_hintYellowOn) return child;
    final isTop = idx == pile.length - 1;
    final byPos = _hintKeys.contains('hint_card:$columnIndex:$idx');
    final byColTop = isTop && _hintKeys.contains('hint_t:$columnIndex');
    if (byPos || byColTop) return _hintYellowOverlay(child);
    return child;
  }

  /// Какие области подсветить по подсказке из движка.
  Set<String> _hintKeysForHint(KlondikeHint hint) {
    final st = _state;
    return switch (hint) {
      HintDrawFromStock() => {'hint_stock'},
      HintWasteToFoundation() => st.waste.isEmpty
          ? {}
          : {'hint_waste', 'hint_f:${st.waste.last.suit.name}'},
      HintWasteToTableau(:final column) => {'hint_waste', 'hint_t:$column'},
      HintTableauToFoundation(:final column) =>
        st.tableau[column].isEmpty
            ? {}
            : {'hint_t:$column', 'hint_f:${st.tableau[column].last.suit.name}'},
      HintTableauRun(:final fromColumn, :final fromCardIndex, :final toColumn) => {
          'hint_t:$toColumn',
          for (var i = fromCardIndex; i < st.tableau[fromColumn].length; i++)
            'hint_card:$fromColumn:$i',
        },
    };
  }

  /// Три моргания жёлтым по целям подсказки.
  Future<void> _runHintBlink(Set<String> keys) async {
    if (keys.isEmpty || !mounted) return;
    for (var b = 0; b < 3; b++) {
      if (!mounted) return;
      setState(() {
        _hintKeys = keys;
        _hintYellowOn = true;
      });
      await Future<void>.delayed(const Duration(milliseconds: 240));
      if (!mounted) return;
      setState(() => _hintYellowOn = false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    if (!mounted) return;
    setState(() {
      _hintKeys = {};
      _hintYellowOn = false;
    });
  }

  void _flashHintFromTag(KlondikeHint? hint) {
    if (hint == null) return;
    final keys = _hintKeysForHint(hint);
    if (keys.isEmpty) return;
    unawaited(_runHintBlink(keys));
  }

  String _hintMessage(AppStrings s, KlondikeHint? hint) {
    if (hint == null) return s.t('hintNone');
    return switch (hint) {
      HintDrawFromStock() => s.t('hintDrawFromStock'),
      HintWasteToFoundation() => s.t('hintWasteToFoundation'),
      HintWasteToTableau() => s.t('hintWasteToTableau'),
      HintTableauToFoundation() => s.t('hintWasteToFoundation'),
      HintTableauRun() => s.t('hintTableauToTableau'),
    };
  }

  Future<void> _onHintPressed() async {
    try {
      ref.read(soundServiceProvider).play(SoundEvent.hint);
      final s = AppStrings.of(Localizations.localeOf(context));
      final r = _controller.takeHintOrPrepareReward();
      if (r.needsReward) {
        final watchAd = await showTableAdOfferDialog(
          context,
          title: s.t('hintRewardTitle'),
          body: s.t('hintRewardBody'),
          primaryLabel: s.t('hintRewardWatch'),
          secondaryLabel: s.t('hintRewardDecline'),
        );
        if (!mounted) return;
        if (watchAd != true) return;
        final ok = await showYandexRewardedAd(
          placement: RewardedAdPlacement.klondikeHint,
        );
        if (!mounted) return;
        if (ok) {
          // Только +1 к счётчику; подсказку игрок запросит вторым нажатием.
          _controller.grantHintFromReward();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('rewardAdFailed')), behavior: SnackBarBehavior.floating));
        }
        return;
      }
      if (r.noMoves) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('hintNone')), behavior: SnackBarBehavior.floating));
        return;
      }
      _flashHintFromTag(r.hint);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_hintMessage(s, r.hint)), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
      );
    } finally {
      // Счётчик подсказок не в KlondikeState — перерисовка панели после расхода.
      if (mounted) setState(() {});
    }
  }

  /// Отмена: 5 бесплатных за партию, дальше диалог и rewarded (как в Пауке, блок R-M-19262021-3).
  Future<void> _onKlondikeUndo() async {
    try {
      if (_controller.canUndoWithBudget) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        await _controller.undo();
        return;
      }
      if (!_controller.canUndo) return;
      final s = AppStrings.of(Localizations.localeOf(context));
      final watchAd = await showTableAdOfferDialog(
        context,
        title: s.t('undoRewardTitle'),
        body: s.t('undoRewardBody'),
        primaryLabel: s.t('hintRewardWatch'),
        secondaryLabel: s.t('hintRewardDecline'),
      );
      if (!mounted) return;
      if (watchAd != true) return;
      final ok = await showYandexRewardedAd(placement: RewardedAdPlacement.klondikeUndo);
      if (!mounted) return;
      if (ok) {
        _controller.grantUndoFromReward();
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        await _controller.undo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.t('rewardAdFailed')), behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  /// Автодобор в основания без рекламы (только если движок разрешает).
  Future<void> _onAutoFinishPressed() async {
    if (!_controller.canAutoFinish()) return;
    await _controller.autoFinishAll();
  }

  Future<void> _onNewGamePressed() async {
    final s = AppStrings.of(Localizations.localeOf(context));
    if (_controller.canOfferDailyRetryAd) {
      final goAd = await showTableAdOfferDialog(
        context,
        title: s.t('dailyRetryTitle'),
        body: s.t('dailyRetryBody'),
        primaryLabel: s.t('dailyRetryWatch'),
        secondaryLabel: s.t('dailyRetrySkip'),
      );
      if (!mounted) return;
      if (goAd == true) {
        final ok = await showYandexRewardedAd();
        if (!mounted) return;
        if (ok) {
          await _controller.restartDailyAfterRewardAd();
          setState(() {
            _seconds = 0;
            _secondsHydrated = true;
          });
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.t('rewardAdFailed')), behavior: SnackBarBehavior.floating));
        return;
      }
      if (goAd == false) {
        await _controller.newGame();
        return;
      }
      return;
    }
    await _controller.newGame();
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(klondikeControllerProvider);
    final state = asyncState.asData?.value;

    // Сброс секунд при новой раздаче (ходы обнулились после сыгранной партии)
    ref.listen(klondikeControllerProvider, (prev, next) {
      final p = prev?.asData?.value;
      final n = next.asData?.value;
      if (n == null || !mounted) return;
      if (n.moves == 0 && p != null && (p.moves > 0 || p.isWin)) {
        setState(() {
          _seconds = 0;
          _secondsHydrated = true;
        });
      }
    });

    // Победа в ежедневной партии: рекорд уже сохранён в контроллере, здесь только SnackBar.
    ref.listen(dailyWinFlashProvider, (prev, next) {
      if (next == null || !context.mounted) return;
      final loc = AppStrings.of(Localizations.localeOf(context));
      final base = loc.t('dailyWinPrefix').replaceAll('{m}', '${next.moves}');
      final tail = next.newBestForDay
          ? ' ${loc.t('dailyWinSuffixNewBest')}'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$base$tail'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      ref.read(dailyWinFlashProvider.notifier).clear();
    });

    if (state == null) {
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

    // Синхронизируем локальный таймер с сохранённым состоянием.
    // Важно при быстром выходе/возврате, когда сохранение может завершиться чуть позже.
    if (!_secondsHydrated || state.elapsedSeconds > _seconds) {
      _seconds = state.elapsedSeconds;
      _secondsHydrated = true;
    }

    // Обновляем масштаб карт из настроек при каждой перерисовке.
    _cardScale = effectiveCardScale(
      ref.watch(settingsProvider.select((v) => v.asData?.value.cardScale ?? 1.0)),
      context,
    );
    final s = AppStrings.of(Localizations.localeOf(context));
    final settings = ref.watch(settingsProvider).asData?.value;
    final showTimer = settings?.showTimer ?? true;
    final score =
        state.foundations.values.fold<int>(0, (a, b) => a + b.length) * 10;

    final gameWidget = Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: tableBackgroundDecoration(settings),
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    topCircleButton(
                      Icons.menu_rounded,
                      () => _exitToMenu(),
                    ),
                    const Spacer(),
                    metricWidget(s.t('metricScore'), '$score'),
                    if (showTimer) ...[
                      const Spacer(),
                      metricWidget(s.t('metricTime'), _timeText(_seconds)),
                    ],
                    const Spacer(),
                    metricWidget(s.t('metricMoves'), '${state.moves}'),
                    const Spacer(),
                    topCircleButton(
                      Icons.palette_rounded,
                      () => Navigator.pushNamed(context, '/style'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Переключатель режима раздачи (1 или 3 карты) прямо на экране Косынки.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () async {
                      // Берем текущие настройки, чтобы синхронно обновить и глобальный стейт, и партию.
                      final settingsAsync = ref.read(settingsProvider);
                      final settings = settingsAsync.asData?.value;
                      if (settings == null) return;
                      final nextDraw = settings.klondikeDrawCount == 3 ? 1 : 3;
                      await ref
                          .read(settingsProvider.notifier)
                          .save(settings.copyWith(klondikeDrawCount: nextDraw));
                      await _controller.newGame(drawCount: nextDraw);
                    },
                    icon: const Icon(Icons.filter_3, color: Colors.white),
                    label: Text(
                      state.drawCount == 3
                          ? s.t('klondikeDealBy3')
                          : s.t('klondikeDealBy1'),
                      style: const TextStyle(color: Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      backgroundColor:
                          const Color(0xFF0D5531).withValues(alpha: 0.85),
                      visualDensity: VisualDensity.compact,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: _boardHorizontalPadding,
                  vertical: 2,
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          for (var i = 0; i < 7; i++) ...[
                            Expanded(
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: switch (i) {
                                  0 => _topSlot(
                                    child: _foundationCard(CardSuit.hearts),
                                  ),
                                  1 => _topSlot(
                                    child: _foundationCard(CardSuit.diamonds),
                                  ),
                                  2 => _topSlot(
                                    child: _foundationCard(CardSuit.clubs),
                                  ),
                                  3 => _topSlot(
                                    child: _foundationCard(CardSuit.spades),
                                  ),
                                  5 => _topSlot(
                                    child: _state.waste.isEmpty
                                        ? _emptyTopCard()
                                        : _hintGlow(
                                            'hint_waste',
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: _state.waste.reversed
                                                .take(_state.drawCount == 3 ? 3 : 1)
                                                .toList()
                                                .asMap()
                                                .entries
                                                .toList()
                                                .reversed
                                                .map((entry) {
                                              final index = entry.key;
                                              final card = entry.value;
                                              final isTop = identical(card, _state.waste.last);
                                              final right = _state.drawCount == 3
                                                  ? 10.0 * index
                                                  : 0.0;
                                              final cardWidget = PlayingCardView(card: card);
                                              final wasteW = _tableauCardWidth(context);
                                              return Positioned(
                                                right: right,
                                                width: wasteW,
                                                child: isTop
                                                    ? Draggable<_DragPayload>(
                                                        data: _DragPayload.fromWaste(card.suit),
                                                        dragAnchorStrategy: pointerDragAnchorStrategy,
                                                        onDragStarted: () => setState(() {
                                                          _activeDragPayload = _DragPayload.fromWaste(card.suit);
                                                        }),
                                                        onDragEnd: (_) => setState(() {
                                                          _dragFromColumn = null;
                                                          _dragFromCardIndex = null;
                                                          _activeDragPayload = null;
                                                        }),
                                                        onDragCompleted: () => setState(() {
                                                          _dragFromColumn = null;
                                                          _dragFromCardIndex = null;
                                                          _activeDragPayload = null;
                                                        }),
                                                        onDraggableCanceled: (_, __) => setState(() {
                                                          _dragFromColumn = null;
                                                          _dragFromCardIndex = null;
                                                          _activeDragPayload = null;
                                                        }),
                                                        feedback: _dragFeedbackCard(
                                                          SizedBox(
                                                            width: wasteW,
                                                            height: _cardHeight,
                                                            child: cardWidget,
                                                          ),
                                                        ),
                                                        childWhenDragging: _emptyTopCard(),
                                                        child: GestureDetector(
                                                          onTap: () => _controller.autoMoveWaste(),
                                                          child: cardWidget,
                                                        ),
                                                      )
                                                    : cardWidget,
                                              );
                                            }).toList(),
                                            ),
                                          ),
                                  ),
                                  6 => _topSlot(
                                    child: _hintGlow(
                                      'hint_stock',
                                      GestureDetector(
                                        key: const Key('klondike_draw_stock'),
                                        onTap: () {
                                          ref
                                              .read(soundServiceProvider)
                                              .play(SoundEvent.cardTap);
                                          _controller.draw();
                                        },
                                        child: _stockCardWithCounter(),
                                      ),
                                    ),
                                  ),
                                  _ => const SizedBox.shrink(),
                                },
                              ),
                            ),
                            if (i != 6) const SizedBox(width: 2),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _boardHorizontalPadding,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 7; i++) ...[
                        Expanded(child: _tableauColumn(i)),
                        if (i != 6) const SizedBox(width: 2),
                      ],
                    ],
                  ),
                ),
              ),
              bottomActionBar(
                actions: [
                  (
                    icon: Icons.style,
                    label: s.t('newGame'),
                    onTap: _onNewGamePressed,
                    badge: null,
                    badgePlay: false,
                  ),
                  (
                    icon: Icons.auto_fix_high,
                    label: s.t('autoFinish'),
                    onTap: _controller.canAutoFinish() ? _onAutoFinishPressed : null,
                    badge: null,
                    badgePlay: false,
                  ),
                  (
                    icon: Icons.lightbulb,
                    label: s.t('hint'),
                    onTap: _onHintPressed,
                    badge: _controller.freeHintsRemaining,
                    badgePlay: false,
                  ),
                  (
                    icon: Icons.undo,
                    label: s.t('btnUndo'),
                    onTap: _controller.canUndo ? _onKlondikeUndo : null,
                    badge: !_controller.canUndo
                        ? null
                        : (_controller.undoBudgetRemaining > 0
                            ? _controller.undoBudgetRemaining
                            : null),
                    badgePlay:
                        _controller.canUndo && _controller.undoBudgetRemaining == 0,
                  ),
                  (
                    icon: Icons.redo,
                    label: s.t('btnRedo'),
                    onTap: _controller.canRedo
                        ? () => _controller.redo()
                        : null,
                    badge: null,
                    badgePlay: false,
                  ),
                ],
              ),
              const YandexStickyBanner(),
            ],
          ),
        ),
      ),
    );

    if (state.isWin) {
      if (_hintYellowOn) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _hintKeys = {};
              _hintYellowOn = false;
            });
          }
        });
      }
      return Stack(
        children: [
          gameWidget,
          WinCelebration(
            modeLabel: s.t('klondike'),
            moves: state.moves,
            seconds: showTimer ? _seconds : 0,
            onNewGame: () {
              _controller.newGame();
              setState(() => _seconds = 0);
            },
            onMenu: _exitToMenu,
          ),
        ],
      );
    }

    return gameWidget;
  }

  String _timeText(int seconds) {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Widget _topSlot({required Widget child}) {
    return SizedBox(width: _cardWidth, height: _cardHeight, child: child);
  }

  /// Фактическая ширина карты в табло (7 колонок + интервалы + поля).
  double _tableauCardWidth(BuildContext context) {
    final totalWidth = MediaQuery.sizeOf(context).width;
    final horizontalGaps = 2.0 * 6; // 6 промежутков между 7 колонками.
    final horizontalPadding = _boardHorizontalPadding * 2;
    return (totalWidth - horizontalGaps - horizontalPadding) / 7;
  }

  Widget _emptyTopCard({Key? key}) {
    return Container(
      key: key,
      height: _cardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  // Подложка для дома: показываем метку туза, чтобы слот читался как foundation.
  Widget _emptyFoundationCard(CardSuit suit, {Key? key}) {
    return Container(
      key: key,
      height: _cardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Center(
        child: Text(
          'A',
          style: TextStyle(
            color: const Color(0xFFD0D0D0).withValues(alpha: 0.65),
            fontWeight: FontWeight.w700,
            fontSize: 27,
          ),
        ),
      ),
    );
  }

  // Колода: показываем рубашку/пустой слот и счётчик оставшихся карт в левом нижнем углу.
  Widget _stockCardWithCounter() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _state.stock.isEmpty
            ? _emptyTopCard()
            : const PlayingCardView.back(),
        Positioned(
          left: 4,
          bottom: 4,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              '${_state.stock.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _foundationCard(CardSuit suit) {
    final pile = _state.foundations[suit]!;
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          _canDropToFoundation(details.data, suit),
      onAcceptWithDetails: (details) =>
          _dropToFoundation(details.data, suit),
      builder: (context, candidateData, rejectedData) {
        final hasHover = candidateData.isNotEmpty;
        final slotWithCard = Stack(
          fit: StackFit.expand,
          children: [
            _emptyFoundationCard(suit, key: ValueKey('empty-${suit.name}')),
            if (pile.isNotEmpty)
              AnimatedSwitcher(
                duration: _cardMoveDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                transitionBuilder: (child, animation) {
                  return SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0, -0.08),
                      end: Offset.zero,
                    ).animate(animation),
                    child: FadeTransition(opacity: animation, child: child),
                  );
                },
                child: PlayingCardView(
                  key: ValueKey('f-${pile.last.suit.name}-${pile.last.rank}'),
                  card: pile.last,
                ),
              ),
          ],
        );

        // Подсветка легальной цели при drag-and-drop
        final bool isLegalDropTarget =
            _activeDragPayload != null &&
                _canDropToFoundation(_activeDragPayload!, suit);

        if (pile.isEmpty) {
          final w = _hintGlow(
            'hint_f:${suit.name}',
            AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: hasHover ? 1.05 : 1,
              child: slotWithCard,
            ),
          );
          return isLegalDropTarget ? legalDropGlow(w) : w;
        }
        final top = pile.last;
        final w = _hintGlow(
          'hint_f:${suit.name}',
          Draggable<_DragPayload>(
          data: _DragPayload.fromFoundation(top.suit),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: () => setState(() {
            _activeDragPayload = _DragPayload.fromFoundation(top.suit);
          }),
          onDragEnd: (_) => setState(() {
            _dragFromColumn = null;
            _dragFromCardIndex = null;
            _activeDragPayload = null;
          }),
          onDragCompleted: () => setState(() {
            _dragFromColumn = null;
            _dragFromCardIndex = null;
            _activeDragPayload = null;
          }),
          onDraggableCanceled: (_, __) => setState(() {
            _dragFromColumn = null;
            _dragFromCardIndex = null;
            _activeDragPayload = null;
          }),
          feedback: _dragFeedbackCard(
            SizedBox(
              width: _cardWidth,
              height: _cardHeight,
              child: PlayingCardView(
                key: ValueKey('f-drag-${top.suit.name}-${top.rank}'),
                card: top,
              ),
            ),
          ),
          // Не скрываем карту в доме во время drag, чтобы не было эффекта "карта исчезла".
          childWhenDragging: slotWithCard,
          child: AnimatedScale(
            duration: const Duration(milliseconds: 160),
            scale: hasHover ? 1.05 : 1,
            child: slotWithCard,
          ),
        ),
        );
        return isLegalDropTarget ? legalDropGlow(w) : w;
      },
    );
  }

  Widget _tableauColumn(int columnIndex) {
    final pile = _state.tableau[columnIndex];
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          _canDropToTableau(details.data, columnIndex),
      onAcceptWithDetails: (details) {
        _dropToTableau(details.data, columnIndex);
        if (_dragFromColumn != null || _dragFromCardIndex != null) {
          setState(() {
            _dragFromColumn = null;
            _dragFromCardIndex = null;
            _activeDragPayload = null;
          });
        }
      },
      builder: (context, candidateData, rejectedData) {
        // Подсветка легальной цели при drag-and-drop
        final bool isLegalDropTarget =
            _activeDragPayload != null &&
                _canDropToTableau(_activeDragPayload!, columnIndex);

        Widget inner;
        if (pile.isEmpty) {
          inner = Align(
            alignment: Alignment.topCenter,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: _hintGlow(
                'hint_t:$columnIndex',
                _emptyTopCard(),
              ),
            ),
          );
        } else {
          inner = Stack(
            children: [
              for (var idx = 0; idx < pile.length; idx++)
                AnimatedPositioned(
                  duration: _cardMoveDuration,
                  curve: Curves.easeInOutCubicEmphasized,
                  top: idx * _tableauStep,
                  left: 0,
                  right: 0,
                  child: _buildTableauCard(pile, idx, columnIndex),
                ),
            ],
          );
        }

        final content = GestureDetector(
          onTap: () {
            ref.read(soundServiceProvider).play(SoundEvent.cardTap);
            _controller.autoMoveTableauTop(columnIndex);
          },
          child: AnimatedContainer(
            duration: _cardMoveDuration,
            constraints: const BoxConstraints(minHeight: double.infinity),
            child: LayoutBuilder(builder: (context, constraints) => inner),
          ),
        );

        return isLegalDropTarget ? legalDropGlow(content) : content;
      },
    );
  }

  Widget _buildTableauCard(List<PlayingCard> pile, int idx, int columnIndex) {
    final card = pile[idx];
    final isPulseTarget =
        _dropPulseColumn == columnIndex && idx == pile.length - 1;
    final cardWidget = PlayingCardView(card: card);
    final pulsedCardWidget = AnimatedScale(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOutCubic,
      scale: isPulseTarget ? 1.02 : 1,
      child: cardWidget,
    );
    final Widget pileSurface =
        _hintWrapTableauCard(columnIndex, idx, pile, pulsedCardWidget);
    final isDraggedRun =
        _dragFromColumn == columnIndex &&
        _dragFromCardIndex != null &&
        idx >= _dragFromCardIndex!;
    if (isDraggedRun) {
      // Плавно приглушаем исходную стопку во время drag, чтобы не было резкого "рывка".
      return AnimatedOpacity(
        duration: _dragFadeDuration,
        curve: Curves.easeOutCubic,
        opacity: 0.05,
        child: pileSurface,
      );
    }
    if (!card.faceUp) return pileSurface;

    final canDragRun = _controller.canDragTableauRun(columnIndex, idx);
    if (!canDragRun) return pileSurface;

    final run = pile.sublist(idx);
    // Ширина как у колонки табло, иначе feedback остаётся 56px при широких ячейках.
    final tw = _tableauCardWidth(context);
    final runFeedback = SizedBox(
      width: tw,
      height: _cardHeight + (run.length - 1) * _tableauStep,
      child: Stack(
        children: [
          for (var i = 0; i < run.length; i++)
            Positioned(
              top: i * _tableauStep,
              left: 0,
              right: 0,
              child: PlayingCardView(card: run[i]),
            ),
        ],
      ),
    );
    return Draggable<_DragPayload>(
      data: _DragPayload.fromTableau(columnIndex, idx, card.suit),
      dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragStarted: () => setState(() {
            _dragFromColumn = columnIndex;
            _dragFromCardIndex = idx;
            _activeDragPayload = _DragPayload.fromTableau(columnIndex, idx, run[0].suit);
          }),
      onDragEnd: (_) => setState(() {
        _dragFromColumn = null;
        _dragFromCardIndex = null;
        _activeDragPayload = null;
      }),
      onDragCompleted: () => setState(() {
        _dragFromColumn = null;
        _dragFromCardIndex = null;
        _activeDragPayload = null;
      }),
      onDraggableCanceled: (_, __) => setState(() {
        _dragFromColumn = null;
        _dragFromCardIndex = null;
        _activeDragPayload = null;
      }),
      feedback: _dragFeedbackCard(runFeedback),
      // Убираем временный placeholder, чтобы не оставался "залипший" полупрозрачный след.
      childWhenDragging: const SizedBox.shrink(),
      child: pileSurface,
    );
  }

  /// Визуал перетаскиваемой карты: легкий scale и тень.
  Widget _dragFeedbackCard(Widget child) {
    return Material(
      color: Colors.transparent,
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 140),
        curve: Curves.easeOutCubic,
        tween: Tween<double>(begin: 1.0, end: 1.03),
        builder: (context, scale, childWidget) {
          return Transform.scale(scale: scale, child: childWidget);
        },
        child: DecoratedBox(
          decoration: BoxDecoration(
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.30),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  /// Проверки легальности дропа — через контроллер (правила исполняются там).
  bool _canDropToTableau(_DragPayload payload, int toColumn) {
    return switch (payload.source) {
      _DragSource.waste => _controller.canMoveWasteToTableau(toColumn),
      _DragSource.foundation =>
          _controller.canMoveFoundationToTableau(payload.suit, toColumn),
      _DragSource.tableau => payload.fromColumn != null &&
          _controller.canMoveTableauRunToTableau(
            payload.fromColumn!,
            payload.fromCardIndex ?? 0,
            toColumn,
          ),
    };
  }

  void _dropToTableau(_DragPayload payload, int toColumn) {
    if (!_canDropToTableau(payload, toColumn)) return;
    ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
    switch (payload.source) {
      case _DragSource.waste:
        _controller.moveWasteToTableau(toColumn);
      case _DragSource.foundation:
        _controller.moveFoundationToTableau(payload.suit, toColumn);
      case _DragSource.tableau when payload.fromColumn != null:
        _controller.moveTableauRunToTableau(
          payload.fromColumn!,
          payload.fromCardIndex ?? 0,
          toColumn,
        );
      default:
        return;
    }
    _resetDragState();
    _triggerDropPulse(toColumn);
  }

  bool _canDropToFoundation(_DragPayload payload, CardSuit suit) {
    if (payload.suit != suit) return false;
    return switch (payload.source) {
      _DragSource.waste => _controller.canMoveWasteToFoundation(),
      _DragSource.tableau => payload.fromColumn != null &&
          (payload.fromCardIndex == null ||
              payload.fromCardIndex ==
                  _state.tableau[payload.fromColumn!].length - 1) &&
          _controller.canMoveTableauTopToFoundation(payload.fromColumn!),
      _ => false,
    };
  }

  void _dropToFoundation(_DragPayload payload, CardSuit suit) {
    if (!_canDropToFoundation(payload, suit)) return;
    ref.read(soundServiceProvider).play(SoundEvent.cardToFoundation);
    switch (payload.source) {
      case _DragSource.waste:
        _controller.moveWasteToFoundation();
      case _DragSource.tableau when payload.fromColumn != null:
        _controller.moveTableauTopToFoundation(payload.fromColumn!);
      default:
        return;
    }
    _resetDragState();
  }
}

enum _DragSource { waste, tableau, foundation }

class _DragPayload {
  const _DragPayload({
    required this.source,
    required this.suit,
    this.fromColumn,
    this.fromCardIndex,
  });

  final _DragSource source;
  final CardSuit suit;
  final int? fromColumn;
  final int? fromCardIndex;

  factory _DragPayload.fromWaste(CardSuit suit) {
    return _DragPayload(source: _DragSource.waste, suit: suit);
  }

  factory _DragPayload.fromTableau(
    int fromColumn,
    int fromCardIndex,
    CardSuit suit,
  ) {
    return _DragPayload(
      source: _DragSource.tableau,
      fromColumn: fromColumn,
      fromCardIndex: fromCardIndex,
      suit: suit,
    );
  }

  factory _DragPayload.fromFoundation(CardSuit suit) {
    return _DragPayload(source: _DragSource.foundation, suit: suit);
  }
}