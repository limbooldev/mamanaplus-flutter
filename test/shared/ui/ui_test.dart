import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/shared/ui/ui.dart';

void main() {
  test('shared UI health', () {
    expect(UiHealth().ok, isTrue);
  });
}
