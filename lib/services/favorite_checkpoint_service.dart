import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:convert';
import 'ad_helper.dart';
import 'ad_click_protection.dart';
import '../utils/ads_config.dart';

class FavoriteCheckpointService {
  static const String _favoriteCheckpointsKey = 'favorite_checkpoints';
  static const String _unlockedSlotsKey = 'unlocked_checkpoint_slots';
  static const String _adsWatchedKey = 'ads_watched_for_checkpoints';
  static const String _lastResetKey = 'checkpoint_last_reset';
  static const String _lastAdWatchKey = 'checkpoint_last_ad_watch';
  
  // Constants
  static const int baseFreeSlots = 3; // Free checkpoint slots for all users
  static const int slotsPerAd = 3; // Additional slots per ad watched
  static const int maxTotalSlots = 12; // Maximum favorite checkpoints allowed
  static const int dailyResetHours = 24; // Hours until slots reset
  static const int adCooldownMinutes = 5; // Minutes between ad watches

  // Get current favorite checkpoint IDs
  static Future<Set<String>> getFavoriteCheckpoints() async {
    final prefs = await SharedPreferences.getInstance();
    final checkpointsJson = prefs.getString(_favoriteCheckpointsKey) ?? '[]';
    final List<dynamic> checkpointsList = json.decode(checkpointsJson);
    return checkpointsList.cast<String>().toSet();
  }

