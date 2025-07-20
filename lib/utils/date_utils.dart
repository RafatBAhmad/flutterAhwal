import 'package:intl/intl.dart';


String formatDateTime(String? isoDate) {
  if (isoDate == null) return "غير متوفر";

  final DateTime dt = DateTime.parse(isoDate).toLocal();
  final now = DateTime.now();

  final isToday = now.day == dt.day && now.month == dt.month && now.year == dt.year;
  final isYesterday = now.subtract(Duration(days: 1)).day == dt.day &&
      now.month == dt.month && now.year == dt.year;

  final timeStr = DateFormat('HH:mm').format(dt);

  if (isToday) {
    return "اليوم الساعة $timeStr";
  } else if (isYesterday) {
    return "أمس الساعة $timeStr";
  } else {
    return DateFormat('yyyy-MM-dd HH:mm').format(dt);
  }
}

String formatRelativeDateTime(String? isoTime) {
  if (isoTime == null) return '';
  try {
    final dateTime = DateTime.parse(isoTime).toLocal();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final messageDate = DateTime(dateTime.year, dateTime.month, dateTime.day);

    final timeFormat = DateFormat('h:mm a', 'ar'); // مثل ١٠:٣٠ ص

    if (messageDate == today) {
      return 'اليوم الساعة ${timeFormat.format(dateTime)}';
    } else if (messageDate == today.subtract(Duration(days: 1))) {
      return 'أمس الساعة ${timeFormat.format(dateTime)}';
    } else {
      return DateFormat('yyyy-MM-dd - h:mm a', 'ar').format(dateTime);
    }
  } catch (e) {
    return '';
  }
}
