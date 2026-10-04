import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../providers/chat_provider.dart';

/// Camera capture only makes sense on phones.
bool get supportsCamera =>
    !kIsWeb &&
    (defaultTargetPlatform == TargetPlatform.android ||
        defaultTargetPlatform == TargetPlatform.iOS);

/// The composer's "+" button and its menu, modelled on ChatGPT / Claude:
/// add content (files, camera, pasted text) and per-message options
/// (think longer, response style).
class ComposerPlusMenu extends StatelessWidget {
  final VoidCallback onUploadFiles;
  final VoidCallback? onTakePhoto;
  final VoidCallback onPasteText;
  final bool thinkLonger;
  final ValueChanged<bool> onThinkLongerChanged;
  final ResponseStyle responseStyle;
  final ValueChanged<ResponseStyle> onResponseStyleChanged;

  const ComposerPlusMenu({
    super.key,
    required this.onUploadFiles,
    this.onTakePhoto,
    required this.onPasteText,
    required this.thinkLonger,
    required this.onThinkLongerChanged,
    required this.responseStyle,
    required this.onResponseStyleChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      alignmentOffset: const Offset(0, 6),
      menuChildren: [
        _item(
          icon: Icons.attach_file_rounded,
          label: 'Upload photos & files',
          onPressed: onUploadFiles,
        ),
        if (onTakePhoto != null)
          _item(
            icon: Icons.photo_camera_outlined,
            label: 'Take photo',
            onPressed: onTakePhoto!,
          ),
        _item(
          icon: Icons.content_paste_rounded,
          label: 'Paste text as file',
          onPressed: onPasteText,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 4),
          child: Divider(height: 1),
        ),
        MenuItemButton(
          closeOnActivate: false,
          leadingIcon: const Icon(Icons.lightbulb_outline_rounded, size: 19),
          trailingIcon: SizedBox(
            height: 24,
            child: FittedBox(
              child: Switch(
                value: thinkLonger,
                onChanged: onThinkLongerChanged,
              ),
            ),
          ),
          onPressed: () => onThinkLongerChanged(!thinkLonger),
          child: const _Label(
            'Think longer',
            'More reasoning for harder questions',
          ),
        ),
        SubmenuButton(
          leadingIcon: const Icon(Icons.tune_rounded, size: 19),
          trailingIcon: Text(
            responseStyle.label,
            style: const TextStyle(color: AppTheme.muted, fontSize: 13),
          ),
          menuChildren: [
            for (final style in ResponseStyle.values)
              MenuItemButton(
                leadingIcon: Icon(
                  Icons.check_rounded,
                  size: 18,
                  color: style == responseStyle
                      ? AppTheme.accentText
                      : Colors.transparent,
                ),
                onPressed: () => onResponseStyleChanged(style),
                child: _Label(style.label, style.description),
              ),
          ],
          child: const Text('Response style'),
        ),
      ],
      builder: (context, controller, _) => IconButton(
        tooltip: 'Add photos, files and more',
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: AnimatedRotation(
          turns: controller.isOpen ? 0.125 : 0,
          duration: const Duration(milliseconds: 180),
          child: const Icon(Icons.add_rounded, size: 20),
        ),
        style: IconButton.styleFrom(
          minimumSize: const Size(36, 36),
          fixedSize: const Size(36, 36),
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
          foregroundColor: controller.isOpen ? AppTheme.text : AppTheme.muted,
          backgroundColor: controller.isOpen ? AppTheme.raised : null,
          side: const BorderSide(color: AppTheme.border),
        ),
      ),
    );
  }

  Widget _item({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) => MenuItemButton(
    leadingIcon: Icon(icon, size: 19),
    onPressed: onPressed,
    child: Text(label),
  );
}

class _Label extends StatelessWidget {
  final String title;
  final String subtitle;
  const _Label(this.title, this.subtitle);

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title),
        Text(
          subtitle,
          style: const TextStyle(fontSize: 12, color: AppTheme.muted),
        ),
      ],
    ),
  );
}

/// A small removable pill showing an active option ("Think longer", a style).
class ActiveOptionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onRemove;
  const ActiveOptionChip({
    super.key,
    required this.icon,
    required this.label,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) => Container(
    height: 32,
    padding: const EdgeInsets.only(left: 10, right: 2),
    decoration: BoxDecoration(
      color: AppTheme.accent.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppTheme.accentText),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppTheme.accentText),
        ),
        IconButton(
          tooltip: 'Turn off $label',
          onPressed: onRemove,
          icon: const Icon(Icons.close_rounded, size: 14),
          style: IconButton.styleFrom(
            minimumSize: const Size(28, 28),
            fixedSize: const Size(28, 28),
            padding: EdgeInsets.zero,
            foregroundColor: AppTheme.accentText,
          ),
        ),
      ],
    ),
  );
}

/// Claude-style "paste text as an attachment" dialog. Returns the text, or
/// null if cancelled.
Future<String?> showPasteTextDialog(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppTheme.border),
      ),
      title: Text('Paste text as file', style: AppTheme.display(19)),
      content: SizedBox(
        width: 560,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Long text (notes, logs, an article) is attached as a .txt file '
              'so your message stays tidy.',
              style: TextStyle(color: AppTheme.muted, fontSize: 13.5),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              autofocus: true,
              minLines: 8,
              maxLines: 14,
              style: const TextStyle(fontSize: 14.5, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Paste or type here…',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel', style: TextStyle(color: AppTheme.muted)),
        ),
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => ElevatedButton(
            style: ElevatedButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: value.text.trim().isEmpty
                ? null
                : () => Navigator.of(context).pop(controller.text),
            child: const Text('Attach'),
          ),
        ),
      ],
    ),
  );
}
