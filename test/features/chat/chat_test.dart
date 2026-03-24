import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/features/chat/chat.dart';

void main() {
  test('chat health', () {
    expect(ChatHealth().ok, isTrue);
  });
}
