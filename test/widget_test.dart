import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:polyrun/src/controller.dart';
import 'package:polyrun/src/ui/shell.dart';

void main() {
  testWidgets('library shows seeded applets', (tester) async {
    final dir = Directory.systemTemp.createTempSync('polyrun-ui');
    addTearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });
    final controller = AppController(probeOnBoot: false);
    await tester.runAsync(() => controller.bootstrap(supportDir: dir));
    await tester.pumpWidget(PolyRunApp(controller: controller));
    await tester.pump();
    expect(find.text('万语盒'), findsWidgets);
    expect(find.text('问候 · Python'), findsOneWidget);
  });
}
