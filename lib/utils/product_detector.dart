import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ProductDetector {
  static const String brandsUrl =
      'https://raw.githubusercontent.com/elia1993/stashly-data/main/brands_github';
  static const String categoriesUrl =
      'https://raw.githubusercontent.com/elia1993/stashly-data/main/categories_github';

  static const String brandsCacheKey = 'cached_brands';
  static const String categoriesCacheKey = 'cached_categories';

  late List<String> _brands;
  late Map<String, String> _categories;

  /// Load and cache brand and category lists from GitHub or local cache
  Future<void> loadData() async {
    final prefs = await SharedPreferences.getInstance();

    try {
      final brandRes = await http.get(Uri.parse(brandsUrl));
      final catRes = await http.get(Uri.parse(categoriesUrl));

      if (brandRes.statusCode == 200 && catRes.statusCode == 200) {
        _brands = List<String>.from(json.decode(utf8.decode(brandRes.bodyBytes)));
        _categories = Map<String, String>.from(json.decode(utf8.decode(catRes.bodyBytes)));

        // Cache them
        await prefs.setString(brandsCacheKey, json.encode(_brands));
        await prefs.setString(categoriesCacheKey, json.encode(_categories));
        return;
      }
    } catch (_) {
      // Ignore errors and try cache
    }

    // Load from cache fallback
    final brandCache = prefs.getString(brandsCacheKey);
    final catCache = prefs.getString(categoriesCacheKey);

    _brands = brandCache != null ? List<String>.from(json.decode(brandCache)) : [];
    _categories = catCache != null ? Map<String, String>.from(json.decode(catCache)) : {};
  }

  /// Detect product info from a scanned string
  Map<String, String> detect(String rawText) {
    final words = rawText.trim().split(RegExp(r'\s+'));

    // Detect brand
    String brand = words.firstWhere(
      (w) => _brands.any((b) => b.toLowerCase() == w.toLowerCase()),
      orElse: () => '',
    );

    // Detect category keyword
    String categoryKeyword = words.firstWhere(
      (w) => _categories.containsKey(w.toLowerCase()),
      orElse: () => '',
    );

    // Build product name (excluding brand if detected)
    String productName = words.where((w) => w != brand).join(' ');

    // Final category match
    String category = _categories[categoryKeyword.toLowerCase()] ?? 'unknown';

    return {
      'brand': brand,
      'product_name': productName.trim(),
      'category': category,
    };
  }
}
