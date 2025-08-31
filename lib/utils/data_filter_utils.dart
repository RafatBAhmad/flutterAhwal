import '../models/checkpoint.dart';

/// فئة للتحكم بفلترة البيانات حسب التاريخ وإخفاء البيانات القديمة
class DataFilterUtils {
  /// فلترة الحواجز التي تم تحديثها خلال فترة معينة
  /// [checkpoints] قائمة الحواجز
  /// [maxHours] الحد الأقصى بالساعات (افتراضي: 48 ساعة)
  static List<Checkpoint> filterRecentCheckpoints(
    List<Checkpoint> checkpoints, {
    int maxHours = 48,
  }) {
    if (checkpoints.isEmpty || maxHours <= 0) {
      return checkpoints;
    }

    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(hours: maxHours));

    return checkpoints.where((checkpoint) {
      // استخدام effectiveAt أو updatedAt أيهما متوفر
      DateTime? checkpointDate = checkpoint.effectiveAtDateTime ??
          checkpoint.updatedAtDateTime;

      if (checkpointDate == null) {
        // إذا لم يكن هناك تاريخ، نعتبر البيان قديم ولا نعرضه
        return false;
      }

      // إرجاع true إذا كان التاريخ أحدث من cutoffDate
      return checkpointDate.isAfter(cutoffDate);
    }).toList();
  }

  /// فحص ما إذا كان الحاجز محدث حديثاً (خلال 48 ساعة)
  static bool isCheckpointRecent(Checkpoint checkpoint, {int maxHours = 48}) {
    final now = DateTime.now();
    final cutoffDate = now.subtract(Duration(hours: maxHours));
    
    DateTime? checkpointDate = checkpoint.effectiveAtDateTime ??
        checkpoint.updatedAtDateTime;
    
    if (checkpointDate == null) return false;
    return checkpointDate.isAfter(cutoffDate);
  }

  /// حساب عمر البيان بالأيام
  static int getCheckpointAgeInDays(Checkpoint checkpoint) {
    DateTime? checkpointDate = checkpoint.effectiveAtDateTime ??
        checkpoint.updatedAtDateTime;
    
    if (checkpointDate == null) return -1; // قيمة خاصة للبيانات بدون تاريخ
    
    final now = DateTime.now();
    return now.difference(checkpointDate).inDays;
  }

  /// حساب عمر البيان بالساعات
  static int getCheckpointAgeInHours(Checkpoint checkpoint) {
    DateTime? checkpointDate = checkpoint.effectiveAtDateTime ??
        checkpoint.updatedAtDateTime;
    
    if (checkpointDate == null) return -1;
    
    final now = DateTime.now();
    return now.difference(checkpointDate).inHours;
  }

  /// فلترة الحواجز حسب المدينة مع إزالة البيانات القديمة
  static List<Checkpoint> filterByCityAndRecent(
    List<Checkpoint> checkpoints,
    String? selectedCity, {
    int maxHours = 48,
  }) {
    // أولاً فلترة البيانات الحديثة
    List<Checkpoint> recentCheckpoints = filterRecentCheckpoints(
      checkpoints,
      maxHours: maxHours,
    );

    // ثم فلترة حسب المدينة إذا كانت محددة
    if (selectedCity == null || selectedCity == "الكل" || selectedCity.isEmpty) {
      return recentCheckpoints;
    }

    return recentCheckpoints
        .where((checkpoint) => checkpoint.city == selectedCity)
        .toList();
  }

  /// إحصائيات البيانات المفلترة
  static Map<String, int> getFilterStatistics(
    List<Checkpoint> originalCheckpoints, {
    int maxHours = 48,
  }) {
    final recentCheckpoints = filterRecentCheckpoints(
      originalCheckpoints,
      maxHours: maxHours,
    );

    return {
      'total': originalCheckpoints.length,
      'recent': recentCheckpoints.length,
      'filtered_out': originalCheckpoints.length - recentCheckpoints.length,
      'max_hours': maxHours,
    };
  }

  /// تصنيف البيانات حسب العمر
  static Map<String, List<Checkpoint>> categorizeByAge(
    List<Checkpoint> checkpoints
  ) {
    final Map<String, List<Checkpoint>> categories = {
      'recent': [], // خلال 48 ساعة
      'old': [], // أكثر من 48 ساعة
      'unknown': [], // بدون تاريخ
    };

    for (final checkpoint in checkpoints) {
      if (isCheckpointRecent(checkpoint)) {
        categories['recent']!.add(checkpoint);
      } else if (getCheckpointAgeInDays(checkpoint) == -1) {
        categories['unknown']!.add(checkpoint);
      } else {
        categories['old']!.add(checkpoint);
      }
    }

    return categories;
  }

  /// رسالة توضيحية لحالة الفلترة
  static String getFilterMessage(
    int originalCount,
    int filteredCount, {
    int maxHours = 48,
  }) {
    final hiddenCount = originalCount - filteredCount;
    
    if (hiddenCount == 0) {
      return "جميع البيانات حديثة";
    }
    
    return "تم إخفاء $hiddenCount حاجز (أقدم من $maxHours ساعة)";
  }

  /// فحص ما إذا كانت الفلترة نشطة
  static bool isFilteringActive(
    List<Checkpoint> originalCheckpoints, {
    int maxHours = 48,
  }) {
    final stats = getFilterStatistics(originalCheckpoints, maxHours: maxHours);
    return stats['filtered_out']! > 0;
  }
}