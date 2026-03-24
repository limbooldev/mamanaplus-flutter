import 'package:flutter_test/flutter_test.dart';

import 'package:mamana_plus_chat/mamana_plus_chat.dart';

void main() {
  group('A group of tests', () {
    final awesome = Awesome();

    setUp(() {
      // Additional setup goes here.
    });

    test('First Test', () {
      expect(awesome.isAwesome, isTrue);
    });
  });
}
