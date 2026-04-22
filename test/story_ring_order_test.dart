import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/features/social/domain/social_models.dart';
import 'package:mamana_plus/features/social/story_ring_order.dart';

void main() {
  test('self first, unseen before seen among others', () {
    final raw = [
      const StoryRing(userId: 2, displayName: 'B', storyId: 20, hasUnseen: false),
      const StoryRing(userId: 3, displayName: 'C', storyId: 30, hasUnseen: true),
      const StoryRing(userId: 1, displayName: 'Me', storyId: 10, hasUnseen: false),
    ];
    final out = orderStoryRingsForFeed(raw, 1);
    expect(out.first.userId, 1);
    expect(out[1].hasUnseen, true);
    expect(out[2].hasUnseen, false);
  });

  test('placeholder when no self ring', () {
    final raw = <StoryRing>[
      const StoryRing(userId: 2, displayName: 'B', storyId: 20, hasUnseen: true),
    ];
    final out = orderStoryRingsForFeed(raw, 99);
    expect(out.first.isAddPlaceholder, true);
    expect(out.first.userId, 99);
    expect(out.length, 2);
  });
}
