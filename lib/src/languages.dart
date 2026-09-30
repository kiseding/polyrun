import 'models.dart';
import 'recipes.dart';

class LangDef {
  const LangDef({
    required this.id,
    required this.name,
    required this.piston,
    required this.fileName,
    required this.category,
    required this.template,
    required this.highlight,
    this.aliases = const [],
    this.note = '',
    this.pinnedVersion,
  });

  final String id;
  final String name;
  final String piston;
  final List<String> aliases;
  final String fileName;
  final String category;
  final String template;
  final String highlight;
  final String note;
  final String? pinnedVersion;

  LocalRecipe? get recipe => kRecipes[id];

  bool get hasLocalRecipe => recipe != null;
}

LangDef _lang({
  required String id,
  required String name,
  required String piston,
  required String category,
  required String template,
  required String highlight,
  List<String> aliases = const [],
  String note = '',
  String? fileName,
}) {
  return LangDef(
    id: id,
    name: name,
    piston: piston,
    aliases: aliases,
    fileName: fileName ?? kRecipes[id]?.fileName ?? 'main.txt',
    category: category,
    template: template,
    highlight: highlight,
    note: note,
  );
}

const _py = r'''
import sys

print("Hello, 万语盒")
text = sys.stdin.read().strip()
if text:
    print(text)
''';

const _js = r'''
const fs = require("fs");

console.log("Hello, 万语盒");
const text = fs.readFileSync(0, "utf8").trim();
if (text) console.log(text);
''';

