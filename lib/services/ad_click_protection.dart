import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to protect against excessive ad clicks that could trigger Google AdMob violations
class AdClickProtection {
  static const String _clickCountKey = 'ad_click_count';
  static const String _lastResetKey = 'ad_last_reset';
  static const String _firstClickKey = 'ad_first_click';
  
  // Protection thresholds
  static const int maxClicksPerHour = 5;       // Maximum clicks per hour
  static const int maxClicksPerDay = 20;       // Maximum clicks per day
  static const int clickCooldownSeconds = 30;  // Minimum time between clicks
  
  static DateTime? _lastClickTime;
  static int _sessionClicks = 0;
  static Timer? _resetTimer;

  /// Check if user can click on ads
  static Future<bool> canClickAd() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      // Check session cooldown
      if (_lastClickTime != null) {
        final timeSinceLastClick = now.difference(_lastClickTime!).inSeconds;
        if (timeSinceLastClick < clickCooldownSeconds) {
          debugPrint('🚫 Ad click blocked: Cooldown active (${clickCooldownSeconds - timeSinceLastClick}s remaining)');
          return false;
        }
      }
      
      // Check daily limits
      final todayClicks = await _getTodayClickCount(prefs);
      if (todayClicks >= maxClicksPerDay) {
        debugPrint('🚫 Ad click blocked: Daily limit reached ($todayClicks/$maxClicksPerDay)');
        return false;
      }
      
      // Check hourly limits
      final hourlyClicks = await _getHourlyClickCount(prefs);
      if (hourlyClicks >= maxClicksPerHour) {
        debugPrint('🚫 Ad click blocked: Hourly limit reached ($hourlyClicks/$maxClicksPerHour)');
        return false;
      }
      
      // Check session limits (additional protection)
      if (_sessionClicks >= 3) {
        debugPrint('🚫 Ad click blocked: Session limit reached ($_sessionClicks/3)');
        return false;
      }
      
