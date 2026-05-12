# Анализ проекта Solitaire

## Общая информация

**Flutter-приложение** — кроссплатформенная офлайн-игра с тремя пасьянсами: **Косынка (Klondike)**, **Паук (Spider)**, **Свободная ячейка (FreeCell)**.

- **SDK:** `^3.9.0`
- **State management:** Riverpod (`flutter_riverpod: ^3.3.1`)
- **Локальное хранение:** `shared_preferences: ^2.5.5`
- **Звук:** `audioplayers: ^6.6.0` + генерация WAV на лету
- **Локализация:** RU/EN через кастомный `AppStrings`
- **Тесты:** 31 unit/widget-тест

---

## Архитектура (feature-first)

```
lib/
├── core/                          # Общее ядро
│   ├── app.dart                   # Корневой MaterialApp + маршруты
│   ├── providers.dart             # Глобальные Riverpod-провайдеры
│   ├── app_table_background.dart  # Тема "зелёное сукно", BottomSheet, themeOnTable
│   ├── daily_seed.dart            # Детерминированный seed для Daily Challenge
│   ├── audio/
│   │   ├── sound_service.dart     # Сервис озвучки (asset → fallback WAV)
│   │   └── tone_generator.dart    # Генератор звуков (PCM → WAV)
│   ├── data/
│   │   └── local_store.dart       # SharedPreferences: настройки, статистика, сейвы
│   ├── l10n/
│   │   └── app_strings.dart       # RU/EN строки
│   └── models/
│       ├── app_settings.dart      # Настройки (язык, звук, тема, рубашка, drawCount)
│       └── app_stats.dart         # Статистика (победы, bestScore, winStreak)
├── features/
│   ├── solitaire_selector/        # Главный экран выбора режима
│   ├── klondike/                  # Косынка
│   │   ├── klondike_controller.dart  # Riverpod-контроллер
│   │   ├── klondike_screen.dart      # UI
│   │   └── domain/
│   │       ├── card.dart              # Модель PlayingCard
│   │       ├── klondike_engine.dart   # Движок правил
│   │       ├── klondike_state.dart    # Состояние партии
│   │       └── klondike_persistence.dart # Сериализация
│   ├── spider/                    # Паук (аналогичная структура)
│   ├── freecell/                  # FreeCell (аналогичная структура)
│   ├── settings/                  # Экран настроек
│   └── stats/                     # Экран статистики
└── shared/
    └── widgets/
        └── game_stub_screen.dart  # Заглушка для будущих режимов
```

---

## Ключевые паттерны

1. **Разделение UI и логики:** Каждый режим имеет `*Engine` (чистая логика без Flutter), `*Controller` (Riverpod `AsyncNotifier` — связка engine + state + persistence), `*Screen` (UI с drag&drop).

2. **Undo/Redo:** Стек состояний в контроллере (`_undo`, `_redo`). Каждый ход сохраняет предыдущее состояние.

3. **Сохранение:** Единый ключ `game_state` в `SharedPreferences`. Формат с версионированием (`version`, `mode`, `payload`). При загрузке определяется режим по `mode`.

4. **Daily Challenge:** Детерминированный seed от даты (`YYYY-MM-DD`). Рекорды ходов сохраняются отдельно.

5. **Звук:** Сначала пытается проиграть WAV из `assets/sounds/`, при ошибке — генерирует PCM-шум через `ToneGenerator`.

---

## Что уже реализовано (MVP)

| Фича | Статус |
|------|--------|
| Klondike (draw-1/draw-3) | ✅ |
| Spider (1 масть) | ✅ |
| FreeCell | ✅ |
| Drag & drop + tap-to-move | ✅ |
| Undo/Redo | ✅ |
| Auto-finish (Klondike) | ✅ |
| Hint (Klondike) | ✅ |
| Daily Challenge (Klondike) | ✅ |
| Статистика по режимам | ✅ |
| Настройки (язык, тема, звук, рубашка, draw count, speed) | ✅ |
| Локализация RU/EN | ✅ |
| Сохранение/восстановление партии | ✅ |
| Звуковые эффекты | ✅ |
| Анимации раздачи (Spider) | ✅ |

---

## Потенциальные улучшения / Roadmap

1. **Подсветка легальных ходов** — в README отмечено как отсутствующее
2. **Spider: несколько мастей** — сейчас только 1 масть (MVP)
3. **Интеграционные тесты** — user-flow сценарии
4. **80% покрытие core-логики** — замер и дополнение
5. **Оптимизация: вынос `PlayingCard` в отдельный файл** — сейчас `card.dart` лежит в `klondike/domain/`, используется всеми режимами
6. **Рефакторинг: дублирование кода в экранах** — `_metric`, `_topCircleButton`, `_bottomAction` повторяются в 3 экранах
7. **Унификация persistence** — Spider не имеет версионирования схемы (в отличие от Klondike и FreeCell)
