import 'dart:convert';
import 'dart:io';

import 'models.dart';

class AppStore {
  AppStore(this.root);

  final Directory root;

  File get appletFile =>
      File('${root.path}${Platform.pathSeparator}applets.json');
  File get settingsFile =>
      File('${root.path}${Platform.pathSeparator}settings.json');

  Future<void> ensure() async {
    if (!root.existsSync()) {
      await root.create(recursive: true);
    }
  }

  Future<List<Applet>> loadApplets() async {
    if (!appletFile.existsSync()) return [];
    final decoded = jsonDecode(await appletFile.readAsString());
    if (decoded is! List) return [];
    return decoded
        .whereType<Map>()
        .map((item) => Applet.fromJson(item.cast<String, Object?>()))
        .toList();
  }

  Future<void> saveApplets(List<Applet> applets) async {
    await ensure();
    final text = const JsonEncoder.withIndent('  ')
        .convert(applets.map((a) => a.toJson()).toList());
    await appletFile.writeAsString(text);
  }

  Future<AppSettings> loadSettings() async {
    if (!settingsFile.existsSync()) return AppSettings.fallback;
    final decoded = jsonDecode(await settingsFile.readAsString());
    if (decoded is! Map) return AppSettings.fallback;
    return AppSettings.fromJson(decoded.cast<String, Object?>());
  }

  Future<void> saveSettings(AppSettings settings) async {
    await ensure();
    final text = const JsonEncoder.withIndent('  ').convert(settings.toJson());
    await settingsFile.writeAsString(text);
  }
}
