import 'package:flutter/material.dart';

import '../languages.dart';
import 'scope.dart';

Future<LangDef?> pickLanguage(BuildContext context) {
  return showModalBottomSheet<LangDef>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends StatefulWidget {
  const _LanguageSheet();

  @override
  State<_LanguageSheet> createState() => _LanguageSheetState();
}

class _LanguageSheetState extends State<_LanguageSheet> {
  final _query = TextEditingController();

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final q = _query.text.trim().toLowerCase();
    final langs = app.allLanguages.where((lang) {
      if (q.isEmpty) return true;
      final hay =
          '${lang.name} ${lang.id} ${lang.piston} ${lang.aliases.join(' ')}'
              .toLowerCase();
      return hay.contains(q);
    }).toList();
    final height = MediaQuery.sizeOf(context).height * 0.78;
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _query,
              autofocus: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: '搜索语言',
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: langs.length,
              itemBuilder: (context, index) {
                final lang = langs[index];
                final local = app.localReady(lang);
                final remote = app.remoteReady(lang);
                return ListTile(
                  title: Text(lang.name),
                  subtitle: Text('${lang.category} · ${lang.fileName}'),
                  trailing: _Badges(local: local, remote: remote),
                  onTap: () => Navigator.pop(context, lang),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _Badges extends StatelessWidget {
  const _Badges({required this.local, required this.remote});

  final bool local;
  final bool remote;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (local) const _Badge('本机'),
        if (remote) const _Badge('远程'),
        if (!local && !remote) const _Badge('未就绪'),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(left: 6),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: scheme.primary.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(fontSize: 11, color: scheme.primary)),
    );
  }
}
