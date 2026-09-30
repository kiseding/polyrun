/// Split a command-line string the way a shell would, enough for program args.
List<String> splitArgs(String raw) {
  final out = <String>[];
  final buf = StringBuffer();
  var quote = '';
  var escape = false;
  var token = false;

  void flush() {
    if (!token) return;
    out.add(buf.toString());
    buf.clear();
    token = false;
  }

  for (final rune in raw.runes) {
    final ch = String.fromCharCode(rune);
    if (escape) {
      buf.write(ch);
      token = true;
      escape = false;
      continue;
    }
    if (ch == r'\' && quote != "'") {
      escape = true;
      token = true;
      continue;
    }
    if (quote.isNotEmpty) {
      if (ch == quote) {
        quote = '';
      } else {
        buf.write(ch);
      }
      token = true;
      continue;
    }
    if (ch == '"' || ch == "'") {
      quote = ch;
      token = true;
      continue;
    }
    if (ch == ' ' || ch == '\t' || ch == '\n') {
      flush();
      continue;
    }
    buf.write(ch);
    token = true;
  }
  flush();
  return out;
}
