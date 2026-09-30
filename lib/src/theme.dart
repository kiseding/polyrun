import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';
import 'package:re_highlight/re_highlight.dart';
import 'package:re_highlight/styles/atom-one-dark.dart';
import 'package:re_highlight/styles/atom-one-light.dart';

import 'models.dart';

ThemeMode themeModeOf(ThemeChoice choice) {
  return switch (choice) {
    ThemeChoice.system => ThemeMode.system,
    ThemeChoice.light => ThemeMode.light,
    ThemeChoice.dark => ThemeMode.dark,
  };
}

ThemeData buildPolyTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFFC4843C),
    brightness: brightness,
    primary: dark ? const Color(0xFFE0A15A) : const Color(0xFF8C4E12),
    surface: dark ? const Color(0xFF14181D) : const Color(0xFFF4F0E7),
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: dark
        ? const Color(0xFF101317)
        : const Color(0xFFEFEAE1),
    dividerColor: dark ? const Color(0xFF2A3038) : const Color(0xFFDDD4C6),
    appBarTheme: AppBarTheme(
      backgroundColor: dark ? const Color(0xFF14181D) : const Color(0xFFF4F0E7),
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: dark ? const Color(0xFF1C222A) : const Color(0xFFFFFCF7),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    cardTheme: CardThemeData(
      color: dark ? const Color(0xFF1A1F26) : const Color(0xFFFFFCF7),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
  );
}

CodeEditorStyle editorStyle({required bool dark, required Mode mode}) {
  return CodeEditorStyle(
    fontSize: 14,
    fontFamily: 'Menlo',
    fontFamilyFallback: const [
      'JetBrains Mono',
      'Sarasa Mono SC',
      'Cascadia Mono',
      'Cascadia Code',
      'Consolas',
      'monospace',
    ],
    fontHeight: 1.5,
    backgroundColor: dark ? const Color(0xFF171B21) : const Color(0xFFFFFCF6),
    textColor: dark ? const Color(0xFFE7E2D6) : const Color(0xFF211C16),
    cursorColor: const Color(0xFFE0A15A),
    selectionColor: const Color(0x55E0A15A),
    cursorLineColor: dark ? const Color(0xFF222833) : const Color(0xFFF6EBDC),
    codeTheme: CodeHighlightTheme(
      languages: {'code': CodeHighlightThemeMode(mode: mode)},
      theme: dark ? atomOneDarkTheme : atomOneLightTheme,
    ),
  );
}

String relativeTime(DateTime time) {
  final delta = DateTime.now().difference(time);
  if (delta.inSeconds < 45) return '刚刚';
  if (delta.inMinutes < 60) return '${delta.inMinutes} 分钟前';
  if (delta.inHours < 24) return '${delta.inHours} 小时前';
  if (delta.inDays < 30) return '${delta.inDays} 天前';
  return '${time.month}月${time.day}日';
}
