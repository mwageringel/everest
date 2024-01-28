import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:everest/main.dart';
import 'package:everest/game.dart';
import 'package:everest/storage.dart';

FinderBase<Element> findKeypad(String n) => find.descendant(of: find.byType(KeyboardButton), matching: find.text(n));

void main() {
  test('debug mode disabled', () {
    expect(debugUnlockAll, equals(false));
  });

  for (final locale in AppLocalizations.supportedLocales) {
    testWidgets('Base64-encoded localized messages ($locale) can be decoded', (WidgetTester tester) async {
      await tester.pumpWidget(
        Localizations(
          delegates: AppLocalizations.localizationsDelegates,
          locale: locale,
          child: const ExtendedMessage(),
        ),
      );
    });
  }

  testWidgets('unlocking of level 1', (WidgetTester tester) async {
    // Check that unlocking of exam 1 works even when we click onto level 0 before opening the level 1 subpage.
    // The problem was that this makes level 0 active, such that lazy redrawing did not refresh exam 1 when it should become visible.
    final game0 = Game(SqfliteDatabaseWrapper(null));
    final world0 = World(null, ThemeMode.light, false, Future.value(game0));
    await tester.pumpWidget(MyApp(world0, game0));
    await tester.tap(findKeypad('3'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('1 + 2'));  // tapping here means that level 0 becomes "active" (the main source of the redrawing issue)
    await tester.pumpAndSettle();
    await tester.tap(find.text('Level 1'));
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(find.textContaining('5 + 5'), findsOneWidget);  // the first exam questions of level 1 should be visible
  });

  testWidgets('theme change', (WidgetTester tester) async {
    // This tests checks that the background color of the exam screen changes
    // immediately after switching from light to dark theme, a regression
    // introduced with the upgrade to flutter 3.3.0.
    final game0 = Game(SqfliteDatabaseWrapper(null));
    const pureBlack0 = false;
    final world0 = World(null, ThemeMode.light, pureBlack0, Future.value(game0));
    await tester.pumpWidget(MyApp(world0, game0));

    checkExamBackgroundColors(Color expectedColor) {
      // helpful accessors: https://stackoverflow.com/a/47296248 https://stackoverflow.com/a/62641476
      List<Color?> colors = tester.elementList(find.byType(ExamWidget)).map((w) =>
        w.findAncestorWidgetOfExactType<Material>()!.color
      ).toList();
      expect(colors.length, greaterThan(3));
      for (final c in colors) {
        expect(c, equals(expectedColor));
      }
    }

    checkExamBackgroundColors(MyApp.lightTheme().scaffoldBackgroundColor);
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();  // important for color transition animation to finish
    await tester.pageBack();
    await tester.pumpAndSettle();
    checkExamBackgroundColors(MyApp.darkTheme(pureBlack0).scaffoldBackgroundColor);
  });
}
