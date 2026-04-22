import 'domain/social_models.dart';

/// Unseen-first among others; current user ring (or "Your story" placeholder) first.
List<StoryRing> orderStoryRingsForFeed(List<StoryRing> raw, int? myId) {
  if (raw.isEmpty && myId == null) return raw;
  StoryRing? selfRing;
  final others = <StoryRing>[];
  for (final r in raw) {
    if (myId != null && r.userId == myId) {
      selfRing = r;
    } else {
      others.add(r);
    }
  }
  others.sort((a, b) {
    final u = (b.hasUnseen ? 1 : 0) - (a.hasUnseen ? 1 : 0);
    if (u != 0) return u;
    return 0;
  });
  final out = <StoryRing>[];
  if (myId != null) {
    if (selfRing != null) {
      out.add(selfRing);
    } else {
      out.add(
        StoryRing(
          userId: myId,
          displayName: 'Your story',
          storyId: 0,
          coverUrl: null,
          hasUnseen: false,
        ),
      );
    }
  }
  out.addAll(others);
  return out;
}
