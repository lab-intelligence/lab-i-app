import 'package:flutter_test/flutter_test.dart';
import 'package:labi/app.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('App initializes', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LabiApp(),
      ),
    );
    // App should render without crashing
    expect(find.byType(LabiApp), findsOneWidget);
  });
}
