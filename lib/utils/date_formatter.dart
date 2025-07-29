import 'package:intl/intl.dart';

class DateFormatter {
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
}
