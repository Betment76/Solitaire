/// Детерминированный seed для ежедневной раздачи Косынки по дате `YYYY-MM-DD`.
int klondikeDailySeed(String ymd) {
  var h = 0;
  for (final c in ymd.codeUnits) {
    h = 0x1fffffff & (h * 31 + c);
  }
  return h == 0 ? 1 : h;
}

/// Seed ежедневной FreeCell (другой множитель — другая раздача, чем у Косынки).
int freecellDailySeed(String ymd) {
  var h = 17;
  for (final c in ymd.codeUnits) {
    h = 0x1fffffff & (h * 37 + c);
  }
  return h == 0 ? 2 : h;
}
