import 'package:intl/intl.dart';

class DateTimeUtils {
  // دالة تنسيق التاريخ للحواجز (معدلة من date_formatter.dart)
  static String formatCheckpointDate(DateTime? dateTime) {
    if (dateTime == null) {
      return 'غير متوفر';
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final checkpointDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    String datePart;
    if (checkpointDate.isAtSameMomentAs(today)) {
      datePart = 'اليوم';
    } else if (checkpointDate.isAtSameMomentAs(yesterday)) {
      datePart = 'أمس';
    } else {
      datePart = DateFormat('yyyy/MM/dd').format(dateTime);
    }

    final timePart = DateFormat('HH:mm').format(dateTime);

    final difference = now.difference(dateTime);
    String relativePart;
    if (difference.inMinutes < 1) {
      relativePart = 'الآن';
    } else if (difference.inHours < 1) {
      relativePart = 'منذ ${difference.inMinutes} دقيقة';
    } else if (difference.inDays < 1) {
      relativePart = 'منذ ${difference.inHours} ساعة';
    } else {
      relativePart = 'منذ ${difference.inDays} يوم';
    }

    return '$datePart الساعة $timePart ($relativePart)';
  }

  // دالة تنسيق التاريخ العامة (من كودك الأصلي)
  static String formatDateTime(String? isoDate) {
    if (isoDate == null) return 'غير متوفر';

    final DateTime dt = DateTime.parse(isoDate).toLocal();
    final now = DateTime.now();

    final isToday = now.day == dt.day && now.month == dt.month && now.year == dt.year;
    final isYesterday = now.subtract(const Duration(days: 1)).day == dt.day &&
        now.month == dt.month && now.year == dt.year;

    final timeStr = DateFormat('HH:mm').format(dt);

    if (isToday) {
      return 'اليوم الساعة $timeStr';
    } else if (isYesterday) {
      return 'أمس الساعة $timeStr';
    } else {
      return DateFormat('yyyy-MM-dd HH:mm').format(dt);
    }
  }

  // دالة تنسيق التاريخ النسبي (من كودك الأصلي)
  static String formatRelativeDateTime(String? isoTime) {
    if (isoTime == null) return '';
    try {
      final dateTime = DateTime.parse(isoTime).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

      final timeFormat = DateFormat('h:mm a', 'ar'); // مثل ١٠:٣٠ ص

      if (messageDate.isAtSameMomentAs(today)) {
        return 'اليوم الساعة ${timeFormat.format(dateTime)}';
      } else if (messageDate.isAtSameMomentAs(today.subtract(const Duration(days: 1)))) {
        return 'أمس الساعة ${timeFormat.format(dateTime)}';
      } else {
        return DateFormat('yyyy-MM-dd - h:mm a', 'ar').format(dateTime);
      }
    } catch (e) {
      return '';
    }
  }
}
