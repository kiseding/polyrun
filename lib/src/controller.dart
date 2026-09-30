import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'args.dart';
import 'languages.dart';
import 'local_runner.dart';
import 'models.dart';
import 'piston.dart';
import 'recipes.dart';
import 'store.dart';
import 'which.dart';

class AppController extends ChangeNotifier {
  AppController({http.Client? client, this.probeOnBoot = true})
    : _client = client ?? http.Client(),
      _ownsClient = client == null {
    _piston = PistonApi(_client);
    _local = LocalRunner();
  }

  final http.Client _client;
  final bool _ownsClient;
  final bool probeOnBoot;
  late final PistonApi _piston;
  late final LocalRunner _local;

  AppStore? _store;
  Timer? _saveTimer;
  var _alive = true;

  var ready = false;
  String? bootError;
  var settings = AppSettings.fallback;
  var applets = <Applet>[];
  String? selectedId;
  var editorEpoch = 0;
  String? runningId;
  final Map<String, RunResult> results = {};
  var localProbes = <String, ResolvedProbe>{};
  var remoteRuntimes = <RemoteRuntime>[];
  var extras = <String, LangDef>{};
  var pathEnv = Platform.environment['PATH'] ?? '';
  String? remoteMessage;
  var remoteLoading = false;
  var probing = false;

  bool get running => runningId != null;

  Applet? get current {
    for (final applet in applets) {
      if (applet.id == selectedId) return applet;
    }
    return null;
  }

  List<Applet> get sortedApplets {
    final copy = [...applets];
    copy.sort((a, b) {
      if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
      return b.updatedAt.compareTo(a.updatedAt);
    });
    return copy;
  }

  List<LangDef> get allLanguages => [...kLanguages, ...extras.values];

  LangDef langOf(Applet applet) =>
      languageById(applet.languageId, extras: extras);

  bool localReady(LangDef lang) => localProbes.containsKey(lang.id);

  bool remoteReady(LangDef lang) {
    if (lang.pinnedVersion != null) return true;
    return bestRuntime(lang, remoteRuntimes) != null;
  }

  Future<void> bootstrap({Directory? supportDir}) async {
    try {
      final dir =
          supportDir ??
          Directory(
            '${(await getApplicationSupportDirectory()).path}${Platform.pathSeparator}polyrun',
          );
      final store = AppStore(dir);
      await store.ensure();
      _store = store;
      final existed = store.appletFile.existsSync();
      applets = existed ? await store.loadApplets() : seedApplets();
      if (!existed) await store.saveApplets(applets);
      settings = await store.loadSettings();
      ready = true;
      notifyListeners();
      if (probeOnBoot) {
        await refreshLocal();
        unawaited(refreshRemote(silent: true));
      }
    } catch (error) {
      bootError = '$error';
      ready = true;
      notifyListeners();
    }
  }

  Future<void> refreshLocal() async {
    probing = true;
    notifyListeners();
    try {
      pathEnv = await resolvePath();
      final found = <String, ResolvedProbe>{};
      for (final lang in kLanguages) {
        final recipe = lang.recipe;
        if (recipe == null) continue;
        final resolved = await recipe.resolve(pathEnv);
        if (resolved == null) continue;
        if (recipe.enrich != null) {
          final meta = await recipe.enrich!(resolved, pathEnv);
          found[lang.id] = resolved.withMeta(meta);
        } else {
          found[lang.id] = resolved;
        }
      }
      localProbes = found;
    } finally {
      probing = false;
      notifyListeners();
    }
  }

  Future<void> refreshRemote({bool silent = false}) async {
    if (settings.pistonBaseUrl.trim().isEmpty) {
      remoteMessage = '还没有填写 Piston 地址';
      notifyListeners();
      return;
    }
    remoteLoading = true;
    if (!silent) notifyListeners();
    try {
      final list = await _piston.fetchRuntimes(settings);
      remoteRuntimes = list;
      extras = _extrasFor(list);
      remoteMessage = 'Piston 上有 ${list.length} 个运行时';
    } catch (error) {
      remoteMessage = '$error';
    } finally {
      remoteLoading = false;
      notifyListeners();
    }
  }

  Map<String, LangDef> _extrasFor(List<RemoteRuntime> list) {
    final next = <String, LangDef>{};
    for (final runtime in list) {
      final covered = kLanguages.any((lang) => runtimeCovers(lang, runtime));
      if (covered) continue;
      final id = 'remote:${runtime.language}:${runtime.version}';
      next[id] = LangDef(
        id: id,
        name: '${runtime.language} ${runtime.version}',
        piston: runtime.language,
        aliases: runtime.aliases,
        fileName: 'main.txt',
        category: '远程',
        template: '',
        highlight: 'plaintext',
        pinnedVersion: runtime.version,
        note: '来自当前 Piston，本机没有单独的运行配方。',
      );
    }
    return next;
  }

  void select(String? id) {
    selectedId = id;
    settings = settings.copyWith(openAppletId: id, clearOpenApplet: id == null);
    notifyListeners();
    _scheduleSave();
  }

  Applet create(LangDef lang, {String? name, String? source}) {
    final applet = createApplet(lang, name: name, source: source);
    applets.add(applet);
    selectedId = applet.id;
    editorEpoch++;
    notifyListeners();
    _scheduleSave();
    return applet;
  }

  void togglePin(Applet applet) {
    applet.pinned = !applet.pinned;
    applet.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
  }

  void rename(String name) {
    final applet = current;
    if (applet == null || applet.name == name) return;
    applet.name = name;
    applet.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
  }

