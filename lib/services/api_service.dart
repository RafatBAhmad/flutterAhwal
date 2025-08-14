import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checkpoint.dart';

class ApiService {
  // 🔥 إعدادات الخادم المحلي
  static const List<String> _baseUrls = [
    'http://192.168.1.105:8081/api/v1/checkpoints',
    'http://localhost:8081/api/v1/checkpoints',
    'http://127.0.0.1:8081/api/v1/checkpoints',
    'http://10.0.2.2:8081/api/v1/checkpoints', // للمحاكي Android
  ];

  static const Duration timeoutDuration = Duration(seconds: 10);
  static String? _cachedWorkingUrl;

  // 🔥 دالة تحديد الخادم المتاح
  static Future<String> _getWorkingBaseUrl() async {
    if (_cachedWorkingUrl != null) {
      return _cachedWorkingUrl!;
    }

    print('🔍 البحث عن خادم متاح...');

    for (String url in _baseUrls) {
      try {
        print('🔄 اختبار: $url');
        final response = await http.get(
          Uri.parse('$url/stats'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 3));

        if (response.statusCode == 200 || response.statusCode == 404) {
          print('✅ خادم متاح للاستخدام: $url');
          _cachedWorkingUrl = url;
          return url;
        } else {
          print('⚠️ استجابة غير متوقعة: ${response.statusCode}');
        }
      } catch (e) {
        print('❌ فشل $url: ${e.toString()}');
        continue;
      }
    }

    print('⚠️ فشلت جميع المحاولات، استخدام الأول كـ fallback');
    _cachedWorkingUrl = _baseUrls.first;
    return _baseUrls.first;
  }

  // 🔥 تتبع التحديثات للإشعارات (بدون تجاهل!)
  static Future<void> _trackCheckpointUpdates(List<Checkpoint> checkpoints) async {
    final prefs = await SharedPreferences.getInstance();

    // جلب آخر تواريخ معروفة للإشعارات
    final lastKnownDates = <String, String>{};
    final storedDates = prefs.getStringList('checkpoint_notification_dates') ?? [];

    for (String stored in storedDates) {
      final parts = stored.split('|');
      if (parts.length == 2) {
        lastKnownDates[parts[0]] = parts[1];
      }
    }

    final updatedDates = <String, String>{};
    int newUpdatesCount = 0;

    for (var checkpoint in checkpoints) {
      final checkpointKey = '${checkpoint.id}_${checkpoint.name}';
      final currentEffectiveAt = checkpoint.effectiveAt;

      if (currentEffectiveAt != null) {
        final lastKnownDate = lastKnownDates[checkpointKey];

        if (lastKnownDate == null) {
          // أول مرة نرى هذا الحاجز
          print('📝 تسجيل حاجز جديد: ${checkpoint.name} - $currentEffectiveAt');
          updatedDates[checkpointKey] = currentEffectiveAt;
        } else if (lastKnownDate != currentEffectiveAt) {
          // تاريخ الحاجز تغير - هذا تحديث حقيقي
          final lastDateTime = DateTime.tryParse(lastKnownDate);
          final currentDateTime = DateTime.tryParse(currentEffectiveAt);

          if (lastDateTime != null && currentDateTime != null) {
            final timeDifference = currentDateTime.difference(lastDateTime);

            print('🔔 تحديث حاجز: ${checkpoint.name}');
            print('   من: $lastKnownDate');
            print('   إلى: $currentEffectiveAt');
            print('   الحالة: ${checkpoint.status}');
            print('   فرق الوقت: ${timeDifference.inHours} ساعة');

            updatedDates[checkpointKey] = currentEffectiveAt;
            newUpdatesCount++;

            // إشعار بالتحديث (إذا مرت أكثر من ساعة)
            if (timeDifference.inHours >= 1) {
              _notifyCheckpointUpdate(checkpoint, lastDateTime, currentDateTime);
            }
          } else {
            updatedDates[checkpointKey] = currentEffectiveAt;
          }
        } else {
          // نفس التاريخ - لا تغيير
          updatedDates[checkpointKey] = lastKnownDate;
        }
      }
    }

    // حفظ التواريخ المحدثة
    final datesToStore = updatedDates.entries.map((e) => '${e.key}|${e.value}').toList();
    await prefs.setStringList('checkpoint_notification_dates', datesToStore);

    if (newUpdatesCount > 0) {
      print('🔔 عدد التحديثات الجديدة: $newUpdatesCount');
    }
    print('💾 تم حفظ ${updatedDates.length} تاريخ حاجز للتتبع');
  }

