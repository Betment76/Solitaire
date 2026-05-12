import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/yandex_rewarded.dart';
import '../../core/app_table_background.dart';
import '../../core/audio/sound_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../core/providers.dart';
import '../../shared/widgets/game_ui_common.dart';
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
  static const double _cardWidth = 56;
  static const double _cardHeight = 84;
  static const double _tableauStep = 20;
  static const double _boardHorizontalPadding = 2;
  static const Duration _cardMoveDuration = Duration(milliseconds: 260);
  static const Duration _dragFadeDuration = Duration(milliseconds: 180);

  int? _dragFromColumn;
  int? _dragFromCardIndex;
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
      // Не крутим время после победы
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

  /// Какие области подсветить по тегу из движка [KlondikeEngine.hint].
  Set<String> _hintKeysForTag(String tag) {
    final st = _state;
    if (tag == 'draw_from_stock') {
      return {'hint_stock'};
    }
    if (tag == 'waste_to_foundation') {
      if (st.waste.isEmpty) return {};
      return {'hint_waste', 'hint_f:${st.waste.last.suit.name}'};
    }
    if (tag.startsWith('waste_to_tableau_')) {
      final col = int.tryParse(tag.substring('waste_to_tableau_'.length));
      if (col == null) return {};
      return {'hint_waste', 'hint_t:$col'};
    }
    if (tag.startsWith('tableau_to_foundation_')) {
      final col = int.tryParse(tag.substring('tableau_to_foundation_'.length));
      if (col == null || st.tableau[col].isEmpty) return {};
      final top = st.tableau[col].last;
      return {'hint_t:$col', 'hint_f:${top.suit.name}'};
    }
    final runMatch = RegExp(r'^tableau_run_(\d+)_(\d+)_to_(\d+)$').firstMatch(tag);
    if (runMatch != null) {
      final from = int.parse(runMatch.group(1)!);
      final startIdx = int.parse(runMatch.group(2)!);
      final to = int.parse(runMatch.group(3)!);
      final keys = <String>{'hint_t:$to'};
      final fpile = st.tableau[from];
      for (var i = startIdx; i < fpile.length; i++) {
        keys.add('hint_card:$from:$i');
      }
      return keys;
    }
    return {};
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

  void _flashHintFromTag(String? tag) {
    if (tag == null) return;
    final keys = _hintKeysForTag(tag);
    if (keys.isEmpty) return;
    unawaited(_runHintBlink(keys));
  }

  String _hintMessage(AppStrings s, String? tag) {
    if (tag == null) return s.t('hintNone');
    if (tag == 'draw_from_stock') return s.t('hintDrawFromStock');
    if (tag == 'waste_to_foundation') return s.t('hintWasteToFoundation');
    if (tag.startsWith('waste_to_tableau_')) return s.t('hintWasteToTableau');
    if (tag.startsWith('tableau_to_foundation_')) return s.t('hintWasteToFoundation');
    if (tag.startsWith('tableau_run_')) return s.t('hintTableauToTableau');
    return s.t('hintNone');
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
      _flashHintFromTag(r.tag);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_hintMessage(s, r.tag)), behavior: SnackBarBehavior.floating, duration: const Duration(seconds: 3)),
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

    final s = AppStrings.of(Localizations.localeOf(context));
    final settings = ref.watch(settingsProvider).asData?.value;
    final score =
        state.foundations.values.fold<int>(0, (a, b) => a + b.length) * 10;

    return Scaffold(
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
                    const Spacer(),
                    metricWidget(s.t('metricTime'), _timeText(_seconds)),
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
                                    child: _foundationCard('hearts'),
                                  ),
                                  1 => _topSlot(
                                    child: _foundationCard('diamonds'),
                                  ),
                                  2 => _topSlot(
                                    child: _foundationCard('clubs'),
                                  ),
                                  3 => _topSlot(
                                    child: _foundationCard('spades'),
                                  ),
                                  5 => _topSlot(
                                    child: _state.waste.isEmpty
                                        ? _emptyTopCard()
                                        : _hintGlow(
                                            'hint_waste',
                                            Stack(
                                              // Разрешаем небольшой выход за границы слота,
                                              // чтобы в режиме draw-3 были видны все 3 карты.
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
                                              // Верхняя карта должна быть визуально сверху,
                                              // поэтому рисуем её последней в Stack.
                                              final right = _state.drawCount == 3
                                                  ? 10.0 * index
                                                  : 0.0;
                                              final cardWidget = _playingCard(
                                                rank: card.rank,
                                                suitName: card.suit.name,
                                                faceUp: true,
                                              );
                                              final wasteW = _tableauCardWidth(context);
                                              return Positioned(
                                                right: right,
                                                width: wasteW,
                                                child: isTop
                                                    ? Draggable<_DragPayload>(
                                                        data: _DragPayload.fromWaste(card.suit.name),
                                                        dragAnchorStrategy: pointerDragAnchorStrategy,
                                                        onDragStarted: () => setState(_resetDragState),
                                                        onDragEnd: (_) => setState(_resetDragState),
                                                        onDragCompleted: () => setState(_resetDragState),
                                                        onDraggableCanceled: (_, __) => setState(_resetDragState),
                                                        // Во overlay без явной ширины карта схлопывается по intrinsic — как на столе.
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
  Widget _emptyFoundationCard(String suitName, {Key? key}) {
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
            : _playingCard(rank: 0, suitName: 'back', faceUp: false),
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

  Widget _foundationCard(String suitName) {
    final suit = _suitFromName(suitName);
    final pile = _state.foundations[suit]!;
    return DragTarget<_DragPayload>(
      onWillAcceptWithDetails: (details) =>
          _canDropToFoundation(details.data, suitName),
      onAcceptWithDetails: (details) =>
          _dropToFoundation(details.data, suitName),
      builder: (context, candidateData, rejectedData) {
        final hasHover = candidateData.isNotEmpty;
        final slotWithCard = Stack(
          fit: StackFit.expand,
          children: [
            _emptyFoundationCard(suitName, key: ValueKey('empty-$suitName')),
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
                child: _playingCard(
                  key: ValueKey('f-${pile.last.suit.name}-${pile.last.rank}'),
                  rank: pile.last.rank,
                  suitName: pile.last.suit.name,
                  faceUp: true,
                ),
              ),
          ],
        );

        if (pile.isEmpty) {
          return _hintGlow(
            'hint_f:$suitName',
            AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: hasHover ? 1.05 : 1,
              child: slotWithCard,
            ),
          );
        }
        final top = pile.last;
        return _hintGlow(
          'hint_f:$suitName',
          Draggable<_DragPayload>(
          data: _DragPayload.fromFoundation(top.suit.name),
          dragAnchorStrategy: pointerDragAnchorStrategy,
          onDragEnd: (_) => setState(_resetDragState),
          onDragCompleted: () => setState(_resetDragState),
          onDraggableCanceled: (_, __) => setState(_resetDragState),
          feedback: _dragFeedbackCard(
            SizedBox(
              width: _cardWidth,
              height: _cardHeight,
              child: _playingCard(
                key: ValueKey('f-drag-${top.suit.name}-${top.rank}'),
                rank: top.rank,
                suitName: top.suit.name,
                faceUp: true,
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
          setState(_resetDragState);
        }
      },
      builder: (context, candidateData, rejectedData) {
        return GestureDetector(
          onTap: () {
            ref.read(soundServiceProvider).play(SoundEvent.cardTap);
            _controller.autoMoveTableauTop(columnIndex);
          },
          child: AnimatedContainer(
            duration: _cardMoveDuration,
            constraints: const BoxConstraints(minHeight: double.infinity),
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (pile.isEmpty) {
                  // Пустая колонка должна оставаться крупной зоной drop.
                  return Align(
                    alignment: Alignment.topCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: _hintGlow(
                        'hint_t:$columnIndex',
                        _emptyTopCard(),
                      ),
                    ),
                  );
                }
                return Stack(
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
              },
            ),
          ),
        );
      },
    );
  }

  Widget _buildTableauCard(List<PlayingCard> pile, int idx, int columnIndex) {
    final card = pile[idx];
    final isPulseTarget =
        _dropPulseColumn == columnIndex && idx == pile.length - 1;
    final cardWidget = _playingCard(
      rank: card.rank,
      suitName: card.suit.name,
      faceUp: card.faceUp,
    );
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
              child: _playingCard(
                rank: run[i].rank,
                suitName: run[i].suit.name,
                faceUp: run[i].faceUp,
              ),
            ),
        ],
      ),
    );
    return Draggable<_DragPayload>(
      data: _DragPayload.fromTableau(columnIndex, idx, card.suit.name),
      dragAnchorStrategy: pointerDragAnchorStrategy,
      onDragStarted: () => setState(() {
        _dragFromColumn = columnIndex;
        _dragFromCardIndex = idx;
      }),
      onDragEnd: (_) => setState(_resetDragState),
      onDragCompleted: () => setState(_resetDragState),
      onDraggableCanceled: (_, __) => setState(_resetDragState),
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

  /// Карточный виджет: лицевая сторона + рубашка для закрытых карт.
  Widget _playingCard({
    Key? key,
    required int rank,
    required String suitName,
    required bool faceUp,
  }) {
    final settings = ref.read(settingsProvider).asData?.value;
    if (!faceUp) {
      // Рубашка карты зависит от выбранного стиля.
      final back = settings?.cardBack ?? 'blue';
      return Container(
        key: key,
        height: _cardHeight,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: back == 'red'
                ? const [Color(0xFFA83A3A), Color(0xFF7A1D1D)]
                : const [Color(0xFF2E5EA8), Color(0xFF1D4178)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white70, width: 1.2),
          boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
        ),
        child: const SizedBox.shrink(),
      );
    }

    final isRed = suitName == 'hearts' || suitName == 'diamonds';
    final rankText = _rankLabel(rank);
    final suitText = _suitSymbol(suitName);
    final faceStyle = settings?.cardFaceStyle ?? CardFaceStyle.classic;
    final ink = isRed ? const Color(0xFFB42020) : const Color(0xFF1B1B1B);
    return Container(
      key: key,
      height: _cardHeight,
      // В minimal используем нулевой внутренний отступ:
      // ранг позиционируем вручную, масть ставим строго по центру карты.
      padding: faceStyle == CardFaceStyle.minimal
          ? EdgeInsets.zero
          : const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 3)],
      ),
      child: faceStyle == CardFaceStyle.minimal
          ? Stack(
              children: [
                // В минимале: ранг и масть слева сверху в ряд, крупная масть по центру.
                Positioned(
                  left: 4,
                  top: 0,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rankText,
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          fontSize: 19,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Text(
                          suitText,
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
                    suitText,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.24),
                      fontWeight: FontWeight.w800,
                      fontSize: 28,
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
                    fontSize: 14,
                    height: 1.0,
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suitText,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.32),
                      fontWeight: FontWeight.w800,
                      fontSize: 26,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: 3.1415926,
                    child: Text(
                      '$rankText\n$suitText',
                      style: TextStyle(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        height: 1.0,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  CardSuit _suitFromName(String suitName) {
    switch (suitName) {
      case 'hearts':
        return CardSuit.hearts;
      case 'diamonds':
        return CardSuit.diamonds;
      case 'clubs':
        return CardSuit.clubs;
      case 'spades':
      default:
        return CardSuit.spades;
    }
  }

  bool _canDropToTableau(_DragPayload payload, int toColumn) {
    return !identical(_previewDropToTableau(payload, toColumn), _state);
  }

  KlondikeState _previewDropToTableau(_DragPayload payload, int toColumn) {
    if (payload.source == _DragSource.waste) {
      return _engineMoveWasteToTableau(_state, toColumn);
    }
    if (payload.source == _DragSource.foundation) {
      return _engineMoveFoundationToTableau(
        _state,
        _suitFromName(payload.suitName),
        toColumn,
      );
    }
    if (payload.source == _DragSource.tableau && payload.fromColumn != null) {
      return _engineMoveTableauRunToTableau(
        _state,
        payload.fromColumn!,
        payload.fromCardIndex ?? 0,
        toColumn,
      );
    }
    return _state;
  }

  void _dropToTableau(_DragPayload payload, int toColumn) {
    final next = _previewDropToTableau(payload, toColumn);
    if (identical(next, _state)) return;
    ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
    _applyMove(next);
    _triggerDropPulse(toColumn);
  }

  bool _canDropToFoundation(_DragPayload payload, String suitName) {
    if (payload.suitName != suitName) return false;
    return !identical(_previewDropToFoundation(payload), _state);
  }

  KlondikeState _previewDropToFoundation(_DragPayload payload) {
    if (payload.source == _DragSource.waste) {
      return _engineMoveWasteToFoundation(_state);
    }
    if (payload.source == _DragSource.tableau && payload.fromColumn != null) {
      final fromPile = _state.tableau[payload.fromColumn!];
      final fromCardIndex = payload.fromCardIndex ?? fromPile.length - 1;
      if (fromCardIndex != fromPile.length - 1) return _state;
      return _engineMoveTableauTopToFoundation(_state, payload.fromColumn!);
    }
    return _state;
  }

  void _dropToFoundation(_DragPayload payload, String suitName) {
    if (payload.suitName != suitName) return;
    ref.read(soundServiceProvider).play(SoundEvent.cardToFoundation);
    _applyMove(_previewDropToFoundation(payload));
  }

  void _applyMove(KlondikeState next) {
    _resetDragState();
    if (identical(next, _state)) return;
    _controller.applyFromScreen(_state, next);
  }

  KlondikeState _engineMoveWasteToTableau(KlondikeState s, int toColumn) {
    final engine = KlondikeEngine();
    return engine.moveWasteToTableau(s, toColumn);
  }

  KlondikeState _engineMoveFoundationToTableau(
    KlondikeState s,
    CardSuit suit,
    int toColumn,
  ) {
    final engine = KlondikeEngine();
    return engine.moveFoundationToTableau(s, suit, toColumn);
  }

  KlondikeState _engineMoveTableauRunToTableau(
    KlondikeState s,
    int fromColumn,
    int fromCardIndex,
    int toColumn,
  ) {
    final engine = KlondikeEngine();
    return engine.moveTableauRunToTableau(
      s,
      fromColumn,
      fromCardIndex,
      toColumn,
    );
  }

  KlondikeState _engineMoveWasteToFoundation(KlondikeState s) {
    final engine = KlondikeEngine();
    return engine.moveWasteToFoundation(s);
  }

  KlondikeState _engineMoveTableauTopToFoundation(
    KlondikeState s,
    int fromColumn,
  ) {
    final engine = KlondikeEngine();
    return engine.moveTableauTopToFoundation(s, fromColumn);
  }

  /// Подпись ранга карты в классическом формате.
  String _rankLabel(int rank) {
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

  /// Символ масти для красивого отображения карты.
  String _suitSymbol(String suitName) {
    switch (suitName) {
      case 'hearts':
        return '♥';
      case 'diamonds':
        return '♦';
      case 'clubs':
        return '♣';
      case 'spades':
        return '♠';
      default:
        return '?';
    }
  }
}

enum _DragSource { waste, tableau, foundation }

class _DragPayload {
  const _DragPayload({
    required this.source,
    required this.suitName,
    this.fromColumn,
    this.fromCardIndex,
  });

  final _DragSource source;
  final String suitName;
  final int? fromColumn;
  final int? fromCardIndex;

  factory _DragPayload.fromWaste(String suitName) {
    return _DragPayload(source: _DragSource.waste, suitName: suitName);
  }

  factory _DragPayload.fromTableau(
    int fromColumn,
    int fromCardIndex,
    String suitName,
  ) {
    return _DragPayload(
      source: _DragSource.tableau,
      fromColumn: fromColumn,
      fromCardIndex: fromCardIndex,
      suitName: suitName,
    );
  }

  factory _DragPayload.fromFoundation(String suitName) {
    return _DragPayload(source: _DragSource.foundation, suitName: suitName);
  }
}