  // Save favorite checkpoint IDs
  static Future<void> _saveFavoriteCheckpoints(Set<String> checkpointIds) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_favoriteCheckpointsKey, json.encode(checkpointIds.toList()));
  }

  // Get unlocked slots count
  static Future<int> getUnlockedSlots() async {
    await _checkAndResetDaily();
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_unlockedSlotsKey) ?? baseFreeSlots;
  }

  // Get total ads watched for checkpoints
  static Future<int> getAdsWatched() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_adsWatchedKey) ?? 0;
  }

  // Check if enough time has passed since last ad watch
  static Future<bool> canWatchAd() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAdWatch = prefs.getInt(_lastAdWatchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - lastAdWatch;
    final cooldownMs = adCooldownMinutes * 60 * 1000;
    return timeDiff >= cooldownMs;
  }

  // Get time remaining until next ad can be watched (in seconds) - async version
  static Future<int> getTimeUntilNextAdAsync() async {
    final prefs = await SharedPreferences.getInstance();
    final lastAdWatch = prefs.getInt(_lastAdWatchKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - lastAdWatch;
    final cooldownMs = adCooldownMinutes * 60 * 1000;
    
    if (timeDiff >= cooldownMs) {
      return 0;
    } else {
      return ((cooldownMs - timeDiff) / 1000).ceil();
    }
  }

  // Check and reset daily if 24 hours have passed
  static Future<void> _checkAndResetDaily() async {
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getInt(_lastResetKey) ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - lastReset;
    final resetIntervalMs = dailyResetHours * 60 * 60 * 1000;
    
    if (timeDiff >= resetIntervalMs) {
      // Reset to base slots
      await prefs.setInt(_unlockedSlotsKey, baseFreeSlots);
      await prefs.setInt(_adsWatchedKey, 0);
      await prefs.setInt(_lastResetKey, now);
    }
  }

  // Unlock additional slots after watching ad
  static Future<void> unlockAdditionalSlots() async {
    final canWatch = await canWatchAd();
    if (!canWatch) return;
    
    final prefs = await SharedPreferences.getInstance();
    final currentSlots = await getUnlockedSlots();
    final adsWatched = await getAdsWatched();
    
    if (currentSlots < maxTotalSlots) {
      final newSlots = currentSlots + slotsPerAd;
      final newAdsCount = adsWatched + 1;
      final now = DateTime.now().millisecondsSinceEpoch;
      
      await prefs.setInt(_unlockedSlotsKey, newSlots.clamp(baseFreeSlots, maxTotalSlots));
      await prefs.setInt(_adsWatchedKey, newAdsCount);
      await prefs.setInt(_lastAdWatchKey, now);
    }
  }

  // Check if user can add more favorites
  static Future<bool> canAddMoreFavorites() async {
    final favoriteCheckpoints = await getFavoriteCheckpoints();
    final unlockedSlots = await getUnlockedSlots();
    return favoriteCheckpoints.length < unlockedSlots;
  }

  // Add checkpoint to favorites (with limit check)
  static Future<FavoriteCheckpointResult> addToFavorites(String checkpointId, String checkpointName) async {
    final favoriteCheckpoints = await getFavoriteCheckpoints();
    final unlockedSlots = await getUnlockedSlots();

    if (favoriteCheckpoints.contains(checkpointId)) {
      return FavoriteCheckpointResult(
        success: false,
        message: 'الحاجز موجود بالفعل في المفضلة',
        action: FavoriteCheckpointAction.alreadyExists,
      );
    }

    if (favoriteCheckpoints.length >= unlockedSlots) {
      return FavoriteCheckpointResult(
        success: false,
        message: 'وصلت للحد الأقصى من الحواجز المفضلة',
        action: FavoriteCheckpointAction.limitReached,
        currentCount: favoriteCheckpoints.length,
        maxAllowed: unlockedSlots,
      );
    }

    favoriteCheckpoints.add(checkpointId);
    await _saveFavoriteCheckpoints(favoriteCheckpoints);

    return FavoriteCheckpointResult(
      success: true,
      message: 'تمت إضافة $checkpointName للمفضلة',
      action: FavoriteCheckpointAction.added,
      currentCount: favoriteCheckpoints.length,
      maxAllowed: unlockedSlots,
    );
  }

  // Remove checkpoint from favorites
  static Future<FavoriteCheckpointResult> removeFromFavorites(String checkpointId, String checkpointName) async {
    final favoriteCheckpoints = await getFavoriteCheckpoints();

    if (!favoriteCheckpoints.contains(checkpointId)) {
      return FavoriteCheckpointResult(
        success: false,
        message: 'الحاجز غير موجود في المفضلة',
        action: FavoriteCheckpointAction.notFound,
      );
    }

    favoriteCheckpoints.remove(checkpointId);
    await _saveFavoriteCheckpoints(favoriteCheckpoints);

    return FavoriteCheckpointResult(
      success: true,
      message: 'تم حذف $checkpointName من المفضلة',
      action: FavoriteCheckpointAction.removed,
      currentCount: favoriteCheckpoints.length,
      maxAllowed: await getUnlockedSlots(),
    );
  }

  // Toggle favorite status
  static Future<FavoriteCheckpointResult> toggleFavorite(String checkpointId, String checkpointName) async {
    final favoriteCheckpoints = await getFavoriteCheckpoints();
    
    if (favoriteCheckpoints.contains(checkpointId)) {
      return await removeFromFavorites(checkpointId, checkpointName);
    } else {
      return await addToFavorites(checkpointId, checkpointName);
    }
  }

  // Check if checkpoint is favorite
  static Future<bool> isFavorite(String checkpointId) async {
    final favoriteCheckpoints = await getFavoriteCheckpoints();
    return favoriteCheckpoints.contains(checkpointId);
  }

  // Get remaining slots
  static Future<int> getRemainingSlots() async {
    final favoriteCheckpoints = await getFavoriteCheckpoints();
    final unlockedSlots = await getUnlockedSlots();
    return (unlockedSlots - favoriteCheckpoints.length).clamp(0, maxTotalSlots);
  }

  // Can unlock more slots via ads
  static Future<bool> canUnlockMoreSlots() async {
    final unlockedSlots = await getUnlockedSlots();
    return unlockedSlots < maxTotalSlots;
  }

  // Get upgrade info
  static Future<FavoriteCheckpointUpgradeInfo> getUpgradeInfo() async {
    final currentSlots = await getUnlockedSlots();
    final favoriteCheckpoints = await getFavoriteCheckpoints();
    final adsWatched = await getAdsWatched();
    final remainingSlots = await getRemainingSlots();
    final canUnlock = await canUnlockMoreSlots();

    return FavoriteCheckpointUpgradeInfo(
      currentSlots: currentSlots,
      usedSlots: favoriteCheckpoints.length,
      remainingSlots: remainingSlots,
      adsWatched: adsWatched,
      canUnlockMore: canUnlock,
      maxPossibleSlots: maxTotalSlots,
    );
  }

  // Show upgrade dialog
  static Future<void> showUpgradeDialog(
    BuildContext context, {
    required VoidCallback onWatchAd,
  }) async {
    final upgradeInfo = await getUpgradeInfo();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.favorite, color: Colors.red, size: 28),
            SizedBox(width: 8),
            Text(
              'ترقية المفضلة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.gps_fixed,
                    color: Colors.blue,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'الحواجز المفضلة الحالية',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  SizedBox(height: 8),
                  Text(
                    '${upgradeInfo.usedSlots} / ${upgradeInfo.currentSlots}',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (upgradeInfo.canUnlockMore) ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.upgrade,
                      color: Colors.green,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'اربح $slotsPerAd حواجز إضافية',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.green,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    Text(
                      'شاهد إعلان واحد لزيادة حدود المفضلة',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ] else ...[
              SizedBox(height: 16),
              Container(
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.celebration,
                      color: Colors.orange,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'وصلت للحد الأقصى!',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.orange,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    Text(
                      'لديك أقصى عدد من الحواجز المفضلة ($maxTotalSlots)',
                      style: TextStyle(fontSize: 14),
                      textAlign: TextAlign.center,
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ],
            if (upgradeInfo.adsWatched > 0) ...[
              SizedBox(height: 12),
              Text(
                'شاهدت ${upgradeInfo.adsWatched} إعلان من أجل المفضلة 🎉',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إغلاق'),
          ),
          if (upgradeInfo.canUnlockMore)
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onWatchAd();
              },
              icon: Icon(Icons.play_arrow),
              label: Text('شاهد إعلان'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }

  // Show reward ad for upgrading favorites
  static Future<void> showRewardAdForUpgrade(BuildContext context) async {
    try {
      // 🔥 تحقق من إعدادات الإعلانات
      if (!AdsConfig.adsEnabled) {
        debugPrint('🚫 الإعلانات معطلة - منح ترقية مجانية للمستخدم');
        await _grantFreeUpgrade();
        if (context.mounted) {
          _showUpgradeSuccessMessage(context, isFreeTrial: true);
        }
        return;
      }
      // Check if enough time has passed since last ad
      final canWatch = await canWatchAd();
      if (!canWatch) {
        _showAdCooldownDialog(context);
        return;
      }

      // Check ad click protection
      final canClick = await AdClickProtection.canClickAd();
      if (!canClick) {
        _showAdProtectionDialog(context);
        return;
      }

      // Load and show rewarded ad
      RewardedAd? rewardedAd;
      bool adLoaded = false;

      await RewardedAd.load(
        adUnitId: AdHelper.getRewardedAdId(),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            rewardedAd = ad;
            adLoaded = true;
          },
          onAdFailedToLoad: (error) {
            _showAdFailedDialog(context);
          },
        ),
      );

      // Wait a bit for ad to load
      await Future.delayed(Duration(seconds: 2));

      if (adLoaded && rewardedAd != null) {
        await AdClickProtection.recordAdClick();
        
        rewardedAd!.show(
          onUserEarnedReward: (ad, reward) async {
            // Unlock additional slots
            await unlockAdditionalSlots();
            final upgradeInfo = await getUpgradeInfo();
            
            Fluttertoast.showToast(
              msg: "🎉 تم فتح ${slotsPerAd} حواجز إضافية! إجمالي: ${upgradeInfo.currentSlots}",
              toastLength: Toast.LENGTH_LONG,
              gravity: ToastGravity.CENTER,
            );
          },
        );
        
        rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _showAdFailedDialog(context);
          },
        );
      } else {
        _showAdFailedDialog(context);
      }
    } catch (e) {
      _showAdFailedDialog(context);
    }
  }

  // Show ad cooldown dialog
  static void _showAdCooldownDialog(BuildContext context) async {
    final timeLeft = await getTimeUntilNextAdAsync();
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.timer, color: Colors.blue, size: 28),
            SizedBox(width: 8),
            Text('انتظار قليل', textDirection: TextDirection.rtl),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.hourglass_bottom,
                    color: Colors.blue,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'يمكنك مشاهدة إعلان آخر خلال:',
                    style: TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  SizedBox(height: 8),
                  Text(
                    minutes > 0 ? '$minutes دقيقة و $seconds ثانية' : '$seconds ثانية',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'هذا لضمان عدل توزيع المميزات',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('موافق'),
          ),
        ],
      ),
    );
  }

  static void _showAdProtectionDialog(BuildContext context) {
    final timeLeft = AdClickProtection.getTimeUntilNextAd();
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.shield, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('حماية الإعلانات', textDirection: TextDirection.rtl),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'يمكنك مشاهدة إعلان آخر خلال:',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
            SizedBox(height: 8),
            Text(
              minutes > 0 ? '$minutes دقيقة و $seconds ثانية' : '$seconds ثانية',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('موافق'),
          ),
        ],
      ),
    );
  }

  static void _showAdFailedDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('عذراً!', textDirection: TextDirection.rtl),
        content: Text(
          'لا يمكن تحميل الإعلان حالياً.\nيرجى المحاولة مرة أخرى لاحقاً.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('موافق'),
          ),
        ],
      ),
    );
  }

  // Reset favorites (for debugging/testing)
  static Future<void> resetFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_favoriteCheckpointsKey);
    await prefs.remove(_unlockedSlotsKey);
    await prefs.remove(_adsWatchedKey);
    await prefs.remove(_lastResetKey);
    await prefs.remove(_lastAdWatchKey);
  }
}

