import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrun/src/args.dart';
import 'package:polyrun/src/languages.dart';
import 'package:polyrun/src/local_runner.dart';
import 'package:polyrun/src/models.dart';
import 'package:polyrun/src/piston.dart';
import 'package:polyrun/src/recipes.dart';
import 'package:polyrun/src/store.dart';

void main() {
  test('split args with quotes', () {
    expect(splitArgs('a "b c" d'), ['a', 'b c', 'd']);
    expect(splitArgs("a 'b c'"), ['a', 'b c']);
    expect(splitArgs(''), isEmpty);
    expect(splitArgs(r'a \ b'), ['a', ' b']);
  });

  test('piston url and response', () {
    expect(
      pistonEndpoint('http://127.0.0.1:2000/api/v2/', 'runtimes').toString(),
      'http://127.0.0.1:2000/api/v2/runtimes',
    );
    expect(
      normalizePistonBase('https://emkc.org/api/v2/piston/runtimes'),
      'https://emkc.org/api/v2/piston',
    );
    final ok = parsePistonResponse(
      status: 200,
      body: '{"language":"python","version":"3.10.0","run":{"stdout":"hi\\n","stderr":"","code":0,"signal":null}}',
      elapsedMs: 12,
      limit: 1000,
    );
    expect(ok.ok, isTrue);
    expect(ok.stdout, 'hi\n');
    final denied = parsePistonResponse(
      status: 401,
      body: '{"message":"whitelist"}',
      elapsedMs: 4,
      limit: 1000,
    );
    expect(denied.ok, isFalse);
    expect(denied.message, contains('whitelist'));
  });

  test('runtime matching picks the newest version', () {
    final lang = kLanguageById['javascript']!;
    final best = bestRuntime(lang, const [
      RemoteRuntime(language: 'javascript', version: '1.32.3'),
      RemoteRuntime(
        language: 'js',
        version: '18.15.0',
        aliases: ['javascript'],
      ),
    ]);
    expect(best?.version, '18.15.0');
    expect(compareSemver('18.15.0', '1.32.3') > 0, isTrue);
  });

  test('applet store roundtrip', () async {
    final dir = await Directory.systemTemp.createTemp('polyrun-store');
    addTearDown(() => dir.delete(recursive: true));
    final store = AppStore(dir);
    final applet = createApplet(
      kLanguageById['python']!,
      name: '示例',
      stdin: '你好',
    );
    await store.saveApplets([applet]);
    await store.saveSettings(AppSettings.fallback.copyWith(timeoutSeconds: 12));
    final loaded = await store.loadApplets();
    expect(loaded.single.name, '示例');
    expect(loaded.single.stdin, '你好');
    expect((await store.loadSettings()).timeoutSeconds, 12);
  });

  test('local bash recipe prints', () async {
    final recipe = kRecipes['bash']!;
    final probe = await recipe.resolve('/bin:/usr/bin:/usr/local/bin');
    if (probe == null) return;
    final runner = LocalRunner();
    final result = await runner.run(
      recipe: recipe,
      probe: probe,
      source: 'printf "pong\\n"',
      stdin: '',
      args: const [],
      timeout: const Duration(seconds: 8),
      outputLimit: 10000,
      pathEnv: '/bin:/usr/bin:/usr/local/bin',
    );
    expect(result.spawnFailed, isFalse, reason: result.display);
    expect(result.ok, isTrue, reason: result.display);
    expect(result.stdout, contains('pong'));
  });
}
