import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/ads/yandex_rewarded.dart';
import '../../core/app_table_background.dart';
import '../../core/audio/sound_service.dart';
import '../../core/l10n/app_strings.dart';
import '../../core/models/app_settings.dart';
import '../../core/models/card.dart';
import '../../core/providers.dart';
import '../../shared/widgets/game_ui_common.dart';
import '../../shared/widgets/yandex_sticky_banner.dart';
import 'domain/freecell_persistence.dart';
import 'domain/freecell_state.dart';
import 'freecell_controller.dart';

/// Экран режима FreeCell с реальной логикой.
class FreecellScreen extends ConsumerStatefulWidget {
  const FreecellScreen({super.key});

  @override
  ConsumerState<FreecellScreen> createState() => _FreecellScreenState();
}

class _FreecellScreenState extends ConsumerState<FreecellScreen> {
  static const double _smallCardHeight = 64;
  /// Сдвиг между картами в колонке — видна полоса с рангом верхней части карты.
  static const double _tableauCardStep = 20;
  // Крупная масть в центре и в углах classic: в 1.5 раза меньше прежней.
  static const double _fcSuitCenterSize = 22.0 / 1.5;
  static const double _fcSuitCornerSize = 12.0 / 1.5;
  static const double _fcRankCornerSize = 12.0;

  int? _dropPulseCell;
  int? _dropPulseFoundation;
  int? _dragRunColumn;
  int? _dragRunStart;

  FreecellState get _state =>
      ref.read(freecellControllerProvider).asData!.value;
  FreecellController get _controller =>
      ref.read(freecellControllerProvider.notifier);

