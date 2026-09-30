import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';
import 'editor_pane.dart';
import 'library_pane.dart';
import 'scope.dart';

class PolyRunApp extends StatefulWidget {
  const PolyRunApp({required this.controller, super.key});

  final AppController controller;

  @override
  State<PolyRunApp> createState() => _PolyRunAppState();
}

class _PolyRunAppState extends State<PolyRunApp> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onController);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onController);
    widget.controller.dispose();
    super.dispose();
  }

  void _onController() {
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '万语盒',
      debugShowCheckedModeBanner: false,
      theme: buildPolyTheme(Brightness.light),
      darkTheme: buildPolyTheme(Brightness.dark),
      themeMode: themeModeOf(widget.controller.settings.theme),
      home: AppScope(controller: widget.controller, child: const RootShell()),
    );
  }
}

class RootShell extends StatelessWidget {
  const RootShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    if (!app.ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (app.bootError != null) {
      return Scaffold(body: Center(child: Text(app.bootError!)));
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 980) return const _WideShell();
        return const _MobileShell();
      },
    );
  }
}

class _WideShell extends StatelessWidget {
  const _WideShell();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    return Scaffold(
      body: Row(
        children: [
          const SizedBox(width: 340, child: LibraryPane()),
          VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
          Expanded(
            child: app.current == null
                ? const EmptyEditor()
                : EditorPane(key: ValueKey(app.current!.id)),
          ),
        ],
      ),
    );
  }
}

class _MobileShell extends StatelessWidget {
  const _MobileShell();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final current = app.current;
    if (current == null) {
      return const Scaffold(body: SafeArea(child: LibraryPane()));
    }
    return Scaffold(
      body: SafeArea(
        child: EditorPane(
          key: ValueKey(current.id),
          onBack: () => app.select(null),
        ),
      ),
    );
  }
}