final List<LangDef> kLanguages = [
  _lang(
    id: 'python',
    name: 'Python',
    piston: 'python',
    category: '脚本',
    highlight: 'python',
    template: _py.trim(),
    aliases: const ['py', 'python3'],
  ),
  _lang(
    id: 'javascript',
    name: 'JavaScript',
    piston: 'javascript',
    category: '脚本',
    highlight: 'javascript',
    template: _js.trim(),
    aliases: const ['js', 'node'],
  ),
  _lang(
    id: 'typescript',
    name: 'TypeScript',
    piston: 'typescript',
    category: '脚本',
    highlight: 'typescript',
    template: 'console.log("Hello, 万语盒");',
    aliases: const ['ts'],
    note: '本机按 bun、deno、tsx、ts-node、node 的顺序找。node 需要支持 --experimental-strip-types。',
  ),
  _lang(
    id: 'dart',
    name: 'Dart',
    piston: 'dart',
    category: '脚本',
    highlight: 'dart',
    template: "void main() {\n  print('Hello, 万语盒');\n}",
  ),
  _lang(
    id: 'php',
    name: 'PHP',
    piston: 'php',
    category: '脚本',
    highlight: 'php',
    template: '<?php\necho "Hello, 万语盒\\n";',
  ),
  _lang(
    id: 'ruby',
    name: 'Ruby',
    piston: 'ruby',
    category: '脚本',
    highlight: 'ruby',
    template: 'puts "Hello, 万语盒"',
    aliases: const ['rb'],
  ),
  _lang(
    id: 'perl',
    name: 'Perl',
    piston: 'perl',
    category: '脚本',
    highlight: 'perl',
    template: 'print "Hello, 万语盒\\n";',
  ),
  _lang(
    id: 'lua',
    name: 'Lua',
    piston: 'lua',
    category: '脚本',
    highlight: 'lua',
    template: 'print("Hello, 万语盒")',
  ),
  _lang(
    id: 'r',
    name: 'R',
    piston: 'rscript',
    category: '科学',
    highlight: 'r',
    template: 'cat("Hello, 万语盒\\n")',
    aliases: const ['r', 'R', 'rscript'],
  ),
  _lang(
    id: 'julia',
    name: 'Julia',
    piston: 'julia',
    category: '科学',
    highlight: 'julia',
    template: 'println("Hello, 万语盒")',
  ),
  _lang(
    id: 'bash',
    name: 'Bash',
    piston: 'bash',
    category: '系统',
    highlight: 'bash',
    template: 'printf "Hello, 万语盒\\n"\ncat',
    aliases: const ['sh'],
  ),
  _lang(
    id: 'powershell',
    name: 'PowerShell',
    piston: 'powershell',
    category: '系统',
    highlight: 'powershell',
    template: 'Write-Output "Hello, 万语盒"',
    aliases: const ['pwsh'],
  ),
  _lang(
    id: 'awk',
    name: 'Awk',
    piston: 'awk',
    category: '系统',
    highlight: 'awk',
    template: 'BEGIN { print "Hello, 万语盒" }',
  ),
  _lang(
    id: 'sql',
    name: 'SQL',
    piston: 'sqlite3',
    category: '科学',
    highlight: 'sql',
    template: "SELECT 'Hello, 万语盒' AS message;",
    aliases: const ['sqlite', 'sqlite3'],
    note: '本机用 sqlite3 执行编辑器里的脚本，标准输入框不会再传给它。',
  ),
  _lang(
    id: 'c',
    name: 'C',
    piston: 'c',
    category: '编译',
    highlight: 'c',
    template:
        '''
#include <stdio.h>
int main(void) {
  printf("Hello, 万语盒\\n");
  return 0;
}
'''
            .trim(),
  ),
  _lang(
    id: 'cpp',
    name: 'C++',
    piston: 'c++',
    category: '编译',
    highlight: 'cpp',
    template:
        '''
#include <iostream>
int main() {
  std::cout << "Hello, 万语盒\\n";
  return 0;
}
'''
            .trim(),
    aliases: const ['cpp', 'cc'],
  ),
  _lang(
    id: 'rust',
    name: 'Rust',
    piston: 'rust',
    category: '编译',
    highlight: 'rust',
    template:
        '''
fn main() {
    println!("Hello, 万语盒");
}
'''
            .trim(),
    aliases: const ['rs'],
  ),
  _lang(
    id: 'go',
    name: 'Go',
    piston: 'go',
    category: '编译',
    highlight: 'go',
    template:
        '''
package main

import "fmt"

func main() {
    fmt.Println("Hello, 万语盒")
}
'''
            .trim(),
    aliases: const ['golang'],
  ),
  _lang(
    id: 'zig',
    name: 'Zig',
    piston: 'zig',
    category: '编译',
    highlight: 'plaintext',
    template:
        '''
const std = @import("std");
pub fn main() !void {
    const out = std.io.getStdOut().writer();
    try out.print("Hello, PolyRun\\n", .{});
}
'''
            .trim(),
    note: 'Zig 标准库在 0.11 和 0.13+ 之间不兼容，模板对不上就按你本机版本文档改。',
  ),
  _lang(
    id: 'nim',
    name: 'Nim',
    piston: 'nim',
    category: '编译',
    highlight: 'nim',
    template: 'echo "Hello, 万语盒"',
  ),
  _lang(
    id: 'd',
    name: 'D',
    piston: 'd',
    category: '编译',
    highlight: 'd',
    template:
        '''
import std.stdio;
void main() {
  writeln("Hello, 万语盒");
}
'''
            .trim(),
  ),
  _lang(
    id: 'fortran',
    name: 'Fortran',
    piston: 'fortran',
    category: '科学',
    highlight: 'fortran',
    template:
        '''
program hello
  print *, 'Hello, PolyRun'
end program hello
'''
            .trim(),
  ),
  _lang(
    id: 'pascal',
    name: 'Pascal',
    piston: 'pascal',
    category: '编译',
    highlight: 'plaintext',
    template:
        '''
program Hello;
begin
  writeln('Hello, PolyRun');
end.
'''
            .trim(),
  ),
  _lang(
    id: 'cobol',
    name: 'COBOL',
    piston: 'cobol',
    category: '编译',
    highlight: 'plaintext',
    template:
        '''
IDENTIFICATION DIVISION.
PROGRAM-ID. HELLO.
PROCEDURE DIVISION.
DISPLAY "Hello, PolyRun".
STOP RUN.
'''
            .trim(),
  ),
  _lang(
    id: 'objc',
    name: 'Objective-C',
    piston: 'objective-c',
    category: '编译',
    highlight: 'objectivec',
    template:
        '''
#import <Foundation/Foundation.h>
int main(int argc, const char * argv[]) {
  @autoreleasepool {
    NSLog(@"Hello, PolyRun");
  }
  return 0;
}
'''
            .trim(),
    note: '本机只在 macOS 上链接 Foundation。NSLog 写到 stderr。',
  ),
  _lang(
    id: 'java',
    name: 'Java',
    piston: 'java',
    category: 'JVM',
    highlight: 'java',
    template:
        '''
public class Main {
    public static void main(String[] args) {
        System.out.println("Hello, 万语盒");
    }
}
'''
            .trim(),
    note: '公共类名必须是 Main。',
  ),
  _lang(
    id: 'kotlin',
    name: 'Kotlin',
    piston: 'kotlin',
    category: 'JVM',
    highlight: 'kotlin',
    template:
        '''
fun main() {
    println("Hello, 万语盒")
}
'''
            .trim(),
    aliases: const ['kt'],
    note: '本机需要 kotlinc 和 java。',
  ),
  _lang(
    id: 'scala',
    name: 'Scala',
    piston: 'scala',
    category: 'JVM',
    highlight: 'scala',
    template: 'println("Hello, 万语盒")',
    note: '本机优先用 scala-cli。',
  ),
  _lang(
    id: 'groovy',
    name: 'Groovy',
    piston: 'groovy',
    category: 'JVM',
    highlight: 'groovy',
    template: "println 'Hello, 万语盒'",
  ),
  _lang(
    id: 'clojure',
    name: 'Clojure',
    piston: 'clojure',
    category: '函数式',
    highlight: 'clojure',
    template: '(println "Hello, 万语盒")',
    aliases: const ['clj'],
    note: '本机优先 babashka (bb)，否则用 clojure CLI。',
  ),
  _lang(
    id: 'csharp',
    name: 'C#',
    piston: 'csharp',
    category: '.NET',
    highlight: 'csharp',
    template: 'Console.WriteLine("Hello, 万语盒");',
    aliases: const ['cs', 'csharp.net'],
    note: '本机会按已安装的 SDK 生成临时工程。第一次运行可能要下载目标包，把超时调大。',
  ),
  _lang(
    id: 'fsharp',
    name: 'F#',
    piston: 'fsharp.net',
    category: '.NET',
    highlight: 'fsharp',
    template: 'printfn "Hello, 万语盒"',
    aliases: const ['fsharp', 'fsi', 'fs'],
    note: '本机用 dotnet fsi，需要装过 F# 工作负载。',
  ),
  _lang(
    id: 'swift',
    name: 'Swift',
    piston: 'swift',
    category: '编译',
    highlight: 'swift',
    template: 'print("Hello, 万语盒")',
  ),
  _lang(
    id: 'haskell',
    name: 'Haskell',
    piston: 'haskell',
    category: '函数式',
    highlight: 'haskell',
    template: 'main = putStrLn "Hello, 万语盒"',
    aliases: const ['hs'],
  ),
  _lang(
    id: 'ocaml',
    name: 'OCaml',
    piston: 'ocaml',
    category: '函数式',
    highlight: 'ocaml',
    template: 'print_endline "Hello, 万语盒"',
    aliases: const ['ml'],
  ),
  _lang(
    id: 'elixir',
    name: 'Elixir',
    piston: 'elixir',
    category: '函数式',
    highlight: 'elixir',
    template: 'IO.puts("Hello, 万语盒")',
    aliases: const ['ex', 'exs'],
  ),
  _lang(
    id: 'erlang',
    name: 'Erlang',
    piston: 'erlang',
    category: '函数式',
    highlight: 'erlang',
    template:
        '''
#!/usr/bin/env escript
%% -*- erlang -*-
main(_) ->
    io:format("Hello, PolyRun~n").
'''
            .trim(),
    note: '本机按 escript 运行，请保留第一行 shebang 和 main/1。',
  ),
  _lang(
    id: 'lisp',
    name: 'Common Lisp',
    piston: 'lisp',
    category: '函数式',
    highlight: 'lisp',
    template: '(format t "Hello, 万语盒~%")',
    aliases: const ['cl', 'commonlisp'],
  ),
  _lang(
    id: 'scheme',
    name: 'Scheme',
    piston: 'scheme',
    category: '函数式',
    highlight: 'scheme',
    template: '(display "Hello, 万语盒")\n(newline)',
  ),
  _lang(
    id: 'racket',
    name: 'Racket',
    piston: 'racket',
    category: '函数式',
    highlight: 'scheme',
    template: '#lang racket\n(displayln "Hello, 万语盒")',
  ),
  _lang(
    id: 'prolog',
    name: 'Prolog',
    piston: 'prolog',
    category: '函数式',
    highlight: 'prolog',
    template:
        '''
:- initialization(main, main).
main :- write('Hello, PolyRun'), nl, halt.
'''
            .trim(),
    note: '本机用 swipl。入口写在 initialization 里。',
  ),
  _lang(
    id: 'crystal',
    name: 'Crystal',
    piston: 'crystal',
    category: '编译',
    highlight: 'crystal',
    template: 'puts "Hello, 万语盒"',
  ),
  _lang(
    id: 'basic',
    name: 'FreeBASIC',
    piston: 'basic',
    category: '编译',
    highlight: 'basic',
    template: 'Print "Hello, PolyRun"',
    aliases: const ['freebasic', 'fbc'],
  ),
  _lang(
    id: 'brainfuck',
    name: 'Brainfuck',
    piston: 'brainfuck',
    category: '远程',
    highlight: 'brainfuck',
    fileName: 'main.bf',
    template: '++++++++[>++++[>++>+++>+++>+<<<<-]>+>+>->>+[<]<-]>>.>---.+++++++..+++.>>.<-.<.+++.------.--------.>>+.>++.',
    aliases: const ['bf'],
    note: '没有内置本机配方，装了 Piston 的 brainfuck 运行时才能跑。',
  ),
];

