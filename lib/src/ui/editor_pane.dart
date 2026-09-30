import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';

import '../controller.dart';
import '../highlight_modes.dart';
import '../languages.dart';
import '../models.dart';
import '../theme.dart';
import 'language_picker.dart';
import 'menu.dart';
import 'scope.dart';
import 'settings_sheet.dart';

class EditorPane extends StatefulWidget {
  const EditorPane({super.key, this.onBack});

  final VoidCallback? onBack;

  @override
  State<EditorPane> createState() => _EditorPaneState();
}

class _EditorPaneState extends State<EditorPane> {
  late final CodeLineEditingController _code;
  final _name = TextEditingController();
  final _stdin = TextEditingController();
  final _args = TextEditingController();
  var _ready = false;
  var _applying = false;
  var _epoch = 0;
  var _tab = 0;
  CodeEditorStyle? _style;
  String? _styleKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    final applet = app.current;
    if (applet == null) return;
    if (!_ready) {
      _ready = true;
      _epoch = app.editorEpoch;
      _code = CodeLineEditingController.fromText(applet.source);
      _code.addListener(_onCode);
      _applyFields(app);
      return;
    }
    if (app.editorEpoch != _epoch) {
      _epoch = app.editorEpoch;
      _applying = true;
      if (_code.text != applet.source) _code.text = applet.source;
      _applyFields(app);
      _applying = false;
    }
  }

  void _applyFields(AppController app) {
    final applet = app.current;
    if (applet == null) return;
    _name.text = applet.name;
    _stdin.text = applet.stdin;
    _args.text = applet.args;
  }

  void _onCode() {
    if (_applying || !mounted) return;
    AppScope.of(context).updateSource(_code.text);
  }

  @override
  void dispose() {
    if (_ready) {
      _code.removeListener(_onCode);
      _code.dispose();
    }
    _name.dispose();
    _stdin.dispose();
    _args.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final applet = app.current;
    if (applet == null || !_ready) {
      return const Center(child: Text('选一个小程序，或新建一个'));
    }
    final lang = app.langOf(applet);
    final result = app.results[applet.id];
    final running = app.runningId == applet.id;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final styleKey = '$dark:${lang.highlight}';
    if (_styleKey != styleKey) {
      _styleKey = styleKey;
      _style = editorStyle(dark: dark, mode: modeFor(lang.highlight));
    }
    final scheme = Theme.of(context).colorScheme;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, meta: true):
            app.runCurrent,
        const SingleActivator(LogicalKeyboardKey.enter, control: true):
            app.runCurrent,
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                if (widget.onBack != null)
                  IconButton(
                    tooltip: '返回',
                    onPressed: widget.onBack,
                    icon: const Icon(Icons.arrow_back),
                  ),
                Expanded(
                  child: TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      isDense: true,
                      border: InputBorder.none,
                      hintText: '小程序名字',
                    ),
                    style: Theme.of(context).textTheme.titleMedium,
                    onChanged: (value) {
                      if (_applying) return;
                      app.rename(value);
                    },
                  ),
                ),
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 132),
                  child: TextButton(
                    onPressed: () => _switchLanguage(context, app, lang),
                    child: Text(
                      lang.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                FilledButton.icon(
                  onPressed: running ? null : app.runCurrent,
                  icon: running
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow),
                  label: const Text('运行'),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _menu(context, app, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'copy', child: Text('复制源码')),
                    PopupMenuItem(value: 'copy-out', child: Text('复制输出')),
                    PopupMenuItem(value: 'dup', child: Text('创建副本')),
                    PopupMenuItem(value: 'pin', child: Text('置顶 / 取消')),
                    PopupMenuItem(value: 'settings', child: Text('设置')),
                    PopupMenuItem(value: 'delete', child: Text('删除')),
                  ],
                ),
              ],
            ),
          ),
          if (lang.note.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  lang.note,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: _style!.backgroundColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: CodeEditor(
                    controller: _code,
                    style: _style,
                    wordWrap: false,
                    autofocus: true,
                    toolbarController: EditorMenu(),
                    indicatorBuilder:
                        (
                          context,
                          editingController,
                          chunkController,
                          notifier,
                        ) {
                          return Row(
                            children: [
                              DefaultCodeLineNumber(
                                controller: editingController,
                                notifier: notifier,
                              ),
                              DefaultCodeChunkIndicator(
                                width: 18,
                                controller: chunkController,
                                notifier: notifier,
                              ),
                            ],
                          );
                        },
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 196,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: const Text('输出'),
                        selected: _tab == 0,
                        onSelected: (_) => setState(() => _tab = 0),
                      ),
                      const SizedBox(width: 6),
                      ChoiceChip(
                        label: const Text('输入'),
                        selected: _tab == 1,
                        onSelected: (_) => setState(() => _tab = 1),
                      ),
                      const Spacer(),
                      if (result != null && _tab == 0)
                        Text(
                          _status(result),
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: result.ok
                                    ? scheme.primary
                                    : scheme.error,
                              ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: _tab == 1
                        ? Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextField(
                                  controller: _stdin,
                                  maxLines: 4,
                                  decoration: const InputDecoration(
                                    labelText: '标准输入',
                                    alignLabelWithHint: true,
                                  ),
                                  onChanged: (value) {
                                    if (!_applying) app.updateStdin(value);
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextField(
                                  controller: _args,
                                  decoration: const InputDecoration(
                                    labelText: '参数',
                                    hintText: 'a "b c"',
                                  ),
                                  onChanged: (value) {
                                    if (!_applying) app.updateArgs(value);
                                  },
                                ),
                              ),
                            ],
                          )
                        : DecoratedBox(
                            decoration: BoxDecoration(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.35),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: SizedBox.expand(
                              child: SingleChildScrollView(
                                padding: const EdgeInsets.all(10),
                                child: SelectableText(
                                  running
                                      ? '运行中…'
                                      : (result?.display ??
                                            '按 ⌘/Ctrl + Enter 运行'),
                                  style: const TextStyle(
                                    fontFamily: 'Menlo',
                                    fontFamilyFallback: ['monospace'],
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _status(RunResult result) {
    final engine = result.engine == 'local'
        ? '本机'
        : result.engine == 'piston'
        ? 'Piston'
        : '';
    final code = result.exitCode == null ? '' : ' 退出 ${result.exitCode}';
    final time = result.elapsedMs > 0 ? ' ${result.elapsedMs} ms' : '';
    return '$engine$code$time'.trim();
  }

  Future<void> _switchLanguage(
    BuildContext context,
    AppController app,
    LangDef current,
  ) async {
    final next = await pickLanguage(context);
    if (next == null || next.id == current.id) return;
    final same =
        app.current?.source.trim() == current.template.trim() ||
        (app.current?.source.trim().isEmpty ?? true);
    var replace = same;
    if (!same && context.mounted) {
      replace = await confirm(
        context,
        '换成 ${next.name} 的模板？',
        '当前代码会被覆盖。选取消则只改语言，保留代码。',
      );
    }
    if (!context.mounted) return;
    app.changeLanguage(next, replaceSource: replace);
  }

  Future<void> _menu(
    BuildContext context,
    AppController app,
    String value,
  ) async {
    final applet = app.current;
    if (applet == null) return;
    switch (value) {
      case 'copy':
        await Clipboard.setData(ClipboardData(text: applet.source));
        if (context.mounted) showPolySnack(context, '已复制源码');
        break;
      case 'copy-out':
        await Clipboard.setData(
          ClipboardData(text: app.results[applet.id]?.display ?? ''),
        );
        if (context.mounted) showPolySnack(context, '已复制输出');
        break;
      case 'dup':
        app.duplicate(applet);
        break;
      case 'pin':
        app.togglePin(applet);
        break;
      case 'settings':
        if (context.mounted) await showSettings(context);
        break;
      case 'delete':
        if (!context.mounted) return;
        final ok = await confirm(
          context,
          '删除「${applet.name}」？',
          '本地保存的这份代码会去掉。',
        );
        if (ok) app.delete(applet);
        break;
    }
  }
}

class EmptyEditor extends StatelessWidget {
  const EmptyEditor({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: const Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '选左边的小程序，或新建一个。\n\n'
            '桌面会直接调用你已经安装的 Python、Node、GCC、Go、Rust 这些。'
            '手机上不能内置全部编译器，需要在设置里填自建 Piston 的地址。',
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}
