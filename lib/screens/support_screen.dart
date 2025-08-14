import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/ad_helper.dart';
import '../services/ad_click_protection.dart';
import '../services/url_launcher_helper.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  RewardedAd? _rewardedAd;
  bool _isRewardedAdLoaded = false;
  int _supportCount = 0;
  bool _isLoadingReward = false;

  @override
  void initState() {
    super.initState();
    _loadSupportCount();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _rewardedAd?.dispose();
    super.dispose();
  }

  // 🔥 تحميل عدد مرات الدعم
  Future<void> _loadSupportCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _supportCount = prefs.getInt('support_count') ?? 0;
    });
  }

  // 🔥 زيادة عداد الدعم
  Future<void> _incrementSupportCount() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _supportCount++;
    });
    await prefs.setInt('support_count', _supportCount);
  }

  // 🔥 تحميل إعلان المكافأة
  void _loadRewardedAd() {
    setState(() => _isLoadingReward = true);

    RewardedAd.load(
      adUnitId: AdHelper.getRewardedAdId(), // استخدام AdHelper
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
            _isLoadingReward = false;
          });
          _setupRewardedAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          setState(() {
            _isRewardedAdLoaded = false;
            _isLoadingReward = false;
          });
          debugPrint('RewardedAd failed to load: $error');
        },
      ),
    );
  }

  // 🔥 إعداد callbacks للإعلان
  void _setupRewardedAdCallbacks() {
    _rewardedAd?.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (RewardedAd ad) {
        debugPrint('Rewarded ad showed full screen content.');
      },
      onAdDismissedFullScreenContent: (RewardedAd ad) {
        debugPrint('Rewarded ad dismissed full screen content.');
        ad.dispose();
        setState(() {
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
        });
        // تحميل إعلان جديد للمرة القادمة
        _loadRewardedAd();
      },
      onAdFailedToShowFullScreenContent: (RewardedAd ad, AdError error) {
        debugPrint('Rewarded ad failed to show full screen content: $error');
        ad.dispose();
        setState(() {
          _rewardedAd = null;
          _isRewardedAdLoaded = false;
        });
        _showSupportFailedDialog();
      },
    );
  }

  // 🔥 عرض الإعلان مع حماية الكليكات
  Future<void> _showRewardedAd() async {
    // التحقق من حماية الكليكات
    final canClick = await AdClickProtection.canClickAd();
    if (!canClick) {
      _showAdProtectionDialog();
      return;
    }

    if (_isRewardedAdLoaded && _rewardedAd != null) {
      // تسجيل النقر على الإعلان
      await AdClickProtection.recordAdClick();
      
      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          // 🎉 المستخدم حصل على المكافأة
          _onRewardEarned();
        },
      );
    } else {
      _showSupportFailedDialog();
    }
  }

  // 🔥 عند حصول المستخدم على المكافأة
  void _onRewardEarned() {
    _incrementSupportCount();

    // إظهار رسالة شكر
    _showThankYouDialog();

    // اهتزاز للتأكيد
    HapticFeedback.heavyImpact();

    Fluttertoast.showToast(
      msg: "🙏 شكراً لدعمك! تم احتساب دعمك رقم $_supportCount",
      toastLength: Toast.LENGTH_LONG,
      gravity: ToastGravity.TOP,
    );
  }

  // 🔥 رسالة الشكر بعد مشاهدة الإعلان
  void _showThankYouDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            const Icon(Icons.favorite, color: Colors.red, size: 28),
            const SizedBox(width: 8),
            const Text(
              'شكراً لدعمك!',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle,
                    color: Colors.green,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'لقد دعمت التطبيق للمرة رقم $_supportCount',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'دعمك يساعدنا في تطوير التطبيق وإضافة مميزات جديدة',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildSupportBadge(),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _showDonationDialog(context);
            },
            child: const Text('دعم إضافي'),
          ),
        ],
      ),
    );
  }

  // 🔥 رسالة حماية الإعلانات
  void _showAdProtectionDialog() {
    final timeLeft = AdClickProtection.getTimeUntilNextAd();
    final minutes = timeLeft ~/ 60;
    final seconds = timeLeft % 60;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: const Row(
          children: [
            Icon(Icons.shield, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text('حماية الإعلانات', textDirection: TextDirection.rtl),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.access_time,
                    color: Colors.orange,
                    size: 48,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'يمكنك مشاهدة إعلان آخر خلال:',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    minutes > 0 ? '$minutes دقيقة و $seconds ثانية' : '$seconds ثانية',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'هذا لحماية حساب الإعلانات من الحظر',
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
            child: const Text('موافق'),
          ),
        ],
      ),
    );
  }

  // 🔥 رسالة فشل في تحميل الإعلان
  void _showSupportFailedDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('عذراً!', textDirection: TextDirection.rtl),
        content: const Text(
          'لا يمكن تحميل إعلان الدعم حالياً.\nيمكنك المحاولة مرة أخرى لاحقاً أو دعمنا بطرق أخرى.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _loadRewardedAd(); // إعادة محاولة تحميل الإعلان
            },
            child: const Text('إعادة المحاولة'),
          ),
        ],
      ),
    );
  }

  // 🔥 شارة الدعم حسب عدد المرات
  Widget _buildSupportBadge() {
    String badgeText;
    Color badgeColor;
    IconData badgeIcon;

    if (_supportCount >= 50) {
      badgeText = 'داعم ذهبي';
      badgeColor = Colors.amber;
      badgeIcon = Icons.emoji_events;
    } else if (_supportCount >= 20) {
      badgeText = 'داعم فضي';
      badgeColor = Colors.grey[600]!;
      badgeIcon = Icons.star;
    } else if (_supportCount >= 10) {
      badgeText = 'داعم برونزي';
      badgeColor = Colors.orange[800]!;
      badgeIcon = Icons.favorite;
    } else if (_supportCount >= 5) {
      badgeText = 'داعم نشط';
      badgeColor = Colors.blue;
      badgeIcon = Icons.thumb_up;
    } else {
      badgeText = 'شكراً لدعمك';
      badgeColor = Colors.green;
      badgeIcon = Icons.volunteer_activism;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(badgeIcon, color: badgeColor, size: 18),
          const SizedBox(width: 6),
          Text(
            badgeText,
            style: TextStyle(
              color: badgeColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  // 🔥 كبسة دعم التطبيق الرئيسية
  Widget _buildSupportButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: ElevatedButton.icon(
        onPressed: _isLoadingReward ? null : _showRewardedAd,
        icon: _isLoadingReward
            ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2)
        )
            : const Icon(Icons.video_library, size: 24),
        label: Text(
          _isLoadingReward
              ? 'جاري التحميل...'
              : '💖 ادعم التطبيق (مشاهدة إعلان)',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red[600],
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
      ),
    );
  }

  // 🔥 عداد الدعم
  Widget _buildSupportCounter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple[400]!, Colors.purple[600]!],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.favorite,
              color: Colors.white,
              size: 32,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'إجمالي مرات الدعم',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Text(
                  '$_supportCount مرة',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
          _buildSupportBadge(),
        ],
      ),
    );
  }

  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _showDonationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.red),
            SizedBox(width: 8),
            Text('ادعم التطبيق', textDirection: TextDirection.rtl),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إذا كان التطبيق مفيداً لك، يمكنك دعمنا بالطرق التالية:',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text('• مشاهدة الإعلانات 📺', textDirection: TextDirection.rtl),
              Text('• تقييم التطبيق في المتجر ⭐', textDirection: TextDirection.rtl),
              Text('• مشاركة التطبيق مع الأصدقاء 📤', textDirection: TextDirection.rtl),
              Text('• إرسال اقتراحاتك وملاحظاتك 💡', textDirection: TextDirection.rtl),
              Text('مشاهدة إعلان لدعم التطوير 💰', textDirection: TextDirection.rtl),
              SizedBox(height: 16),
              Text(
                'شكراً لدعمك المستمر! ❤️',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  Widget _buildContactCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required String value,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textDirection: TextDirection.rtl,
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () => _copyToClipboard(value, 'تم نسخ $title'),
              tooltip: 'نسخ',
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<bool> _checkAdAvailability() async {
    try {
      // محاولة تحميل إعلان للتأكد من التوفر
      final completer = Completer<bool>();

      RewardedAd.load(
        adUnitId: AdHelper.getRewardedAdId(),
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.dispose(); // نتخلص من الإعلان فوراً
            completer.complete(true);
          },
          onAdFailedToLoad: (error) {
            completer.complete(false);
          },
        ),
      );

      return await completer.future;
    } catch (e) {
      return false;
    }
  }

  // 🔥 دالة محسنة لتحميل الإعلان مع retry
  void _loadRewardedAdWithRetry({int retryCount = 0}) {
    if (retryCount > 3) {
      setState(() {
        _isLoadingReward = false;
      });
      return;
    }

    setState(() => _isLoadingReward = true);

    RewardedAd.load(
      adUnitId: AdHelper.getRewardedAdId(),
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (RewardedAd ad) {
          setState(() {
            _rewardedAd = ad;
            _isRewardedAdLoaded = true;
            _isLoadingReward = false;
          });
          _setupRewardedAdCallbacks();
        },
        onAdFailedToLoad: (LoadAdError error) {
          setState(() {
            _isRewardedAdLoaded = false;
            _isLoadingReward = false;
          });

          // 🔄 إعادة المحاولة بعد تأخير
          Future.delayed(Duration(seconds: (retryCount + 1) * 2), () {
            _loadRewardedAdWithRetry(retryCount: retryCount + 1);
          });

          debugPrint('RewardedAd failed to load (attempt ${retryCount + 1}): $error');
        },
      ),
    );
  }

  // 🔥 دالة لتتبع إحصائيات الإعلانات
  Future<void> _trackAdInteraction(String event) async {
    final prefs = await SharedPreferences.getInstance();
    final stats = prefs.getString('ad_stats') ?? '{}';
    final Map<String, dynamic> adStats = Map<String, dynamic>.from(
        json.decode(stats)
    );

    final today = DateTime.now().toIso8601String().split('T')[0];
    adStats[today] = adStats[today] ?? {};
    adStats[today][event] = (adStats[today][event] ?? 0) + 1;

    await prefs.setString('ad_stats', json.encode(adStats));
  }

  // 🔥 دالة محسنة لعرض الإعلان مع حماية
  Future<void> _showRewardedAdWithTracking() async {
    // التحقق من حماية الكليكات
    final canClick = await AdClickProtection.canClickAd();
    if (!canClick) {
      _trackAdInteraction('ad_blocked_protection');
      _showAdProtectionDialog();
      return;
    }

    if (_isRewardedAdLoaded && _rewardedAd != null) {
      // تسجيل النقر على الإعلان
      await AdClickProtection.recordAdClick();
      _trackAdInteraction('ad_started');

      _rewardedAd!.show(
        onUserEarnedReward: (AdWithoutView ad, RewardItem reward) {
          _trackAdInteraction('ad_completed');
          _onRewardEarned();
        },
      );
    } else {
      _trackAdInteraction('ad_not_available');
      _showSupportFailedDialog();
    }
  }

  // 🔥 كبسة دعم محسنة مع مؤشر أفضل
  Widget _buildEnhancedSupportButton() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: _isLoadingReward
          ? _buildLoadingButton()
          : _isRewardedAdLoaded
          ? _buildReadyButton()
          : _buildRetryButton(),
    );
  }

  Widget _buildLoadingButton() {
    return ElevatedButton.icon(
      onPressed: null,
      icon: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      label: const Text(
        'جاري تحميل الإعلان...',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey[400],
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Widget _buildReadyButton() {
    return ElevatedButton.icon(
      onPressed: _showRewardedAdWithTracking,
      icon: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.play_arrow, size: 20),
      ),
      label: const Text(
        '💖 ادعم التطبيق (مشاهدة إعلان)',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 4,
      ),
    );
  }

  Widget _buildRetryButton() {
    return ElevatedButton.icon(
      onPressed: () => _loadRewardedAdWithRetry(),
      icon: const Icon(Icons.refresh, size: 20),
      label: const Text(
        'إعادة تحميل الإعلان',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.orange[600],
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
      ),
    );
  }

  // 🔥 معاينة إحصائيات الإعلانات للمطور
  Widget _buildAdStatsForDev() {
    if (!AdHelper.isTestMode) return const SizedBox.shrink();

    return FutureBuilder<Map<String, dynamic>>(
      future: _getAdStats(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox.shrink();

        final stats = snapshot.data!;
        return Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '📊 إحصائيات الإعلانات (وضع التطوير)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text('مرات البدء: ${stats['ad_started'] ?? 0}', style: const TextStyle(fontSize: 10)),
              Text('مرات الإكمال: ${stats['ad_completed'] ?? 0}', style: const TextStyle(fontSize: 10)),
              Text('عدم التوفر: ${stats['ad_not_available'] ?? 0}', style: const TextStyle(fontSize: 10)),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getAdStats() async {
    final prefs = await SharedPreferences.getInstance();
    final stats = prefs.getString('ad_stats') ?? '{}';
    final allStats = Map<String, dynamic>.from(json.decode(stats));

    final today = DateTime.now().toIso8601String().split('T')[0];
    return allStats[today] ?? {};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس الصفحة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'مرحباً بك في صفحة الدعم',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'نحن هنا لمساعدتك في أي وقت',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // 🔥 عداد الدعم
            _buildSupportCounter(),

            const SizedBox(height: 16),

            // 🔥 كبسة دعم التطبيق
            _buildSupportButton(),

            const SizedBox(height: 24),

            // قسم التواصل
            Text(
              '📞 طرق التواصل',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),

            _buildContactCard(
              context,
              icon: Icons.email,
              title: 'البريد الإلكتروني',
              subtitle: 'للاستفسارات والدعم الفني',
              value: 'apptariqi@gmail.com',
              color: Colors.blue,
              onTap: () async {
                await UrlLauncherHelper.openEmail(
                  'apptariqi@gmail.com',
                  subject: 'استفسار حول تطبيق طريقي',
                  body: 'السلام عليكم،\n\nأود الاستفسار عن:\n\n',
                );
              },
            ),

            _buildContactCard(
              context,
              icon: Icons.phone,
              title: 'رقم الهاتف',
              subtitle: 'للتواصل المباشر',
              value: '+970 598662581',
              color: Colors.green,
              onTap: () async {
                await UrlLauncherHelper.makePhoneCall('+970598662581');
              },
            ),

            _buildContactCard(
              context,
              icon: Icons.message,
              title: 'واتساب',
              subtitle: 'التواصل السريع عبر الواتساب',
              value: '+970 598662581',
              color: Colors.green[700]!,
              onTap: () async {
                await UrlLauncherHelper.openWhatsApp(
                  '+970598662581',
                  message: 'السلام عليكم، أود التواصل بخصوص تطبيق طريقي',
                );
              },
            ),

            const SizedBox(height: 24),

            // قسم مميزات التطبيق
            Text(
              '✨ مميزات التطبيق',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.notifications_active,
              title: 'تنبيهات فورية',
              description: 'اشعارات عند تغير حالة الحواجز المفضلة',
              color: Colors.orange,
            ),

            _buildFeatureCard(
              icon: Icons.auto_awesome,
              title: 'تحديث تلقائي',
              description: 'تحديث البيانات كل 5 دقائق تلقائياً',
              color: Colors.blue,
            ),

            _buildFeatureCard(
              icon: Icons.filter_list,
              title: 'فلترة متقدمة',
              description: 'فلترة حسب المدينة والحالة والمفضلة',
              color: Colors.purple,
            ),

            _buildFeatureCard(
              icon: Icons.dark_mode,
              title: 'وضع ليلي',
              description: 'تجربة مريحة للعينين في الظلام',
              color: Colors.indigo,
            ),

            const SizedBox(height: 24),

            // قسم الدعم والتقييم - محدث مع أزرار فعالة
            Text(
              '❤️ ادعم التطبيق',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => _showDonationDialog(context),
                    icon: const Icon(Icons.favorite),
                    label: const Text('ادعم التطبيق'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // 🔥 فتح Google Play Store للتقييم
                      await UrlLauncherHelper.openPlayStore('com.example.ahwal_app');
                    },
                    icon: const Icon(Icons.star),
                    label: const Text('قيّم التطبيق'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // إشعار الإعلانات
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.monetization_on,
                        color: Colors.amber[700],
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'حول الإعلانات',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber[300],
                          fontSize: 16,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'نحن نستخدم الإعلانات لدعم التطوير المستمر وتقديم ميزات جديدة. شكراً لتفهمك ودعمك المستمر!',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // معلومات المطور
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.code,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'فريق ضاد التقني',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نطور التطبيقات لخدمة المجتمع',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الإصدار 1.0.3',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🔥 زر اختبار جميع وسائل التواصل (للتطوير فقط)
            if (AdHelper.isTestMode) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🧪 وضع التطوير',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await UrlLauncherHelper.testAllMethods();
                      },
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('اختبار جميع وسائل التواصل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}