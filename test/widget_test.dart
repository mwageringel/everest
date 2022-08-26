import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:everest/main.dart';

void main() {
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
}
