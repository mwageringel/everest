import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:everest/main.dart';
import 'package:everest/game.dart';

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

  testWidgets('theme change', (WidgetTester tester) async {
    // This tests checks that the background color of the exam screen changes
    // immediately after switching from light to dark theme, a regression
    // introduced with the upgrade to flutter 3.3.0.
    final game0 = Game(null);
    const pureBlack0 = false;
    final world0 = World(null, ThemeMode.light, pureBlack0, Future.value(game0));
    await tester.pumpWidget(MyApp(world0, game0));

    Color? examBackgroundColor() {
      final m = tester.firstElement(find.byType(ExamWidget)).findAncestorWidgetOfExactType<Material>();
      return m!.color;
    }
    // helpful accessors: https://stackoverflow.com/a/47296248 https://stackoverflow.com/a/62641476

    expect(examBackgroundColor(), equals(MyApp.lightTheme().scaffoldBackgroundColor));
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dark'));
    await tester.pumpAndSettle();  // important for color transition animation to finish
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(examBackgroundColor(), equals(MyApp.darkTheme(pureBlack0).scaffoldBackgroundColor));
  });
}
