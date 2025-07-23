
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:vibration/vibration.dart';
import 'screens/home_screen.dart';
import 'screens/city_filter_screen.dart';
import 'screens/map_screen.dart';
import 'services/api_service.dart';
import 'models/checkpoint.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> showNotification(String title, String body) async {
  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'checkpoint_channel',
    'Checkpoint Updates',
    importance: Importance.max,
    priority: Priority.high,
  );
  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
  await flutterLocalNotificationsPlugin.show(0, title, body, platformDetails);
}

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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
  const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
  await flutterLocalNotificationsPlugin.initialize(initializationSettings);

  await initializeService();

  runApp(const AhwalApp());
}

class AhwalApp extends StatefulWidget {
  const AhwalApp({super.key});

  @override
  State<AhwalApp> createState() => _AhwalAppState();
}

class _AhwalAppState extends State<AhwalApp> {
  ThemeMode _themeMode = ThemeMode.system;

  void toggleTheme() {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أحوال الطرق',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
      ),
      darkTheme: ThemeData.dark(),
      themeMode: _themeMode,
      home: MainNavigationScreen(toggleTheme: toggleTheme, themeMode: _themeMode),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const MainNavigationScreen({super.key, required this.toggleTheme, required this.themeMode});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  late final List<Widget> screens;

  @override
  void initState() {
    super.initState();
    screens = [
      HomeScreen(toggleTheme: widget.toggleTheme, themeMode: widget.themeMode),
      const CityFilterScreen(),
      const MapScreen(),
    ];
  }

  final List<String> titles = [
    'أحوال الطرق',
    'فلترة حسب المدينة',
    'الخريطة',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[currentIndex]),
        actions: [
          IconButton(
            icon: Icon(widget.themeMode == ThemeMode.dark ? Icons.wb_sunny : Icons.nightlight_round),
            onPressed: widget.toggleTheme,
          ),
        ],
      ),
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_list),
            label: 'الفلترة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'الخريطة',
          ),
        ],
      ),
    );
  }
}
