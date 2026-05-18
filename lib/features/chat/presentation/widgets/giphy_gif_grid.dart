import 'package:flutter/material.dart';
import 'package:giphy_get/giphy_get.dart';

/// Scrollable Giphy grid (GIFs or stickers) for the in-thread emoji panel.
class GiphyGifGrid extends StatefulWidget {
  const GiphyGifGrid({
    super.key,
    required this.apiKey,
    required this.type,
    required this.onSelected,
    this.searchQuery = '',
  });

  final String apiKey;
  final String type;
  final ValueChanged<GiphyGif> onSelected;
  final String searchQuery;

  @override
  State<GiphyGifGrid> createState() => _GiphyGifGridState();
}

class _GiphyGifGridState extends State<GiphyGifGrid> {
  late final GiphyClient _client;
  final _scrollController = ScrollController();
  final _items = <GiphyGif>[];
  var _loading = false;
  var _canLoadMore = true;
  var _offset = 0;
  static const _limit = 30;
  String _lastSearch = '';

  @override
  void initState() {
    super.initState();
    _client = GiphyClient(apiKey: widget.apiKey, randomId: '');
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void didUpdateWidget(covariant GiphyGifGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.searchQuery != widget.searchQuery) {
      _load(reset: true);
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_canLoadMore || _loading) return;
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (_loading) return;
    if (reset) {
      _offset = 0;
      _canLoadMore = true;
      _items.clear();
    }
    if (!_canLoadMore && !reset) return;

    setState(() => _loading = true);
    try {
      final q = widget.searchQuery.trim();
      final GiphyCollection collection;
      if (q.isEmpty) {
        collection = await _client.trending(
          offset: _offset,
          limit: _limit,
          type: widget.type,
        );
      } else {
        collection = await _client.search(
          q,
          offset: _offset,
          limit: _limit,
          type: widget.type,
        );
      }
      if (!mounted) return;
      final batch = collection.data;
      setState(() {
        _items.addAll(batch);
        final count = collection.pagination?.count ?? batch.length;
        _offset += count;
        final total = collection.pagination?.totalCount ?? 0;
        _canLoadMore = total == 0 ? batch.length >= _limit : _offset < total;
        _lastSearch = q;
      });
    } catch (_) {
      if (mounted && reset) {
        setState(() {
          _items.clear();
          _canLoadMore = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String? _thumbUrl(GiphyGif gif) {
    final images = gif.images;
    if (images == null) return null;
    final still = images.fixedWidthStill?.url;
    if (still != null && still.isNotEmpty) return still;
    return images.previewWebp?.url ??
        images.downsizedStill?.url ??
        images.fixedWidth.url;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.apiKey.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Giphy API key not configured.\n'
            'Set --dart-define=GIPHY_API_KEY=...',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (_items.isEmpty && _loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_items.isEmpty) {
      return Center(
        child: Text(
          _lastSearch.isEmpty ? 'No GIFs found' : 'No results for "$_lastSearch"',
        ),
      );
    }

    final crossAxisCount = widget.type == GiphyType.stickers ? 3 : 2;

    return GridView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.all(8),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        childAspectRatio: widget.type == GiphyType.stickers ? 1 : 1.2,
      ),
      itemCount: _items.length + (_loading ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= _items.length) {
          return const Center(child: CircularProgressIndicator());
        }
        final gif = _items[index];
        final url = _thumbUrl(gif);
        return GestureDetector(
          onTap: () => widget.onSelected(gif),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: url == null
                ? const ColoredBox(
                    color: Color(0xFFE0E0E0),
                    child: SizedBox.expand(),
                  )
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return const ColoredBox(
                        color: Color(0xFFE8E8E8),
                        child: Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                    errorBuilder: (_, __, ___) => const ColoredBox(
                      color: Color(0xFFE0E0E0),
                      child: Icon(Icons.broken_image_outlined),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
