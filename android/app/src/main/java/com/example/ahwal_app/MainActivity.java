package com.tariqi.roads;

import io.flutter.embedding.android.FlutterActivity;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;

public class MainActivity extends FlutterActivity {
    @Override
    public void configureFlutterEngine(FlutterEngine flutterEngine) {
        super.configureFlutterEngine(flutterEngine);

        // تسجيل Native Ad Factory
        GoogleMobileAdsPlugin.registerNativeAdFactory(
                flutterEngine,
                "adFactoryExample",
                new NativeAdFactoryExample(getLayoutInflater())
        );
    }

    @Override
    public void cleanUpFlutterEngine(FlutterEngine flutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine);

        // إلغاء تسجيل Native Ad Factory
        GoogleMobileAdsPlugin.unregisterNativeAdFactory(flutterEngine, "adFactoryExample");
    }
}