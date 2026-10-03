import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/quote.dart';

/// Autoguardado local de borradores de cotización (reanudables).
class QuoteDraftStore {
  QuoteDraftStore._();
  static final QuoteDraftStore instance = QuoteDraftStore._();

  String _key(String uid) => 'cotiapp_quote_draft_$uid';

  Future<void> save(String uid, Quote quote) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(uid), jsonEncode(quote.toMap()));
  }

  Future<Quote?> load(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(uid));
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      return Quote.fromMap(map);
    } catch (_) {
      return null;
    }
  }

  Future<void> clear(String uid) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(uid));
  }
}
