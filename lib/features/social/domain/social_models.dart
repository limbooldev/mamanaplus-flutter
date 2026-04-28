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

  SocialPost copyWith({
    int? id,
    int? authorId,
    String? authorName,
    String? title,
    String? content,
    String? postType,
    String? mediaUrl,
    String? thumbnailUrl,
    int? likeCount,
    int? commentCount,
    bool? likedByViewer,
    bool? bookmarked,
    DateTime? createdAt,
  }) {
    return SocialPost(
      id: id ?? this.id,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      title: title ?? this.title,
      content: content ?? this.content,
      postType: postType ?? this.postType,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      likeCount: likeCount ?? this.likeCount,
      commentCount: commentCount ?? this.commentCount,
      likedByViewer: likedByViewer ?? this.likedByViewer,
      bookmarked: bookmarked ?? this.bookmarked,
      createdAt: createdAt ?? this.createdAt,
    );
  }

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

/// `GET /v1/users/{id}/profile`
class UserProfile {
  const UserProfile({
    required this.id,
    required this.displayName,
    required this.bio,
    this.avatarMediaKey,
    required this.profileApproved,
    required this.followersCount,
    required this.followingCount,
    required this.postsCount,
    required this.following,
    required this.hiddenByMe,
    required this.isSelf,
  });

  final int id;
  final String displayName;
  final String bio;
  final String? avatarMediaKey;
  final bool profileApproved;
  final int followersCount;
  final int followingCount;
  final int postsCount;
  final bool following;
  final bool hiddenByMe;
  final bool isSelf;

  UserProfile copyWith({
    bool? following,
    bool? hiddenByMe,
    bool? profileApproved,
    int? followersCount,
    int? followingCount,
    int? postsCount,
  }) {
    return UserProfile(
      id: id,
      displayName: displayName,
      bio: bio,
      avatarMediaKey: avatarMediaKey,
      profileApproved: profileApproved ?? this.profileApproved,
      followersCount: followersCount ?? this.followersCount,
      followingCount: followingCount ?? this.followingCount,
      postsCount: postsCount ?? this.postsCount,
      following: following ?? this.following,
      hiddenByMe: hiddenByMe ?? this.hiddenByMe,
      isSelf: isSelf,
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    return UserProfile(
      id: (j['id'] as num).toInt(),
      displayName: j['display_name'] as String? ?? '',
      bio: j['bio'] as String? ?? '',
      avatarMediaKey: j['avatar_media_key'] as String?,
      profileApproved: j['profile_approved'] == true,
      followersCount: (j['followers_count'] as num?)?.toInt() ?? 0,
      followingCount: (j['following_count'] as num?)?.toInt() ?? 0,
      postsCount: (j['posts_count'] as num?)?.toInt() ?? 0,
      following: j['following'] == true,
      hiddenByMe: j['hidden_by_me'] == true,
      isSelf: j['is_self'] == true,
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

  /// Client-only placeholder for "Your story" when the user has no active ring (`story_id == 0`).
  bool get isAddPlaceholder => storyId == 0;
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

/// One account that viewed a story slide (`GET .../viewers`).
class StoryMediaViewer {
  const StoryMediaViewer({
    required this.userId,
    required this.displayName,
    required this.seenAt,
  });

  final int userId;
  final String displayName;
  final DateTime seenAt;

  factory StoryMediaViewer.fromJson(Map<String, dynamic> j) {
    return StoryMediaViewer(
      userId: (j['user_id'] as num).toInt(),
      displayName: j['display_name'] as String? ?? '',
      seenAt: DateTime.tryParse(j['seen_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
