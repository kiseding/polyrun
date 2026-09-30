import 'dart:convert';
import 'dart:io';

import 'which.dart';

class ProbeSpec {
  const ProbeSpec(this.id, this.bins);
  final String id;
  final List<String> bins;
}

class ResolvedProbe {
  const ResolvedProbe({
    required this.id,
    required this.binaries,
    this.meta = const {},
  });

  final String id;
  final Map<String, String> binaries;
  final Map<String, String> meta;

  String bin(String name) {
    final found = binaries[name];
    if (found == null) {
      throw StateError('未解析到 $name');
    }
    return found;
  }

  ResolvedProbe withMeta(Map<String, String> next) {
    return ResolvedProbe(id: id, binaries: binaries, meta: {...meta, ...next});
  }
}

class PlanInput {
  PlanInput({
    required this.probe,
    required this.src,
    required this.dir,
    required this.args,
  });

  final ResolvedProbe probe;
  final String src;
  final String dir;
  final List<String> args;

  String get sep => Platform.pathSeparator;
  String get prog =>
      Platform.isWindows ? '$dir${sep}prog.exe' : '$dir${sep}prog';
  String get jar => '$dir${sep}prog.jar';
}

class CommandPlan {
  CommandPlan({
    this.compile,
    required this.run,
    this.env = const {},
    this.prepare,
  });

  final List<String>? compile;
  final List<String> run;
  final Map<String, String> env;
  final Future<void> Function(Directory dir)? prepare;
}

typedef PlanBuilder = CommandPlan Function(PlanInput input);
typedef ProbeEnricher = Future<Map<String, String>> Function(
  ResolvedProbe probe,
  String pathEnv,
);

class LocalRecipe {
  const LocalRecipe({
    required this.fileName,
    required this.probes,
    required this.plan,
    this.stdinIsSource = false,
    this.enrich,
  });

  final String fileName;
  final List<ProbeSpec> probes;
  final PlanBuilder plan;
  final bool stdinIsSource;
  final ProbeEnricher? enrich;

  String get summary =>
      probes.map((probe) => probe.bins.join(' + ')).join(' / ');

  Future<ResolvedProbe?> resolve(String pathEnv) async {
    for (final spec in probes) {
      final found = <String, String>{};
      var ok = true;
      for (final name in spec.bins) {
        final hit = findExecutable(name, pathEnv);
        if (hit == null) {
          ok = false;
          break;
        }
        found[name] = hit;
      }
      if (ok) {
        return ResolvedProbe(id: spec.id, binaries: found);
      }
    }
    return null;
  }
}

CommandPlan _run(
  PlanInput input,
  String bin, {
  List<String> before = const [],
}) {
  return CommandPlan(
    run: [input.probe.bin(bin), ...before, input.src, ...input.args],
  );
}

CommandPlan _compile(
  PlanInput input,
  List<String> compile, {
  List<String>? run,
}) {
  return CommandPlan(compile: compile, run: run ?? [input.prog, ...input.args]);
}

