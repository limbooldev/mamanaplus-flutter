class SocialPost {
  const SocialPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    required this.title,
    required this.content,
    required this.postType,
    this.mediaUrl,
    this.thumbnailUrl,
    required this.likeCount,
    required this.commentCount,
    required this.likedByViewer,
    required this.bookmarked,
    required this.createdAt,
  });

  final int id;
  final int authorId;
  final String authorName;
  final String title;
  final String content;
  final String postType;
  final String? mediaUrl;
  final String? thumbnailUrl;
  final int likeCount;
  final int commentCount;
  final bool likedByViewer;
  final bool bookmarked;
  final DateTime createdAt;

  factory SocialPost.fromJson(Map<String, dynamic> j) {
    return SocialPost(
      id: (j['id'] as num).toInt(),
      authorId: (j['author_id'] as num).toInt(),
      authorName: j['author_name'] as String? ?? '',
      title: j['title'] as String? ?? '',
      content: j['content'] as String? ?? '',
      postType: j['post_type'] as String? ?? 'image',
      mediaUrl: j['media_url'] as String?,
      thumbnailUrl: j['thumbnail_url'] as String?,
      likeCount: (j['like_count'] as num?)?.toInt() ?? 0,
      commentCount: (j['comment_count'] as num?)?.toInt() ?? 0,
      likedByViewer: j['liked_by_viewer'] == true,
      bookmarked: j['bookmarked'] == true,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SocialComment {
  const SocialComment({
    required this.id,
    required this.postId,
    required this.userId,
    required this.userName,
    this.parentId,
    required this.body,
    required this.createdAt,
  });

  final int id;
  final int postId;
  final int userId;
  final String userName;
  final int? parentId;
  final String body;
  final DateTime createdAt;

  factory SocialComment.fromJson(Map<String, dynamic> j) {
    return SocialComment(
      id: (j['id'] as num).toInt(),
      postId: (j['post_id'] as num).toInt(),
      userId: (j['user_id'] as num).toInt(),
      userName: j['user_name'] as String? ?? '',
      parentId: (j['parent_id'] as num?)?.toInt(),
      body: j['body'] as String? ?? '',
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}

class SocialUserBrief {
  const SocialUserBrief({required this.id, required this.displayName});

  final int id;
  final String displayName;

  factory SocialUserBrief.fromJson(Map<String, dynamic> j) {
    return SocialUserBrief(
      id: (j['id'] as num).toInt(),
      displayName: j['display_name'] as String? ?? '',
    );
  }
}

class StoryRing {
  const StoryRing({
    required this.userId,
    required this.displayName,
    required this.storyId,
    this.coverUrl,
    required this.hasUnseen,
  });

  final int userId;
  final String displayName;
  final int storyId;
  final String? coverUrl;
  final bool hasUnseen;

  factory StoryRing.fromJson(Map<String, dynamic> j) {
    return StoryRing(
      userId: (j['user_id'] as num).toInt(),
      displayName: j['display_name'] as String? ?? '',
      storyId: (j['story_id'] as num).toInt(),
      coverUrl: j['cover_url'] as String?,
      hasUnseen: j['has_unseen'] == true,
    );
  }
}

class StoryMedia {
  const StoryMedia({
    required this.id,
    required this.storyId,
    required this.mediaUrl,
    required this.position,
    required this.createdAt,
    required this.seenByMe,
  });

  final int id;
  final int storyId;
  final String mediaUrl;
  final int position;
  final DateTime createdAt;
  final bool seenByMe;

  factory StoryMedia.fromJson(Map<String, dynamic> j) {
    return StoryMedia(
      id: (j['id'] as num).toInt(),
      storyId: (j['story_id'] as num).toInt(),
      mediaUrl: j['media_url'] as String? ?? '',
      position: (j['position'] as num?)?.toInt() ?? 0,
      createdAt: DateTime.tryParse(j['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      seenByMe: j['seen_by_me'] == true,
    );
  }
}
