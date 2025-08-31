import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import '../services/ad_helper.dart';
import '../utils/ads_config.dart';

class NativeAdCard extends StatefulWidget {
  const NativeAdCard({super.key});

  @override
  State<NativeAdCard> createState() => _NativeAdCardState();
}

class _NativeAdCardState extends State<NativeAdCard> {
  NativeAd? _nativeAd;
  bool _isAdLoaded = false;

  @override
  void initState() {
    super.initState();
    // 🔥 تحقق من إعدادات الإعلانات قبل التحميل
    if (AdsConfig.shouldShowAd(adLocation: 'native_ad')) {
      _loadNativeAd();
    } else {
      debugPrint('🚫 الإعلانات معطلة - لن يتم تحميل الإعلان الأصلي');
    }
  }

  void _loadNativeAd() {
    // تجاهل الإعلانات على الويب
    if (kIsWeb) {
      debugPrint('Native ads not supported on web');
      return;
    }

    _nativeAd = NativeAd(
      adUnitId: AdHelper.getNativeAdId(), // 🔥 Ad Unit ID الصحيح
      factoryId: "adFactoryExample", // 🔥 يجب أن يطابق اسم Factory في MainActivity
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) {
          if (mounted) {
            setState(() {
              _isAdLoaded = true;
            });
          }
          debugPrint("✅ Native ad loaded successfully");
        },
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          debugPrint("❌ Failed to load Native Ad: $error");
          if (mounted) {
            setState(() {
              _isAdLoaded = false;
            });
          }
        },
        onAdOpened: (ad) {
          debugPrint("📱 Native ad opened");
        },
        onAdClosed: (ad) {
          debugPrint("🔒 Native ad closed");
        },
        onAdImpression: (ad) {
          debugPrint("👁️ Native ad impression recorded");
        },
        onAdClicked: (ad) {
          debugPrint("👆 Native ad clicked");
        },
      ),
    );

    _nativeAd?.load();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // على الويب، لا نعرض شيء
    if (kIsWeb) {
      return const SizedBox.shrink();
    }

    // 🔥 إذا كانت الإعلانات معطلة، لا نعرض شيء
    if (!AdsConfig.shouldShowAd(adLocation: 'native_ad')) {
      return const SizedBox.shrink();
    }

    if (_isAdLoaded && _nativeAd != null) {
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.blue.withValues(alpha: 0.3),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        height: 150,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: AdWidget(ad: _nativeAd!),
        ),
      );
    } else {
      // عرض placeholder أثناء التحميل
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        height: 150,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor.withValues(alpha: 0.7),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.grey.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: 30,
                height: 30,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 8),
              Text(
                'جاري تحميل الإعلان...',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                ),
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
      );
    }
  }
}