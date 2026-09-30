import 'package:flutter/material.dart';
import 'package:re_editor/re_editor.dart';

class EditorMenu extends SelectionToolbarController {
  EditorMenu();

  @override
  void hide(BuildContext context) {}

  @override
  void show({
    required BuildContext context,
    required CodeLineEditingController controller,
    required TextSelectionToolbarAnchors anchors,
    Rect? renderRect,
    required LayerLink layerLink,
    required ValueNotifier<bool> visibility,
  }) {
    showMenu<void>(
      context: context,
      position: RelativeRect.fromRect(
        anchors.primaryAnchor & const Size(160, 1),
        Offset.zero & MediaQuery.sizeOf(context),
      ),
      items: [
        PopupMenuItem(onTap: controller.cut, child: const Text('剪切')),
        PopupMenuItem(
          onTap: () {
            controller.copy();
          },
          child: const Text('复制'),
        ),
        PopupMenuItem(onTap: controller.paste, child: const Text('粘贴')),
        PopupMenuItem(onTap: controller.selectAll, child: const Text('全选')),
      ],
    );
  }
}
