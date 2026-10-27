import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'core/design/design_catalog.dart';
import 'core/state/app_state.dart';
import 'features/catalog/catalog_page.dart';
import 'features/scene/scene_page.dart';

class ThinkApp extends StatelessWidget {
  ThinkApp({
    super.key,
    required this.catalog,
    required this.state,
    this.initialScreen,
  });
  final DesignCatalog catalog;
  final AppState state;
  final String? initialScreen;
  final navigator = GlobalKey<NavigatorState>();

  void _open(String name) => navigator.currentState!.pushNamed(
    '/screen/${Uri.encodeComponent(catalog.screen(name).id)}',
  );
  void _catalog() => navigator.currentState!.popUntil((route) => route.isFirst);

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Think',
    debugShowCheckedModeBanner: false,
    navigatorKey: navigator,
    theme: ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: thinkPrimary),
      scaffoldBackgroundColor: Colors.white,
      fontFamily: 'Montserrat',
      useMaterial3: true,
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
      ),
    ),
    initialRoute: initialScreen == null
        ? '/'
        : '/screen/${Uri.encodeComponent(catalog.screen(initialScreen!).id)}',
    builder: (context, child) => Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.keyK, meta: true): _CatalogIntent(),
        SingleActivator(LogicalKeyboardKey.home, alt: true): _CatalogIntent(),
      },
      child: Actions(
        actions: {
          _CatalogIntent: CallbackAction<_CatalogIntent>(
            onInvoke: (_) {
              _catalog();
              return null;
            },
          ),
        },
        child: child!,
      ),
    ),
    onGenerateRoute: (settings) {
      final route = settings.name ?? '/';
      if (route.startsWith('/screen/')) {
        final id = Uri.decodeComponent(route.substring('/screen/'.length));
        final target = catalog.screens.where((s) => s.id == id).firstOrNull;
        if (target != null) {
          return MaterialPageRoute<void>(
            settings: settings,
            builder: (context) => ScenePage(
              catalog: catalog,
              screen: target,
              state: state,
              openCatalog: _catalog,
              openScreen: (name) {
                if (catalog.screen(name).id != id) _open(name);
              },
            ),
          );
        }
      }
      return MaterialPageRoute<void>(
        settings: settings,
        builder: (context) => CatalogPage(catalog: catalog, openScreen: _open),
      );
    },
  );
}

class _CatalogIntent extends Intent {
  const _CatalogIntent();
}
