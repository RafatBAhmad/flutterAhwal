import '../models/checkpoint.dart';

/// Utility class لحساب إحصائيات الحواجز بطريقة موحدة
class CheckpointStatisticsUtils {

  /// تصنيف الحالات المختلفة للحواجز
  static const Map<String, CheckpointStatusCategory> _statusMapping = {
    'مفتوح': CheckpointStatusCategory.open,
    'سالك': CheckpointStatusCategory.open,
    'سالكة': CheckpointStatusCategory.open,
    'سالكه': CheckpointStatusCategory.open,
    'مغلق': CheckpointStatusCategory.closed,
    'ازدحام': CheckpointStatusCategory.congestion,
    'حاجز': CheckpointStatusCategory.checkpoint,
  };

  /// تحديد فئة الحالة بناءً على النص
  static CheckpointStatusCategory getStatusCategory(String status) {
    final normalizedStatus = status.toLowerCase().trim();

    // البحث المباشر أولاً
    if (_statusMapping.containsKey(normalizedStatus)) {
      return _statusMapping[normalizedStatus]!;
    }

    // البحث بالاحتواء للحالات المركبة
    for (final entry in _statusMapping.entries) {
      if (normalizedStatus.contains(entry.key)) {
        return entry.value;
      }
    }

    return CheckpointStatusCategory.unknown;
  }

  /// حساب إحصائيات مجموعة من الحواجز
  static CheckpointStatistics calculateStatistics(List<Checkpoint> checkpoints) {
    int openCount = 0;
    int closedCount = 0;
    int congestionCount = 0;
    int checkpointCount = 0;
    int unknownCount = 0;

    for (final checkpoint in checkpoints) {
      switch (getStatusCategory(checkpoint.status)) {
        case CheckpointStatusCategory.open:
          openCount++;
          break;
        case CheckpointStatusCategory.closed:
          closedCount++;
          break;
        case CheckpointStatusCategory.congestion:
          congestionCount++;
          break;
        case CheckpointStatusCategory.checkpoint:
          checkpointCount++;
          break;
        case CheckpointStatusCategory.unknown:
          unknownCount++;
          break;
      }
    }

    return CheckpointStatistics(
      total: checkpoints.length,
      open: openCount,
      closed: closedCount,
      congestion: congestionCount,
      checkpoint: checkpointCount,
      unknown: unknownCount,
    );
  }

  /// حساب إحصائيات مجمعة حسب المدينة
  static Map<String, CheckpointStatistics> calculateStatisticsByCity(
      List<Checkpoint> checkpoints) {
    final Map<String, List<Checkpoint>> checkpointsByCity = {};

    // تجميع الحواجز حسب المدينة
    for (final checkpoint in checkpoints) {
      final city = checkpoint.city == "غير معروف" ? "أخرى" : checkpoint.city;
      checkpointsByCity[city] = checkpointsByCity[city] ?? [];
      checkpointsByCity[city]!.add(checkpoint);
    }

    // حساب الإحصائيات لكل مدينة
    final Map<String, CheckpointStatistics> result = {};
    for (final entry in checkpointsByCity.entries) {
      result[entry.key] = calculateStatistics(entry.value);
    }

    return result;
  }

  /// فلترة الحواجز حسب المدينة
  static List<Checkpoint> filterByCity(List<Checkpoint> checkpoints, String? selectedCity) {
    if (selectedCity == null || selectedCity == "الكل") {
      return checkpoints;
    }
    return checkpoints.where((cp) => cp.city == selectedCity).toList();
  }

  /// الحصول على قائمة المدن المتاحة
  static List<String> getAvailableCities(List<Checkpoint> checkpoints) {
    final citySet = checkpoints
        .map((cp) => cp.city)
        .where((city) => city != "غير معروف")
        .toSet();

    final cities = ["الكل", ...citySet.toList()];
    cities.sort();
    return cities;
  }
}

/// تصنيف حالات الحواجز
enum CheckpointStatusCategory {
  open,      // مفتوح/سالك
  closed,    // مغلق
  congestion, // ازدحام
  checkpoint, // حاجز
  unknown,   // غير معروف
}

/// كلاس لتخزين إحصائيات الحواجز
class CheckpointStatistics {
  final int total;
  final int open;
  final int closed;
  final int congestion;
  final int checkpoint;
  final int unknown;

  const CheckpointStatistics({
    required this.total,
    required this.open,
    required this.closed,
    required this.congestion,
    required this.checkpoint,
    required this.unknown,
  });

  @override
  String toString() {
    return 'CheckpointStatistics(total: $total, open: $open, closed: $closed, congestion: $congestion, checkpoint: $checkpoint, unknown: $unknown)';
  }

  /// تحويل إلى Map للتصدير
  Map<String, dynamic> toMap() {
    return {
      'total': total,
      'open': open,
      'closed': closed,
      'congestion': congestion,
      'checkpoint': checkpoint,
      'unknown': unknown,
    };
  }
}

