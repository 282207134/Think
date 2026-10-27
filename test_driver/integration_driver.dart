import 'dart:io';
import 'package:integration_test/integration_test_driver_extended.dart';

Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    final directory = Directory('docs/screenshots/simulator')
      ..createSync(recursive: true);
    File('${directory.path}/$name.png').writeAsBytesSync(bytes);
    return true;
  },
);
