import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

typedef Json = Map<String, dynamic>;

/// Immutable source data. No screen is represented by a full-page image.
class DesignNode {
  DesignNode(Json json, List<Json> styles)
    : id = json['id'],
      name = json['n'],
      type = json['t'],
      text = json['text'] ?? '',
      component = json['component'] ?? '',
      width = (json['w'] as num).toDouble(),
      height = (json['h'] as num).toDouble(),
      matrix = (json['m'] as List)
          .cast<num>()
          .map((v) => v.toDouble())
          .toList(),
      style = styles[json['s']],
      children = [
        for (final child in json['c'] ?? []) DesignNode(child, styles),
      ];

  final String id, name, type, text, component;
  final double width, height;
  final List<double> matrix;
  final Json style;
  final List<DesignNode> children;

  Rect get rect => Rect.fromLTWH(matrix[4], matrix[5], width, height);
  String get label => descendants
      .where((n) => n.type == 'TEXT' && n.text.trim().isNotEmpty)
      .map((n) => n.text.trim())
      .join(' ');
  Iterable<DesignNode> get descendants sync* {
    yield this;
    for (final child in children) {
      yield* child.descendants;
    }
  }

  Matrix4 get transform => Matrix4.identity()
    ..setEntry(0, 0, matrix[0])
    ..setEntry(1, 0, matrix[1])
    ..setEntry(0, 1, matrix[2])
    ..setEntry(1, 1, matrix[3])
    ..setEntry(0, 3, matrix[4])
    ..setEntry(1, 3, matrix[5]);
}

class DesignCategory {
  DesignCategory(this.id, this.name, this.title, this.screens);
  final String id, name, title;
  final List<DesignNode> screens;
}

class DesignCatalog {
  DesignCatalog._(this.categories, this.paths, this.imagePaths);
  final List<DesignCategory> categories;
  final List<Json> paths;
  final Map<String, String> imagePaths;
  final Map<String, ui.Image> images = {};
  Iterable<DesignNode> get screens => categories.expand((c) => c.screens);

  DesignNode screen(String name) => screens.firstWhere(
    (s) => s.name == name || s.id == name,
    orElse: () => throw ArgumentError('Unknown screen: $name'),
  );

  static Future<DesignCatalog> load() async {
    final json =
        jsonDecode(await rootBundle.loadString('assets/catalog/think.json'))
            as Json;
    final styles = (json['styles'] as List).cast<Json>();
    final catalog = DesignCatalog._(
      [
        for (final page in json['pages'])
          DesignCategory(page['id'], page['name'], page['title'], [
            for (final screen in page['screens']) DesignNode(screen, styles),
          ]),
      ],
      (json['paths'] as List).cast<Json>(),
      (json['images'] as Map).cast<String, String>(),
    );
    // Decode once, share across every variant and thumbnail.
    await Future.wait(
      catalog.imagePaths.entries.map((entry) async {
        final bytes = await rootBundle.load(entry.value);
        final codec = await ui.instantiateImageCodec(
          bytes.buffer.asUint8List(),
        );
        catalog.images[entry.key] = (await codec.getNextFrame()).image;
        codec.dispose();
      }),
    );
    return catalog;
  }
}
