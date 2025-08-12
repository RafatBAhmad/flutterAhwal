import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/checkpoint.dart';
import 'dart:io';
import 'dart:async';
import '../models/city_summary.dart';

class ApiService {
  // 🔥 إضافة fallback URLs متعددة
  static const List<String> _baseUrls = [
    'https://backendspringboot-production-46d6.up.railway.app/api/v1/checkpoints',
    'https://ahwal-checkpoints-api.onrender.com/api/v1/checkpoints', // backup
  ];

  static const Duration timeoutDuration = Duration(seconds: 15); // زيادة المهلة

  // 🔥 دالة اختيار URL صالح
  static Future<String> _getWorkingBaseUrl() async {
    for (String url in _baseUrls) {
      try {
        final response = await http.get(
          Uri.parse('$url/cities'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 5));

        if (response.statusCode == 200 || response.statusCode == 404) {
          print('✅ Using working URL: $url');
          return url;
        }
      } catch (e) {
        print('❌ URL failed: $url - $e');
        continue;
      }
    }

    // إذا فشلت جميع URLs، استخدم الأول كـ fallback
    print('⚠️ All URLs failed, using first as fallback');
    return _baseUrls.first;
  }

  // 🔥 دالة محسنة لمعالجة API calls
  static Future<List<Checkpoint>> _fetchCheckpoints(String endpoint) async {
    String baseUrl = await _getWorkingBaseUrl();
    Uri uri = Uri.parse('$baseUrl$endpoint');

    try {
      print('🔄 Fetching from: $uri');

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'TariqiApp/1.0',
        },
      ).timeout(timeoutDuration);

      print('📡 Response status: ${response.statusCode}');
      print('📡 Response body length: ${response.body.length}');

