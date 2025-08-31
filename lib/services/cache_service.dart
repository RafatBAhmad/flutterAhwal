import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checkpoint.dart';

class CacheService {
  static const String _checkpointsKey = 'cached_checkpoints';
  static const String _lastUpdateKey = 'last_update_time';
  static const String _lastFetchAttemptKey = 'last_fetch_attempt_time';
  static const String _appUsageKey = 'app_usage_stats';
  static const String _searchHistoryKey = 'search_history';

  // مدة انتهاء صلاحية الكاش (10 دقائق لتوازن أفضل بين الأداء والحداثة)
  static const Duration _cacheExpiration = Duration(minutes: 10);

  // حفظ الحواجز في الكاش
  static Future<void> cacheCheckpoints(List<Checkpoint> checkpoints) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final checkpointsJson = checkpoints.map((cp) => {
        'id': cp.id,
        'name': cp.name,
        'city': cp.city,
        'latitude': cp.latitude,
        'longitude': cp.longitude,
        'status': cp.status,
        'updatedAt': cp.updatedAt,
        'effectiveAt': cp.effectiveAt,
        'sourceText': cp.sourceText,
      }).toList();

      await prefs.setString(_checkpointsKey, jsonEncode(checkpointsJson));
      await prefs.setString(_lastUpdateKey, DateTime.now().toIso8601String());
      await prefs.setString(_lastFetchAttemptKey, DateTime.now().toIso8601String());
    } catch (e) {
      // في حالة الفشل، لا نفعل شيء
    }
  }

  // استرجاع الحواجز من الكاش
  static Future<List<Checkpoint>?> getCachedCheckpoints() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final cachedData = prefs.getString(_checkpointsKey);
      final lastUpdateStr = prefs.getString(_lastUpdateKey);

      if (cachedData == null || lastUpdateStr == null) return null;

      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();

      // التحقق من انتهاء صلاحية الكاش
      if (now.difference(lastUpdate) > _cacheExpiration) {
        return null;
      }

      final List<dynamic> jsonList = jsonDecode(cachedData);
      return jsonList.map((json) => Checkpoint.fromJson(json)).toList();
    } catch (e) {
      return null;
    }
  }

  // حفظ وقت آخر محاولة استعلام (حتى لو فشلت)
  static Future<void> updateLastFetchAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_lastFetchAttemptKey, DateTime.now().toIso8601String());
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // الحصول على وقت آخر محاولة استعلام
  static Future<DateTime?> getLastFetchAttempt() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastFetchStr = prefs.getString(_lastFetchAttemptKey);
      if (lastFetchStr != null) {
        return DateTime.parse(lastFetchStr);
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // التحقق من وجود كاش صالح
  static Future<bool> hasFreshCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final lastUpdateStr = prefs.getString(_lastUpdateKey);

      if (lastUpdateStr == null) return false;

      final lastUpdate = DateTime.parse(lastUpdateStr);
      final now = DateTime.now();

      return now.difference(lastUpdate) <= _cacheExpiration;
    } catch (e) {
      return false;
    }
  }

  // حفظ إحصائيات الاستخدام
  static Future<void> updateUsageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stats = await getUsageStats();

      stats['appOpenCount'] = (stats['appOpenCount'] ?? 0) + 1;
      stats['lastUsed'] = DateTime.now().toIso8601String();
      stats['totalUsageTime'] = stats['totalUsageTime'] ?? 0;

      await prefs.setString(_appUsageKey, jsonEncode(stats));
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // الحصول على إحصائيات الاستخدام
  static Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final statsStr = prefs.getString(_appUsageKey);

      if (statsStr == null) {
        return {
          'appOpenCount': 0,
          'totalUsageTime': 0,
          'lastUsed': null,
          'favoriteSearches': <String>[],
          'mostViewedCities': <String, int>{},
        };
      }

      return Map<String, dynamic>.from(jsonDecode(statsStr));
    } catch (e) {
      return {
        'appOpenCount': 0,
        'totalUsageTime': 0,
        'lastUsed': null,
        'favoriteSearches': <String>[],
        'mostViewedCities': <String, int>{},
      };
    }
  }

  // حفظ تاريخ البحث
  static Future<void> addToSearchHistory(String searchTerm) async {
    try {
      if (searchTerm.trim().isEmpty) return;

      final prefs = await SharedPreferences.getInstance();
      final history = await getSearchHistory();

      // إزالة المصطلح إذا كان موجوداً مسبقاً
      history.remove(searchTerm);

      // إضافة المصطلح في المقدمة
      history.insert(0, searchTerm);

      // الاحتفاظ بأحدث 20 بحث فقط
      if (history.length > 20) {
        history.removeRange(20, history.length);
      }

      await prefs.setStringList(_searchHistoryKey, history);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // الحصول على تاريخ البحث
  static Future<List<String>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_searchHistoryKey) ?? [];
    } catch (e) {
      return [];
    }
  }

  // مسح تاريخ البحث
  static Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // تسجيل زيارة مدينة
  static Future<void> trackCityView(String cityName) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final stats = await getUsageStats();

      Map<String, int> mostViewedCities = Map<String, int>.from(
          stats['mostViewedCities'] ?? {}
      );

      mostViewedCities[cityName] = (mostViewedCities[cityName] ?? 0) + 1;
      stats['mostViewedCities'] = mostViewedCities;

      await prefs.setString(_appUsageKey, jsonEncode(stats));
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // الحصول على أكثر المدن زيارة
  static Future<List<MapEntry<String, int>>> getMostViewedCities() async {
    try {
      final stats = await getUsageStats();
      final Map<String, int> cities = Map<String, int>.from(
          stats['mostViewedCities'] ?? {}
      );

      final sortedCities = cities.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedCities.take(5).toList();
    } catch (e) {
      return [];
    }
  }

  // مسح الكاش
  static Future<void> clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_checkpointsKey);
      await prefs.remove(_lastUpdateKey);
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // مسح جميع البيانات المحفوظة
  static Future<void> clearAllData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // حفظ إعدادات الألوان المخصصة
  static Future<void> saveCustomColors(Map<String, int> colors) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('custom_colors', jsonEncode(colors));
    } catch (e) {
      // تجاهل الأخطاء
    }
  }

  // الحصول على الألوان المخصصة
  static Future<Map<String, int>> getCustomColors() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final colorsStr = prefs.getString('custom_colors');

      if (colorsStr == null) {
        return {
          'openColor': 0xFF4CAF50,   // أخضر
          'closedColor': 0xFFF44336, // أحمر
          'congestionColor': 0xFFFF9800, // برتقالي
          'checkpointColor': 0xFF9C27B0, // بنفسجي
        };
      }

      return Map<String, int>.from(jsonDecode(colorsStr));
    } catch (e) {
      return {
        'openColor': 0xFF4CAF50,
        'closedColor': 0xFFF44336,
        'congestionColor': 0xFFFF9800,
        'checkpointColor': 0xFF9C27B0,
      };
    }
  }
}