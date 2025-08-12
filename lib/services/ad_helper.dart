import 'dart:io';
import 'package:flutter/foundation.dart';

/// 🔥 فئة مساعدة لإدارة جميع أنواع الإعلانات في التطبيق
/// تحتوي على جميع Ad Unit IDs والدوال المساعدة
class AdHelper {

  // 🔥 App ID الرئيسي (من إعدادات AdMob)
  static String get appId {
    return 'ca-app-pub-8441579772501971~6123201355';
  }

  // 🔥 Banner Ad ID (للإعلانات البانر)
  static String get bannerAdUnitId {
    if (Platform.isAndroid) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/6300978111'  // Test ID
          : 'ca-app-pub-8441579772501971/9416708402'; // Real ID
    } else if (Platform.isIOS) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/2934735716'  // Test ID iOS
          : 'ca-app-pub-8441579772501971/9416708402'; // Real ID iOS (نفس الـ Android أو ID منفصل)
    }
    return 'ca-app-pub-3940256099942544/6300978111'; // Fallback
  }

  // 🔥 Native Ad ID (للإعلانات الأصلية)
  static String get nativeAdUnitId {
    if (Platform.isAndroid) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/2247696110'  // Test ID
          : 'ca-app-pub-8441579772501971/9982555310'; // Real ID
    } else if (Platform.isIOS) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/3986624511'  // Test ID iOS
          : 'ca-app-pub-8441579772501971/9982555310'; // Real ID iOS
    }
    return 'ca-app-pub-3940256099942544/2247696110'; // Fallback
  }

  // 🔥 Rewarded Ad ID (لإعلانات المكافأة - سيتم تحديثه عند الحصول على ID حقيقي)
  static String get rewardedAdUnitId {
    if (Platform.isAndroid) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/5224354917'  // Test ID
          : 'ca-app-pub-8441579772501971/6767769422'; // 🔥 استبدل هذا بالـ ID الحقيقي
    } else if (Platform.isIOS) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/1712485313'  // Test ID iOS
          : 'ca-app-pub-8441579772501971/6767769422'; // iOS ID
    }
    return 'ca-app-pub-3940256099942544/5224354917'; // Fallback
  }

  // 🔥 Interstitial Ad ID (للإعلانات البينية - مستقبلياً)
  static String get interstitialAdUnitId {
    if (Platform.isAndroid) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/1033173712'  // Test ID
          : 'ca-app-pub-8441579772501971/6058959460'; // Real ID
    } else if (Platform.isIOS) {
      return isTestMode
          ? 'ca-app-pub-3940256099942544/4411468910'  // Test ID iOS
          : 'ca-app-pub-8441579772501971/6058959460'; // iOS ID
    }
    return 'ca-app-pub-3940256099942544/1033173712'; // Fallback
  }

  // 🔥 التحقق من وضع التطوير
  static bool get isTestMode {
    // في وضع التطوير (Debug) استخدم Test IDs
    // في وضع الإنتاج (Release) استخدم Real IDs
    return kDebugMode;
  }

  // 🔥 دالة للحصول على Rewarded Ad ID مع إمكانية فرض الاختبار
  static String getRewardedAdId({bool forceTest = false}) {
    if (isTestMode || forceTest) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/5224354917'  // Test Android
          : 'ca-app-pub-3940256099942544/1712485313'; // Test iOS
    }
    return rewardedAdUnitId;
  }

  // 🔥 دالة للحصول على Banner Ad ID
  static String getBannerAdId({bool forceTest = false}) {
    if (isTestMode || forceTest) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/6300978111'  // Test Android
          : 'ca-app-pub-3940256099942544/2934735716'; // Test iOS
    }
    return bannerAdUnitId;
  }

  // 🔥 دالة للحصول على Native Ad ID
  static String getNativeAdId({bool forceTest = false}) {
    if (isTestMode || forceTest) {
      return Platform.isAndroid
          ? 'ca-app-pub-3940256099942544/2247696110'  // Test Android
          : 'ca-app-pub-3940256099942544/3986624511'; // Test iOS
    }
    return nativeAdUnitId;
  }

  // 🔥 دالة للحصول على معلومات النظام
  static Map<String, dynamic> getAdInfo() {
    return {
      'platform': Platform.isAndroid ? 'Android' : 'iOS',
      'isTestMode': isTestMode,
      'appId': appId,
      'rewardedAdId': getRewardedAdId(),
      'bannerAdId': getBannerAdId(),
      'nativeAdId': getNativeAdId(),
    };
  }

  // 🔥 دالة للطباعة معلومات الإعلانات (للتطوير)
  static void printAdInfo() {
    if (!kDebugMode) return;

    print('🔥 === AdHelper Info ===');
    print('Platform: ${Platform.isAndroid ? 'Android' : 'iOS'}');
    print('Test Mode: $isTestMode');
    print('App ID: $appId');
    print('Rewarded ID: ${getRewardedAdId()}');
    print('Banner ID: ${getBannerAdId()}');
    print('Native ID: ${getNativeAdId()}');
    print('🔥 =====================');
  }

  // 🔥 دالة للتحقق من صحة الـ IDs
  static bool validateAdIds() {
    final rewardedId = getRewardedAdId();
    final bannerId = getBannerAdId();
    final nativeId = getNativeAdId();

    // التحقق من أن IDs ليست فارغة وتحتوي على البادئة الصحيحة
    return rewardedId.isNotEmpty &&
        bannerId.isNotEmpty &&
        nativeId.isNotEmpty &&
        rewardedId.startsWith('ca-app-pub-') &&
        bannerId.startsWith('ca-app-pub-') &&
        nativeId.startsWith('ca-app-pub-');
  }
}