      return true;
    } catch (e) {
      debugPrint('❌ Error checking ad click permission: $e');
      return false; // Fail safe - block if error
    }
  }
  
  /// Record an ad click
  static Future<void> recordAdClick() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final now = DateTime.now();
      
      _lastClickTime = now;
      _sessionClicks++;
      
      // Record click with timestamp
      final clickHistory = prefs.getStringList('ad_click_history') ?? [];
      clickHistory.add(now.millisecondsSinceEpoch.toString());
      
      // Keep only last 100 clicks to prevent storage bloat
      if (clickHistory.length > 100) {
        clickHistory.removeRange(0, clickHistory.length - 100);
      }
      
      await prefs.setStringList('ad_click_history', clickHistory);
      
      // Update daily counter
      final today = _getTodayString();
      final dailyKey = 'ad_clicks_$today';
      final dailyCount = prefs.getInt(dailyKey) ?? 0;
      await prefs.setInt(dailyKey, dailyCount + 1);
      
      debugPrint('✅ Ad click recorded. Daily: ${dailyCount + 1}/$maxClicksPerDay, Session: $_sessionClicks/3');
      
      // Schedule cleanup of old data
      _scheduleCleanup();
      
    } catch (e) {
      debugPrint('❌ Error recording ad click: $e');
    }
  }
  
  /// Get today's click count
  static Future<int> _getTodayClickCount(SharedPreferences prefs) async {
    final today = _getTodayString();
    final dailyKey = 'ad_clicks_$today';
    return prefs.getInt(dailyKey) ?? 0;
  }
  
  /// Get current hour's click count
  static Future<int> _getHourlyClickCount(SharedPreferences prefs) async {
    final clickHistory = prefs.getStringList('ad_click_history') ?? [];
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    
    int hourlyCount = 0;
    for (final clickTimestampStr in clickHistory) {
      try {
        final clickTimestamp = DateTime.fromMillisecondsSinceEpoch(
          int.parse(clickTimestampStr)
        );
        if (clickTimestamp.isAfter(oneHourAgo)) {
          hourlyCount++;
        }
      } catch (e) {
        debugPrint('❌ Error parsing click timestamp: $e');
      }
    }
    
    return hourlyCount;
  }
  
  /// Get today's date string
  static String _getTodayString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }
  
  /// Schedule cleanup of old data
  static void _scheduleCleanup() {
    _resetTimer?.cancel();
    _resetTimer = Timer(const Duration(hours: 1), () {
      _cleanupOldData();
    });
  }
  
  /// Clean up old click data
  static Future<void> _cleanupOldData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove daily counters older than 7 days
      final keys = prefs.getKeys();
      final now = DateTime.now();
      final sevenDaysAgo = now.subtract(const Duration(days: 7));
      
      for (final key in keys) {
        if (key.startsWith('ad_clicks_')) {
          try {
            final dateStr = key.substring('ad_clicks_'.length);
            final dateParts = dateStr.split('-');
            if (dateParts.length == 3) {
              final date = DateTime(
                int.parse(dateParts[0]),
                int.parse(dateParts[1]),
                int.parse(dateParts[2]),
              );
              if (date.isBefore(sevenDaysAgo)) {
                await prefs.remove(key);
                debugPrint('🧹 Cleaned up old ad click data: $key');
              }
            }
          } catch (e) {
            debugPrint('❌ Error parsing date from key $key: $e');
          }
        }
      }
      
      // Clean up click history older than 24 hours
      final clickHistory = prefs.getStringList('ad_click_history') ?? [];
      final oneDayAgo = now.subtract(const Duration(hours: 24));
      final recentClicks = <String>[];
      
      for (final clickTimestampStr in clickHistory) {
        try {
          final clickTimestamp = DateTime.fromMillisecondsSinceEpoch(
            int.parse(clickTimestampStr)
          );
          if (clickTimestamp.isAfter(oneDayAgo)) {
            recentClicks.add(clickTimestampStr);
          }
        } catch (e) {
          debugPrint('❌ Error cleaning click history: $e');
        }
      }
      
      if (recentClicks.length != clickHistory.length) {
        await prefs.setStringList('ad_click_history', recentClicks);
        debugPrint('🧹 Cleaned up old click history. Kept ${recentClicks.length}/${clickHistory.length}');
      }
      
    } catch (e) {
      debugPrint('❌ Error during cleanup: $e');
    }
  }
  
  /// Get time until next ad can be clicked (in seconds)
  static int getTimeUntilNextAd() {
    if (_lastClickTime == null) return 0;
    
    final now = DateTime.now();
    final timeSinceLastClick = now.difference(_lastClickTime!).inSeconds;
    final remainingTime = clickCooldownSeconds - timeSinceLastClick;
    
    return remainingTime > 0 ? remainingTime : 0;
  }

  /// Get click statistics for debugging
  static Future<Map<String, dynamic>> getClickStats() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final todayClicks = await _getTodayClickCount(prefs);
      final hourlyClicks = await _getHourlyClickCount(prefs);
      
      return {
        'todayClicks': todayClicks,
        'maxDailyClicks': maxClicksPerDay,
        'hourlyClicks': hourlyClicks,
        'maxHourlyClicks': maxClicksPerHour,
        'sessionClicks': _sessionClicks,
        'maxSessionClicks': 3,
        'canClick': await canClickAd(),
        'lastClickTime': _lastClickTime?.toIso8601String(),
        'cooldownSeconds': clickCooldownSeconds,
      };
    } catch (e) {
      debugPrint('❌ Error getting click stats: $e');
      return {'error': e.toString()};
    }
  }
  
  /// Reset session data (call when app starts)
  static void resetSession() {
    _sessionClicks = 0;
    _lastClickTime = null;
    debugPrint('🔄 Ad click protection session reset');
  }
  
  /// Force reset all data (for testing/debugging only)
  static Future<void> resetAllData() async {
    if (!kDebugMode) return; // Only allow in debug mode
    
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();
      
      for (final key in keys) {
        if (key.startsWith('ad_clicks_') || key == 'ad_click_history') {
          await prefs.remove(key);
        }
      }
      
      resetSession();
      debugPrint('🔄 All ad click protection data reset (DEBUG MODE ONLY)');
    } catch (e) {
      debugPrint('❌ Error resetting ad click data: $e');
    }
  }
}