final Map<String, LocalRecipe> kRecipes = {
  'python': LocalRecipe(
    fileName: 'main.py',
    probes: const [
      ProbeSpec('python3', ['python3']),
      ProbeSpec('python', ['python']),
      ProbeSpec('py', ['py']),
    ],
    plan: (input) {
      if (input.probe.id == 'py') {
        return CommandPlan(
          run: [input.probe.bin('py'), '-3', input.src, ...input.args],
        );
      }
      return _run(input, input.probe.id);
    },
  ),
  'javascript': LocalRecipe(
    fileName: 'main.js',
    probes: const [
      ProbeSpec('node', ['node']),
    ],
    plan: (input) => _run(input, 'node'),
  ),
  'typescript': LocalRecipe(
    fileName: 'main.ts',
    probes: const [
      ProbeSpec('bun', ['bun']),
      ProbeSpec('deno', ['deno']),
      ProbeSpec('tsx', ['tsx']),
      ProbeSpec('ts-node', ['ts-node']),
      ProbeSpec('node', ['node']),
    ],
    plan: (input) {
      switch (input.probe.id) {
        case 'bun':
          return _run(input, 'bun');
        case 'deno':
          return _run(
            input,
            'deno',
            before: const ['run', '--quiet', '--no-prompt', '--allow-all'],
          );
        case 'tsx':
          return _run(input, 'tsx');
        case 'ts-node':
          return _run(input, 'ts-node', before: const ['--transpile-only']);
        default:
          return _run(
            input,
            'node',
            before: const ['--experimental-strip-types'],
          );
      }
    },
  ),
  'dart': LocalRecipe(
    fileName: 'main.dart',
    probes: const [
      ProbeSpec('dart', ['dart']),
    ],
    plan: (input) => _run(input, 'dart', before: const ['run']),
  ),
  'php': LocalRecipe(
    fileName: 'main.php',
    probes: const [
      ProbeSpec('php', ['php']),
    ],
    plan: (input) => _run(input, 'php'),
  ),
  'ruby': LocalRecipe(
    fileName: 'main.rb',
    probes: const [
      ProbeSpec('ruby', ['ruby']),
    ],
    plan: (input) => _run(input, 'ruby'),
  ),
  'perl': LocalRecipe(
    fileName: 'main.pl',
    probes: const [
      ProbeSpec('perl', ['perl']),
    ],
    plan: (input) => _run(input, 'perl'),
  ),
  'lua': LocalRecipe(
    fileName: 'main.lua',
    probes: const [
      ProbeSpec('lua', ['lua']),
      ProbeSpec('luajit', ['luajit']),
    ],
    plan: (input) => _run(input, input.probe.id),
  ),
  'r': LocalRecipe(
    fileName: 'main.R',
    probes: const [
      ProbeSpec('Rscript', ['Rscript']),
    ],
    plan: (input) => _run(input, 'Rscript', before: const ['--vanilla']),
  ),
  'bash': LocalRecipe(
    fileName: 'main.sh',
    probes: const [
      ProbeSpec('bash', ['bash']),
      ProbeSpec('sh', ['sh']),
    ],
    plan: (input) => _run(input, input.probe.id),
  ),
  'powershell': LocalRecipe(
    fileName: 'main.ps1',
    probes: const [
      ProbeSpec('pwsh', ['pwsh']),
      ProbeSpec('powershell', ['powershell']),
    ],
    plan: (input) => CommandPlan(
      run: [
        input.probe.bin(input.probe.id),
        '-NoProfile',
        '-File',
        input.src,
        ...input.args,
      ],
    ),
  ),
  'awk': LocalRecipe(
    fileName: 'main.awk',
    probes: const [
      ProbeSpec('awk', ['awk']),
    ],
    plan: (input) =>
        CommandPlan(run: [input.probe.bin('awk'), '-f', input.src]),
  ),
  'sql': LocalRecipe(
    fileName: 'main.sql',
    probes: const [
      ProbeSpec('sqlite3', ['sqlite3']),
    ],
    stdinIsSource: true,
    plan: (input) =>
        CommandPlan(run: [input.probe.bin('sqlite3'), '-batch', ':memory:']),
  ),
  'c': LocalRecipe(
    fileName: 'main.c',
    probes: const [
      ProbeSpec('gcc', ['gcc']),
      ProbeSpec('clang', ['clang']),
    ],
    plan: (input) => _compile(input, [
      input.probe.bin(input.probe.id),
      '-O2',
      '-std=c11',
      '-o',
      input.prog,
      input.src,
    ]),
  ),
  'cpp': LocalRecipe(
    fileName: 'main.cpp',
    probes: const [
      ProbeSpec('g++', ['g++']),
      ProbeSpec('clang++', ['clang++']),
    ],
    plan: (input) => _compile(input, [
      input.probe.bin(input.probe.id),
      '-O2',
      '-std=c++17',
      '-o',
      input.prog,
      input.src,
    ]),
  ),
  'rust': LocalRecipe(
    fileName: 'main.rs',
    probes: const [
      ProbeSpec('rustc', ['rustc']),
    ],
    plan: (input) => _compile(input, [
      input.probe.bin('rustc'),
      '-O',
      '-o',
      input.prog,
      input.src,
    ]),
  ),
  'go': LocalRecipe(
    fileName: 'main.go',
    probes: const [
      ProbeSpec('go', ['go']),
    ],
    plan: (input) => CommandPlan(
      prepare: (dir) async {
        await File('${dir.path}${Platform.pathSeparator}go.mod')
            .writeAsString('module polyrun\n\ngo 1.20\n');
      },
      run: [input.probe.bin('go'), 'run', input.src, ...input.args],
    ),
  ),
  'zig': LocalRecipe(
    fileName: 'main.zig',
    probes: const [
      ProbeSpec('zig', ['zig']),
    ],
    plan: (input) => CommandPlan(
      run: [
        input.probe.bin('zig'),
        'run',
        input.src,
        if (input.args.isNotEmpty) '--',
        ...input.args,
      ],
    ),
  ),
  'nim': LocalRecipe(
    fileName: 'main.nim',
    probes: const [
      ProbeSpec('nim', ['nim']),
    ],
    plan: (input) => _compile(input, [
      input.probe.bin('nim'),
      'c',
      '--hints:off',
      '-o:${input.prog}',
      input.src,
    ]),
  ),
  'd': LocalRecipe(
    fileName: 'main.d',
    probes: const [
      ProbeSpec('dmd', ['dmd']),
      ProbeSpec('gdc', ['gdc']),
    ],
    plan: (input) {
      if (input.probe.id == 'gdc') {
        return _compile(input, [
          input.probe.bin('gdc'),
          '-o',
          input.prog,
          input.src,
        ]);
      }
      return _compile(input, [
        input.probe.bin('dmd'),
        '-of=${input.prog}',
        input.src,
      ]);
    },
  ),
  'fortran': LocalRecipe(
    fileName: 'main.f90',
    probes: const [
      ProbeSpec('gfortran', ['gfortran']),
    ],
    plan: (input) => _compile(input, [
      input.probe.bin('gfortran'),
      '-O2',
      '-o',
      input.prog,
      input.src,
    ]),
  ),
  'pascal': LocalRecipe(
    fileName: 'main.pas',
    probes: const [
      ProbeSpec('fpc', ['fpc']),
    ],
    plan: (input) =>
        _compile(input, [input.probe.bin('fpc'), '-o${input.prog}', input.src]),
  ),
  'cobol': LocalRecipe(
    fileName: 'main.cob',
    probes: const [
      ProbeSpec('cobc', ['cobc']),
    ],
    plan: (input) => _compile(input, [
      input.probe.bin('cobc'),
      '-x',
      '-free',
      '-o',
      input.prog,
      input.src,
    ]),
  ),
  'objc': LocalRecipe(
    fileName: 'main.m',
    probes: const [
      ProbeSpec('clang', ['clang']),
    ],
    plan: (input) => _compile(input, [
      input.probe.bin('clang'),
      '-fobjc-arc',
      '-framework',
      'Foundation',
      '-o',
      input.prog,
      input.src,
    ]),
  ),
  'java': LocalRecipe(
    fileName: 'Main.java',
    probes: const [
      ProbeSpec('javac', ['javac', 'java']),
    ],
    plan: (input) => _compile(
      input,
      [input.probe.bin('javac'), input.src],
      run: [input.probe.bin('java'), '-cp', input.dir, 'Main', ...input.args],
    ),
  ),
  'kotlin': LocalRecipe(
    fileName: 'main.kt',
    probes: const [
      ProbeSpec('kotlinc', ['kotlinc', 'java']),
    ],
    plan: (input) => _compile(
      input,
      [
        input.probe.bin('kotlinc'),
        input.src,
        '-include-runtime',
        '-d',
        input.jar,
      ],
      run: [input.probe.bin('java'), '-jar', input.jar, ...input.args],
    ),
  ),
  'scala': LocalRecipe(
    fileName: 'main.scala',
    probes: const [
      ProbeSpec('scala-cli', ['scala-cli']),
      ProbeSpec('scala', ['scala']),
    ],
    plan: (input) {
      if (input.probe.id == 'scala-cli') {
        return CommandPlan(
          run: [
            input.probe.bin('scala-cli'),
            'run',
            '-q',
            input.src,
            if (input.args.isNotEmpty) '--',
            ...input.args,
          ],
        );
      }
      return _run(input, 'scala');
    },
  ),
  'groovy': LocalRecipe(
    fileName: 'main.groovy',
    probes: const [
      ProbeSpec('groovy', ['groovy']),
    ],
    plan: (input) => _run(input, 'groovy'),
  ),
  'csharp': LocalRecipe(
    fileName: 'Program.cs',
    probes: const [
      ProbeSpec('dotnet', ['dotnet']),
    ],
    enrich: _dotnetMeta,
    plan: (input) {
      final tfm = input.probe.meta['tfm'] ?? 'net8.0';
      return CommandPlan(
        env: const {
          'DOTNET_NOLOGO': '1',
          'DOTNET_SKIP_FIRST_TIME_EXPERIENCE': '1',
          'DOTNET_CLI_TELEMETRY_OPTOUT': '1',
        },
        prepare: (dir) async {
          await File('${dir.path}${input.sep}polyrun.csproj').writeAsString('''
<Project Sdk="Microsoft.NET.Sdk">
  <PropertyGroup>
    <OutputType>Exe</OutputType>
    <TargetFramework>$tfm</TargetFramework>
    <ImplicitUsings>enable</ImplicitUsings>
    <Nullable>enable</Nullable>
  </PropertyGroup>
</Project>
''');
        },
        run: [
          input.probe.bin('dotnet'),
          'run',
          '--nologo',
          '--project',
          input.dir,
          '--',
          ...input.args,
        ],
      );
    },
  ),
  'fsharp': LocalRecipe(
    fileName: 'main.fsx',
    probes: const [
      ProbeSpec('dotnet', ['dotnet']),
    ],
    plan: (input) => CommandPlan(
      run: [
        input.probe.bin('dotnet'),
        'fsi',
        '--nologo',
        '--exec',
        input.src,
        if (input.args.isNotEmpty) '--',
        ...input.args,
      ],
    ),
  ),
  'swift': LocalRecipe(
    fileName: 'main.swift',
    probes: const [
      ProbeSpec('swift', ['swift']),
    ],
    plan: (input) => _run(input, 'swift'),
  ),
  'haskell': LocalRecipe(
    fileName: 'main.hs',
    probes: const [
      ProbeSpec('runghc', ['runghc']),
      ProbeSpec('ghc', ['ghc']),
    ],
    plan: (input) {
      if (input.probe.id == 'ghc') {
        return _compile(input, [
          input.probe.bin('ghc'),
          '-O0',
          '-o',
          input.prog,
          input.src,
        ]);
      }
      return _run(input, 'runghc');
    },
  ),
  'ocaml': LocalRecipe(
    fileName: 'main.ml',
    probes: const [
      ProbeSpec('ocaml', ['ocaml']),
    ],
    plan: (input) => _run(input, 'ocaml'),
  ),
  'elixir': LocalRecipe(
    fileName: 'main.exs',
    probes: const [
      ProbeSpec('elixir', ['elixir']),
    ],
    plan: (input) => _run(input, 'elixir'),
  ),
  'erlang': LocalRecipe(
    fileName: 'main.escript',
    probes: const [
      ProbeSpec('escript', ['escript']),
    ],
    plan: (input) => _run(input, 'escript'),
  ),
  'clojure': LocalRecipe(
    fileName: 'main.clj',
    probes: const [
      ProbeSpec('bb', ['bb']),
      ProbeSpec('clojure', ['clojure']),
    ],
    plan: (input) {
      if (input.probe.id == 'bb') return _run(input, 'bb');
      final path = input.src.replaceAll(r'\', '/').replaceAll('"', '');
      return CommandPlan(
        run: [
          input.probe.bin('clojure'),
          '-M',
          '-e',
          "(load-file \"$path\")",
        ],
      );
    },
  ),
  'lisp': LocalRecipe(
    fileName: 'main.lisp',
    probes: const [
      ProbeSpec('sbcl', ['sbcl']),
    ],
    plan: (input) => CommandPlan(
      run: [input.probe.bin('sbcl'), '--script', input.src, ...input.args],
    ),
  ),
  'scheme': LocalRecipe(
    fileName: 'main.scm',
    probes: const [
      ProbeSpec('guile', ['guile']),
      ProbeSpec('scheme', ['scheme']),
    ],
    plan: (input) => _run(input, input.probe.id),
  ),
  'racket': LocalRecipe(
    fileName: 'main.rkt',
    probes: const [
      ProbeSpec('racket', ['racket']),
    ],
    plan: (input) => _run(input, 'racket'),
  ),
  'prolog': LocalRecipe(
    fileName: 'main.pro',
    probes: const [
      ProbeSpec('swipl', ['swipl']),
    ],
    plan: (input) =>
        CommandPlan(run: [input.probe.bin('swipl'), '-q', '-s', input.src]),
  ),
  'julia': LocalRecipe(
    fileName: 'main.jl',
    probes: const [
      ProbeSpec('julia', ['julia']),
    ],
    plan: (input) => _run(input, 'julia'),
  ),
  'crystal': LocalRecipe(
    fileName: 'main.cr',
    probes: const [
      ProbeSpec('crystal', ['crystal']),
    ],
    plan: (input) => CommandPlan(
      run: [
        input.probe.bin('crystal'),
        'run',
        input.src,
        if (input.args.isNotEmpty) '--',
        ...input.args,
      ],
    ),
  ),
  'basic': LocalRecipe(
    fileName: 'main.bas',
    probes: const [
      ProbeSpec('fbc', ['fbc']),
    ],
    plan: (input) =>
        _compile(input, [input.probe.bin('fbc'), '-x', input.prog, input.src]),
  ),
};

Future<Map<String, String>> _dotnetMeta(
  ResolvedProbe probe,
  String pathEnv,
) async {
  try {
    final result = await Process.run(
      probe.bin('dotnet'),
      ['--version'],
      environment: {'PATH': pathEnv},
      stdoutEncoding: utf8,
    ).timeout(const Duration(seconds: 8));
    final raw = '${result.stdout}'.trim();
    final major = int.tryParse(raw.split('.').first);
    if (major != null && major >= 6) {
      return {'tfm': 'net$major.0', 'sdk': raw};
    }
  } catch (_) {
    return const {'tfm': 'net8.0'};
  }
  return const {'tfm': 'net8.0'};
}
