import 'dart:convert';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../languages.dart';
import '../models.dart';
import '../theme.dart';
import 'language_picker.dart';
import 'scope.dart';
import 'settings_sheet.dart';

class LibraryPane extends StatefulWidget {
  const LibraryPane({super.key});

  @override
  State<LibraryPane> createState() => _LibraryPaneState();
}

class _LibraryPaneState extends State<LibraryPane> {
  final _query = TextEditingController();
  var _filter = _Filter.all;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final scheme = Theme.of(context).colorScheme;
    final q = _query.text.trim().toLowerCase();
    final items = app.sortedApplets.where((applet) {
      final lang = app.langOf(applet);
      if (_filter == _Filter.local && !app.localReady(lang)) return false;
      if (_filter == _Filter.remote && !app.remoteReady(lang)) return false;
      if (q.isEmpty) return true;
      return '${applet.name} ${lang.name}'.toLowerCase().contains(q);
    }).toList();

    return ColoredBox(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: Text(
                    '万',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      color: scheme.primary,
                      fontSize: 18,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '万语盒',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        app.probing ? '正在找本机语言…' : '本机编译器 + 自建 Piston',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '设置',
                  onPressed: () => showSettings(context),
                  icon: const Icon(Icons.settings_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: '更多',
                  onSelected: (value) => _onMenu(context, value),
                  itemBuilder: (context) => const [
                    PopupMenuItem(value: 'open', child: Text('打开源文件')),
                    PopupMenuItem(value: 'import', child: Text('导入小程序')),
                    PopupMenuItem(value: 'export', child: Text('导出小程序')),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _query,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索小程序',
                isDense: true,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final filter in _Filter.values)
                  ChoiceChip(
                    label: Text(filter.label),
                    selected: _filter == filter,
                    onSelected: (_) => setState(() => _filter = filter),
                  ),
                FilledButton.tonalIcon(
                  onPressed: () => _create(context),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('新建'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? const Center(child: Text('没有小程序'))
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final applet = items[index];
                      final lang = app.langOf(applet);
                      final selected = app.selectedId == applet.id;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Material(
                          color: selected
                              ? scheme.primary.withValues(alpha: 0.14)
                              : Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(12),
                          child: ListTile(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selected: selected,
                            leading: _Mark(text: lang.name),
                            title: Text(
                              applet.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            subtitle: Text(
                              '${lang.name} · ${relativeTime(applet.updatedAt)}',
                            ),
                            trailing: applet.pinned
                                ? Icon(
                                    Icons.push_pin,
                                    size: 16,
                                    color: scheme.primary,
                                  )
                                : null,
                            onTap: () => app.select(applet.id),
                            onLongPress: () => app.togglePin(applet),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    final lang = await pickLanguage(context);
    if (lang == null || !context.mounted) return;
    AppScope.of(context).create(lang);
  }

  Future<void> _onMenu(BuildContext context, String value) async {
    final app = AppScope.of(context);
    try {
      switch (value) {
        case 'open':
          await _openSource(context);
          break;
        case 'import':
          final file = await openFile(
            acceptedTypeGroups: const [
              XTypeGroup(label: 'json', extensions: ['json']),
            ],
          );
          if (file == null || !context.mounted) return;
          final decoded = jsonDecode(await file.readAsString());
          if (decoded is! List) {
            if (context.mounted) showPolySnack(context, '文件不是小程序列表');
            return;
          }
          final incoming = decoded
              .whereType<Map>()
              .map((item) => Applet.fromJson(item.cast<String, Object?>()))
              .toList();
          final added = await app.importApplets(incoming);
          if (context.mounted) showPolySnack(context, '导入 $added 个');
          break;
        case 'export':
          await _export(context);
          break;
      }
    } catch (error) {
      if (context.mounted) showPolySnack(context, '$error');
    }
  }

  Future<void> _openSource(BuildContext context) async {
    final file = await openFile();
    if (file == null || !context.mounted) return;
    final source = await file.readAsString();
    if (!context.mounted) return;
    var lang = languageForFilename(file.name);
    lang ??= await pickLanguage(context);
    if (lang == null || !context.mounted) return;
    AppScope.of(context).create(lang, name: file.name, source: source);
  }

  Future<void> _export(BuildContext context) async {
    final app = AppScope.of(context);
    final text = const JsonEncoder.withIndent('  ')
        .convert(app.applets.map((a) => a.toJson()).toList());
    try {
      final location = await getSaveLocation(
        suggestedName: 'polyrun-applets.json',
      );
      if (location == null) return;
      await File(location.path).writeAsString(text);
      if (context.mounted) showPolySnack(context, '已导出');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: text));
      if (context.mounted) showPolySnack(context, '这个平台不能直接存文件，已复制 JSON');
    }
  }
}

enum _Filter {
  all('全部'),
  local('本机可跑'),
  remote('远程可跑');

  const _Filter(this.label);
  final String label;
}

class _Mark extends StatelessWidget {
  const _Mark({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    final letters = text.length <= 2 ? text : text.substring(0, 2);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.primary.withValues(alpha: 0.5)),
      ),
      child: Text(
        letters,
        style: TextStyle(
          fontSize: 12,
          color: scheme.primary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