      if (response.statusCode == 200) {
        try {
          final List data = jsonDecode(response.body);
          return data.map((item) => Checkpoint.fromJson(item)).toList();
        } catch (jsonError) {
          print('❌ JSON Parse Error: $jsonError');
          throw Exception('خطأ في تحليل البيانات من الخادم');
        }
      } else if (response.statusCode == 404) {
        throw Exception('الخدمة غير متوفرة حالياً (404)');
      } else if (response.statusCode >= 500) {
        print('🔧 Server Error ${response.statusCode}: ${response.body}');
        throw Exception('خطأ في الخادم (${response.statusCode}). يرجى المحاولة لاحقاً');
      } else {
        throw Exception('خطأ في الاتصال (${response.statusCode})');
      }
    } on SocketException {
      throw Exception('لا يوجد اتصال بالإنترنت. تحقق من اتصالك');
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال. تحقق من سرعة الإنترنت');
    } on FormatException catch (e) {
      print('❌ Format Error: $e');
      throw Exception('خطأ في تنسيق البيانات');
    } catch (e) {
      print('❌ Unexpected Error: $e');
      throw Exception('حدث خطأ غير متوقع: ${e.toString()}');
    }
  }

  // 🔥 جلب جميع الرسائل والتحديثات مع retry
  static Future<List<Checkpoint>> getAllCheckpoints() async {
    return await _fetchCheckpointsWithRetry('/all-messages?limit=500&days=7');
  }

  // 🔥 جلب آخر حالة فقط لكل حاجز
  static Future<List<Checkpoint>> getLatestCheckpointsOnly() async {
    return await _fetchCheckpointsWithRetry('/latest-only');
  }

  // 🔥 دالة retry للحصول على البيانات
  static Future<List<Checkpoint>> _fetchCheckpointsWithRetry(String endpoint, {int maxRetries = 2}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await _fetchCheckpoints(endpoint);
      } catch (e) {
        print('❌ Attempt ${attempt + 1} failed: $e');

        if (attempt == maxRetries) {
          // في المحاولة الأخيرة، أرجع بيانات وهمية إذا فشل كل شيء
          return _getFallbackData();
        }

        // انتظار قبل إعادة المحاولة
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }

    return _getFallbackData();
  }

  // 🔥 بيانات احتياطية في حالة فشل جميع الطلبات
  static List<Checkpoint> _getFallbackData() {
    print('🔄 Using fallback data');
    return [
      Checkpoint(
        id: 'fallback_1',
        name: 'خدمة البيانات مؤقتاً غير متاحة',
        city: 'عذراً',
        latitude: 0.0,
        longitude: 0.0,
        status: 'يرجى المحاولة لاحقاً',
        updatedAt: DateTime.now().toIso8601String(),
        effectiveAt: DateTime.now().toIso8601String(),
        sourceText: 'تحقق من اتصال الإنترنت وأعد المحاولة',
      ),
    ];
  }

  // 🔥 دوال أخرى محدثة
  static Future<List<Checkpoint>> getAllMessages({int limit = 500, int days = 7}) async {
    return await _fetchCheckpointsWithRetry('/all-messages?limit=$limit&days=$days');
  }

  static Future<List<Checkpoint>> fetchAllMessages() async {
    return getAllMessages();
  }

  static Future<List<Checkpoint>> fetchLatestOnly() async {
    return getLatestCheckpointsOnly();
  }

  // 🔥 جلب الحواجز حسب المدينة مع معالجة أفضل
  static Future<List<Checkpoint>> getCheckpointsByCity(String city) async {
    try {
      return await _fetchCheckpointsWithRetry('/by-city?city=${Uri.encodeComponent(city)}');
    } catch (e) {
      // في حالة فشل endpoint المدينة، جلب الكل وفلترة محلياً
      final allCheckpoints = await getLatestCheckpointsOnly();
      return allCheckpoints.where((cp) => cp.city == city).toList();
    }
  }

  // 🔥 إحصائيات محسنة مع fallback
  static Future<Map<String, dynamic>> getStats() async {
    try {
      String baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return Map<String, dynamic>.from(jsonDecode(response.body));
      }
    } catch (e) {
      print('❌ Stats API failed: $e');
    }

    // حساب الإحصائيات محلياً
    try {
      final checkpoints = await getLatestCheckpointsOnly();
      return _calculateLocalStats(checkpoints);
    } catch (e) {
      return _getDefaultStats();
    }
  }

  static Map<String, dynamic> _calculateLocalStats(List<Checkpoint> checkpoints) {
    int open = 0, closed = 0, congestion = 0;

    for (final cp in checkpoints) {
      final status = cp.status.toLowerCase();
      if (status.contains('مفتوح') || status.contains('سالك')) {
        open++;
      } else if (status.contains('مغلق')) {
        closed++;
      } else if (status.contains('ازدحام')) {
        congestion++;
      }
    }

    return {
      'totalCheckpoints': checkpoints.length,
      'statusDistribution': {
        'open': open,
        'closed': closed,
        'congestion': congestion,
        'unknown': checkpoints.length - open - closed - congestion,
      },
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  static Map<String, dynamic> _getDefaultStats() {
    return {
      'totalCheckpoints': 0,
      'statusDistribution': {'open': 0, 'closed': 0, 'congestion': 0, 'unknown': 0},
      'lastUpdated': DateTime.now().toIso8601String(),
    };
  }

  // 🔥 قائمة المدن المتاحة مع fallback
  static Future<List<String>> getAvailableCities() async {
    try {
      String baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/cities'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> cities = jsonDecode(response.body);
        return cities.map((city) => city.toString()).toList();
      }
    } catch (e) {
      print('❌ Cities API failed: $e');
    }

    // حساب المدن محلياً
    try {
      final checkpoints = await getLatestCheckpointsOnly();
      return checkpoints
          .map((cp) => cp.city)
          .where((city) => city.isNotEmpty && city != "غير معروف")
          .toSet()
          .toList()..sort();
    } catch (e) {
      return ['القدس', 'رام الله', 'نابلس', 'الخليل', 'بيت لحم']; // قائمة افتراضية
    }
  }

  // 🔥 اختبار الاتصال المحسن
  static Future<bool> testConnection() async {
    try {
      String baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/cities'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 10));

      return response.statusCode == 200 || response.statusCode == 404;
    } catch (e) {
      print('❌ Connection test failed: $e');
      return false;
    }
  }

  // 🔥 معلومات صحة API محسنة
  static Future<Map<String, dynamic>> getApiHealth() async {
    try {
      final isConnected = await testConnection();
      if (!isConnected) {
        return {
          'status': 'disconnected',
          'error': 'لا يمكن الاتصال بالخادم',
          'lastCheck': DateTime.now().toIso8601String(),
        };
      }

      final stats = await getStats();
      final cities = await getAvailableCities();

      return {
        'status': 'healthy',
        'totalCheckpoints': stats['totalCheckpoints'] ?? 0,
        'totalCities': cities.length,
        'lastCheck': DateTime.now().toIso8601String(),
        'endpoints': {
          'latest': 'متاح',
          'allMessages': 'متاح',
          'byCity': 'متاح',
          'stats': 'متاح',
        },
      };
    } catch (e) {
      return {
        'status': 'error',
        'error': e.toString(),
        'lastCheck': DateTime.now().toIso8601String(),
      };
    }
  }
}