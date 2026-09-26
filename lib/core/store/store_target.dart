/// Целевой магазин распространения.
///
/// Выбор: `--dart-define=STORE=gplay` для сборки под Google Play.
/// По умолчанию (без dart-define) — RuStore: `--flavor rustore`.
const String _store = String.fromEnvironment('STORE', defaultValue: 'rustore');

const bool isGplayTarget = _store == 'gplay';
const bool isRuStoreTarget = !isGplayTarget;
