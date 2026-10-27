import 'package:flutter/material.dart';

import '../../core/design/design_catalog.dart';

enum ControlKind {
  button,
  icon,
  input,
  checkbox,
  toggle,
  counter,
  link,
  row,
  tab,
}

class SceneControl {
  const SceneControl(this.node, this.kind, this.label, {this.bounds});
  final DesignNode node;
  final ControlKind kind;
  final String label;
  final Rect? bounds;
  Rect get rect => bounds ?? node.rect;
  String get key => '${kind.name}:${node.id}';
}

/// Infers semantics from component names, not from screenshot pixel regions.
List<SceneControl> controlsFor(DesignNode screen) {
  final out = <SceneControl>[];
  void scan(DesignNode n, {bool inControl = false}) {
    final name = '${n.name} ${n.component}'.toLowerCase();
    final rect = n.rect;
    if (rect.right < 0 ||
        rect.left > 375 ||
        rect.bottom < 0 ||
        rect.top > 1200) {
      return;
    }
    if (!inControl && n.type != 'TEXT') {
      if (n.component.startsWith('Buttons/') || n.name == 'Button') {
        final icon = n.descendants
            .where((c) => c.component.startsWith('Icons/'))
            .firstOrNull;
        out.add(
          SceneControl(
            n,
            ControlKind.button,
            n.label.isNotEmpty
                ? n.label
                : icon?.component.split('/').last ?? 'Continue',
          ),
        );
        return;
      }
      if (name.contains('checkbox')) {
        out.add(SceneControl(n, ControlKind.checkbox, n.name));
        return;
      }
      if (n.component.startsWith('Switch/')) {
        out.add(SceneControl(n, ControlKind.toggle, n.component));
        return;
      }
      if (n.name == 'Counter' && screen.name == 'Shopping Cart') {
        out.add(SceneControl(n, ControlKind.counter, 'Quantity'));
        return;
      }
      if (n.component.startsWith('Icons/')) {
        final label = n.component.split('/').last;
        if (!name.contains('color')) {
          out.add(SceneControl(n, ControlKind.icon, label));
        }
        return;
      }
    }
    if (n.type == 'TEXT' && !inControl) {
      final value = n.text.trim();
      if (screen.name == 'Pay With Card' && value == 'E-mail') return;
      if (screen.name == 'Pay With Card' && value.contains('@')) {
        out.add(
          SceneControl(
            n,
            ControlKind.input,
            'E-Mail',
            bounds: Rect.fromLTWH(rect.left, rect.top - 7, rect.width, 36),
          ),
        );
        return;
      }
      if ((screen.name.contains('Phone') || screen.name == 'Enter Password') &&
          RegExp(r'^\d$').hasMatch(value)) {
        out.add(SceneControl(n, ControlKind.button, value));
        return;
      }
      if (const [
        'E-Mail',
        'E-mail',
        'E-Mail address',
        'Password',
        'Name',
        'Phone number',
        'Age',
        'Type a message',
        'Write comment…',
        'Write something…',
        'Title',
        'Search',
        'Street',
      ].contains(value)) {
        final chat = value == 'Type a message' || value == 'Write comment…';
        final width = chat
            ? (screen.name == 'Chat Bot' ? 180.0 : 170.0)
            : value == 'Password'
            ? 180.0
            : 240.0;
        out.add(
          SceneControl(
            n,
            ControlKind.input,
            value,
            bounds: Rect.fromLTWH(rect.left, rect.top - 7, width, 36),
          ),
        );
      } else if (const [
            'CREATE ACCOUNT',
            'FORGOT',
            'FORGOT PASSWORD',
            'SIGN OUT',
            'PRIVACY POLICY',
            'TERMS & CONDITIONS',
            'CONTINUE',
            'TRY AGAIN',
            'CONTINUE SHOPPING',
            'CLOSE',
            'RATE',
            'NO, THANKS',
            'WRITE A REVIEW',
            'SELECT SIZE',
            'SELECT ALL',
            'INVITE',
            'WRITE',
            'SEE ALL',
            'Sign Up',
            'Sign In',
            'Skip',
            'SKIP',
            'SUBMIT',
            'CANCEL',
          ].contains(value) ||
          value.startsWith('Sign In with')) {
        out.add(SceneControl(n, ControlKind.link, value));
      }
      if (screen.id.startsWith('0:') &&
          const [
            'DAILY',
            'WEEKLY',
            'MONTHLY',
            'TODAY',
            'DAY',
            'WEEK',
            'MONTH',
            'YEAR',
            '1W',
            '1M',
            '3M',
            '6M',
            '1Y',
            'BEST',
            'ALL TICKETS',
            'POPULAR',
            'RECENT',
            'BEST SELLERS',
            'IMAGES',
            'COLLECTIONS',
            'BOOKMARKS',
            'MAN',
            'WOMEN',
          ].contains(value)) {
        out.add(SceneControl(n, ControlKind.tab, value));
      }
      if (screen.name.startsWith('Navigation') &&
          value.isNotEmpty &&
          !value.contains('@') &&
          !RegExp(r'^\d').hasMatch(value)) {
        out.add(SceneControl(n, ControlKind.link, value));
      }
    }
    for (final child in n.children) {
      scan(child, inControl: inControl);
    }
  }

  scan(screen);
  // Rows and image cards have their own navigation, while nested controls retain
  // priority because they are added above these broad hit targets in the view.
  for (final n in screen.descendants) {
    if (n.id.startsWith('I')) continue;
    final name = n.name.toLowerCase();
    if (n.type == 'GROUP' &&
        (name == 'post' ||
            name == 'tour' ||
            name == 'product' ||
            name == 'item' ||
            name == 'track' ||
            name == 'album' ||
            name.startsWith('dialog') ||
            name == 'contact' ||
            name == 'friend')) {
      if (n.width > 60 && n.height > 40) {
        out.add(SceneControl(n, ControlKind.row, n.label));
      }
    }
    if (!n.id.startsWith('I') &&
        n.type == 'GROUP' &&
        ((screen.name == 'Tickets' && n.name == 'Line' && n.height > 100) ||
            (const ['Catalog', 'Home Shop 3'].contains(screen.name) &&
                name == 'category') ||
            (screen.name == 'Hot Tours' && name == 'item'))) {
      out.add(SceneControl(n, ControlKind.row, n.label));
    }
  }
  return out;
}
