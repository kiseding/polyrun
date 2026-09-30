import 'package:flutter/material.dart';

import '../controller.dart';
import '../languages.dart';
import '../models.dart';
import 'scope.dart';

Future<void> showSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => const SettingsSheet(),
  );
}

class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  final _url = TextEditingController();
  final _token = TextEditingController();
  var _obscure = true;
  var _filled = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_filled) return;
    final settings = AppScope.of(context).settings;
    _url.text = settings.pistonBaseUrl;
    _token.text = settings.pistonToken;
    _filled = true;
  }

  @override
  void dispose() {
    _url.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final settings = app.settings;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final localNames = [
      for (final id in app.localProbes.keys)
        languageById(id, extras: app.extras).name,
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 16 + bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.82,
        child: ListView(
          children: [
            Text('设置', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 8),
            const Text(
              '桌面优先用已经装好的编译器，不经过网络。手机以及本机没有的语言走你自己的 Piston。'
              '公共接口 emkc.org 从 2026-02-15 起要白名单，个人项目基本拿不到。',
            ),
            const SizedBox(height: 16),
            SegmentedButton<EnginePreference>(
              segments: const [
                ButtonSegment(value: EnginePreference.auto, label: Text('自动')),
                ButtonSegment(
                  value: EnginePreference.local,
                  label: Text('仅本机'),
                ),
                ButtonSegment(
                  value: EnginePreference.remote,
                  label: Text('仅远程'),
                ),
              ],
              selected: {settings.engine},
              onSelectionChanged: (value) {
                app.updateSettings(settings.copyWith(engine: value.first));
              },
            ),
            const SizedBox(height: 16),
            Text('每阶段超时 ${settings.timeoutSeconds} 秒（编译和运行分开计）'),
            Slider(
              min: 3,
              max: 180,
              divisions: 177,
              value: settings.timeoutSeconds.clamp(3, 180).toDouble(),
              label: '${settings.timeoutSeconds}',
              onChanged: (value) {
                app.updateSettings(
                  settings.copyWith(timeoutSeconds: value.round()),
                );
              },
            ),
            TextField(
              controller: _url,
              decoration: const InputDecoration(
                labelText: 'Piston 地址',
                hintText: 'http://127.0.0.1:2000/api/v2',
              ),
              onSubmitted: (_) => _saveEndpoint(app),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: const Text('本机 Docker'),
                  onPressed: () => _url.text = 'http://127.0.0.1:2000/api/v2',
                ),
                ActionChip(
                  label: const Text('安卓模拟器访问宿主机'),
                  onPressed: () => _url.text = 'http://10.0.2.2:2000/api/v2',
                ),
                ActionChip(
                  label: const Text('公共 API'),
                  onPressed: () => _url.text = 'https://emkc.org/api/v2/piston',
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _token,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: '令牌（可选，放进 Authorization: Bearer）',
                suffixIcon: IconButton(
                  onPressed: () => setState(() => _obscure = !_obscure),
                  icon: Icon(
                    _obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton(
                  onPressed: app.remoteLoading
                      ? null
                      : () => _saveEndpoint(app, ping: true),
                  child: Text(app.remoteLoading ? '连接中…' : '保存并测试'),
                ),
                const SizedBox(width: 8),
                OutlinedButton(
                  onPressed: app.probing ? null : () => app.refreshLocal(),
                  child: const Text('重新扫描本机'),
                ),
              ],
            ),
            if (app.remoteMessage != null) ...[
              const SizedBox(height: 8),
              Text(app.remoteMessage!),
            ],
            const SizedBox(height: 16),
            Text('外观', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            SegmentedButton<ThemeChoice>(
              segments: const [
                ButtonSegment(value: ThemeChoice.system, label: Text('跟随系统')),
                ButtonSegment(value: ThemeChoice.light, label: Text('浅色')),
                ButtonSegment(value: ThemeChoice.dark, label: Text('深色')),
              ],
              selected: {settings.theme},
              onSelectionChanged: (value) {
                app.updateSettings(settings.copyWith(theme: value.first));
              },
            ),
            const SizedBox(height: 16),
            Text(
              '本机已发现 ${localNames.length} 个',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              localNames.isEmpty
                  ? '一个都没有。桌面版会去登录 shell 的 PATH 里找 python3、node、gcc、go 这些。'
                  : localNames.join('、'),
            ),
            const SizedBox(height: 16),
            Text(
              '本机运行等于用你的用户权限执行代码，没有沙箱。不要跑不信任的程序。'
              'Piston 才是隔离执行。工作目录是临时文件夹，进程结束后删除。',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _saveEndpoint(AppController app, {bool ping = false}) async {
    await app.updateSettings(
      app.settings.copyWith(
        pistonBaseUrl: _url.text.trim(),
        pistonToken: _token.text.trim(),
      ),
    );
    if (ping) await app.refreshRemote();
  }
}
