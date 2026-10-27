import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Local demo state shared by the design variants. No credentials are saved.
class AppState extends ChangeNotifier {
  AppState(this._preferences) {
    final saved = _preferences.getString('think.state.v1');
    if (saved == null) return;
    try {
      final data = jsonDecode(saved) as Map<String, dynamic>;
      liked.addAll((data['liked'] as List? ?? []).cast<String>());
      flags.addAll((data['flags'] as Map? ?? {}).cast<String, bool>());
      quantities.addAll((data['quantities'] as Map? ?? {}).cast<String, int>());
      messages.addAll((data['messages'] as List? ?? []).cast<String>());
      tasks.addAll((data['tasks'] as List? ?? []).cast<String>());
      displayName = data['name'] as String? ?? displayName;
    } on FormatException {
      _preferences.remove('think.state.v1');
    } on TypeError {
      _preferences.remove('think.state.v1');
    }
  }

  final SharedPreferences _preferences;
  final liked = <String>{};
  final flags = <String, bool>{};
  final quantities = <String, int>{};
  final messages = <String>[];
  final tasks = <String>[];
  String displayName = 'Helena Barnes';
  bool playing = false;
  bool signedIn = false;
  double position = .5;
  bool seeked = false;
  double? checkoutTotal;
  static const cartPrices = {
    '0:3510': 24.99,
    '0:3503': 32.19,
    '0:3496': 49.19,
    '0:3489': 24.99,
  };
  int get cartCount => cartPrices.keys.fold(0, (sum, id) => sum + quantity(id));
  double get cartTotal => cartPrices.entries.fold(
    0,
    (sum, entry) => sum + entry.value * quantity(entry.key),
  );
  void beginCheckout() {
    checkoutTotal = cartTotal;
    notifyListeners();
  }

  void _changed() {
    notifyListeners();
    _preferences.setString(
      'think.state.v1',
      jsonEncode({
        'liked': liked.toList(),
        'flags': flags,
        'quantities': quantities,
        'messages': messages,
        'tasks': tasks,
        'name': displayName,
      }),
    );
  }

  void toggleLike(String id) {
    liked.contains(id) ? liked.remove(id) : liked.add(id);
    _changed();
  }

  void toggleFlag(String id, {bool initial = false}) {
    flags[id] = !(flags[id] ?? initial);
    _changed();
  }

  int quantity(String id) => quantities[id] ?? 1;
  void changeQuantity(String id, int delta) {
    quantities[id] = (quantity(id) + delta).clamp(0, 99);
    _changed();
  }

  void addToCart() {
    quantities['0:3489'] = quantity('0:3489') + 1;
    _changed();
  }

  void sendMessage(String message) {
    if (message.trim().isNotEmpty) {
      messages.add(message.trim());
      _changed();
    }
  }

  void addTask(String task) {
    if (task.trim().isNotEmpty) {
      tasks.add(task.trim());
      _changed();
    }
  }

  void signIn(String name) {
    signedIn = true;
    if (name.trim().isNotEmpty) displayName = name.trim();
    _changed();
  }

  void signOut() {
    signedIn = false;
    _changed();
  }

  void togglePlayer() {
    playing = !playing;
    notifyListeners();
  }

  void seek(double value) {
    position = value;
    seeked = true;
    notifyListeners();
  }
}
