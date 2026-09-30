import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'models.dart';
import 'recipes.dart';

class LocalRunner {
  Future<RunResult> run({
    required LocalRecipe recipe,
    required ResolvedProbe probe,
    required String source,
    required String stdin,
    required List<String> args,
    required Duration timeout,
    required int outputLimit,
    required String pathEnv,
  }) async {
    if (Platform.isAndroid || Platform.isIOS) {
      return RunResult.message('手机系统不能随意启动本机编译器，请改用 Piston。');
    }
    final watch = Stopwatch()..start();
    final dir = await Directory.systemTemp.createTemp('polyrun_');
    try {
      final srcPath = '${dir.path}${Platform.pathSeparator}${recipe.fileName}';
      await File(srcPath).writeAsString(source);
      final plan = recipe.plan(
        PlanInput(probe: probe, src: srcPath, dir: dir.path, args: args),
      );
      if (plan.prepare != null) await plan.prepare!(dir);
      final env = _environment(pathEnv, plan.env);
      if (plan.compile != null) {
        final compiled = await _spawn(
          command: plan.compile!,
          stdin: '',
          dir: dir,
          env: env,
          timeout: timeout,
          limit: outputLimit,
        );
        if (compiled.timedOut || compiled.code != 0) {
          return RunResult(
            engine: 'local',
            ok: false,
            exitCode: compiled.code,
            stdout: '',
            stderr: '',
            compileOutput: _merge(compiled.stdout, compiled.stderr),
            elapsedMs: watch.elapsedMilliseconds,
            timedOut: compiled.timedOut,
            truncated: compiled.truncated,
            spawnFailed: compiled.spawnFailed,
            message: compiled.timedOut ? '编译超时' : '编译失败',
          );
        }
      }
      final ran = await _spawn(
        command: plan.run,
        stdin: recipe.stdinIsSource ? source : stdin,
        dir: dir,
        env: env,
        timeout: timeout,
        limit: outputLimit,
      );
      return RunResult(
        engine: 'local',
        ok: !ran.timedOut && !ran.spawnFailed && ran.code == 0,
        exitCode: ran.code,
        stdout: ran.stdout,
        stderr: ran.stderr,
        compileOutput: '',
        elapsedMs: watch.elapsedMilliseconds,
        timedOut: ran.timedOut,
        truncated: ran.truncated,
        spawnFailed: ran.spawnFailed,
        message: ran.spawnFailed
            ? '无法启动 ${plan.run.first}'
            : ran.timedOut
            ? '运行超时，进程已结束'
            : null,
      );
    } on ProcessException catch (error) {
      return RunResult(
        engine: 'local',
        ok: false,
        exitCode: null,
        stdout: '',
        stderr: error.message,
        compileOutput: '',
        elapsedMs: watch.elapsedMilliseconds,
        timedOut: false,
        truncated: false,
        spawnFailed: true,
        message: '无法启动进程：${error.message}',
      );
    } finally {
      try {
        await dir.delete(recursive: true);
      } catch (_) {}
    }
  }

  Map<String, String> _environment(String pathEnv, Map<String, String> extra) {
    final env = Map<String, String>.from(Platform.environment);
    env['PATH'] = pathEnv;
    env.putIfAbsent('PYTHONUNBUFFERED', () => '1');
    env.putIfAbsent('PYTHONIOENCODING', () => 'utf-8');
    env.putIfAbsent('PYTHONDONTWRITEBYTECODE', () => '1');
    env.putIfAbsent('DOTNET_CLI_TELEMETRY_OPTOUT', () => '1');
    env.putIfAbsent('DOTNET_NOLOGO', () => '1');
    env.putIfAbsent('GOTELEMETRY', () => 'off');
    env.addAll(extra);
    return env;
  }

  String _merge(String stdout, String stderr) {
    if (stdout.isEmpty) return stderr;
    if (stderr.isEmpty) return stdout;
    return '$stdout\n$stderr';
  }
}

class _Spawned {
  const _Spawned({
    required this.code,
    required this.stdout,
    required this.stderr,
    required this.timedOut,
    required this.truncated,
    required this.spawnFailed,
  });

  final int code;
  final String stdout;
  final String stderr;
  final bool timedOut;
  final bool truncated;
  final bool spawnFailed;
}

Future<_Spawned> _spawn({
  required List<String> command,
  required String stdin,
  required Directory dir,
  required Map<String, String> env,
  required Duration timeout,
  required int limit,
}) async {
  if (command.isEmpty) {
    return const _Spawned(
      code: -1,
      stdout: '',
      stderr: '空命令',
      timedOut: false,
      truncated: false,
      spawnFailed: true,
    );
  }
  final process = await Process.start(
    command.first,
    command.skip(1).toList(),
    workingDirectory: dir.path,
    environment: env,
  );
  final stdout = StringBuffer();
  final stderr = StringBuffer();
  final truncated = <bool>[false];
  final drains = [
    _collect(process.stdout, stdout, limit, truncated),
    _collect(process.stderr, stderr, limit, truncated),
  ];
  var timedOut = false;
  final killer = Timer(timeout, () {
    timedOut = true;
    process.kill(ProcessSignal.sigkill);
  });
  try {
    if (stdin.isNotEmpty) process.stdin.add(utf8.encode(stdin));
    await process.stdin.close();
  } catch (_) {}
  var code = -1;
  try {
    code = await process.exitCode.timeout(timeout + const Duration(seconds: 2));
  } on TimeoutException {
    timedOut = true;
    process.kill(ProcessSignal.sigkill);
  }
  killer.cancel();
  try {
    await Future.wait(drains).timeout(const Duration(seconds: 2));
  } catch (_) {}
  return _Spawned(
    code: code,
    stdout: stdout.toString(),
    stderr: stderr.toString(),
    timedOut: timedOut,
    truncated: truncated[0],
    spawnFailed: false,
  );
}

Future<void> _collect(
  Stream<List<int>> stream,
  StringBuffer buffer,
  int limit,
  List<bool> truncated,
) {
  final done = Completer<void>();
  stream
      .transform(const Utf8Decoder(allowMalformed: true))
      .listen(
        (chunk) {
          if (buffer.length >= limit) {
            truncated[0] = true;
            return;
          }
          final room = limit - buffer.length;
          if (chunk.length <= room) {
            buffer.write(chunk);
          } else {
            buffer.write(chunk.substring(0, room));
            truncated[0] = true;
          }
        },
        onError: (Object _) {
          if (!done.isCompleted) done.complete();
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        cancelOnError: false,
      );
  return done.future;
}
