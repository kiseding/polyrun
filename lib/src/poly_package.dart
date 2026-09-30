import 'dart:convert';

import 'languages.dart';
import 'models.dart';

/// 万语盒只认这一种程序包：文件名以 `.poly` 结尾，内容是 version 1 的 poly 文档。
const polyFormat = 'poly';
const polyVersion = 1;

class PolyPackageException implements Exception {
  PolyPackageException(this.message);

  final String message;

  @override
  String toString() => message;
}

bool isPolyPackageName(String name) {
  final base = name.split(RegExp(r'[\\/]')).last;
  return base.toLowerCase().endsWith('.poly');
}

String polyFileName(String name) {
  final cleaned = name.replaceAll(RegExp(r'[\\/:*?"<>|\r\n]'), ' ').trim();
  final base = cleaned.isEmpty ? '未命名' : cleaned;
  if (base.toLowerCase().endsWith('.poly')) return base;
  return '$base.poly';
}

String encodePolyPackage(Applet applet) {
  return const JsonEncoder.withIndent('  ').convert({
    'format': polyFormat,
    'version': polyVersion,
    'name': applet.name,
    'language': applet.languageId,
    'source': applet.source,
    'stdin': applet.stdin,
    'args': applet.args,
  });
}

Applet decodePolyPackage(String text, {required String filename}) {
  if (!isPolyPackageName(filename)) {
    throw PolyPackageException('只支持 .poly 程序包');
  }
  if (text.length > 1500000) {
    throw PolyPackageException('程序包超过 1.5MB');
  }
  final body = text.startsWith('\uFEFF') ? text.substring(1) : text;
  Object? decoded;
  try {
    decoded = jsonDecode(body);
  } catch (_) {
    throw PolyPackageException('不是有效的 .poly 程序包');
  }
  if (decoded is! Map) {
    throw PolyPackageException('不是有效的 .poly 程序包');
  }
  final json = decoded.cast<String, Object?>();
  if (json['format'] != polyFormat) {
    throw PolyPackageException('不是有效的 .poly 程序包');
  }
  final version = json['version'];
  if (version is! num || version != polyVersion) {
    throw PolyPackageException('不支持的 .poly 版本');
  }
  final language = json['language'];
  final source = json['source'];
  if (language is! String || language.trim().isEmpty || source is! String) {
    throw PolyPackageException('不是有效的 .poly 程序包');
  }
  final stdin = json['stdin'];
  final args = json['args'];
  if ((stdin != null && stdin is! String) ||
      (args != null && args is! String)) {
    throw PolyPackageException('不是有效的 .poly 程序包');
  }
  final rawName = json['name'];
  final name = rawName is String && rawName.trim().isNotEmpty
      ? rawName.trim()
      : _stem(filename);
  final now = DateTime.now();
  return Applet(
    id: newAppletId(),
    name: name,
    languageId: language.trim(),
    source: source,
    stdin: stdin is String ? stdin : '',
    args: args is String ? args : '',
    pinned: false,
    createdAt: now,
    updatedAt: now,
  );
}

String _stem(String filename) {
  final base = filename.split(RegExp(r'[\\/]')).last;
  final stem = base.toLowerCase().endsWith('.poly')
      ? base.substring(0, base.length - 5)
      : base;
  final trimmed = stem.trim();
  return trimmed.isEmpty ? '未命名' : trimmed;
}
