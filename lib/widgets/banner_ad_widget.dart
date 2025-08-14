import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import '../services/ad_helper.dart';
import '../services/ad_click_protection.dart';

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadBannerAd();
  }

  void _loadBannerAd() {
    // تجاهل الإعلانات على الويب
    if (kIsWeb) {
      debugPrint('Banner ads not supported on web');
      return;
    }

    _bannerAd = BannerAd(
      adUnitId: AdHelper.getBannerAdId(), // 🔥 Fixed: use banner ID, not native ID
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
          debugPrint('✅ Banner ad loaded successfully');
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint('❌ Banner ad failed to load: $error');
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
        },
        onAdOpened: (ad) async {
          debugPrint('📱 Banner ad opened');
          // Record ad click with protection
          final canClick = await AdClickProtection.canClickAd();
          if (canClick) {
            await AdClickProtection.recordAdClick();
            debugPrint('✅ Banner ad click recorded');
          } else {
            debugPrint('🚫 Banner ad click blocked by protection');
          }
        },
        onAdClosed: (ad) {
          debugPrint('🔒 Banner ad closed');
        },
      ),
    );

    _bannerAd?.load();
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // على الويب، لا نعرض شيء
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    if (_isAdLoaded && _bannerAd != null) {
      return Container(
        width: double.infinity,
        height: _bannerAd!.size.height.toDouble(),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          border: Border(
            top: BorderSide(
              color: Colors.grey.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: AdWidget(ad: _bannerAd!),
      );
    } else {
      // عرض placeholder بسيط أثناء التحميل
      return Container(
        width: double.infinity,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.5),
          border: Border(
            top: BorderSide(
              color: Colors.grey.withValues(alpha: 0.3),
              width: 1,
            ),
          ),
        ),
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
  }
}