import 'package:flutter/services.dart';
import 'package:vibration/vibration.dart';

class HapticService {
  static bool _isEnabled = true;

  static void setEnabled(bool enabled) {
    _isEnabled = enabled;
  }

  static bool get isEnabled => _isEnabled;

  // اهتزاز خفيف للضغط العادي
  static Future<void> lightTap() async {
    if (!_isEnabled) return;

    try {
      // محاولة استخدام النظام المدمج أولاً
      await HapticFeedback.lightImpact();
    } catch (e) {
      // في حالة الفشل، استخدم مكتبة الاهتزاز
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 50);
      }
    }
  }

  // اهتزاز متوسط للإجراءات المهمة
  static Future<void> mediumTap() async {
    if (!_isEnabled) return;

    try {
      await HapticFeedback.mediumImpact();
    } catch (e) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 100);
      }
    }
  }

  // اهتزاز قوي للإجراءات الحرجة
  static Future<void> heavyTap() async {
    if (!_isEnabled) return;

    try {
      await HapticFeedback.heavyImpact();
    } catch (e) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 200);
      }
    }
  }

  // اهتزاز للتحديد
  static Future<void> selection() async {
    if (!_isEnabled) return;

    try {
      await HapticFeedback.selectionClick();
    } catch (e) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 30);
      }
    }
  }

  // اهتزاز للنجاح
  static Future<void> success() async {
    if (!_isEnabled) return;

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // نمط اهتزاز للنجاح: قصير-توقف-قصير
      Vibration.vibrate(pattern: [0, 100, 50, 100]);
    }
  }

  // اهتزاز للخطأ
  static Future<void> error() async {
    if (!_isEnabled) return;

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // نمط اهتزاز للخطأ: طويل-قصير-طويل
      Vibration.vibrate(pattern: [0, 200, 100, 200]);
    }
  }

  // اهتزاز للتنبيه
  static Future<void> notification() async {
    if (!_isEnabled) return;

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      // نمط اهتزاز للتنبيه: ثلاث نبضات سريعة
      Vibration.vibrate(pattern: [0, 50, 50, 50, 50, 50]);
    }
  }

  // اهتزاز مخصص
  static Future<void> customVibrate(List<int> pattern) async {
    if (!_isEnabled) return;

    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(pattern: pattern);
    }
  }
}