  // 🔥 إشعار بتحديث الحاجز
  static void _notifyCheckpointUpdate(Checkpoint checkpoint, DateTime oldDate, DateTime newDate) {
    print('📢 حاجز ${checkpoint.name} تم تحديثه');
    print('   الحالة: ${checkpoint.status}');
    print('   التاريخ القديم: ${oldDate.toString()}');
    print('   التاريخ الجديد: ${newDate.toString()}');

    // يمكن إضافة منطق الإشعارات المحلية هنا
    // مثل LocalNotifications أو إرسال broadcast
  }

  // 🔥 دالة fetch محسنة مع logs مفصلة
  static Future<List<Checkpoint>> _fetchCheckpoints(String endpoint) async {
    String baseUrl = await _getWorkingBaseUrl();
    Uri uri = Uri.parse('$baseUrl$endpoint');

    try {
      print('🔄 جلب البيانات من: $uri');

      final stopwatch = Stopwatch()..start();

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          'User-Agent': 'TariqiApp-LocalDev/1.0',
          'Cache-Control': 'no-cache',
        },
      ).timeout(timeoutDuration);

      stopwatch.stop();

      print('📡 Response تم استلامه:');
      print('   Status: ${response.statusCode}');
      print('   Time: ${stopwatch.elapsedMilliseconds}ms');
      print('   Body length: ${response.body.length} characters');
      print('   Content-Type: ${response.headers['content-type']}');

