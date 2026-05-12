/// Детерминированный seed для ежедневной раздачи Косынки по дате `YYYY-MM-DD`.
int klondikeDailySeed(String ymd) {
  var h = 0;
  for (final c in ymd.codeUnits) {
    h = 0x1fffffff & (h * 31 + c);
  }
  return h == 0 ? 1 : h;
}
