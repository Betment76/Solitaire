import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/yandex_rewarded.dart';
import '../../core/app_table_background.dart';
import '../../core/audio/sound_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers.dart';
import '../../core/models/card.dart';
import '../../shared/widgets/game_ui_common.dart';
import '../../shared/widgets/yandex_sticky_banner.dart';
import 'domain/spider_engine.dart';
import 'domain/spider_state.dart';
import 'spider_controller.dart';

/// Экран Паука: правила зависят от количества мастей в раздаче (1/2/4).
class SpiderScreen extends ConsumerStatefulWidget {
  const SpiderScreen({super.key});

  @override
  ConsumerState<SpiderScreen> createState() => _SpiderScreenState();
}

class _SpiderScreenState extends ConsumerState<SpiderScreen>
    with SingleTickerProviderStateMixin {
  static const double _cardWidth = 48;
  static const double _cardHeight = 62;
  static const double _tableauStep = 16;
  static const double _boardHorizontalPadding = 1;
  static const Duration _cardMoveDuration = Duration(milliseconds: 260);
  static const Duration _dragFadeDuration = Duration(milliseconds: 180);
  static const int _dealFlightDurationMs = 560;
  static const int _dealStepPauseMs = 80;
  static const int _cinematicDealFlightDurationMs = 860;
  static const int _cinematicDealStepPauseMs = 170;

  int? _dragFromColumn;
  int? _dragFromIndex;
  bool _isDealing = false;
  int? _activeDealFlightColumn;
  Set<int> _dealRevealedColumns = const <int>{};
  AnimationController? _dealFlightController;
  bool _isCollectAnimating = false;
  int? _collectFromColumn;
  int? _collectToSlot;
  int? _collectCardStep;
  int _collectFromColumnLenBefore = 0;
  List<PlayingCard> _collectCards = const <PlayingCard>[];
  AnimationController? _collectFlightController;

  /// Подсветка подсказки (жёлтый слой по ключам слотов).
  Set<String> _hintKeys = {};
  bool _hintYellowOn = false;

  SpiderState get _state => ref.read(spiderControllerProvider).asData!.value;
  SpiderController get _controller =>
      ref.read(spiderControllerProvider.notifier);

  AnimationController get _dealCtrl {
    _dealFlightController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _dealFlightDurationMs),
    );
    return _dealFlightController!;
  }

  AnimationController get _collectCtrl {
    _collectFlightController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: _dealFlightDurationMs),
    );
    return _collectFlightController!;
  }

  void _resetDragState() {
    _dragFromColumn = null;
    _dragFromIndex = null;
  }

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

  Widget _hintGlowSpider(String slotKey, Widget child) {
    if (!_hintKeys.contains(slotKey) || !_hintYellowOn) return child;
    return _hintYellowOverlay(child);
  }

  Widget _spiderHintWrapCard(
    int columnIndex,
    int idx,
    List<PlayingCard> pile,
    Widget child,
  ) {
    if (!_hintYellowOn) return child;
    final top = idx == pile.length - 1;
    final byCard = _hintKeys.contains('hint_spider_card:$columnIndex:$idx');
    final byCol = top && _hintKeys.contains('hint_spider_t:$columnIndex');
    if (byCard || byCol) return _hintYellowOverlay(child);
    return child;
  }

  Set<String> _spiderHintKeysForTag(String tag, SpiderState st) {
    if (tag == 'spider_deal_stock') return {'hint_spider_stock'};
    final m = RegExp(r'^spider_move_(\d+)_(\d+)_to_(\d+)$').firstMatch(tag);
    if (m != null) {
      final from = int.parse(m.group(1)!);
      final startIdx = int.parse(m.group(2)!);
      final to = int.parse(m.group(3)!);
      final keys = <String>{'hint_spider_t:$to'};
      final fp = st.tableau[from];
      for (var i = startIdx; i < fp.length; i++) {
        keys.add('hint_spider_card:$from:$i');
      }
      return keys;
    }
    return {};
  }

  Future<void> _runSpiderHintBlink(Set<String> keys) async {
    if (keys.isEmpty || !mounted) return;
    for (var i = 0; i < 3; i++) {
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

  void _flashSpiderHint(String? tag) {
    if (tag == null) return;
    final keys = _spiderHintKeysForTag(tag, _state);
    if (keys.isEmpty) return;
    unawaited(_runSpiderHintBlink(keys));
  }

  String _spiderHintMessage(AppStrings s, String? tag) {
    if (tag == null) return s.t('hintNone');
    if (tag == 'spider_deal_stock') return s.t('hintSpiderDeal');
    if (tag.startsWith('spider_move_')) return s.t('hintTableauToTableau');
    return s.t('hintNone');
  }

  Future<void> _onSpiderHintPressed() async {
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
          placement: RewardedAdPlacement.spiderHint,
        );
        if (!mounted) return;
        if (ok) {
          _controller.grantHintFromReward();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(s.t('rewardAdFailed')),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      if (r.noMoves) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.t('hintNone')),
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }
      _flashSpiderHint(r.tag);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_spiderHintMessage(s, r.tag)),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _dealFlightController?.dispose();
    _collectFlightController?.dispose();
    super.dispose();
  }

  Future<void> _playCompleteSequenceAnimation({
    required int fromColumn,
    required int toSlot,
    required int fromColumnLenBefore,
    required CardSuit suit,
  }) async {
    if (_isCollectAnimating || !mounted) return;
    final settings = ref
        .read(settingsProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);
    final speed = settings?.dealSpeed ?? DealSpeed.normal;
    final flightMs = switch (speed) {
      DealSpeed.fast => 360,
      DealSpeed.normal => _dealFlightDurationMs,
      DealSpeed.cinematic => _cinematicDealFlightDurationMs,
    };
    final stepPauseMs = switch (speed) {
      DealSpeed.fast => 30,
      DealSpeed.normal => _dealStepPauseMs,
      DealSpeed.cinematic => _cinematicDealStepPauseMs,
    };
    _collectCtrl
      ..stop()
      ..reset();
    _collectCtrl.duration = Duration(milliseconds: flightMs);

    setState(() {
      _isCollectAnimating = true;
      _collectFromColumn = fromColumn;
      _collectToSlot = toSlot;
      _collectCardStep = 0;
      _collectFromColumnLenBefore = fromColumnLenBefore;
    });

    for (var step = 0; step < 13; step++) {
      if (!mounted || !_isCollectAnimating) return;
      setState(() => _collectCardStep = step);
      ref.read(soundServiceProvider).play(SoundEvent.dealStep);
      _collectCtrl.reset();
      await _collectCtrl.forward();
      await Future<void>.delayed(Duration(milliseconds: stepPauseMs));
    }

    if (!mounted) return;
    setState(() {
      _isCollectAnimating = false;
      _collectFromColumn = null;
      _collectToSlot = null;
      _collectCardStep = null;
      _collectCards = const <PlayingCard>[];
    });
  }

  Future<void> _dealFromStockAnimated() async {
    if (_isDealing) return;
    final current = _state;
    final next = SpiderEngine().dealFromStock(current);
    if (identical(next, current)) return;
    final settings = ref
        .read(settingsProvider)
        .maybeWhen(data: (v) => v, orElse: () => null);
    final speed = settings?.dealSpeed ?? DealSpeed.normal;
    final flightMs = switch (speed) {
      DealSpeed.fast => 360,
      DealSpeed.normal => _dealFlightDurationMs,
      DealSpeed.cinematic => _cinematicDealFlightDurationMs,
    };
    final stepPauseMs = switch (speed) {
      DealSpeed.fast => 30,
      DealSpeed.normal => _dealStepPauseMs,
      DealSpeed.cinematic => _cinematicDealStepPauseMs,
    };
    // Подстраиваем длительность контроллера под выбранный режим раздачи.
    _dealCtrl.duration = Duration(milliseconds: flightMs);

    _controller.dealFromStock();
    setState(() {
      _isDealing = true;
      _activeDealFlightColumn = null;
      _dealRevealedColumns = const <int>{};
    });

    for (var i = 0; i < 10; i++) {
      if (!mounted) return;
      setState(() => _activeDealFlightColumn = i);
      ref.read(soundServiceProvider).play(SoundEvent.dealStep);
      await _dealCtrl.forward(from: 0);
      if (!mounted) return;
      setState(() => _dealRevealedColumns = {..._dealRevealedColumns, i});
      await Future<void>.delayed(Duration(milliseconds: stepPauseMs));
    }

    if (!mounted) return;
    setState(() {
      _activeDealFlightColumn = null;
      _isDealing = false;
      _dealRevealedColumns = const <int>{};
    });
  }

  SpiderController get _spiderController => ref.read(spiderControllerProvider.notifier);

  /// Отмена: при лимите 0 — диалог как у подсказки, затем rewarded.
  Future<void> _onSpiderUndo() async {
    try {
      final s = AppStrings.of(Localizations.localeOf(context));
      if (_spiderController.canUndoWithBudget) {
        await _spiderController.undo();
        return;
      }
      if (!_spiderController.canUndo) return;
      final watchAd = await showTableAdOfferDialog(
        context,
        title: s.t('undoRewardTitle'),
        body: s.t('undoRewardBody'),
        primaryLabel: s.t('hintRewardWatch'),
        secondaryLabel: s.t('hintRewardDecline'),
      );
      if (!mounted) return;
      if (watchAd != true) return;
      final ok = await showYandexRewardedAd(
        placement: RewardedAdPlacement.spiderUndo,
      );
      if (!mounted) return;
      if (ok) {
        _spiderController.grantUndoFromReward();
        await _spiderController.undo();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(s.t('rewardAdFailed')),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(spiderControllerProvider);
    final state = asyncState.asData?.value;

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

    final s = AppStrings.of(Localizations.localeOf(context));
    final settings = ref.watch(settingsProvider).asData?.value;

    ref.listen(spiderControllerProvider, (prev, next) {
      final p = prev?.asData?.value;
      final n = next.asData?.value;
      if (p == null || n == null || !mounted) return;
      if (n.completedSequences < p.completedSequences) {
        // Undo: остановить анимацию сбора, сбросить состояние.
        _collectFlightController?.stop();
        setState(() {
          _isCollectAnimating = false;
          _collectFromColumn = null;
          _collectToSlot = null;
          _collectCardStep = null;
          _collectCards = const <PlayingCard>[];
        });
        return;
      }
      if (n.completedSequences <= p.completedSequences) return;

      // Ищем колонку, из которой ушла собранная последовательность.
      int? fromColumn;
      CardSuit? suit;
      int fromLenBefore = 0;
      List<PlayingCard> movedCards = const <PlayingCard>[];
      for (var i = 0; i < p.tableau.length; i++) {
        final before = p.tableau[i];
        final after = n.tableau[i];
        if (before.length - after.length >= 13) {
          final tail = before.sublist(before.length - 13);
          fromColumn = i;
          fromLenBefore = before.length;
          suit = tail.last.suit; // В собранной K..A последняя карта — туз.
          movedCards = tail;
          break;
        }
      }
      if (fromColumn == null || suit == null) return;
      final toSlot = n.completedSequences - 1;
      setState(() => _collectCards = movedCards);
      unawaited(
        _playCompleteSequenceAnimation(
          fromColumn: fromColumn,
          toSlot: toSlot,
          fromColumnLenBefore: fromLenBefore,
          suit: suit,
        ),
      );
    });

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: tableBackgroundDecoration(settings),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        topCircleButton(
                          Icons.menu_rounded,
                          () => Navigator.pop(context),
                        ),
                        const Spacer(),
                        metricWidget(
                          s.t('metricStock'),
                          '${state.stock.length}',
                        ),
                        const Spacer(),
                        metricWidget(
                          s.t('metricCollected'),
                          '${state.completedSequences}/8',
                        ),
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
                  const SizedBox(height: 6),
                  // Кнопка выбора количества мастей — как в косынке переключатель раздачи.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        onPressed: () async {
                          final settingsAsync = ref.read(settingsProvider);
                          final settings = settingsAsync.asData?.value;
                          if (settings == null) return;
                          final nextCount = switch (settings.spiderSuitCount) {
                            1 => 2,
                            2 => 4,
                            _ => 1,
                          };
                          await ref
                              .read(settingsProvider.notifier)
                              .save(settings.copyWith(spiderSuitCount: nextCount));
                          await _controller.newGame();
                        },
                        icon: const Icon(Icons.grid_view, color: Colors.white),
                        label: Text(
                          '${s.t('spiderSuitTitle')}: ${settings?.spiderSuitCount ?? 1}',
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
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: _boardHorizontalPadding,
                      vertical: 2,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Row(
                            children: [
                              for (var i = 0; i < 10; i++) ...[
                                Expanded(
                                  child: Align(
                                    alignment: Alignment.topCenter,
                                    child: i == 9
                                        ? _topSlot(
                                            child: _hintGlowSpider(
                                              'hint_spider_stock',
                                              GestureDetector(
                                                onTap:
                                                    _isDealing ||
                                                            !_controller
                                                                .canDealFromStock()
                                                        ? null
                                                        : _dealFromStockAnimated,
                                                child: state.stock.isEmpty
                                                    ? _emptySlot()
                                                    : _cardBack(),
                                              ),
                                            ),
                                          )
                                        : i <= 7
                                        ? _topSlot(child: _completedSlot(i))
                                        : const SizedBox.shrink(),
                                  ),
                                ),
                                if (i != 9) const SizedBox(width: 1),
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
                          for (var c = 0; c < 10; c++) ...[
                            Expanded(child: _column(c)),
                            if (c != 9) const SizedBox(width: 1),
                          ],
                        ],
                      ),
                    ),
                  ),
                  bottomActionBar(
                    actions: [
                      (
                        icon: Icons.undo,
                        label: s.t('btnUndo'),
                        onTap: _controller.canUndo ? _onSpiderUndo : null,
                        badge: _controller.undoBudgetRemaining,
                        badgePlay: false,
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
                      (
                        icon: Icons.lightbulb,
                        label: s.t('hint'),
                        onTap: _onSpiderHintPressed,
                        badge: _controller.freeHintsRemaining,
                        badgePlay: false,
                      ),
                      (
                        icon: Icons.style,
                        label: s.t('btnNewShort'),
                        onTap: () => _controller.newGame(),
                        badge: null,
                        badgePlay: false,
                      ),
                    ],
                  ),
                  const YandexStickyBanner(),
                ],
              ),
              if (_activeDealFlightColumn != null)
                Positioned.fill(
                  child: IgnorePointer(child: _dealFlightsOverlay()),
                ),
              if (_isCollectAnimating)
                Positioned.fill(
                  child: IgnorePointer(child: _collectSequenceOverlay()),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _column(int column) {
    final pile = _state.tableau[column];
    return DragTarget<_SpiderDragPayload>(
      onWillAcceptWithDetails: (details) {
        final payload = details.data;
        return _controller.canMove(
          payload.fromColumn,
          payload.fromIndex,
          column,
        );
      },
      onAcceptWithDetails: (details) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        final payload = details.data;
        _controller.moveRun(payload.fromColumn, payload.fromIndex, column);
      },
      builder: (context, candidate, rejected) {
        return GestureDetector(
          onTap: () {
            ref.read(soundServiceProvider).play(SoundEvent.cardTap);
            _controller.autoMoveTop(column);
          },
          child: AnimatedContainer(
            duration: _cardMoveDuration,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final columnCardWidth = constraints.maxWidth;
                if (pile.isEmpty) {
                  return SizedBox(
                    width: columnCardWidth,
                    height: _cardHeight,
                    child: _hintGlowSpider(
                      'hint_spider_t:$column',
                      DecoratedBox(
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.white24),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  );
                }
                return Stack(
                  children: [
                    for (var i = 0; i < pile.length; i++)
                      AnimatedPositioned(
                        duration: _cardMoveDuration,
                        curve: Curves.easeInOutCubicEmphasized,
                        top: i * _tableauStep,
                        left: 0,
                        right: 0,
                        child: _buildCard(pile, i, column, columnCardWidth),
                      ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildCard(
    List<PlayingCard> pile,
    int idx,
    int column,
    double columnCardWidth,
  ) {
    final card = pile[idx];
    final isHiddenDealtTop =
        _isDealing &&
        idx == pile.length - 1 &&
        !_dealRevealedColumns.contains(column);
    if (isHiddenDealtTop) {
      // Пока "летит" карта в этот столбец, верхнюю новую карту скрываем в самом столбце.
      return const SizedBox.shrink();
    }
    final isDragged =
        _dragFromColumn == column &&
        _dragFromIndex != null &&
        idx >= _dragFromIndex!;
    final cardView = _playingCard(card);
    final cardFace = _spiderHintWrapCard(column, idx, pile, cardView);
    if (isDragged) {
      // Плавно приглушаем исходную стопку, чтобы не было резкого "рывка".
      return AnimatedOpacity(
        duration: _dragFadeDuration,
        curve: Curves.easeOutCubic,
        opacity: 0.05,
        child: cardFace,
      );
    }
    if (!_controller.canDragRun(column, idx)) return cardFace;

    final run = pile.sublist(idx);
    final runFeedback = SizedBox(
      // Ширина feedback равна ширине карты в колонке, чтобы при drag карта не "толстела".
      width: columnCardWidth,
      height: _cardHeight + (run.length - 1) * _tableauStep,
      child: Stack(
        children: [
          for (var i = 0; i < run.length; i++)
            Positioned(
              top: i * _tableauStep,
              left: 0,
              right: 0,
              child: _playingCard(run[i]),
            ),
        ],
      ),
    );

    return Draggable<_SpiderDragPayload>(
      data: _SpiderDragPayload(fromColumn: column, fromIndex: idx),
      // Якорь ниже карты: при drag карта гарантированно отображается выше пальца.
      dragAnchorStrategy: (draggable, context, position) {
        final box = context.findRenderObject() as RenderBox?;
        final size = box?.size ?? const Size(_cardWidth, _cardHeight);
        return Offset(size.width / 2, size.height + 36);
      },
      onDragStarted: () => setState(() {
        _dragFromColumn = column;
        _dragFromIndex = idx;
      }),
      onDragEnd: (_) => setState(_resetDragState),
      onDragCompleted: () => setState(_resetDragState),
      onDraggableCanceled: (_, __) => setState(_resetDragState),
      // Без доп. увеличения, чтобы карта не выглядела "выросшей" при перетаскивании.
      feedback: Material(color: Colors.transparent, child: runFeedback),
      // Оставляем легкий плейсхолдер, чтобы карта визуально не "исчезала" при drag.
      childWhenDragging: Opacity(opacity: 0.18, child: cardView),
      child: cardFace,
    );
  }

  // Оверлей: видимый разлет карт из колоды по столбцам с каскадной задержкой.
  Widget _dealFlightsOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final column = _activeDealFlightColumn;
        if (column == null) return const SizedBox.shrink();
        final pile = _state.tableau[column];
        final flyingCard = pile.isEmpty ? null : pile.last;
        const gap = 1.0;
        final columnWidth = (constraints.maxWidth - (9 * gap)) / 10;
        // В полете используем ту же ширину, что у карты в колонке, чтобы не было "широкая -> узкая".
        final flyingCardWidth = columnWidth;
        final startX =
            9 * (columnWidth + gap) + (columnWidth - flyingCardWidth) / 2;
        final safeTop = MediaQuery.paddingOf(context).top;
        final startY = 96.0 + safeTop;
        // Верх области табло в текущем лэйауте (после верхних панелей).
        final tableauTopY = 128.0 + safeTop;
        // Карта должна прилетать вниз столбца: на позицию верхней новой карты.
        final targetY = tableauTopY + ((pile.length - 1) * _tableauStep);
        final targetX =
            column * (columnWidth + gap) + (columnWidth - flyingCardWidth) / 2;

        return AnimatedBuilder(
          animation: _dealCtrl,
          builder: (context, _) {
            final t = Curves.easeInOutCubicEmphasized.transform(
              _dealCtrl.value,
            );
            final x = startX + (targetX - startX) * t;
            final y = startY + (targetY - startY) * t;
            return Stack(
              children: [
                Positioned(
                  left: x,
                  top: y,
                  width: flyingCardWidth,
                  height: _cardHeight,
                  // Летит реальная раздаваемая карта без полупрозрачности.
                  child: flyingCard == null
                      ? SizedBox(
                          width: flyingCardWidth,
                          height: _cardHeight,
                          child: _cardBack(),
                        )
                      : SizedBox(
                          width: flyingCardWidth,
                          height: _cardHeight,
                          child: _playingCard(flyingCard),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // Оверлей: перелет 13 карт (K..A) в дом по одной.
  Widget _collectSequenceOverlay() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final fromColumn = _collectFromColumn;
        final toSlot = _collectToSlot;
        final step = _collectCardStep;
        if (fromColumn == null || toSlot == null || step == null) {
          return const SizedBox.shrink();
        }

        const gap = 1.0;
        final columnWidth = (constraints.maxWidth - (9 * gap)) / 10;
        final flyingCardWidth = columnWidth;
        final safeTop = MediaQuery.paddingOf(context).top;

        final tableauTopY = 128.0 + safeTop;
        // Каждая карта должна стартовать со своей позиции в исходном столбце.
        final startY = tableauTopY +
            ((_collectFromColumnLenBefore - 1 - step) * _tableauStep);
        final startX = fromColumn * (columnWidth + gap) + (columnWidth - flyingCardWidth) / 2;

        // Слоты completed находятся в верхнем ряду в позициях 0..7.
        final topSlotY = 94.0 + safeTop;
        final targetX = toSlot * (columnWidth + gap) + (columnWidth - flyingCardWidth) / 2;
        final targetY = topSlotY;

        if (_collectCards.length != 13) return const SizedBox.shrink();
        final flying = _collectCards[step]; // K..A, последняя карта — туз.

        return AnimatedBuilder(
          animation: _collectCtrl,
          builder: (context, _) {
            final t = Curves.easeInOutCubicEmphasized.transform(_collectCtrl.value);
            final x = startX + (targetX - startX) * t;
            final y = startY + (targetY - startY) * t;
            return Stack(
              children: [
                // Временно рисуем оставшуюся часть собранного ранa,
                // чтобы столбик не "исчезал" мгновенно.
                for (var i = step + 1; i < _collectCards.length; i++)
                  Positioned(
                    left: startX,
                    top: tableauTopY + ((_collectFromColumnLenBefore - 13 + i) * _tableauStep),
                    width: flyingCardWidth,
                    height: _cardHeight,
                    child: SizedBox(
                      width: flyingCardWidth,
                      height: _cardHeight,
                      child: _playingCard(_collectCards[i]),
                    ),
                  ),
                Positioned(
                  left: x,
                  top: y,
                  width: flyingCardWidth,
                  height: _cardHeight,
                  child: SizedBox(
                    width: flyingCardWidth,
                    height: _cardHeight,
                    child: _playingCard(flying),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _topSlot({required Widget child}) {
    return SizedBox(width: _cardWidth, height: _cardHeight, child: child);
  }

  // Слева в доме показываем собранные столбцы (до 8), чтобы прогресс был виден визуально.
  Widget _completedSlot(int slotIndex) {
    final isCompleted = _state.completedSequences > slotIndex;
    if (!isCompleted) return _emptySlot();
    final suit = slotIndex < _state.completedSuits.length
        ? _state.completedSuits[slotIndex]
        : CardSuit.spades;
    final ace = PlayingCard(suit: suit, rank: 1, faceUp: true);
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          top: 8,
          child: Opacity(opacity: 0.45, child: _cardBack()),
        ),
        Positioned.fill(
          top: 4,
          child: Opacity(opacity: 0.75, child: _cardBack()),
        ),
        // Финальная карта собранной последовательности — туз, показываем его сверху.
        _playingCard(ace),
      ],
    );
  }

  Widget _emptySlot() {
    return Container(
      height: _cardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _cardBack() {
    final settings = ref.read(settingsProvider).asData?.value;
    final back = settings?.cardBack ?? 'blue';
    return Container(
      // Закрытая карта должна иметь ту же высоту, иначе превращается в "полоску".
      height: _cardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: back == 'red'
              ? const [Color(0xFFA83A3A), Color(0xFF7A1D1D)]
              : const [Color(0xFF2E5EA8), Color(0xFF1D4178)],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white70, width: 1.1),
      ),
    );
  }

  Widget _playingCard(PlayingCard c) {
    if (!c.faceUp) return _cardBack();
    final settings = ref.read(settingsProvider).asData?.value;
    final isRed = c.suit == CardSuit.hearts || c.suit == CardSuit.diamonds;
    final faceStyle = settings?.cardFaceStyle ?? CardFaceStyle.classic;
    final ink = isRed ? const Color(0xFFB42020) : const Color(0xFF1B1B1B);
    final rankText = _rank(c.rank);
    final suitText = _suit(c.suit);
    return Container(
      height: _cardHeight,
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: faceStyle == CardFaceStyle.minimal
          ? Stack(
              children: [
                // Узкая карта Паука: для «10» ранг+масть в ряд — меньший кегль и scale-down.
                Positioned(
                  left: 1,
                  top: 0,
                  child: SizedBox(
                    width: _cardWidth - 6,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            rankText,
                            style: TextStyle(
                              color: ink,
                              fontWeight: FontWeight.w800,
                              fontSize: rankText.length >= 2 ? 9.5 : 11,
                              height: 1,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(left: 1),
                            child: Text(
                              suitText,
                              style: TextStyle(
                                color: ink,
                                fontWeight: FontWeight.w800,
                                fontSize: rankText.length >= 2 ? 8.5 : 10,
                                height: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suitText,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.24),
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                Text(
                  '$rankText\n$suitText',
                  style: TextStyle(
                    color: ink,
                    fontWeight: FontWeight.w800,
                    fontSize: 11,
                    height: 1.0,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suitText,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.30),
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: 3.1415926,
                    child: Text(
                      '$rankText\n$suitText',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                        height: 1.0,
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  String _rank(int rank) {
    switch (rank) {
      case 1:
        return 'A';
      case 11:
        return 'J';
      case 12:
        return 'Q';
      case 13:
        return 'K';
      default:
        return '$rank';
    }
  }

  String _suit(CardSuit suit) {
    switch (suit) {
      case CardSuit.hearts:
        return '♥';
      case CardSuit.diamonds:
        return '♦';
      case CardSuit.clubs:
        return '♣';
      case CardSuit.spades:
        return '♠';
    }
  }
}

class _SpiderDragPayload {
  const _SpiderDragPayload({required this.fromColumn, required this.fromIndex});

  final int fromColumn;
  final int fromIndex;
}
