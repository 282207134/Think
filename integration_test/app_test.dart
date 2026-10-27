import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:think_app/main.dart' as app;
import 'package:think_app/features/scene/scene_page.dart';
import 'package:think_app/features/scene/scene_controls.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('Android: catalog → login → feed → shop → cart → payment', (
    tester,
  ) async {
    await (await SharedPreferences.getInstance()).remove('think.state.v1');
    await app.main();
    await tester.pumpAndSettle();
    for (
      var i = 0;
      i < 40 && find.byKey(const ValueKey('catalog-search')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 250));
    }
    expect(find.byKey(const ValueKey('catalog-search')), findsOneWidget);
    await binding.convertFlutterSurfaceToImage();
    await tester.pumpAndSettle();
    await binding.takeScreenshot('android-01-catalog');
    await tester.enterText(
      find.byKey(const ValueKey('catalog-search')),
      'Sign In 1',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await SystemChannels.textInput.invokeMethod<void>('TextInput.hide');
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('screen:0:386')),
      150,
      scrollable: find
          .descendant(
            of: find.byType(CustomScrollView),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.tap(find.byKey(const ValueKey('screen:0:386')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).screen.name,
      'Sign In 1',
    );
    await binding.takeScreenshot('android-02-sign-in');
    await tester.enterText(
      find.byKey(const ValueKey('field:E-Mail')),
      'demo@think.app',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:Password')),
      'demo1234',
    );
    await tester.tap(find.byKey(const ValueKey('action:0:399')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).screen.name,
      'News Feed 1',
    );
    await binding.takeScreenshot('android-03-feed');
    final feed = tester.widget<ScenePage>(find.byType(ScenePage));
    final shop = controlsFor(feed.screen).firstWhere((c) => c.label == 'Grid');
    await tester.tap(find.byKey(ValueKey('action:${shop.node.id}')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).screen.name,
      'Home Shop 1',
    );
    await binding.takeScreenshot('android-04-shop');
    await tester.tap(find.byKey(const ValueKey('action:0:3980')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).screen.name,
      'Item Shop 1',
    );
    await tester.tap(find.byKey(const ValueKey('action:0:3901')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).screen.name,
      'Shopping Cart',
    );
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).state.quantity('0:3489'),
      greaterThan(1),
    );
    await binding.takeScreenshot('android-05-cart');
    await tester.tap(find.byKey(const ValueKey('action:0:3517')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).screen.name,
      'Pay With Card',
    );
    await binding.takeScreenshot('android-06-payment');
    await tester.tap(find.byKey(const ValueKey('action:0:3645')));
    await tester.pumpAndSettle();
    expect(
      tester.widget<ScenePage>(find.byType(ScenePage)).screen.name,
      'Success Shop',
    );
    await binding.takeScreenshot('android-07-success');
    expect(tester.takeException(), isNull);
  });
}
