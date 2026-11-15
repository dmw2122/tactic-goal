import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tactic_goal/main.dart';

void main() {
  testWidgets('home screen renders the game entry point', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const ProviderScope(child: TacticGoalApp()));
    await tester.pumpAndSettle();

    expect(find.text('TACTIC GOAL'), findsOneWidget);
    expect(find.text('OYNA'), findsOneWidget);

    await tester.tap(find.text('OYNA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Antrenman Sahası'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bölüm 1'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));

    expect(find.text('Antrenman 1'), findsOneWidget);
    expect(find.text('GÜÇ 2'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
