import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/api_service.dart';
import 'models/checkpoint.dart';
import 'main.dart'; // للوصول إلى showNotification

Future<void> initializeService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: false,
    ),
    iosConfiguration: IosConfiguration(),
  );

  service.startService();
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  final prefs = await SharedPreferences.getInstance();
  final favoriteIds = prefs.getStringList('favorites')?.toSet() ?? {};
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

  if (!notificationsEnabled || favoriteIds.isEmpty) return;

  final allCheckpoints = await ApiService.getAllCheckpoints();
  final Map<String, String> lastStatuses = Map<String, String>.from(
    prefs.getString('last_statuses') != null
        ? Map<String, dynamic>.from(Uri.splitQueryString(prefs.getString('last_statuses')!))
        : {},
  );

  for (final cp in allCheckpoints) {
    if (favoriteIds.contains(cp.id)) {
      final prev = lastStatuses[cp.id];
      if (prev != null && prev != cp.status) {
        await showNotification("📢 تحديث حالة حاجز", "${cp.name} أصبح ${cp.status}");
      }
      lastStatuses[cp.id] = cp.status;
    }
  }

  prefs.setString(
    'last_statuses',
    lastStatuses.entries.map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}").join("&"),
  );
}
