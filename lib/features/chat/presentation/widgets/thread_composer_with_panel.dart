import 'package:flutter/material.dart';
import 'package:flutter_chat_core/flutter_chat_core.dart';
import 'package:flutter_chat_ui/flutter_chat_ui.dart';
import 'package:giphy_get/giphy_get.dart';
import 'package:provider/provider.dart';

import 'emoji_sticker_gif_panel.dart';

/// Composer row + optional emoji/GIF panel; updates [ComposerHeightNotifier].
class ThreadComposerWithPanel extends StatefulWidget {
  const ThreadComposerWithPanel({
    super.key,
    required this.textEditingController,
    required this.focusNode,
    required this.hintText,
    required this.topWidget,
    required this.showEmojiPanel,
    required this.panelHeight,
    required this.giphyApiKey,
    required this.onToggleEmojiPanel,
    required this.onEmojiSelected,
    required this.onGifSelected,
    required this.onStickerSelected,
    this.panelInitialTab = 0,
    this.isDark = false,
    this.handleSafeArea = true,
  });

  final TextEditingController textEditingController;
  final FocusNode focusNode;
  final String hintText;
  final Widget topWidget;
  final bool showEmojiPanel;
  final double panelHeight;
  final String giphyApiKey;
  final VoidCallback onToggleEmojiPanel;
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<GiphyGif> onGifSelected;
  final ValueChanged<GiphyGif> onStickerSelected;
  final int panelInitialTab;
  final bool isDark;
  final bool handleSafeArea;

  @override
  State<ThreadComposerWithPanel> createState() => _ThreadComposerWithPanelState();
}

class _ThreadComposerWithPanelState extends State<ThreadComposerWithPanel> {
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  @override
  void didUpdateWidget(covariant ThreadComposerWithPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final renderBox = _key.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final height = renderBox.size.height;
    final bottomSafe = widget.handleSafeArea ? MediaQuery.paddingOf(context).bottom : 0.0;
    context.read<ComposerHeightNotifier>().setHeight(
      widget.handleSafeArea ? height - bottomSafe : height,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomSafe = widget.handleSafeArea ? MediaQuery.paddingOf(context).bottom : 0.0;
    final theme = context.read<ChatTheme>();
    final onAttachmentTap = context.read<OnAttachmentTapCallback?>();

    final bar = Material(
      color: widget.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          widget.topWidget,
          Padding(
            padding: EdgeInsets.fromLTRB(8, 8, 8, 8 + bottomSafe),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onAttachmentTap != null)
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    color: theme.colors.onSurface.withValues(alpha: 0.5),
                    onPressed: onAttachmentTap,
                  ),
                Expanded(
                  child: TextField(
                    controller: widget.textEditingController,
                    focusNode: widget.focusNode,
                    decoration: InputDecoration(
                      hintText: widget.hintText,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: theme.colors.surfaceContainerHigh.withValues(alpha: 0.8),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    style: theme.typography.bodyMedium.copyWith(
                      color: theme.colors.onSurface,
                    ),
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (text) {
                      context.read<OnMessageSendCallback?>()?.call(text.trim());
                      widget.textEditingController.clear();
                    },
                  ),
                ),
                IconButton(
                  icon: Icon(
                    widget.showEmojiPanel
                        ? Icons.keyboard_outlined
                        : Icons.emoji_emotions_outlined,
                  ),
                  color: widget.showEmojiPanel
                      ? theme.colors.primary
                      : theme.colors.onSurface.withValues(alpha: 0.5),
                  onPressed: widget.onToggleEmojiPanel,
                ),
                ValueListenableBuilder<TextEditingValue>(
                  valueListenable: widget.textEditingController,
                  builder: (context, value, _) {
                    final hasText = value.text.trim().isNotEmpty;
                    return IconButton(
                      icon: const Icon(Icons.send),
                      color: hasText
                          ? theme.colors.primary
                          : theme.colors.onSurface.withValues(alpha: 0.35),
                      onPressed: hasText
                          ? () {
                              final text = widget.textEditingController.text.trim();
                              context.read<OnMessageSendCallback?>()?.call(text);
                              widget.textEditingController.clear();
                            }
                          : null,
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bar,
        if (widget.showEmojiPanel)
          EmojiStickerGifPanel(
            height: widget.panelHeight,
            giphyApiKey: widget.giphyApiKey,
            initialTabIndex: widget.panelInitialTab,
            isDark: widget.isDark,
            onEmojiSelected: widget.onEmojiSelected,
            onGifSelected: widget.onGifSelected,
            onStickerSelected: widget.onStickerSelected,
          ),
      ],
    );

    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: Container(
          key: _key,
          child: content,
        ),
      ),
    );
  }
}
