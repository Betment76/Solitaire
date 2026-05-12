import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:solitaire/core/data/local_store.dart';
import 'package:solitaire/core/models/app_settings.dart';
import 'package:solitaire/core/models/app_stats.dart';

void main() {
  late LocalStore store;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    store = LocalStore();
  });

  test('loadSettings: пусто — дефолты', () async {
    final s = await store.loadSettings();
    expect(s.soundOn, isTrue);
    expect(s.klondikeDrawCount, 1);
  });

  test('saveSettings / loadSettings круговой путь', () async {
    const s = AppSettings(
      languageCode: 'en',
      soundOn: false,
      vibrationOn: false,
      dealSpeed: DealSpeed.fast,
      themeMode: ThemeMode.dark,
      cardBack: 'red',
      klondikeDrawCount: 3,
    );
    await store.saveSettings(s);
    final loaded = await store.loadSettings();
    expect(loaded.languageCode, 'en');
    expect(loaded.soundOn, isFalse);
    expect(loaded.dealSpeed, DealSpeed.fast);
    expect(loaded.themeMode, ThemeMode.dark);
    expect(loaded.cardBack, 'red');
    expect(loaded.klondikeDrawCount, 3);
  });

  test('loadSettings: legacy cinematicDealOn → cinematic', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'settings',
      jsonEncode({'cinematicDealOn': true, 'soundOn': true}),
    );
    final s = await store.loadSettings();
    expect(s.dealSpeed, DealSpeed.cinematic);
  });

  test('loadSettings: неверное dealSpeed → normal', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'settings',
      jsonEncode({'dealSpeed': 'nope', 'soundOn': true}),
    );
    final s = await store.loadSettings();
    expect(s.dealSpeed, DealSpeed.normal);
  });

  test('klondikeDrawCount не 3 — сохраняется как 1', () async {
    final p = await SharedPreferences.getInstance();
    await p.setString(
      'settings',
      jsonEncode({'klondikeDrawCount': 7, 'soundOn': true}),
    );
    final s = await store.loadSettings();
    expect(s.klondikeDrawCount, 1);
  });

  test('stats и game state', () async {
    const st = AppStats(wins: 2, winsKlondike: 2, winsSpider: 0, winsFreecell: 0, bestScore: 50, winStreak: 1);
    await store.saveStats(st);
    final l = await store.loadStats();
    expect(l.wins, 2);
    expect(l.bestScore, 50);

    await store.saveKlondikeState({'mode': 'x', 'v': 1});
    final g = await store.loadKlondikeState();
    expect(g?['mode'], 'x');
  });

  test('daily best moves', () async {
    expect(await store.loadDailyKlondikeBestMoves('2026-01-01'), isNull);
    expect(await store.saveDailyKlondikeBestMovesIfBetter('2026-01-01', 100), isTrue);
    expect(await store.loadDailyKlondikeBestMoves('2026-01-01'), 100);
    expect(await store.saveDailyKlondikeBestMovesIfBetter('2026-01-01', 120), isFalse);
    expect(await store.loadDailyKlondikeBestMoves('2026-01-01'), 100);
    expect(await store.saveDailyKlondikeBestMovesIfBetter('2026-01-01', 80), isTrue);
    expect(await store.loadDailyKlondikeBestMoves('2026-01-01'), 80);
    expect(await store.saveDailyKlondikeBestMovesIfBetter('2026-01-02', 50), isTrue);
    expect(await store.loadDailyKlondikeBestMoves('2026-01-02'), 50);
  });
}
