import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';

class StoryViewerPage extends StatefulWidget {
  const StoryViewerPage({
    super.key,
    required this.storyId,
    required this.title,
  });

  final int storyId;
  final String title;

  @override
  State<StoryViewerPage> createState() => _StoryViewerPageState();
}

class _StoryViewerPageState extends State<StoryViewerPage> {
  List<StoryMedia> _items = [];
  bool _loading = true;
  String? _error;
  final _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final repo = context.read<SocialRepository>();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final items = await repo.listStoryMedia(widget.storyId);
      final unseen = items.where((m) => !m.seenByMe).map((m) => m.id).toList();
      if (unseen.isNotEmpty) {
        await repo.markStorySeen(unseen);
      }
      setState(() {
        _items = items;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _report() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report this story?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Report'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await context.read<SocialRepository>().reportStory(widget.storyId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reported')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(widget.title),
        actions: [
          IconButton(onPressed: _report, icon: const Icon(Icons.flag_outlined)),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                )
              : _items.isEmpty
                  ? const Center(
                      child: Text(
                        'No media in this story',
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                  : PageView.builder(
                      controller: _pageController,
                      itemCount: _items.length,
                      onPageChanged: (i) {
                        final id = _items[i].id;
                        context.read<SocialRepository>().markStorySeen([id]);
                      },
                      itemBuilder: (_, i) {
                        final m = _items[i];
                        return InteractiveViewer(
                          minScale: 1,
                          maxScale: 4,
                          child: Center(
                            child: Image.network(
                              m.mediaUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, __, ___) => const Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white54,
                                size: 64,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
    );
  }
}
