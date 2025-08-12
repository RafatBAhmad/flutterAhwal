import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart'; // 🔥 إضافة مكتبة المشاركة
import '../models/checkpoint.dart';

class ShareService {

  // مشاركة حالة حاجز واحد
  static Future<void> shareCheckpoint(Checkpoint checkpoint) async {
    final String statusEmoji = _getStatusEmoji(checkpoint.status);
    final String timeAgo = _getTimeAgo(checkpoint.effectiveAtDateTime);

    final String message = '''
🚧 تحديث حالة حاجز

📍 ${checkpoint.name}
🏙️ ${checkpoint.city}
$statusEmoji ${checkpoint.status}
⏰ $timeAgo

📱 تطبيق طريقي - أحوال الطرق
متابعة حالة الحواجز في الوقت الفعلي
    '''.trim();

    await _shareText(message);
  }

  // مشاركة إحصائيات مدينة
  static Future<void> shareCityStats(String cityName, int open, int closed, int congestion) async {
    final String message = '''
📊 إحصائيات حواجز $cityName

✅ سالك: $open
❌ مغلق: $closed
⚠️ ازدحام: $congestion
📈 المجموع: ${open + closed + congestion}

📱 تطبيق طريقي - أحوال الطرق
    '''.trim();

    await _shareText(message);
  }

  // مشاركة التطبيق
  static Future<void> shareApp() async {
    final String message = '''
🚗 تطبيق طريقي - أحوال الطرق

تابع حالة الحواجز والطرق في الوقت الفعلي!

✨ المميزات:
• تحديث تلقائي كل 5 دقائق
• إشعارات للحواجز المفضلة  
• فلترة حسب المدينة والحالة
• وضع ليلي مريح للعينين
• مشاركة سهلة للحواجز

📲 حمّل التطبيق الآن
[رابط التطبيق سيُضاف لاحقاً]

#طريقي #أحوال_الطرق #فلسطين #الحواجز
    '''.trim();

    await _shareText(message);
  }

  // مشاركة قائمة حواجز مفضلة
  static Future<void> shareFavoriteCheckpoints(List<Checkpoint> favorites) async {
    if (favorites.isEmpty) {
      await _shareText('لا توجد حواجز مفضلة حالياً 📱 تطبيق طريقي - أحوال الطرق');
      return;
    }

    final StringBuffer message = StringBuffer();
    message.writeln('⭐ حواجزي المفضلة\n');

    for (final checkpoint in favorites.take(10)) { // أقصى 10 حواجز
      final String statusEmoji = _getStatusEmoji(checkpoint.status);
      final String timeAgo = _getTimeAgo(checkpoint.effectiveAtDateTime);
      message.writeln('📍 ${checkpoint.name}');
      message.writeln('   🏙️ ${checkpoint.city}');
      message.writeln('   $statusEmoji ${checkpoint.status}');
      message.writeln('   ⏰ $timeAgo\n');
    }

    if (favorites.length > 10) {
      message.writeln('... و ${favorites.length - 10} حواجز أخرى\n');
    }

    message.writeln('📱 تطبيق طريقي - أحوال الطرق');

    await _shareText(message.toString());
  }

  // مشاركة إحصائيات شاملة
  static Future<void> shareGeneralStats(int totalCheckpoints, int open, int closed, int congestion) async {
    final String message = '''
📊 إحصائيات شاملة للحواجز

📈 إجمالي الحواجز: $totalCheckpoints

✅ سالك: $open (${totalCheckpoints > 0 ? ((open / totalCheckpoints) * 100).toStringAsFixed(1) : '0.0'}%)
❌ مغلق: $closed (${totalCheckpoints > 0 ? ((closed / totalCheckpoints) * 100).toStringAsFixed(1) : '0.0'}%)
⚠️ ازدحام: $congestion (${totalCheckpoints > 0 ? ((congestion / totalCheckpoints) * 100).toStringAsFixed(1) : '0.0'}%)

⏰ ${DateTime.now().toString().split(' ')[0]}

📱 تطبيق طريقي - أحوال الطرق
    '''.trim();

    await _shareText(message);
  }

  // نسخ نص إلى الحافظة
  static Future<void> copyToClipboard(String text) async {
    await Clipboard.setData(ClipboardData(text: text));
  }

  // مشاركة النص الفعلية
  static Future<void> _shareText(String text) async {
    try {
      if (kIsWeb) {
        // على الويب، نسخ فقط للحافظة
        await copyToClipboard(text);
      } else {
        // 🔥 على المنصات الأخرى، استخدام المشاركة الحقيقية
        await Share.share(
          text,
          subject: 'طريقي - أحوال الطرق',
        );
      }
    } catch (e) {
      // في حالة الفشل، نسخ فقط
      await copyToClipboard(text);
    }
  }

  // مشاركة مع إمكانية اختيار التطبيق
  static Future<void> shareWithOptions(String text, {String? subject}) async {
    try {
      if (kIsWeb) {
        await copyToClipboard(text);
      } else {
        final result = await Share.shareWithResult(
          text,
          subject: subject ?? 'طريقي - أحوال الطرق',
        );

        // يمكن معالجة نتيجة المشاركة هنا
        if (result.status == ShareResultStatus.success) {
          debugPrint('تمت المشاركة بنجاح');
        }
      }
    } catch (e) {
      await copyToClipboard(text);
    }
  }

  // مشاركة مع ملفات (للصور مستقبلاً)
  static Future<void> shareFiles(List<String> paths, {String? text}) async {
    try {
      if (!kIsWeb) {
        await Share.shareXFiles(
          paths.map((path) => XFile(path)).toList(),
          text: text,
          subject: 'طريقي - أحوال الطرق',
        );
      }
    } catch (e) {
      // fallback للنص فقط
      if (text != null) {
        await _shareText(text);
      }
    }
  }

  // الحصول على رمز الحالة
  static String _getStatusEmoji(String status) {
    switch (status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
      case 'سالك':
        return '✅';
      case 'مغلق':
        return '❌';
      case 'ازدحام':
        return '⚠️';
      default:
        return '❓';
    }
  }

  // الحصول على الوقت النسبي
  static String _getTimeAgo(DateTime? dateTime) {
    if (dateTime == null) return 'غير محدد';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'قبل ${difference.inMinutes} دقيقة';
    } else if (difference.inHours < 24) {
      return 'قبل ${difference.inHours} ساعة';
    } else {
      return 'قبل ${difference.inDays} يوم';
    }
  }

  // مشاركة سريعة للحالة فقط
  static Future<void> shareQuickStatus(String checkpointName, String status) async {
    final String statusEmoji = _getStatusEmoji(status);
    final String message = '''
🚧 $checkpointName
$statusEmoji $status

📱 تطبيق طريقي
    '''.trim();

    await _shareText(message);
  }

  // مشاركة مخصصة بنص حر
  static Future<void> shareCustomMessage(String customText) async {
    final String message = '''
$customText

📱 تطبيق طريقي - أحوال الطرق
    '''.trim();

    await _shareText(message);
  }
}