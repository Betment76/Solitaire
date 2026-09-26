/// Целевой магазин распространения.
///
/// Выбор: `--dart-define-from-file=config/dart_defines/googleplay.json`
/// (внутри `STORE=googleplay`) для сборки под Google Play.
/// По умолчанию (без dart-define) — RuStore: `--flavor rustore`.
const String _store = String.fromEnvironment('STORE', defaultValue: 'rustore');

const bool isGplayTarget = _store == 'googleplay';
const bool isRuStoreTarget = !isGplayTarget;