final Map<String, LangDef> kLanguageById = {
  for (final lang in kLanguages) lang.id: lang,
};

LangDef languageById(String id, {Map<String, LangDef> extras = const {}}) {
  final known = kLanguageById[id] ?? extras[id];
  if (known != null) return known;
  if (id.startsWith('remote:')) {
    final parts = id.split(':');
    if (parts.length >= 3) {
      final version = parts.last;
      final language = parts.sublist(1, parts.length - 1).join(':');
      return LangDef(
        id: id,
        name: '$language $version',
        piston: language,
        fileName: 'main.txt',
        category: '远程',
        template: '',
        highlight: 'plaintext',
        pinnedVersion: version,
      );
    }
  }
  return LangDef(
    id: id,
    name: id,
    piston: id,
    fileName: 'main.txt',
    category: '其他',
    template: '',
    highlight: 'plaintext',
  );
}

bool runtimeCovers(LangDef lang, RemoteRuntime remote) {
  final langKeys = {
    lang.id,
    lang.piston,
    ...lang.aliases,
  }.map((e) => e.toLowerCase()).toSet();
  final remoteKeys = {
    remote.language,
    ...remote.aliases,
  }.map((e) => e.toLowerCase()).toSet();
  return langKeys.intersection(remoteKeys).isNotEmpty;
}

