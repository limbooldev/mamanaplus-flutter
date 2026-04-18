import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/social_repository.dart';
import '../../domain/social_models.dart';
import '../cubit/social_explore_cubit.dart';
import '../widgets/social_media_widgets.dart';
import 'social_post_page.dart';

class SocialExplorePage extends StatelessWidget {
  const SocialExplorePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          SocialExploreCubit(context.read<SocialRepository>())..refresh(),
      child: const _ExploreBody(),
    );
  }
}

class _ExploreBody extends StatelessWidget {
  const _ExploreBody();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Explore')),
      body: BlocBuilder<SocialExploreCubit, SocialExploreState>(
        builder: (context, state) {
          if (state is SocialExploreLoading || state is SocialExploreInitial) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state is SocialExploreFailure) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(state.message, textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: () =>
                        context.read<SocialExploreCubit>().refresh(),
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }
          if (state is! SocialExploreLoaded) {
            return const SizedBox.shrink();
          }
          if (state.posts.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => context.read<SocialExploreCubit>().refresh(),
              child: ListView(
                children: const [
                  SizedBox(height: 120),
                  Center(child: Text('Nothing here yet.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<SocialExploreCubit>().refresh(),
            child: NotificationListener<ScrollNotification>(
              onNotification: (n) {
                if (n is ScrollEndNotification) {
                  final m = n.metrics;
                  if (m.pixels >= m.maxScrollExtent - 80) {
                    context.read<SocialExploreCubit>().loadMore();
                  }
                }
                return false;
              },
              child: GridView.builder(
                padding: const EdgeInsets.all(8),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.82,
                ),
                itemCount: state.posts.length +
                    ((state.hasMore || state.loadingMore) ? 1 : 0),
                itemBuilder: (ctx, i) {
                  if (i >= state.posts.length) {
                    return const Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    );
                  }
                  final p = state.posts[i];
                  return _ExploreTile(
                    post: p,
                    onTap: () {
                      Navigator.of(context).push<void>(
                        MaterialPageRoute<void>(
                          builder: (_) => RepositoryProvider.value(
                            value: context.read<SocialRepository>(),
                            child: SocialPostPage(postId: p.id),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}

class _ExploreTile extends StatelessWidget {
  const _ExploreTile({required this.post, required this.onTap});

  final SocialPost post;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Widget preview;
    if (post.postType == 'video') {
      final t = post.thumbnailUrl;
      if (t != null && t.isNotEmpty) {
        preview = SocialPostImage(mediaRef: t, fit: BoxFit.cover);
      } else {
        preview = ColoredBox(
          color: Colors.grey.shade800,
          child: const Center(
            child: Icon(Icons.play_circle_outline, color: Colors.white70, size: 40),
          ),
        );
      }
    } else {
      final ref = post.thumbnailUrl ?? post.mediaUrl;
      preview = ref != null && ref.isNotEmpty
          ? SocialPostImage(mediaRef: ref, fit: BoxFit.cover)
          : Container(
              color: Colors.grey.shade200,
              alignment: Alignment.center,
              child: const Icon(Icons.grid_view_rounded, size: 36),
            );
    }
    return Material(
      borderRadius: BorderRadius.circular(12),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: preview),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                post.content.isNotEmpty ? post.content : 'Post',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
