import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/core/core.dart';

void main() {
  test('core health', () {
    expect(CoreHealth().ok, isTrue);
  });
}