// Result classes
class FavoriteCheckpointResult {
  final bool success;
  final String message;
  final FavoriteCheckpointAction action;
  final int? currentCount;
  final int? maxAllowed;

  FavoriteCheckpointResult({
    required this.success,
    required this.message,
    required this.action,
    this.currentCount,
    this.maxAllowed,
  });
}

enum FavoriteCheckpointAction {
  added,
  removed,
  alreadyExists,
  limitReached,
  notFound,
}

/// منح ترقية مجانية عندما تكون الإعلانات معطلة
Future<void> _grantFreeUpgrade() async {
  final prefs = await SharedPreferences.getInstance();
  final currentSlots = await FavoriteCheckpointService.getUnlockedSlots();
  final newSlots = (currentSlots + FavoriteCheckpointService.slotsPerAd).clamp(0, FavoriteCheckpointService.maxTotalSlots);
  await prefs.setInt('unlocked_checkpoint_slots', newSlots);
  
  // تسجيل الترقية المجانية
  final adsWatched = prefs.getInt('ads_watched_for_checkpoints') ?? 0;
  await prefs.setInt('ads_watched_for_checkpoints', adsWatched + 1);
}

/// عرض رسالة نجاح الترقية
void _showUpgradeSuccessMessage(BuildContext context, {bool isFreeTrial = false}) {
  final message = isFreeTrial 
      ? "🎉 تم منحك 3 خانات إضافية مجاناً!"
      : "🎉 تم إضافة 3 خانات جديدة للمفضلة!";
      
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      title: Row(
        children: [
          Icon(Icons.star, color: Colors.amber, size: 28),
          SizedBox(width: 8),
          Text('نجح الأمر!', style: TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.favorite, color: Colors.green, size: 48),
                SizedBox(height: 12),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                ),
                if (isFreeTrial) ...[
                  SizedBox(height: 8),
                  Text(
                    'عذراً للإزعاج - الإعلانات معطلة مؤقتاً',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text('رائع!'),
        ),
      ],
    ),
  );
}

class FavoriteCheckpointUpgradeInfo {
  final int currentSlots;
  final int usedSlots;
  final int remainingSlots;
  final int adsWatched;
  final bool canUnlockMore;
  final int maxPossibleSlots;

  FavoriteCheckpointUpgradeInfo({
    required this.currentSlots,
    required this.usedSlots,
    required this.remainingSlots,
    required this.adsWatched,
    required this.canUnlockMore,
    required this.maxPossibleSlots,
  });
}