  void updateSource(String source) {
    final applet = current;
    if (applet == null || applet.source == source) return;
    applet.source = source;
    applet.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
  }

  void updateStdin(String stdin) {
    final applet = current;
    if (applet == null || applet.stdin == stdin) return;
    applet.stdin = stdin;
    applet.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
  }

  void updateArgs(String args) {
    final applet = current;
    if (applet == null || applet.args == args) return;
    applet.args = args;
    applet.updatedAt = DateTime.now();
    notifyListeners();
    _scheduleSave();
  }

  void changeLanguage(LangDef lang, {required bool replaceSource}) {
    final applet = current;
    if (applet == null) return;
    applet.languageId = lang.id;
    if (replaceSource) applet.source = lang.template;
    applet.updatedAt = DateTime.now();
    editorEpoch++;
    notifyListeners();
    _scheduleSave();
  }

  Applet duplicate(Applet applet) {
    final copy = applet.copyWith(
      id: newAppletId(),
      name: '${applet.name} 副本',
      pinned: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    applets.add(copy);
    selectedId = copy.id;
    editorEpoch++;
    notifyListeners();
    _scheduleSave();
    return copy;
  }

  void delete(Applet applet) {
    applets.removeWhere((item) => item.id == applet.id);
    results.remove(applet.id);
    if (selectedId == applet.id) selectedId = null;
    notifyListeners();
    _scheduleSave();
  }

  Future<int> importApplets(List<Applet> incoming) async {
    final known = {for (final applet in applets) applet.id};
    var added = 0;
    for (final applet in incoming) {
      if (known.add(applet.id)) {
        applets.add(applet);
        added++;
      }
    }
    notifyListeners();
    await flush();
    return added;
  }

  Future<void> updateSettings(AppSettings next) async {
    settings = next;
    notifyListeners();
    await _store?.saveSettings(settings);
  }

  Future<void> runCurrent() async {
    final applet = current;
    if (applet == null || runningId != null) return;
    await flush();
    runningId = applet.id;
    notifyListeners();
    try {
      results[applet.id] = await _dispatch(applet);
    } catch (error) {
      results[applet.id] = RunResult.message('$error');
    } finally {
      runningId = null;
      notifyListeners();
    }
  }

  Future<RunResult> _dispatch(Applet applet) async {
    final lang = langOf(applet);
    final args = splitArgs(applet.args);
    if (args.length > 64) return RunResult.message('参数超过 64 个');
    if (applet.source.length > 1000000) {
      return RunResult.message('源码超过 1MB，拒绝执行');
    }
    final timeout = Duration(seconds: settings.timeoutSeconds);
    final limit = settings.outputLimitKb * 1024;
    final wantLocal = settings.engine != EnginePreference.remote;
    final wantRemote = settings.engine != EnginePreference.local;
    final probe = localProbes[lang.id];
    final remote = _remoteFor(lang);
    final desktop = !Platform.isAndroid && !Platform.isIOS;

    if (wantLocal && desktop && probe != null && lang.recipe != null) {
      final localResult = await _local.run(
        recipe: lang.recipe!,
        probe: probe,
        source: applet.source,
        stdin: applet.stdin,
        args: args,
        timeout: timeout,
        outputLimit: limit,
        pathEnv: pathEnv,
      );
      final fallback =
          settings.engine == EnginePreference.auto &&
          localResult.spawnFailed &&
          wantRemote &&
          remote != null;
      if (!fallback) return localResult;
    }

    if (wantRemote &&
        remote != null &&
        settings.pistonBaseUrl.trim().isNotEmpty) {
      return _piston.execute(
        settings: settings,
        language: remote.language,
        version: remote.version,
        fileName: lang.fileName,
        source: applet.source,
        stdin: applet.stdin,
        args: args,
      );
    }
    return RunResult.message(
      _explain(lang, probe != null && desktop, remote != null),
    );
  }

  RemoteRuntime? _remoteFor(LangDef lang) {
    if (lang.pinnedVersion != null) {
      return RemoteRuntime(
        language: lang.piston,
        version: lang.pinnedVersion!,
        aliases: lang.aliases,
      );
    }
    return bestRuntime(lang, remoteRuntimes);
  }

  String _explain(LangDef lang, bool hasLocal, bool hasRemote) {
    final lines = <String>['现在跑不了 ${lang.name}。'];
    if (Platform.isAndroid || Platform.isIOS) {
      lines.add('手机不能调用系统里的编译器。');
    } else if (lang.recipe == null) {
      lines.add('这个语言没有本机运行配方。');
    } else if (!hasLocal) {
      lines.add('本机没找到：${lang.recipe!.summary}');
    }
    if (settings.engine == EnginePreference.local) {
      lines.add('引擎被设成了「仅本机」。');
    } else if (!hasRemote) {
      lines.add('Piston 语言列表里没有 ${lang.piston}。先在设置里连上自建 Piston，或装对应运行时。');
    } else if (settings.pistonBaseUrl.trim().isEmpty) {
      lines.add('还没有填写 Piston 地址。');
    }
    lines.add('公共 emkc.org 接口从 2026-02-15 起要白名单，默认请自建。');
    return lines.join('\n');
  }

  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 400), () {
      unawaited(flush());
    });
  }

  Future<void> flush() async {
    _saveTimer?.cancel();
    final store = _store;
    if (store == null) return;
    await store.saveApplets(applets);
    await store.saveSettings(settings);
  }

  @override
  void notifyListeners() {
    if (_alive) super.notifyListeners();
  }

  @override
  void dispose() {
    _alive = false;
    _saveTimer?.cancel();
    if (_ownsClient) _client.close();
    super.dispose();
  }
}
