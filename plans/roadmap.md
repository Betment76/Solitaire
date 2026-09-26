# 🚀 Дорожная карта: MVP → Полноценный продукт

> Версия: **1.0.2+3** · **1.1 ✅** · **1.2 ✅** · **2.0 ~40%**

---

## 🎯 Версия 2.0 — «Полноценный продукт»

### Тесты
- [x] Интеграция save→load для Косынки, Паука, FreeCell (`game_save_restore_integration_test.dart`)
- [x] Unit-тест сериализации Паука (`spider_persistence_test.dart`)
- [ ] UI-тесты drag & drop (integration_test на устройстве)
- [ ] Покрытие > 80% (замер `flutter test --coverage`)

### Надёжность
- [x] Битый JSON сейва → `load*State` возвращает `null` (новая игра)

### Haptic
- [x] Вибрация в `SoundService.play()` по `vibrationOn` (tap / slide / foundation / win)

### Планшеты / landscape
- [ ] Отдельная landscape-раскладка
- [~] `effectiveCardScale` для планшетов (1.1)

---

## ▶️ Дальше

1. `integration_test/` — smoke на эмуляторе (открыть режим → ход → выход → продолжить)
2. CI: `flutter test --coverage` + порог
3. Landscape для игровых экранов