RemoteRuntime? bestRuntime(LangDef lang, List<RemoteRuntime> all) {
  final hits = all.where((remote) => runtimeCovers(lang, remote)).toList();
  if (hits.isEmpty) return null;
  hits.sort((a, b) => compareSemver(b.version, a.version));
  return hits.first;
}

const Map<String, String> kExtensionToLanguage = {
  '.py': 'python',
  '.js': 'javascript',
  '.mjs': 'javascript',
  '.cjs': 'javascript',
  '.ts': 'typescript',
  '.dart': 'dart',
  '.php': 'php',
  '.rb': 'ruby',
  '.pl': 'perl',
  '.lua': 'lua',
  '.r': 'r',
  '.jl': 'julia',
  '.sh': 'bash',
  '.bash': 'bash',
  '.ps1': 'powershell',
  '.awk': 'awk',
  '.sql': 'sql',
  '.c': 'c',
  '.h': 'c',
  '.cpp': 'cpp',
  '.cc': 'cpp',
  '.cxx': 'cpp',
  '.rs': 'rust',
  '.go': 'go',
  '.zig': 'zig',
  '.nim': 'nim',
  '.d': 'd',
  '.f90': 'fortran',
  '.f95': 'fortran',
  '.pas': 'pascal',
  '.cob': 'cobol',
  '.cbl': 'cobol',
  '.m': 'objc',
  '.java': 'java',
  '.kt': 'kotlin',
  '.kts': 'kotlin',
  '.scala': 'scala',
  '.groovy': 'groovy',
  '.clj': 'clojure',
  '.cs': 'csharp',
  '.fs': 'fsharp',
  '.fsx': 'fsharp',
  '.swift': 'swift',
  '.hs': 'haskell',
  '.ml': 'ocaml',
  '.ex': 'elixir',
  '.exs': 'elixir',
  '.erl': 'erlang',
  '.lisp': 'lisp',
  '.lsp': 'lisp',
  '.scm': 'scheme',
  '.rkt': 'racket',
  '.pro': 'prolog',
  '.cr': 'crystal',
  '.bas': 'basic',
  '.bf': 'brainfuck',
};

LangDef? languageForFilename(String name) {
  final dot = name.lastIndexOf('.');
  if (dot < 0) return null;
  final id = kExtensionToLanguage[name.substring(dot).toLowerCase()];
  if (id == null) return null;
  return kLanguageById[id];
}

int _ids = 0;

String newAppletId() =>
    '${DateTime.now().microsecondsSinceEpoch.toRadixString(36)}-${_ids++}';

Applet createApplet(
  LangDef lang, {
  String? name,
  String? source,
  String? stdin,
}) {
  final now = DateTime.now();
  return Applet(
    id: newAppletId(),
    name: name ?? '未命名 ${lang.name}',
    languageId: lang.id,
    source: source ?? lang.template,
    stdin: stdin ?? '',
    args: '',
    pinned: false,
    createdAt: now,
    updatedAt: now,
  );
}

List<Applet> seedApplets() {
  LangDef lang(String id) => kLanguageById[id]!;
  return [
    createApplet(lang('python'), name: '问候 · Python', stdin: '你好'),
    createApplet(lang('javascript'), name: '问候 · JavaScript'),
    createApplet(lang('c'), name: '问候 · C'),
    createApplet(lang('go'), name: '问候 · Go'),
  ];
}
