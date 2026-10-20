import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:jaypharma/main.dart';
import 'package:jaypharma/providers/app_state.dart';

void main() {
  testWidgets('App smoke test loads successfully', (WidgetTester tester) async {
    final appState = AppState();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: appState,
        child: const JayPharmaApp(),
      ),
    );

    expect(find.byType(JayPharmaApp), findsOneWidget);

    appState.dispose();
  });
}
