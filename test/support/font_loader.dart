import 'package:flutter/services.dart';

Future<void> loadDesignFonts() async {
  for (final entry in {
    'Montserrat': 'Montserrat',
    'Bebas Neue': 'BebasNeue',
    'Dancing Script': 'DancingScript',
  }.entries) {
    await (FontLoader(
      entry.key,
    )..addFont(rootBundle.load('assets/fonts/${entry.value}.ttf'))).load();
  }
}
