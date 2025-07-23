import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/checkpoint.dart';
import 'dart:io'; // For SocketException
import 'dart:async'; // For TimeoutException

class ApiService {
  // static const String baseUrl = 'https://ahwal-checkpoints-api.onrender.com/api/v1/checkpoints';
  static const String baseUrl = 'http://192.168.1.101:8081/api/v1/checkpoints';

  static const Duration timeoutDuration = Duration(seconds: 10); // Define a timeout duration

  // Helper function to handle API calls and errors
  static Future<List<Checkpoint>> _fetchCheckpoints(Uri uri) async {
    try {
      final response = await http.get(uri).timeout(timeoutDuration);

      if (response.statusCode == 200) {
        final List data = jsonDecode(response.body);
        return data.map((item) => Checkpoint.fromJson(item)).toList();
      } else if (response.statusCode >= 400 && response.statusCode < 500) {
        throw Exception('خطأ في طلب البيانات: ${response.statusCode} - ${response.body}');
      } else if (response.statusCode >= 500) {
        throw Exception('خطأ في الخادم: ${response.statusCode} - ${response.body}');
      }
      throw Exception('فشل في جلب البيانات: ${response.statusCode}');
    } on SocketException {
      throw Exception('لا يوجد اتصال بالإنترنت. يرجى التحقق من اتصالك.');
    } on TimeoutException {
      throw Exception('انتهت مهلة الاتصال بالخادم. يرجى المحاولة مرة أخرى.');
    } on FormatException {
      throw Exception('خطأ في تنسيق البيانات المستلمة من الخادم.');
    } catch (e) {
      throw Exception('حدث خطأ غير متوقع: $e');
    }
  }

  // لجلب كل الحواجز
  static Future<List<Checkpoint>> getAllCheckpoints() async {
    return _fetchCheckpoints(Uri.parse('$baseUrl/all'));
  }

  // لجلب الحواجز حسب المدينة
  static Future<List<Checkpoint>> getCheckpointsByCity(String city) async {
    return _fetchCheckpoints(Uri.parse('$baseUrl/by-city?city=$city'));
  }
}