  void _triggerDropPulseCell(int idx) {
    setState(() => _dropPulseCell = idx);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _dropPulseCell != idx) return;
      setState(() => _dropPulseCell = null);
    });
  }

  void _triggerDropPulseFoundation(String suitName) {
    setState(() => _dropPulseFoundation = suitName.hashCode);
    Future<void>.delayed(const Duration(milliseconds: 150), () {
      if (!mounted || _dropPulseFoundation != suitName.hashCode) return;
      setState(() => _dropPulseFoundation = null);
    });
  }

  /// Автофиниш: бесплатная попытка, затем rewarded (как в Косынке).
  Future<void> _onAutoFinishPressed() async {
    final s = AppStrings.of(Localizations.localeOf(context));
    if (_controller.canAutoFinish()) {
      await _controller.autoFinishAll();
      return;
    }
    if (!_controller.engineAllowsAutoFinish()) return;
    final ok = await showYandexRewardedAd();
    if (!mounted) return;
    if (ok) {
      _controller.grantAutoFinishFromReward();
      await _controller.autoFinishAll();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('rewardAdFailed')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// До 4 доп. ячеек: первая без рекламы, остальные 3 — диалог и rewarded.
  Future<void> _onExtraCellPressed() async {
    final s = AppStrings.of(Localizations.localeOf(context));
    if (_state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells) {
      return;
    }
    ref.read(soundServiceProvider).play(SoundEvent.hint);
    if (_state.freeExtraCellUnlockPending) {
      _controller.addExtraFreeCellSlotFree();
      return;
    }
    final watchAd = await showTableAdOfferDialog(
      context,
      title: s.t('extraCellRewardTitle'),
      body: s.t('extraCellRewardBody'),
      primaryLabel: s.t('hintRewardWatch'),
      secondaryLabel: s.t('hintRewardDecline'),
    );
    if (!mounted) return;
    if (watchAd != true) return;
    final ok = await showYandexRewardedAd();
    if (!mounted) return;
    if (ok) {
      _controller.addExtraFreeCellSlotFromAd();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.t('rewardAdFailed')), behavior: SnackBarBehavior.floating),
      );
    }
  }

  /// Отмена: 5 бесплатных за партию, дальше диалог и rewarded (как в Пауке).
  Future<void> _onFreecellUndo() async {
    try {
      final s = AppStrings.of(Localizations.localeOf(context));
      if (_controller.canUndoWithBudget) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        await _controller.undo();
        return;
      }
      if (!_controller.canUndo) return;
      final watchAd = await showTableAdOfferDialog(
        context,
        title: s.t('undoRewardTitle'),
        body: s.t('undoRewardBody'),
        primaryLabel: s.t('hintRewardWatch'),
        secondaryLabel: s.t('hintRewardDecline'),
      );
      if (!mounted) return;
      if (watchAd != true) return;
      final ok = await showYandexRewardedAd(placement: RewardedAdPlacement.freecellUndo);
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

  @override
  Widget build(BuildContext context) {
    final asyncState = ref.watch(freecellControllerProvider);
    final state = asyncState.asData?.value;

    final settings = ref.watch(settingsProvider).asData?.value;

    if (state == null) {
      return Scaffold(
        backgroundColor: Colors.transparent,
        body: SizedBox.expand(
          child: DecoratedBox(
            decoration: tableBackgroundDecoration(settings),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final s = AppStrings.of(Localizations.localeOf(context));

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
                      () => Navigator.pop(context),
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
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: _topRow(),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: LayoutBuilder(
                    builder: (context, c) {
                      // Прежняя ширина одной колонки: (экран − 12) / 8; свободу даём через Spacer.
                      final cw = (c.maxWidth - 12) / 8;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Spacer(),
                          for (var col = 0; col < 8; col++) ...[
                            SizedBox(width: cw, child: _column(col)),
                            const Spacer(),
                          ],
                        ],
                      );
                    },
                  ),
                ),
              ),
              bottomActionBar(
                actions: [
                  (
                    icon: Icons.undo,
                    label: s.t('btnUndo'),
                    onTap: _controller.canUndo ? _onFreecellUndo : null,
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
                  (
                    icon: Icons.style,
                    label: s.t('btnPlay'),
                    onTap: () => _controller.newGame(),
                    badge: null,
                    badgePlay: false,
                  ),
                  (
                    icon: Icons.add_box_outlined,
                    label: s.t('rewardExtraCell'),
                    onTap: _state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells
                        ? null
                        : _onExtraCellPressed,
                    // Бесплатная «1» или тот же жёлтый кружок с play (реклама).
                    badge: _state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells
                        ? null
                        : (_state.freeExtraCellUnlockPending ? 1 : null),
                    badgePlay: _state.extraFreeCellSlots >= FreecellPersistence.maxExtraFreeCells ||
                            _state.freeExtraCellUnlockPending
                        ? false
                        : true,
                  ),
                  (
                    icon: Icons.auto_fix_high,
                    label: s.t('autoFinish'),
                    onTap: (_controller.canAutoFinish() ||
                            _controller.engineAllowsAutoFinish())
                        ? _onAutoFinishPressed
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

  /// Верх ячеек + оснований: одна раскладка на любую ширину (без горизонтального скролла и «узкого» режима).
  Widget _topRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: _leftSection()),
        const SizedBox(width: 12),
        Expanded(child: _rightSection()),
      ],
    );
  }

  Widget _leftSection() {
    final n = _state.freeCells.length;
    if (n <= 4) {
      return SizedBox(
        height: _smallCardHeight,
        child: Row(
          children: [
            for (var i = 0; i < n; i++)
              Expanded(child: _freeCellSlot(i)),
          ],
        ),
      );
    }
    // 5–8 ячеек: две строки по 4 колонки, ширина ячейки = четверть строки (как у верхнего ряда при любой заполненности нижней).
    return LayoutBuilder(
      builder: (context, constraints) {
        final cellW = constraints.maxWidth / 4;
        return SizedBox(
          height: _smallCardHeight * 2 + 4,
          child: Column(
            children: [
              SizedBox(
                height: _smallCardHeight,
                child: Row(
                  children: [
                    for (var i = 0; i < 4; i++)
                      SizedBox(
                        width: cellW,
                        height: _smallCardHeight,
                        child: _freeCellSlot(i),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: _smallCardHeight,
                child: Row(
                  children: [
                    for (var col = 0; col < 4; col++)
                      SizedBox(
                        width: cellW,
                        height: _smallCardHeight,
                        child: col + 4 < n
                            ? _freeCellSlot(col + 4)
                            : const SizedBox.shrink(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _rightSection() {
    return SizedBox(
      height: _smallCardHeight,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++)
            Expanded(child: _foundationSlot(CardSuit.values[i])),
        ],
      ),
    );
  }

  Widget _freeCellSlot(int idx) {
    final card = _state.freeCells[idx];
    final isPulse = _dropPulseCell == idx;
    return DragTarget<_FcDragPayload>(
      onWillAcceptWithDetails: (details) =>
          details.data.source != _FcSource.foundation && card == null,
      onAcceptWithDetails: (details) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        final p = details.data;
        if (p.source == _FcSource.tableau) {
          _controller.moveTableauToFreeCell(p.fromColumn!, idx);
          _triggerDropPulseCell(idx);
        }
      },
      builder: (context, candidate, rejected) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final hasHover = candidate.isNotEmpty;
            final slotWidget =
                card == null ? _emptySmallSlot() : _fcPlayingCard(card, width: w);
            final pulsedWidget = AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: isPulse ? 1.05 : 1,
              child: slotWidget,
            );
            if (card == null) {
              return AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: hasHover ? 1.05 : 1,
                child: pulsedWidget,
              );
            }
            return Draggable<_FcDragPayload>(
              data: _FcDragPayload.fromFreeCell(idx, card.suit.name),
              feedback: Material(
                color: Colors.transparent,
                child: _fcPlayingCard(card, width: w),
              ),
              childWhenDragging: _emptySmallSlot(),
              child: pulsedWidget,
            );
          },
        );
      },
    );
  }

  Widget _foundationSlot(CardSuit suit) {
    final pile = _state.foundations[suit]!;
    final isPulse = _dropPulseFoundation == suit.name.hashCode;
    return DragTarget<_FcDragPayload>(
      onWillAcceptWithDetails: (details) {
        final p = details.data;
        if (p.suitName != suit.name) return false;
        if (p.source == _FcSource.tableau) {
          return _controller.canMoveTableauToFoundation(p.fromColumn!);
        }
        if (p.source == _FcSource.freeCell) {
          return _controller.canMoveFreeCellToFoundation(p.fromCell!);
        }
        return false;
      },
      onAcceptWithDetails: (details) {
        ref.read(soundServiceProvider).play(SoundEvent.cardToFoundation);
        final p = details.data;
        if (p.source == _FcSource.tableau)
          _controller.moveTableauToFoundation(p.fromColumn!);
        if (p.source == _FcSource.freeCell)
          _controller.moveFreeCellToFoundation(p.fromCell!);
        _triggerDropPulseFoundation(suit.name);
      },
      builder: (context, candidate, rejected) {
        return LayoutBuilder(
          builder: (context, constraints) {
            final w = constraints.maxWidth;
            final hasHover = candidate.isNotEmpty;
            final slotWidget = pile.isEmpty
                ? _emptyFoundationSlot()
                : _fcPlayingCard(pile.last, width: w);
            final pulsedWidget = AnimatedScale(
              duration: const Duration(milliseconds: 160),
              scale: isPulse ? 1.05 : 1,
              child: slotWidget,
            );
            if (pile.isEmpty) {
              return AnimatedScale(
                duration: const Duration(milliseconds: 160),
                scale: hasHover ? 1.05 : 1,
                child: pulsedWidget,
              );
            }
            return Draggable<_FcDragPayload>(
              data: _FcDragPayload.fromFoundation(suit.name),
              feedback: Material(
                color: Colors.transparent,
                child: _fcPlayingCard(pile.last, width: w),
              ),
              childWhenDragging: pulsedWidget,
              child: pulsedWidget,
            );
          },
        );
      },
    );
  }

  Widget _column(int column) {
    final pile = _state.tableau[column];
    final draggingThisColumn =
        _dragRunColumn == column && _dragRunStart != null;
    final dragStart = _dragRunStart ?? -1;
    return DragTarget<_FcDragPayload>(
      onWillAcceptWithDetails: (details) {
        final p = details.data;
        var ok = false;
        if (p.source == _FcSource.tableau)
          ok = _controller.canMoveTableauToTableau(p.fromColumn!, column, fromCardIndex: p.fromCardIndex);
        if (p.source == _FcSource.freeCell)
          ok = _controller.canMoveFreeCellToTableau(p.fromCell!, column);
        return ok;
      },
      onAcceptWithDetails: (details) {
        ref.read(soundServiceProvider).play(SoundEvent.cardSlide);
        final p = details.data;
        if (p.source == _FcSource.tableau)
          _controller.moveTableauToTableau(p.fromColumn!, column, fromCardIndex: p.fromCardIndex);
        if (p.source == _FcSource.freeCell)
          _controller.moveFreeCellToTableau(p.fromCell!, column);
      },
      builder: (context, candidate, rejected) {
        return GestureDetector(
          onTap: () {
            ref.read(soundServiceProvider).play(SoundEvent.cardTap);
            _controller.autoMoveTableauTop(column);
          },
          child: LayoutBuilder(
            builder: (context, constraints) {
              final cardWidth = constraints.maxWidth;
              return Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < pile.length; i++)
                    if (!(draggingThisColumn && i > dragStart))
                      Positioned(
                        top: i * _tableauCardStep,
                        left: 0,
                        right: 0,
                        child: (_isFcDraggableFrom(pile, i))
                            ? Draggable<_FcDragPayload>(
                                data: _FcDragPayload.fromTableau(
                                  column,
                                  i,
                                  pile[i].suit.name,
                                ),
                                onDragStarted: () {
                                  setState(() {
                                    _dragRunColumn = column;
                                    _dragRunStart = i;
                                  });
                                },
                                onDragEnd: (_) {
                                  if (!mounted) return;
                                  setState(() {
                                    _dragRunColumn = null;
                                    _dragRunStart = null;
                                  });
                                },
                                feedback: Material(
                                  color: Colors.transparent,
                                  child: _runDragFeedback(pile, i, cardWidth),
                                ),
                                childWhenDragging: const SizedBox.shrink(),
                                child: _fcPlayingCard(pile[i], width: cardWidth),
                              )
                            : _fcPlayingCard(pile[i], width: cardWidth),
                      ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  /// В FreeCell можно тащить последовательность от [index] до конца колонки,
  /// если все карты чередуются по цвету и убывают по рангу.
  bool _isFcDraggableFrom(List<PlayingCard> pile, int index) {
    for (var i = index; i < pile.length - 1; i++) {
      if (pile[i].color == pile[i + 1].color ||
          pile[i].rank != pile[i + 1].rank + 1) {
        return false;
      }
    }
    return true;
  }

  /// Визуал "летящей" стопки при перетаскивании.
  Widget _runDragFeedback(
    List<PlayingCard> pile,
    int fromIndex,
    double width,
  ) {
    final run = pile.sublist(fromIndex);
    final height = _smallCardHeight + ((run.length - 1) * _tableauCardStep);
    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          for (var i = 0; i < run.length; i++)
            Positioned(
              top: i * _tableauCardStep,
              left: 0,
              right: 0,
              child: _fcPlayingCard(run[i], width: width),
            ),
        ],
      ),
    );
  }

  Widget _emptySmallSlot() {
    return Container(
      height: _smallCardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _emptyFoundationSlot() {
    return Container(
      height: _smallCardHeight,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.white24),
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Center(
        child: Text(
          'A',
          style: TextStyle(
            color: Colors.white38,
            fontSize: 19,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  /// Рубашка по настройке «Стиль».
  Widget _fcCardBack({double? width}) {
    final loaded = ref.read(settingsProvider).asData?.value;
    final back = loaded?.cardBack ?? 'blue';
    return Container(
      width: width,
      height: _smallCardHeight,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: back == 'red'
              ? const [Color(0xFFA83A3A), Color(0xFF7A1D1D)]
              : const [Color(0xFF2E5EA8), Color(0xFF1D4178)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white70, width: 1.1),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
    );
  }

  /// Лицо карты: [width] — явная ширина (важно для feedback при перетаскивании).
  Widget _fcPlayingCard(PlayingCard c, {double? width}) {
    if (!c.faceUp) return _fcCardBack(width: width);
    final loaded = ref.read(settingsProvider).asData?.value;
    final faceStyle = loaded?.cardFaceStyle ?? CardFaceStyle.classic;
    final isRed = c.suit == CardSuit.hearts || c.suit == CardSuit.diamonds;
    final ink = isRed ? const Color(0xFFB42020) : const Color(0xFF1B1B1B);
    final rankText = _rank(c.rank);
    final suitText = _suit(c.suit);
    return Container(
      width: width,
      height: _smallCardHeight,
      padding: faceStyle == CardFaceStyle.minimal
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 5, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 2)],
      ),
      child: faceStyle == CardFaceStyle.minimal
          ? Stack(
              clipBehavior: Clip.none,
              children: [
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
                          fontSize: 14,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Text(
                          suitText,
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w800,
                            fontSize: 12,
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
                      fontSize: 26,
                    ),
                  ),
                ),
              ],
            )
          : Stack(
              children: [
                Text.rich(
                  TextSpan(
                    style: TextStyle(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      height: 1.0,
                    ),
                    children: [
                      TextSpan(
                        text: rankText,
                        style: const TextStyle(fontSize: _fcRankCornerSize),
                      ),
                      TextSpan(
                        text: '\n$suitText',
                        style: TextStyle(fontSize: _fcSuitCornerSize),
                      ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.center,
                  child: Text(
                    suitText,
                    style: TextStyle(
                      color: ink.withValues(alpha: 0.30),
                      fontWeight: FontWeight.w800,
                      fontSize: _fcSuitCenterSize,
                    ),
                  ),
                ),
                Align(
                  alignment: Alignment.bottomRight,
                  child: Transform.rotate(
                    angle: 3.1415926535897932,
                    child: Text.rich(
                      TextSpan(
                        style: TextStyle(
                          color: ink,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                        ),
                        children: [
                          TextSpan(
                            text: rankText,
                            style: const TextStyle(fontSize: _fcRankCornerSize),
                          ),
                          TextSpan(
                            text: '\n$suitText',
                            style: TextStyle(fontSize: _fcSuitCornerSize),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.right,
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

enum _FcSource { tableau, freeCell, foundation }

class _FcDragPayload {
  const _FcDragPayload({
    required this.source,
    required this.suitName,
    this.fromColumn,
    this.fromCardIndex,
    this.fromCell,
  });

  final _FcSource source;
  final String suitName;
  final int? fromColumn;
  final int? fromCardIndex;
  final int? fromCell;

  factory _FcDragPayload.fromTableau(int fromColumn, int fromCardIndex, String suitName) {
    return _FcDragPayload(
      source: _FcSource.tableau,
      suitName: suitName,
      fromColumn: fromColumn,
      fromCardIndex: fromCardIndex,
    );
  }

  factory _FcDragPayload.fromFreeCell(int fromCell, String suitName) {
    return _FcDragPayload(
      source: _FcSource.freeCell,
      suitName: suitName,
      fromCell: fromCell,
    );
  }

  factory _FcDragPayload.fromFoundation(String suitName) {
    return _FcDragPayload(source: _FcSource.foundation, suitName: suitName);
  }
}
