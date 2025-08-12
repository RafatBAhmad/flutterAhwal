package com.tariqi.roads;

import com.tariqi.roads.R;
import com.google.android.gms.ads.nativead.NativeAd;
import com.google.android.gms.ads.nativead.NativeAdView;
import io.flutter.plugins.googlemobileads.GoogleMobileAdsPlugin;
import android.view.LayoutInflater;
import android.view.View;
import android.widget.TextView;
import android.widget.ImageView;
import android.widget.Button;

public class NativeAdFactoryExample implements GoogleMobileAdsPlugin.NativeAdFactory {
    private final LayoutInflater inflater;

    public NativeAdFactoryExample(LayoutInflater inflater) {
        this.inflater = inflater;
    }

    @Override
    public NativeAdView createNativeAd(NativeAd nativeAd, java.util.Map<String, Object> customOptions) {
        NativeAdView adView = (NativeAdView) inflater.inflate(R.layout.native_ad_card, null);

        // العنوان الرئيسي
        TextView headlineView = adView.findViewById(R.id.ad_headline);
        if (nativeAd.getHeadline() != null) {
            headlineView.setText(nativeAd.getHeadline());
            adView.setHeadlineView(headlineView);
        }

        // النص الوصفي
        TextView bodyView = adView.findViewById(R.id.ad_body);
        if (nativeAd.getBody() != null) {
            bodyView.setText(nativeAd.getBody());
            bodyView.setVisibility(View.VISIBLE);
            adView.setBodyView(bodyView);
        } else {
            bodyView.setVisibility(View.GONE);
        }

        // الأيقونة
        ImageView iconView = adView.findViewById(R.id.ad_icon);
        if (nativeAd.getIcon() != null) {
            iconView.setImageDrawable(nativeAd.getIcon().getDrawable());
            iconView.setVisibility(View.VISIBLE);
            adView.setIconView(iconView);
        } else {
            iconView.setVisibility(View.GONE);
        }

        // زر الدعوة للعمل (Call to Action)
        Button callToActionView = adView.findViewById(R.id.ad_call_to_action);
        if (nativeAd.getCallToAction() != null) {
            callToActionView.setText(nativeAd.getCallToAction());
            callToActionView.setVisibility(View.VISIBLE);
            adView.setCallToActionView(callToActionView);
        } else {
            callToActionView.setVisibility(View.GONE);
        }

        // ربط الإعلان بالـ View
        adView.setNativeAd(nativeAd);
        return adView;
    }
}