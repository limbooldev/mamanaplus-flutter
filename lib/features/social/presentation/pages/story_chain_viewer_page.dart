import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/ui/ui.dart';
import '../../../chat/data/chat_repository.dart';
import '../../data/social_repository.dart';
import '../widgets/social_media_widgets.dart';
import '../../data/story_seen_local_store.dart';
import '../../domain/social_models.dart';

/// Full-screen stories: swipe horizontally between users; timed vertical slides per user.
class StoryChainViewerPage extends StatefulWidget {
  const StoryChainViewerPage({
    super.key,
    required this.rings,
    required this.initialUserIndex,
    required this.seenStore,
  });

  final List<StoryRing> rings;
  final int initialUserIndex;
  final StorySeenLocalStore seenStore;

  @override
  State<StoryChainViewerPage> createState() => _StoryChainViewerPageState();
}

class _StoryChainViewerPageState extends State<StoryChainViewerPage> {
  late final PageController _userCtrl = PageController(
    initialPage: widget.initialUserIndex.clamp(0, widget.rings.length - 1),
  );
  bool _changed = false;

  void _close() {
    Navigator.of(context).pop(_changed);
  }

  void _markChanged() {
    _changed = true;
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: PageView.builder(
        controller: _userCtrl,
        itemCount: widget.rings.length,
        itemBuilder: (ctx, userIdx) {
          final ring = widget.rings[userIdx];
          return _UserStorySegment(
            ring: ring,
            seenStore: widget.seenStore,
            onClose: _close,
            onChanged: _markChanged,
            onFinishedUser: () {
              if (userIdx + 1 < widget.rings.length) {
                _userCtrl.nextPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                );
              } else {
                _close();
              }
            },
            onPrevUser: () {
              if (userIdx > 0) {
                _userCtrl.previousPage(
                  duration: const Duration(milliseconds: 280),
                  curve: Curves.easeOut,
                );
              } else {
                _close();
              }
            },
          );
        },
      ),
    );
  }
}

class _UserStorySegment extends StatefulWidget {
  const _UserStorySegment({
    required this.ring,
    required this.seenStore,
    required this.onClose,
    required this.onChanged,
    required this.onFinishedUser,
    required this.onPrevUser,
  });

  final StoryRing ring;
  final StorySeenLocalStore seenStore;
  final VoidCallback onClose;
  final VoidCallback onChanged;
  final VoidCallback onFinishedUser;
  final VoidCallback onPrevUser;

  @override
  State<_UserStorySegment> createState() => _UserStorySegmentState();
}

