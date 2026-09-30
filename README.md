# 万语盒 PolyRun

在 Linux、Windows、macOS、Android、iOS 上运行的小程序平台。一个小程序就是一份可保存的源码，外加标准输入和参数。

没有从零写编辑器，也没有从零写四十种解释器。

| 能力 | 用的现成项目 |
| --- | --- |
| 代码编辑、行号、折叠、语法高亮 | [re_editor](https://github.com/reqable/re-editor) + [re_highlight](https://github.com/reqable/re-highlight) |
| 多语言隔离执行 | [Piston](https://github.com/engineer-man/piston)（自建） |

GitHub 上没有找到一个现成的 Flutter 应用，能同时覆盖这五个系统、又真能跑主流语言。接近的只有编辑器组件和执行引擎，所以只写了产品壳。

## 实际能跑到什么程度

主流语言的编译器加在一起有几个 GB，也不能塞进 iOS / Android 的沙箱。所以分两条路：

- **本机（Linux / Windows / macOS）**：调用你已经安装的解释器和编译器。自动会去登录 shell 的 `PATH`，以及 Homebrew、Cargo、Go、Flutter 的常见目录。
- **远程（五个平台都能用）**：把代码交给你自己的 Piston。Piston 用 Docker + Isolate 跑不受信任的代码，语言包由你在服务器上安装，装多少就能跑多少，包括目录里没单列的冷门语言。

内置了本机配方的语言：Python、JavaScript、TypeScript、Dart、PHP、Ruby、Perl、Lua、R、Julia、Bash、PowerShell、Awk、SQL（sqlite3）、C、C++、Rust、Go、Zig、Nim、D、Fortran、Pascal、COBOL、Objective-C、Java、Kotlin、Scala、Groovy、C#、F#、Swift、Haskell、OCaml、Elixir、Erlang、Clojure、Common Lisp、Scheme、Racket、Prolog、Crystal、FreeBASIC。Brainfuck 只走 Piston。

本机没装对应程序时，运行按钮会说明缺什么，不会假装执行成功。

## 公共 Piston 不能当默认后端

[engineer-man/piston](https://github.com/engineer-man/piston) 写明：从 2026-02-15 起，`https://emkc.org/api/v2/piston` 要白名单，个人项目、课程作业、临时项目都不发 key。万语盒默认地址是 `http://127.0.0.1:2000/api/v2`。

自建（官方镜像，需要 Docker，并且容器要特权模式）：

```sh
docker run --privileged -dit -p 2000:2000 --name piston_api ghcr.io/engineer-man/piston
```

镜像起来之后还没有语言包。进入容器用 Piston CLI 安装需要的 runtime，见上游 README 的 CLI 一节。安卓模拟器访问宿主机用 `http://10.0.2.2:2000/api/v2`。真机填电脑的局域网地址。

## 运行

```sh
cd polyrun
flutter pub get
flutter run -d macos     # 或 windows / linux / android / ios
```

快捷键：⌘/Ctrl + Enter 运行当前小程序。

小程序保存在应用支持目录的 `polyrun/applets.json`。库页面可以导入、导出，也可以直接打开一个源文件。

## 安全

本机引擎就是 `Process.start`，权限和你自己的用户一样，**没有沙箱**。不要运行不信任的代码。需要隔离时用 Piston，并把引擎设成「仅远程」。

macOS 的 App Sandbox 关掉了，否则桌面应用既调不了本机编译器，也访问不了 Homebrew 的 PATH。这样的包不能按沙箱应用上架 Mac App Store。

工作目录是临时文件夹，进程结束就删掉。这不是一个带工程文件、依赖管理和多文件构建的 IDE。

## 目录

```
lib/src/languages.dart     语言目录和模板
lib/src/recipes.dart       本机怎么编译、怎么运行
lib/src/local_runner.dart  超时、截断输出、临时目录
lib/src/piston.dart        Piston runtimes / execute
lib/src/ui/                小程序库、编辑器、设置
```
