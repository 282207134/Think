import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:think_app/core/design/design_catalog.dart';
import 'package:think_app/core/state/app_state.dart';
import 'package:think_app/features/scene/scene_page.dart';
import 'package:think_app/features/scene/scene_controls.dart';
import 'support/font_loader.dart';

void main() {
  late DesignCatalog catalog;
  late AppState state;
  Future<void> setup(WidgetTester tester) async {
    tester.view.physicalSize = const Size(375, 812);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues({});
    await tester.runAsync(() async {
      await loadDesignFonts();
      catalog = await DesignCatalog.load();
      state = AppState(await SharedPreferences.getInstance());
    });
  }

  Future<void> scene(
    WidgetTester tester,
    String name, {
    ValueChanged<String>? go,
    GlobalKey? boundary,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RepaintBoundary(
          key: boundary,
          child: ScenePage(
            key: ValueKey(name),
            catalog: catalog,
            screen: catalog.screen(name),
            state: state,
            openCatalog: () {},
            openScreen: go ?? (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('all 120 screens render and produce PNG documentation', (
    tester,
  ) async {
    await setup(tester);
    expect(catalog.categories.length, 11);
    expect(catalog.screens.length, 120);
    final manifest = <Map<String, String>>[];
    for (final category in catalog.categories) {
      final number = category.name.substring(0, 2);
      for (final screen in category.screens) {
        expect(
          controlsFor(
            screen,
          ).where((c) => c.kind == ControlKind.counter).length,
          screen.name == 'Shopping Cart' ? 4 : 0,
          reason:
              'Only shopping cart quantities are editable counters; statistics must retain their source values.',
        );
        final boundary = GlobalKey();
        await scene(tester, screen.id, boundary: boundary);
        expect(tester.takeException(), isNull, reason: screen.name);
        final filename =
            '$number-${screen.name.toLowerCase().replaceAll(RegExp('[^a-z0-9]+'), '-')}.png';
        await tester.runAsync(() async {
          final image =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          expect(
            bytes!.lengthInBytes,
            greaterThan(5000),
            reason: '${screen.name} should not be blank',
          );
          File(
            'docs/screenshots/$filename',
          ).writeAsBytesSync(bytes.buffer.asUint8List());
          image.dispose();
        });
        manifest.add({
          'category': category.name,
          'title': category.title,
          'name': screen.name,
          'id': screen.id,
          'file': filename,
        });
      }
    }
    File(
      'docs/screenshots/manifest.json',
    ).writeAsStringSync(const JsonEncoder.withIndent('  ').convert(manifest));
  });

  testWidgets('email login validates and reaches the feed', (tester) async {
    await setup(tester);
    String? destination;
    await scene(tester, 'Sign In 1', go: (value) => destination = value);
    await tester.tap(find.byKey(const ValueKey('action:0:399')));
    await tester.pump();
    expect(find.text('请输入有效的邮箱地址'), findsOneWidget);
    expect(destination, isNull);
    await tester.enterText(
      find.byKey(const ValueKey('field:E-Mail')),
      'demo@think.app',
    );
    await tester.enterText(
      find.byKey(const ValueKey('field:Password')),
      'demo1234',
    );
    await tester.tap(find.byKey(const ValueKey('action:0:399')));
    await tester.pump();
    expect(state.signedIn, isTrue);
    expect(destination, 'News Feed 1');
  });

  testWidgets('chat sends a native text field message', (tester) async {
    await setup(tester);
    await scene(tester, 'Chat');
    await tester.enterText(
      find.byKey(const ValueKey('field:Type a message')),
      'See you tomorrow',
    );
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump();
    expect(state.messages, ['See you tomorrow']);
    expect(find.text('See you tomorrow'), findsOneWidget);
  });

  testWidgets('cart quantity and checkout work', (tester) async {
    await setup(tester);
    String? destination;
    await scene(tester, 'Shopping Cart', go: (value) => destination = value);
    await tester.tap(find.byKey(const ValueKey('action:0:3510')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('2'));
    await tester.pumpAndSettle();
    expect(state.quantity('0:3510'), 2);
    await tester.tap(find.byKey(const ValueKey('action:0:3517')));
    await tester.pump();
    expect(destination, 'Pay With Card');
    expect(state.cartTotal, closeTo(156.35, .001));
    expect(state.checkoutTotal, closeTo(state.cartTotal, .001));
  });

  testWidgets('player pause/play and native seeking update visible state', (
    tester,
  ) async {
    await setup(tester);
    await scene(tester, 'Music Pause');
    final page = tester.widget<ScenePage>(find.byType(ScenePage));
    final play = page.screen.descendants.firstWhere(
      (n) => n.component == 'Icons/Play',
    );
    expect(state.playing, isFalse);
    await tester.tap(find.byKey(ValueKey('action:${play.id}')));
    await tester.pump();
    expect(state.playing, isTrue);
    await tester.drag(find.byType(Slider), const Offset(50, 0));
    await tester.pump();
    expect(state.seeked, isTrue);
    expect(state.position, greaterThan(.5));
  });

  testWidgets('task completion and notification preferences persist', (
    tester,
  ) async {
    await setup(tester);
    await scene(tester, 'Todo');
    await tester.tap(find.byKey(const ValueKey('action:0:2499')));
    await tester.pump();
    expect(state.flags['task:0:2499'], isTrue);
    await scene(tester, 'Settings Notifications');
    await tester.tap(find.byType(CupertinoSwitch).first);
    await tester.pumpAndSettle();
    final restored = AppState(await SharedPreferences.getInstance());
    expect(restored.flags, state.flags);
    expect(restored.flags.length, greaterThan(1));
  });
}