class _UserStorySegmentState extends State<_UserStorySegment>
    with SingleTickerProviderStateMixin {
  List<StoryMedia> _items = [];
  bool _loading = true;
  String? _error;
  late final PageController _slideCtrl = PageController();
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 5),
  );
  int _slideIndex = 0;
  bool _holding = false;
  int? _myId;

  bool get _isOwn => _myId != null && _myId == widget.ring.userId;

  @override
  void initState() {
    super.initState();
    _progress.addStatusListener(_onProgressCompleted);
    _init();
  }

  void _onProgressCompleted(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    if (_slideIndex >= _items.length - 1) {
      widget.onFinishedUser();
    } else {
      _slideCtrl.nextPage(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _init() async {
    final social = context.read<SocialRepository>();
    final me = await social.currentUserId();
    if (!mounted) return;
    setState(() => _myId = me);
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = social;
      final items = await repo.listStoryMedia(widget.ring.storyId);
      final unseen = items.where((m) => !m.seenByMe).map((m) => m.id).toList();
      for (final id in unseen) {
        await _safeMarkSeen(id);
      }
      if (!mounted) return;
      setState(() {
        _items = items;
        _loading = false;
      });
      if (items.isNotEmpty) {
        _startProgress();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _progress.removeStatusListener(_onProgressCompleted);
    _progress.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  Future<void> _safeMarkSeen(int mediaId) async {
    if (mediaId <= 0 || _isOwn) return;
    try {
      await context.read<SocialRepository>().markStorySeen([mediaId]);
      widget.seenStore.removePending({mediaId});
    } catch (_) {
      widget.seenStore.addPending({mediaId});
    }
  }

  void _startProgress() {
    if (_holding || _items.isEmpty) return;
    _progress
      ..stop()
      ..reset()
      ..forward();
  }

  void _goSlide(int delta) {
    if (_items.isEmpty) return;
    final next = _slideIndex + delta;
    if (next < 0) {
      widget.onPrevUser();
      return;
    }
    if (next >= _items.length) {
      widget.onFinishedUser();
      return;
    }
    _slideCtrl.animateToPage(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  Future<void> _deleteCurrent() async {
    if (_items.isEmpty) return;
    _progress.stop();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete story?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('This story will be permanently removed.'),
            const SizedBox(height: 20),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Delete'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) {
      if (mounted && !_holding) _startProgress();
      return;
    }
    final id = _items[_slideIndex].id;
    try {
      await context.read<SocialRepository>().deleteStoryMedia(id);
      if (!mounted) return;
      widget.onChanged();
      setState(() {
        _items.removeAt(_slideIndex);
        if (_items.isEmpty) {
          widget.onClose();
          return;
        }
        if (_slideIndex >= _items.length) {
          _slideIndex = _items.length - 1;
        }
      });
      _startProgress();
    } on DioException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message ?? 'Delete failed')),
        );
        if (!_holding) _startProgress();
      }
    }
  }

  Future<void> _showViewers() async {
    if (_items.isEmpty) return;
    final m = _items[_slideIndex];
    try {
      final list = await context.read<SocialRepository>().listStoryMediaViewers(
            storyId: widget.ring.storyId,
            mediaId: m.id,
          );
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Viewers (${list.length})', style: Theme.of(ctx).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...list.map(
              (v) => ListTile(
                title: Text(v.displayName),
                subtitle: Text(v.seenAt.toLocal().toString()),
              ),
            ),
          ],
        ),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _sendStoryReply() async {
    if (_isOwn || _items.isEmpty) return;
    _progress.stop();
    final ctrl = TextEditingController();
    final bool? ok;
    try {
      ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Message'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(hintText: 'Write a message…'),
            maxLines: 3,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
          ],
        ),
      );
    } finally {
      if (mounted && !_holding) _progress.forward();
    }
    if (ok != true || !mounted) return;
    final body = ctrl.text.trim();
    if (body.isEmpty) return;
    final mediaId = _items[_slideIndex].id;
    try {
      final chat = context.read<ChatRepository>();
      final dm = await chat.createDm(widget.ring.userId);
      final cid = (dm['id'] as num).toInt();
      await chat.sendMessage(cid, body: body, storyMediaId: mediaId);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sent')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Widget _buildProgressBar() {
    return AnimatedBuilder(
      animation: _progress,
      builder: (_, __) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
          child: Row(
            children: List.generate(_items.length, (i) {
              final value = i < _slideIndex
                  ? 1.0
                  : i == _slideIndex
                      ? _progress.value
                      : 0.0;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: i < _items.length - 1 ? 4 : 0),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: LinearProgressIndicator(
                      value: value,
                      minHeight: 2,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return ColoredBox(
        color: Colors.black,
        child: Center(child: Text(_error!, style: const TextStyle(color: Colors.white70))),
      );
    }
    if (_items.isEmpty) {
      return ColoredBox(
        color: Colors.black,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('No slides', style: TextStyle(color: Colors.white70)),
              TextButton(onPressed: widget.onClose, child: const Text('Close')),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTapUp: (d) {
        final w = MediaQuery.of(context).size.width;
        if (d.localPosition.dx < w * 0.25) {
          _goSlide(-1);
        } else if (d.localPosition.dx > w * 0.75) {
          _goSlide(1);
        }
      },
      onLongPressStart: (_) {
        setState(() => _holding = true);
        _progress.stop();
      },
      onLongPressEnd: (_) {
        setState(() => _holding = false);
        _progress.forward();
      },
      child: Stack(
        fit: StackFit.expand,
        children: [
          PageView.builder(
            controller: _slideCtrl,
            itemCount: _items.length,
            onPageChanged: (i) {
              setState(() => _slideIndex = i);
              unawaited(_safeMarkSeen(_items[i].id));
              _startProgress();
            },
            itemBuilder: (_, i) {
              final ref = _items[i].mediaUrl;
              return SocialPostImage(
                mediaRef: ref,
                fit: BoxFit.contain,
              );
            },
          ),
          SafeArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildProgressBar(),
                Row(
                  children: [
                    IconButton(
                      onPressed: widget.onClose,
                      icon: const Icon(Icons.close, color: Colors.white),
                    ),
                    Expanded(
                      child: Text(
                        widget.ring.displayName,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (!_isOwn)
                      IconButton(
                        onPressed: () async {
                          final repo = context.read<SocialRepository>();
                          final messenger = ScaffoldMessenger.of(context);
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Report story?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                                FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Report')),
                              ],
                            ),
                          );
                          if (ok == true && mounted) {
                            await repo.reportStory(widget.ring.storyId);
                            if (mounted) {
                              messenger.showSnackBar(const SnackBar(content: Text('Reported')));
                            }
                          }
                        },
                        icon: const Icon(Icons.flag_outlined, color: Colors.white),
                      ),
                    if (_isOwn) ...[
                      IconButton(
                        onPressed: _deleteCurrent,
                        icon: const Icon(Icons.delete_outline, color: Colors.white),
                      ),
                      IconButton(
                        onPressed: _showViewers,
                        icon: const Icon(Icons.remove_red_eye_outlined, color: Colors.white),
                      ),
                    ],
                  ],
                ),
                const Spacer(),
                if (!_isOwn)
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.tonal(
                      onPressed: _sendStoryReply,
                      child: const Text('Reply to story'),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
