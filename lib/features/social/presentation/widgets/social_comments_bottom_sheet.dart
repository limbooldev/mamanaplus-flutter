import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../data/social_repository.dart';
import '../cubit/social_comments_cubit.dart';
import 'social_post_comment_widgets.dart';

/// Instagram-style comments sheet for a post.
Future<void> showSocialCommentsBottomSheet(
  BuildContext context, {
  required int postId,
  required VoidCallback onCommentAdded,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return BlocProvider(
        create: (_) =>
            SocialCommentsCubit(ctx.read<SocialRepository>(), postId)..load(),
        child: _CommentsSheetBody(onCommentAdded: onCommentAdded),
      );
    },
  );
}

class _CommentsSheetBody extends StatelessWidget {
  const _CommentsSheetBody({required this.onCommentAdded});

  final VoidCallback onCommentAdded;

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.72,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Comments',
                style: GoogleFonts.inter(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: BlocBuilder<SocialCommentsCubit, SocialCommentsState>(
                builder: (context, state) {
                  if (state is SocialCommentsLoading ||
                      state is SocialCommentsInitial) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (state is SocialCommentsFailure) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(state.message, textAlign: TextAlign.center),
                      ),
                    );
                  }
                  if (state is! SocialCommentsReady) {
                    return const SizedBox.shrink();
                  }
                  final cubit = context.read<SocialCommentsCubit>();
                  return ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      ...state.comments.map(
                        (c) => SocialPostCommentTile(
                          comment: c,
                          onReport: cubit.reportComment,
                        ),
                      ),
                      if (!state.commentsDone)
                        TextButton(
                          onPressed: () => cubit.loadMore(),
                          child: const Text('Load more comments'),
                        ),
                    ],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: SocialPostCommentComposer(
                onSubmit: (body) async {
                  await context.read<SocialCommentsCubit>().submitComment(body);
                  onCommentAdded();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