      if (response.statusCode == 200) {
        if (response.body.isEmpty) {
          print('⚠️ تحذير: الاستجابة فارغة');
          return [];
        }

        try {
          final List data = jsonDecode(response.body);
          print('✅ تم تحليل JSON بنجاح: ${data.length} عنصر');

          // طباعة عينة من البيانات للتشخيص
          if (data.isNotEmpty) {
            print('📋 عينة من البيانات الأولى:');
            final sample = data.first;
            print('   Name: ${sample['name']}');
            print('   City: ${sample['city']}');
            print('   Status: ${sample['status']}');
            print('   EffectiveAt: ${sample['effectiveAt']}');
          }

          final checkpoints = data.map((item) => Checkpoint.fromJson(item)).toList();

          // 🔥 تتبع التحديثات للإشعارات فقط (بدون تجاهل!)
          await _trackCheckpointUpdates(checkpoints);

          return checkpoints;
        } catch (jsonError) {
          print('❌ خطأ في تحليل JSON: $jsonError');
          print('📄 أول 300 حرف من الاستجابة:');
          print(response.body.substring(0, response.body.length > 300 ? 300 : response.body.length));
          throw Exception('خطأ في تحليل البيانات: $jsonError');
        }
      } else if (response.statusCode == 404) {
        print('❌ Endpoint غير موجود: $endpoint');
        print('📄 Response body: ${response.body}');
        throw Exception('الخدمة غير متوفرة (404): $endpoint');
      } else if (response.statusCode >= 500) {
        print('🔧 خطأ خادم ${response.statusCode}:');
        print('📄 Error details: ${response.body}');
        throw Exception('خطأ في الخادم المحلي (${response.statusCode})');
      } else {
        print('⚠️ استجابة غير متوقعة ${response.statusCode}:');
        print('📄 Response: ${response.body}');
        throw Exception('خطأ في الاتصال (${response.statusCode})');
      }
    } on SocketException catch (e) {
      print('❌ خطأ شبكة: $e');
      print('💡 تأكد من:');
      print('   - تشغيل Spring Boot على port 8081');
      print('   - اتصال WiFi نشط');
      print('   - إيقاف Firewall أو السماح للـ port');
      throw Exception('لا يمكن الوصول للخادم المحلي. تأكد من تشغيل Backend');
    } on TimeoutException catch (e) {
      print('❌ انتهت مهلة الاتصال: $e');
      throw Exception('انتهت مهلة الاتصال بالخادم المحلي');
    } catch (e) {
      print('❌ خطأ غير متوقع: $e');
      throw Exception('خطأ في الاتصال المحلي: ${e.toString()}');
    }
  }

  // 🔥 استخدام endpoints الصحيحة من Spring Boot

  /// جلب جميع الحواجز مع آخر حالة لكل حاجز
  static Future<List<Checkpoint>> getAllCheckpoints() async {
    print('🔄 [API] جلب جميع الحواجز مع آخر حالة...');
    try {
      return await _fetchCheckpointsWithRetry('/all-sorted');
    } catch (e) {
      print('❌ /all-sorted failed, trying /all...');
      return await _fetchCheckpointsWithRetry('/all');
    }
  }

  /// جلب آخر حالة لكل حاجز (نفس getAllCheckpoints)
  static Future<List<Checkpoint>> getLatestCheckpointsOnly() async {
    print('🔄 [API] جلب آخر حالة الحواجز...');
    return await getAllCheckpoints();
  }

  /// Fallback method للتوافق مع الإصدارات السابقة
  static Future<List<Checkpoint>> fetchLatestOnly() async {
    print('🔄 [API] fetchLatestOnly (fallback)');
    return await getLatestCheckpointsOnly();
  }

  // 🔥 جلب حسب المدينة مع ترتيب
  static Future<List<Checkpoint>> getCheckpointsByCity(String city) async {
    print('🔄 [API] جلب حواجز مدينة: $city');
    try {
      return await _fetchCheckpointsWithRetry('/by-city-sorted?city=${Uri.encodeComponent(city)}');
    } catch (e) {
      print('❌ /by-city-sorted failed, trying /by-city...');
      try {
        return await _fetchCheckpointsWithRetry('/by-city?city=${Uri.encodeComponent(city)}');
      } catch (e2) {
        print('❌ Both city endpoints failed, filtering locally...');
        // fallback: جلب الكل وفلترة محلياً
        final allCheckpoints = await getAllCheckpoints();
        return allCheckpoints.where((cp) => cp.city == city).toList();
      }
    }
  }

  // 🔥 جلب الحواجز المحدثة خلال فترة معينة
  static Future<List<Checkpoint>> getRecentCheckpoints({int days = 2}) async {
    print('🔄 [API] جلب الحواجز المحدثة خلال $days أيام...');
    try {
      return await _fetchCheckpointsWithRetry('/recent?days=$days');
    } catch (e) {
      print('❌ /recent endpoint failed, filtering locally...');
      // fallback: جلب الكل وفلترة محلياً
      final allCheckpoints = await getAllCheckpoints();
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      return allCheckpoints.where((cp) {
        final checkpointDate = cp.effectiveAtDateTime ?? cp.updatedAtDateTime;
        return checkpointDate != null && checkpointDate.isAfter(cutoffDate);
      }).toList();
    }
  }

  // 🔥 جلب حواجز المدينة المحدثة حديثاً
  static Future<List<Checkpoint>> getCityRecentCheckpoints(String city, {int days = 2}) async {
    print('🔄 [API] جلب حواجز مدينة $city المحدثة خلال $days أيام...');
    try {
      return await _fetchCheckpointsWithRetry('/by-city-recent?city=${Uri.encodeComponent(city)}&days=$days');
    } catch (e) {
      print('❌ /by-city-recent failed, filtering locally...');
      // fallback: جلب حواجز المدينة وفلترة محلياً
      final cityCheckpoints = await getCheckpointsByCity(city);
      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      return cityCheckpoints.where((cp) {
        final checkpointDate = cp.effectiveAtDateTime ?? cp.updatedAtDateTime;
        return checkpointDate != null && checkpointDate.isAfter(cutoffDate);
      }).toList();
    }
  }

  // 🔥 جلب قائمة المدن المتاحة
  static Future<List<String>> getAvailableCities() async {
    print('🔄 [API] جلب قائمة المدن...');
    try {
      String baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/cities'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List<dynamic> cities = jsonDecode(response.body);
        return cities.map((city) => city.toString()).toList();
      } else {
        throw Exception('فشل في جلب المدن: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ فشل في جلب المدن، استخدام fallback...');
      // fallback: استخراج المدن من جميع الحواجز
      final allCheckpoints = await getAllCheckpoints();
      final cities = allCheckpoints
          .map((cp) => cp.city)
          .where((city) => city.isNotEmpty && city != "غير معروف")
          .toSet()
          .toList();
      cities.sort();
      return cities;
    }
  }

  // 🔥 جلب إحصائيات الخادم
  static Future<Map<String, dynamic>> getServerStats() async {
    print('🔄 [API] جلب إحصائيات الخادم...');
    try {
      String baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('فشل في جلب الإحصائيات: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ فشل في جلب الإحصائيات: $e');
      return {
        'error': 'فشل في الاتصال بالخادم',
        'details': e.toString(),
      };
    }
  }

  // 🔥 retry محسن للتطوير
  static Future<List<Checkpoint>> _fetchCheckpointsWithRetry(String endpoint, {int maxRetries = 2}) async {
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        print('🔄 محاولة ${attempt + 1}/${maxRetries + 1} لـ $endpoint');
        final result = await _fetchCheckpoints(endpoint);
        print('✅ نجح $endpoint - ${result.length} حاجز');
        return result;
      } catch (e) {
        print('❌ فشلت محاولة ${attempt + 1} لـ $endpoint: $e');

        if (attempt == maxRetries) {
          print('💔 فشلت جميع محاولات $endpoint');
          return _getFallbackData();
        }

        print('⏳ انتظار ${(attempt + 1) * 2} ثواني...');
        await Future.delayed(Duration(seconds: (attempt + 1) * 2));
      }
    }

    return _getFallbackData();
  }

  // 🔥 بيانات احتياطية محسنة للتطوير
  static List<Checkpoint> _getFallbackData() {
    print('🔄 استخدام بيانات احتياطية - الخادم غير متاح');
    final now = DateTime.now();
    return [
      Checkpoint(
        id: 'debug_1',
        name: '🔧 خادم التطوير المحلي غير متاح',
        city: 'تشخيص',
        latitude: 0.0,
        longitude: 0.0,
        status: 'تأكد من تشغيل Spring Boot على المنفذ 8081',
        updatedAt: now.toIso8601String(),
        effectiveAt: now.toIso8601String(),
        sourceText: 'تحقق من:\n1. تشغيل Spring Boot\n2. اتصال الشبكة\n3. إعدادات الـ Firewall',
      ),
      Checkpoint(
        id: 'debug_2',
        name: '💡 نصائح للمطورين',
        city: 'مساعدة',
        latitude: 0.0,
        longitude: 0.0,
        status: 'راجع Console logs للتفاصيل',
        updatedAt: now.toIso8601String(),
        effectiveAt: now.toIso8601String(),
        sourceText: 'تحقق من الـ logs في Flutter console للمزيد من التفاصيل',
      ),
      Checkpoint(
        id: 'debug_3',
        name: '📊 اختبار البيانات',
        city: 'نابلس',
        latitude: 32.2211,
        longitude: 35.2544,
        status: 'سالكة',
        updatedAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
        effectiveAt: now.subtract(const Duration(hours: 2)).toIso8601String(),
        sourceText: 'هذه بيانات تجريبية لاختبار التطبيق',
      ),
    ];
  }

  // 🔥 اختبار شامل للخادم المحلي
  static Future<Map<String, dynamic>> testAllEndpoints() async {
    print('🧪 اختبار جميع endpoints...');

    final String baseUrl = await _getWorkingBaseUrl();
    final endpoints = [
      '/cities',
      '/all',
      '/all-sorted',
      '/by-city?city=نابلس',
      '/by-city-sorted?city=نابلس',
      '/recent?days=2',
      '/by-city-recent?city=نابلس&days=2',
      '/stats',
    ];

    final results = <String, dynamic>{};
    int successCount = 0;

    for (String endpoint in endpoints) {
      try {
        print('🔄 اختبار: $baseUrl$endpoint');

        final response = await http.get(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
        ).timeout(const Duration(seconds: 8));

        final isSuccess = response.statusCode == 200;
        results[endpoint] = {
          'status': response.statusCode,
          'success': isSuccess,
          'body_length': response.body.length,
          'content_type': response.headers['content-type'],
          'response_time': 'OK',
        };

        if (isSuccess) {
          successCount++;
          print('✅ $endpoint -> OK (${response.body.length} chars)');
        } else {
          print('❌ $endpoint -> ${response.statusCode}');
        }

      } catch (e) {
        results[endpoint] = {
          'success': false,
          'error': e.toString(),
          'status': 'TIMEOUT/ERROR',
        };
        print('❌ $endpoint -> ERROR: $e');
      }
    }

    print('📊 نتائج الاختبار: $successCount/${endpoints.length} endpoints تعمل');

    return {
      'server': baseUrl,
      'tested_endpoints': endpoints.length,
      'working_endpoints': successCount,
      'overall_status': successCount >= (endpoints.length * 0.7) ? 'ممتاز' :
      successCount >= (endpoints.length * 0.5) ? 'جيد' : 'يحتاج مراجعة',
      'success_rate': '${((successCount / endpoints.length) * 100).round()}%',
      'results': results.entries.map((e) =>
      '${e.key}: ${e.value['success'] == true ? '✅' : '❌'} ${e.value['status']}'
      ).join('\n'),
      'detailed_results': results,
      'recommendations': _getRecommendations(successCount, endpoints.length),
    };
  }

  static List<String> _getRecommendations(int successCount, int totalEndpoints) {
    final successRate = successCount / totalEndpoints;
    final recommendations = <String>[];

    if (successRate < 0.3) {
      recommendations.addAll([
        'تأكد من تشغيل Spring Boot على المنفذ 8081',
        'تحقق من اتصال الشبكة المحلية',
        'تأكد من عدم حجب Firewall للمنفذ',
      ]);
    } else if (successRate < 0.7) {
      recommendations.addAll([
        'بعض الـ endpoints لا تعمل بشكل صحيح',
        'تحقق من إعدادات قاعدة البيانات',
        'راجع logs الخادم للأخطاء',
      ]);
    } else {
      recommendations.add('الخادم يعمل بشكل ممتاز! ✅');
    }

    return recommendations;
  }

  // 🔥 دوال مساعدة لإدارة الكاش والإعدادات

  /// مسح جميع البيانات المحفوظة محلياً
  static Future<void> clearAllLocalData() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('checkpoint_notification_dates');
    await prefs.remove('cached_checkpoints');
    await prefs.remove('cache_timestamp');
    print('🗑️ تم مسح جميع البيانات المحلية');
  }

  /// إحصائيات الاستخدام
  static Future<Map<String, dynamic>> getUsageStats() async {
    final prefs = await SharedPreferences.getInstance();
    final storedDates = prefs.getStringList('checkpoint_notification_dates') ?? [];

    return {
      'tracked_checkpoints': storedDates.length,
      'cache_available': prefs.containsKey('cached_checkpoints'),
      'last_cache_time': prefs.getString('cache_timestamp'),
      'working_server': _cachedWorkingUrl ?? 'غير محدد',
      'notification_tracking_enabled': storedDates.isNotEmpty,
    };
  }

  /// تصدير/استيراد الإعدادات (للنسخ الاحتياطي)
  static Future<String> exportSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = {
      'checkpoint_notification_dates': prefs.getStringList('checkpoint_notification_dates'),
      'favorites': prefs.getStringList('favorites'),
      'notifications_enabled': prefs.getBool('notifications_enabled'),
      'auto_refresh_enabled': prefs.getBool('auto_refresh_enabled'),
      'show_all_messages': prefs.getBool('show_all_messages'),
      'export_timestamp': DateTime.now().toIso8601String(),
      'app_version': '1.0.0', // يمكن تحديثها
    };

    return jsonEncode(settings);
  }

  static Future<void> importSettings(String settingsJson) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final settings = jsonDecode(settingsJson) as Map<String, dynamic>;

      for (final entry in settings.entries) {
        final key = entry.key;
        final value = entry.value;

        // تخطي بعض الحقول التي لا نريد استيرادها
        if (key == 'export_timestamp' || key == 'app_version') continue;

        if (value is List) {
          final stringList = value.map((e) => e.toString()).toList();
          await prefs.setStringList(key, stringList);
        } else if (value is bool) {
          await prefs.setBool(key, value);
        } else if (value is String) {
          await prefs.setString(key, value);
        } else if (value is int) {
          await prefs.setInt(key, value);
        } else if (value is double) {
          await prefs.setDouble(key, value);
        }
      }

      print('📥 تم استيراد الإعدادات بنجاح');
    } catch (e) {
      print('❌ فشل في استيراد الإعدادات: $e');
      throw Exception('فشل في استيراد الإعدادات: ${e.toString()}');
    }
  }

  /// فحص حالة الاتصال
  static Future<bool> checkConnection() async {
    try {
      final baseUrl = await _getWorkingBaseUrl();
      final response = await http.get(
        Uri.parse('$baseUrl/stats'),
        headers: {'Content-Type': 'application/json'},
      ).timeout(const Duration(seconds: 5));

      return response.statusCode == 200;
    } catch (e) {
      print('❌ فشل فحص الاتصال: $e');
      return false;
    }
  }

  /// إعادة تعيين الخادم المحفوظ
  static void resetCachedServer() {
    _cachedWorkingUrl = null;
    print('🔄 تم إعادة تعيين cache الخادم');
  }

  /// حصول على معلومات الاتصال الحالي
  static Future<Map<String, dynamic>> getConnectionInfo() async {
    final isConnected = await checkConnection();
    final serverUrl = await _getWorkingBaseUrl();

    return {
      'is_connected': isConnected,
      'server_url': serverUrl,
      'cached_server': _cachedWorkingUrl,
      'available_servers': _baseUrls,
      'last_check': DateTime.now().toIso8601String(),
    };
  }

  /// تنظيف البيانات القديمة
  static Future<void> cleanupOldData({int daysToKeep = 30}) async {
    final prefs = await SharedPreferences.getInstance();
    final cutoffDate = DateTime.now().subtract(Duration(days: daysToKeep));

    // تنظيف تواريخ التتبع القديمة
    final storedDates = prefs.getStringList('checkpoint_notification_dates') ?? [];
    final cleanedDates = <String>[];

    for (String stored in storedDates) {
      final parts = stored.split('|');
      if (parts.length == 2) {
        final dateStr = parts[1];
        final date = DateTime.tryParse(dateStr);

        if (date != null && date.isAfter(cutoffDate)) {
          cleanedDates.add(stored);
        }
      }
    }

    await prefs.setStringList('checkpoint_notification_dates', cleanedDates);

    final removedCount = storedDates.length - cleanedDates.length;
    if (removedCount > 0) {
      print('🧹 تم تنظيف $removedCount سجل قديم');
    }
  }

  /// دالة شاملة للصحة العامة للنظام
  static Future<Map<String, dynamic>> getSystemHealth() async {
    final connectionInfo = await getConnectionInfo();
    final usageStats = await getUsageStats();
    final serverStats = await getServerStats();

    return {
      'connection': connectionInfo,
      'usage': usageStats,
      'server': serverStats,
      'system_status': connectionInfo['is_connected'] ? 'صحي' : 'يحتاج فحص',
      'last_health_check': DateTime.now().toIso8601String(),
    };
  }
}