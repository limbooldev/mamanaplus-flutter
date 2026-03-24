import 'package:flutter_test/flutter_test.dart';

import 'package:mamana_plus_ui/mamana_plus_ui.dart';

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
