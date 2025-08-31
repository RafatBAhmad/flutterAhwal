/// إدارة إعدادات الإعلانات في التطبيق
class AdsConfig {
  /// 🔥 مفتاح تحكم رئيسي لتفعيل/تعطيل جميع الإعلانات
  /// 
  /// للتفعيل: غير القيمة إلى true
  /// للتعطيل: غير القيمة إلى false
  /// 
  /// التاريخ: 29 أغسطس 2025 - تم تعطيل الإعلانات بسبب تعليق AdMob
  /// التفعيل المتوقع: 27 سبتمبر 2025 (بعد انتهاء فترة التعليق)
  static const bool _adsEnabled = false; // 🚫 معطل حالياً بسبب تعليق AdMob لمدة 29 يوم
  
  /// فحص ما إذا كانت الإعلانات مفعلة
  static bool get adsEnabled => _adsEnabled;
  
  /// رسالة توضيحية لحالة الإعلانات
  static String get statusMessage {
    if (_adsEnabled) {
      return "الإعلانات مفعلة";
    } else {
      return "الإعلانات معطلة مؤقتاً";
    }
  }
  
  /// فحص ما إذا كان يجب عرض إعلان في موقع معين
  static bool shouldShowAd({String? adLocation}) {
    if (!_adsEnabled) return false;
    
    // يمكن إضافة منطق إضافي هنا للتحكم بأماكن محددة
    // مثلاً: إيقاف الإعلانات في صفحة معينة فقط
    switch (adLocation) {
      case 'home_screen':
        return true;
      case 'native_ad':
        return true;
      default:
        return true;
    }
  }
  
  /// رسالة للمطورين عن حالة الإعلانات
  static String get devMessage {
    if (_adsEnabled) {
      return "✅ الإعلانات مفعلة - ستظهر للمستخدمين";
    } else {
      return "🚫 الإعلانات معطلة - لن تظهر للمستخدمين";
    }
  }
}

/// تواريخ مهمة للإعلانات (للمرجع)
class AdsTimeline {
  /// تاريخ تعليق AdMob
  static const String suspensionDate = "2025-08-29";
  
  /// تاريخ انتهاء التعليق المتوقع (29 يوم)
  static const String expectedReactivationDate = "2025-09-27";
  
  /// ملاحظة للمطور
  static const String note = """
  تم تعليق حساب AdMob لمدة 29 يوم بسبب النقرات الذاتية.
  يجب تفعيل الإعلانات مرة أخرى في $expectedReactivationDate
  عن طريق تغيير AdsConfig._adsEnabled إلى true
  """;
}