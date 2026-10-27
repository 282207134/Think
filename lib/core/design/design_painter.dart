import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_drawing/path_drawing.dart';

import 'design_catalog.dart';

/// Renders the original vector geometry, photographs and live Flutter text.
/// Masks and boolean paths stay vectors, including tiny recolored kit icons.
class DesignPainter extends CustomPainter {
  DesignPainter({
    required this.catalog,
    required this.screen,
    this.hidden = const {},
    this.overrides = const {},
    this.only,
    this.excluded = const {},
    this.origin = Offset.zero,
  });

  final DesignCatalog catalog;
  final DesignNode screen;
  final Set<String> hidden, excluded;
  final Map<String, String> overrides;
  final Set<String>? only;
  final Offset origin;
  static final _geometry = <String, Path>{};
  static final _vectors = <int, Path>{};

  static Color color(Json value, [double opacity = 1]) => Color.fromRGBO(
    ((value['r'] ?? 0) * 255).round(),
    ((value['g'] ?? 0) * 255).round(),
    ((value['b'] ?? 0) * 255).round(),
    ((value['a'] ?? 1) * opacity).clamp(0.0, 1.0),
  );

  Path geometry(DesignNode n) => _geometry.putIfAbsent(n.id, () {
    if (n.type == 'BOOLEAN_OPERATION') {
      final children = n.children.map(geometry).toList();
      if (children.isEmpty) return Path();
      final op = switch (n.style['booleanOperation']) {
        'SUBTRACT' => PathOperation.difference,
        'INTERSECT' => PathOperation.intersect,
        'EXCLUDE' => PathOperation.xor,
        _ => PathOperation.union,
      };
      return children
          .skip(1)
          .fold(children.first, (path, child) => Path.combine(op, path, child));
    }
    final local = Path();
    if (n.style['paths'] case final List indices) {
      for (final index in indices.cast<int>()) {
        final path = _vectors.putIfAbsent(index, () {
          final data = catalog.paths[index];
          return parseSvgPathData(data['data'])
            ..fillType = data['windingRule'] == 'EVENODD'
                ? PathFillType.evenOdd
                : PathFillType.nonZero;
        });
        local.addPath(path, Offset.zero);
      }
      local.fillType = PathFillType.evenOdd;
    } else {
      final s = n.style;
      final r = (s['cornerRadius'] as num? ?? 0).toDouble();
      Radius radius(String key) =>
          Radius.circular((s[key] as num? ?? r).toDouble());
      local.addRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(0, 0, n.width, n.height),
          topLeft: radius('topLeftRadius'),
          topRight: radius('topRightRadius'),
          bottomLeft: radius('bottomLeftRadius'),
          bottomRight: radius('bottomRightRadius'),
        ),
      );
    }
    return local.transform(n.transform.storage);
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.clipRect(Offset.zero & size);
    canvas.translate(-origin.dx, -origin.dy);
    _draw(canvas, screen, 1, root: true);
  }

  void _draw(
    Canvas canvas,
    DesignNode n,
    double inherited, {
    bool root = false,
  }) {
    if (hidden.contains(n.id) || excluded.contains(n.id)) return;
    final opacity = inherited * (n.style['opacity'] as num? ?? 1);
    if (opacity <= 0 || n.width <= 0 || n.height <= 0) return;
    canvas.save();
    final blur = (n.style['effects'] as List? ?? [])
        .cast<Json>()
        .where(
          (effect) =>
              effect['type'] == 'LAYER_BLUR' && effect['visible'] != false,
        )
        .firstOrNull;
    if (blur != null) {
      final sigma = (blur['radius'] as num).toDouble() / 2;
      canvas.saveLayer(
        null,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
      );
    }
    if (!root && n.style['clipsContent'] == true) canvas.clipPath(geometry(n));
    if (only == null || only!.contains(n.id)) {
      if (n.type == 'TEXT') {
        _text(canvas, n, opacity.toDouble());
      } else {
        _shape(canvas, n, opacity.toDouble());
      }
    }
    if (n.type != 'BOOLEAN_OPERATION') {
      var masking = false;
      for (final child in n.children) {
        if (child.style['isMask'] == true) {
          if (masking) canvas.restore();
          canvas.save();
          canvas.clipPath(geometry(child));
          masking = true;
        } else {
          _draw(canvas, child, opacity.toDouble());
        }
      }
      if (masking) canvas.restore();
    }
    if (blur != null) canvas.restore();
    canvas.restore();
  }

  void _shape(Canvas canvas, DesignNode n, double opacity) {
    final fills = (n.style['fills'] as List? ?? []).cast<Json>();
    final strokes = (n.style['strokes'] as List? ?? []).cast<Json>();
    if (fills.isEmpty &&
        strokes.isEmpty &&
        (n.style['effects'] as List? ?? []).isEmpty) {
      return;
    }
    final path = geometry(n);
    for (final effect in n.style['effects'] ?? []) {
      if (effect['visible'] == false || effect['type'] != 'DROP_SHADOW') {
        continue;
      }
      final offset = effect['offset'] ?? {};
      canvas.drawPath(
        path.shift(
          Offset(
            (offset['x'] as num? ?? 0).toDouble(),
            (offset['y'] as num? ?? 0).toDouble(),
          ),
        ),
        Paint()
          ..color = color(effect['color'] ?? {}, opacity)
          ..maskFilter = MaskFilter.blur(
            BlurStyle.normal,
            (effect['radius'] as num? ?? 0) / 2,
          ),
      );
    }
    for (final fill in fills) {
      if (fill['visible'] == false) continue;
      final alpha = opacity * (fill['opacity'] as num? ?? 1);
      if (fill['type'] == 'IMAGE') {
        final image = catalog.images[fill['imageHash']];
        if (image == null) continue;
        canvas.save();
        canvas.clipPath(path);
        canvas.transform(n.transform.storage);
        paintImage(
          canvas: canvas,
          rect: Rect.fromLTWH(0, 0, n.width, n.height),
          image: image,
          opacity: alpha.toDouble(),
          fit: fill['scaleMode'] == 'FIT' ? BoxFit.contain : BoxFit.cover,
          filterQuality: FilterQuality.medium,
        );
        canvas.restore();
      } else {
        canvas.drawPath(path, _paint(fill, n, alpha.toDouble()));
      }
    }
    for (final stroke in strokes) {
      if (stroke['visible'] == false) continue;
      final width = (n.style['strokeWeight'] as num? ?? 1).toDouble();
      if (width == 0) continue;
      canvas.save();
      final inside = n.style['strokeAlign'] == 'INSIDE';
      if (inside) canvas.clipPath(path);
      var strokePath = path;
      final dash = (n.style['dashPattern'] as List? ?? []).cast<num>();
      if (dash.isNotEmpty) {
        strokePath = dashPath(
          path,
          dashArray: CircularIntervalList(
            dash.map((v) => v.toDouble()).toList(),
          ),
        );
      }
      canvas.drawPath(
        strokePath,
        _paint(stroke, n, opacity * (stroke['opacity'] as num? ?? 1))
          ..style = PaintingStyle.stroke
          ..strokeWidth = width * (inside ? 2 : 1)
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.restore();
    }
  }

  Paint _paint(Json fill, DesignNode n, double opacity) {
    final paint = Paint()..isAntiAlias = true;
    if (fill['type'] == 'SOLID') {
      return paint..color = color(fill['color'] ?? {}, opacity);
    }
    final stops = (fill['gradientStops'] as List? ?? []).cast<Json>();
    if (stops.isEmpty) return paint..color = Colors.transparent;
    final colors = stops.map((s) => color(s['color'], opacity)).toList();
    final positions = stops
        .map((s) => (s['position'] as num).toDouble())
        .toList();
    final t =
        fill['gradientTransform'] ??
        [
          [1, 0, 0],
          [0, 1, 0],
        ];
    final a = (t[0][0] as num).toDouble(), b = (t[0][1] as num).toDouble();
    final c = (t[1][0] as num).toDouble(), d = (t[1][1] as num).toDouble();
    final det = a * d - b * c;
    Offset point(double x, double y) {
      x -= (t[0][2] as num).toDouble();
      y -= (t[1][2] as num).toDouble();
      final px = det.abs() < 0.00001 ? x : (d * x - b * y) / det;
      final py = det.abs() < 0.00001 ? y : (-c * x + a * y) / det;
      return MatrixUtils.transformPoint(
        n.transform,
        Offset(px * n.width, py * n.height),
      );
    }

    final start = point(0, .5), end = point(1, .5);
    paint.shader = fill['type'] == 'GRADIENT_RADIAL'
        ? ui.Gradient.radial(
            point(.5, .5),
            math.max(1, (end - start).distance / 2),
            colors,
            positions,
          )
        : ui.Gradient.linear(start, end, colors, positions);
    return paint;
  }

  void _text(Canvas canvas, DesignNode n, double opacity) {
    final s = n.style;
    var text = overrides[n.id] ?? n.text;
    if (text.trim().isEmpty) return;
    if (s['textCase'] == 'UPPER') text = text.toUpperCase();
    if (s['textCase'] == 'LOWER') text = text.toLowerCase();
    final font = s['fontName'] as Json? ?? {};
    final fontSize = (s['fontSize'] as num? ?? 15).toDouble();
    final fills = (s['fills'] as List? ?? []).cast<Json>();
    final fill = fills.isEmpty ? <String, dynamic>{} : fills.first;
    final spacing = s['letterSpacing'] as Json? ?? {};
    final line = s['lineHeight'] as Json? ?? {};
    final lineHeight = line['unit'] == 'PIXELS'
        ? (line['value'] as num) / fontSize
        : line['unit'] == 'PERCENT'
        ? (line['value'] as num) / 100
        : null;
    final bold = (font['style'] as String? ?? '').contains('Bold');
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: font['family'] ?? 'Montserrat',
          fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
          fontSize: fontSize,
          height: lineHeight?.toDouble(),
          letterSpacing: spacing['unit'] == 'PERCENT'
              ? (spacing['value'] as num? ?? 0) * fontSize / 100
              : (spacing['value'] as num? ?? 0).toDouble(),
          color: color(
            fill['color'] ?? {},
            opacity * (fill['opacity'] as num? ?? 1),
          ),
          decoration: s['textDecoration'] == 'STRIKETHROUGH'
              ? TextDecoration.lineThrough
              : s['textDecoration'] == 'UNDERLINE'
              ? TextDecoration.underline
              : TextDecoration.none,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: switch (s['textAlignHorizontal']) {
        'CENTER' => TextAlign.center,
        'RIGHT' => TextAlign.right,
        _ => TextAlign.left,
      },
    )..layout(minWidth: n.width, maxWidth: n.width + .8);
    final vertical = s['textAlignVertical'];
    final dy = vertical == 'CENTER'
        ? (n.height - painter.height) / 2
        : vertical == 'BOTTOM'
        ? n.height - painter.height
        : 0.0;
    canvas.save();
    canvas.transform(n.transform.storage);
    painter.paint(canvas, Offset(0, dy));
    canvas.restore();
    painter.dispose();
  }

  @override
  bool shouldRepaint(DesignPainter old) =>
      old.screen.id != screen.id ||
      old.hidden != hidden ||
      old.overrides != overrides ||
      old.only != only ||
      old.excluded != excluded ||
      old.origin != origin;

  @override
  bool hitTest(Offset position) => false;
}
