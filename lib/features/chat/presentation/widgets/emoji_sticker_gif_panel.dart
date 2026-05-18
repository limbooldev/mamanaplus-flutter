import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/material.dart';
import 'package:giphy_get/giphy_get.dart';

import 'giphy_gif_grid.dart';

/// WhatsApp/Telegram-style bottom panel: Emoji | Sticker (Giphy) | GIF (Giphy).
class EmojiStickerGifPanel extends StatefulWidget {
  const EmojiStickerGifPanel({
    super.key,
    required this.height,
    required this.giphyApiKey,
    required this.onEmojiSelected,
    required this.onGifSelected,
    required this.onStickerSelected,
    this.initialTabIndex = 0,
    this.isDark = false,
  });

  final double height;
  final String giphyApiKey;
  final ValueChanged<String> onEmojiSelected;
  final ValueChanged<GiphyGif> onGifSelected;
  final ValueChanged<GiphyGif> onStickerSelected;
  final int initialTabIndex;
  final bool isDark;

  @override
  State<EmojiStickerGifPanel> createState() => _EmojiStickerGifPanelState();
}

class _EmojiStickerGifPanelState extends State<EmojiStickerGifPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _gifSearchController = TextEditingController();
  final _stickerSearchController = TextEditingController();
  String _gifSearch = '';
  String _stickerSearch = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex.clamp(0, 2),
    );
  }

  @override
  void didUpdateWidget(covariant EmojiStickerGifPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialTabIndex != widget.initialTabIndex &&
        widget.initialTabIndex != _tabController.index) {
      _tabController.index = widget.initialTabIndex.clamp(0, 2);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _gifSearchController.dispose();
    _stickerSearchController.dispose();
    super.dispose();
  }

  void _submitGifSearch() {
    setState(() => _gifSearch = _gifSearchController.text.trim());
  }

  void _submitStickerSearch() {
    setState(() => _stickerSearch = _stickerSearchController.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final surface = widget.isDark ? const Color(0xFF1C1C1E) : const Color(0xFFF2F2F7);
    final indicator = widget.isDark ? Colors.white70 : Colors.black54;

    return Material(
      color: surface,
      child: SizedBox(
        height: widget.height,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              labelColor: indicator,
              unselectedLabelColor: indicator.withValues(alpha: 0.5),
              indicatorColor: Theme.of(context).colorScheme.primary,
              tabs: const [
                Tab(text: 'Emoji'),
                Tab(text: 'Sticker'),
                Tab(text: 'GIF'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  EmojiPicker(
                    onEmojiSelected: (category, emoji) {
                      widget.onEmojiSelected(emoji.emoji);
                    },
                    config: Config(
                      height: widget.height - 48,
                      checkPlatformCompatibility: true,
                      emojiViewConfig: EmojiViewConfig(
                        backgroundColor: surface,
                        columns: 8,
                      ),
                      categoryViewConfig: CategoryViewConfig(
                        backgroundColor: surface,
                        indicatorColor: Theme.of(context).colorScheme.primary,
                      ),
                      bottomActionBarConfig: const BottomActionBarConfig(
                        enabled: false,
                      ),
                      searchViewConfig: SearchViewConfig(
                        backgroundColor: surface,
                      ),
                    ),
                  ),
                  Column(
                    children: [
                      _SearchField(
                        controller: _stickerSearchController,
                        hint: 'Search stickers',
                        onSubmitted: (_) => _submitStickerSearch(),
                        onClear: () {
                          _stickerSearchController.clear();
                          _submitStickerSearch();
                        },
                      ),
                      Expanded(
                        child: GiphyGifGrid(
                          apiKey: widget.giphyApiKey,
                          type: GiphyType.stickers,
                          searchQuery: _stickerSearch,
                          onSelected: widget.onStickerSelected,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    children: [
                      _SearchField(
                        controller: _gifSearchController,
                        hint: 'Search GIFs',
                        onSubmitted: (_) => _submitGifSearch(),
                        onClear: () {
                          _gifSearchController.clear();
                          _submitGifSearch();
                        },
                      ),
                      Expanded(
                        child: GiphyGifGrid(
                          apiKey: widget.giphyApiKey,
                          type: GiphyType.gifs,
                          searchQuery: _gifSearch,
                          onSelected: widget.onGifSelected,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 4, 8, 4),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hint,
          isDense: true,
          prefixIcon: const Icon(Icons.search, size: 20),
          suffixIcon: IconButton(
            icon: const Icon(Icons.clear, size: 18),
            onPressed: onClear,
          ),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        ),
        textInputAction: TextInputAction.search,
        onSubmitted: onSubmitted,
      ),
    );
  }
}
