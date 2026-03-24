import 'package:flutter_test/flutter_test.dart';
import 'package:mamana_plus/main.dart';

void main() {
  testWidgets('App loads', (WidgetTester tester) async {
    await tester.pumpWidget(const MamanaPlusApp());
    expect(find.text('MamanaPlus'), findsOneWidget);
  });
}
