import 'dart:async';
import 'package:flutter/foundation.dart'; // إضافة هذا للويب
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_background_service_android/flutter_background_service_android.dart';
import 'package:vibration/vibration.dart';
import 'screens/home_screen.dart';
import 'screens/city_filter_screen.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart'; // تم تصحيح الاسم
import 'services/api_service.dart';
import 'models/checkpoint.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> showNotification(String title, String body) async {
  // تحقق من عدم كون التطبيق يعمل على الويب
  if (kIsWeb) {
    debugPrint('Notifications not supported on web');
    return;
  }

  const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'checkpoint_channel',
    'Checkpoint Updates',
    channelDescription: 'تنبيهات تحديث حالة الحواجز',
    importance: Importance.max,
    priority: Priority.high,
    styleInformation: BigTextStyleInformation(''),
    enableVibration: true,
    playSound: true,
  );
  const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
  await flutterLocalNotificationsPlugin.show(0, title, body, platformDetails);
}

Future<void> initializeService() async {
  // تجاهل الخدمات في الخلفية على الويب
  if (kIsWeb) {
    debugPrint('Background service not supported on web');
    return;
  }

  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      onStart: onStart,
      autoStart: true,
      isForegroundMode: false,
      autoStartOnBoot: true,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );

  service.startService();
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  if (kIsWeb) return true;

  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

  if (!notificationsEnabled) return true;

  await _checkForUpdates();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  if (kIsWeb) return;

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  // تحقق من التحديثات كل 10 دقائق
  Timer.periodic(const Duration(seconds: 60), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;

    if (notificationsEnabled) {
      await _checkForUpdates();
    }
  });
}

Future<void> _checkForUpdates() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorites')?.toSet() ?? {};

    if (favoriteIds.isEmpty) return;

    final allCheckpoints = await ApiService.getAllCheckpoints();
    final Map<String, String> lastStatuses = Map<String, String>.from(
      prefs.getString('last_statuses') != null
          ? _parseQueryString(prefs.getString('last_statuses')!)
          : {},
    );

    bool hasChanges = false;
    final List<String> changedCheckpoints = [];

    for (final cp in allCheckpoints) {
      if (favoriteIds.contains(cp.id)) {
        final prev = lastStatuses[cp.id];
        if (prev != null && prev != cp.status) {
          await showNotification(
              "📢 تحديث حالة حاجز مفضل",
              "${cp.name} أصبح ${cp.status}"
          );
          changedCheckpoints.add("${cp.name}: ${cp.status}");
          hasChanges = true;
        }
        lastStatuses[cp.id] = cp.status;
      }
    }

    if (hasChanges) {
      prefs.setString('last_update_time', DateTime.now().toIso8601String());
      prefs.setStringList('recent_changes', changedCheckpoints);
    }

    prefs.setString(
      'last_statuses',
      _buildQueryString(lastStatuses),
    );
  } catch (e) {
    debugPrint('Error checking updates: $e');
  }
}

Map<String, String> _parseQueryString(String query) {
  final result = <String, String>{};
  final pairs = query.split('&');
  for (final pair in pairs) {
    final keyValue = pair.split('=');
    if (keyValue.length == 2) {
      result[Uri.decodeComponent(keyValue[0])] = Uri.decodeComponent(keyValue[1]);
    }
  }
  return result;
}

String _buildQueryString(Map<String, String> params) {
  return params.entries
      .map((e) => "${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}")
      .join("&");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // إعداد التنبيهات فقط على المنصات المدعومة
  if (!kIsWeb) {
    try {
      debugPrint('✅ Notification plugin initialized');

      const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');

      const DarwinInitializationSettings initializationSettingsIOS =
      DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsIOS,
      );

      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (NotificationResponse response) async {
          debugPrint('Notification tapped: ${response.payload}');
        },
      );

      // طلب إذن التنبيهات على iOS
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
        alert: true,
        badge: true,
        sound: true,
      );

      // بدء الخدمة في الخلفية
      await initializeService();
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
    }
  } else {
    debugPrint('🌐 Running on web - skipping platform-specific features');
  }

  runApp(const AhwalApp());
}

class AhwalApp extends StatefulWidget {
  const AhwalApp({super.key});

  @override
  State<AhwalApp> createState() => _AhwalAppState();
}

class _AhwalAppState extends State<AhwalApp> {
  ThemeMode _themeMode = ThemeMode.system;

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeModeIndex = prefs.getInt('theme_mode') ?? 0;
    setState(() {
      _themeMode = ThemeMode.values[themeModeIndex];
    });
  }

  Future<void> toggleTheme() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    await prefs.setInt('theme_mode', _themeMode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أحوال الطرق',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      darkTheme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.dark,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 2,
          centerTitle: true,
          titleTextStyle: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        ),
      ),
      themeMode: _themeMode,
      home: MainNavigationScreen(toggleTheme: toggleTheme, themeMode: _themeMode),
      localizationsDelegates: const [
        // يمكن إضافة المحليات هنا إذا أردت
      ],
      supportedLocales: const [
        Locale('ar', ''),
        Locale('en', ''),
      ],
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

class _MainNavigationScreenState extends State<MainNavigationScreen>
    with TickerProviderStateMixin {
  int currentIndex = 0;
  late final List<Widget> screens;
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    screens = [
      HomeScreen(toggleTheme: widget.toggleTheme, themeMode: widget.themeMode),
      const CityFilterScreen(),
      const MapScreen(),
      const SettingsScreen(),
    ];

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  final List<NavigationItem> navigationItems = [
    NavigationItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home,
      label: 'الرئيسية',
      title: 'أحوال الطرق',
    ),
    NavigationItem(
      icon: Icons.filter_list_outlined,
      activeIcon: Icons.filter_list,
      label: 'الفلترة',
      title: 'فلترة حسب المدينة',
    ),
    NavigationItem(
      icon: Icons.map_outlined,
      activeIcon: Icons.map,
      label: 'الخريطة',
      title: 'خريطة الحواجز',
    ),
    NavigationItem(
      icon: Icons.settings_outlined,
      activeIcon: Icons.settings,
      label: 'الإعدادات',
      title: 'الإعدادات',
    ),
  ];

  void _onTabTapped(int index) {
    if (index != currentIndex) {
      _animationController.reset();
      setState(() => currentIndex = index);
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(navigationItems[currentIndex].title),
        actions: [
          if (currentIndex != 3)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showAppInfo(context),
              tooltip: 'معلومات التطبيق',
            ),
          if (currentIndex != 3)
            IconButton(
              icon: Icon(
                  widget.themeMode == ThemeMode.dark
                      ? Icons.wb_sunny
                      : Icons.nightlight_round
              ),
              onPressed: widget.toggleTheme,
              tooltip: widget.themeMode == ThemeMode.dark
                  ? 'الوضع النهاري'
                  : 'الوضع الليلي',
            ),
        ],
      ),
      body: FadeTransition(
        opacity: _animation,
        child: screens[currentIndex],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          child: BottomNavigationBar(
            currentIndex: currentIndex,
            onTap: _onTabTapped,
            type: BottomNavigationBarType.fixed,
            selectedItemColor: Theme.of(context).primaryColor,
            unselectedItemColor: Colors.grey,
            selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
            items: navigationItems.map((item) {
              final isSelected = navigationItems.indexOf(item) == currentIndex;
              return BottomNavigationBarItem(
                icon: Icon(isSelected ? item.activeIcon : item.icon),
                label: item.label,
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات التطبيق', textDirection: TextDirection.rtl),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('تطبيق أحوال الطرق',
                style: TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl),
            SizedBox(height: 8),
            Text('الإصدار: 1.0.0', textDirection: TextDirection.rtl),
            SizedBox(height: 8),
            Text('تطبيق لمتابعة حالة الحواجز والطرق في الوقت الفعلي',
                textDirection: TextDirection.rtl),
            SizedBox(height: 12),
            Text('المميزات:',
                style: TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl),
            SizedBox(height: 4),
            Text('• تحديث تلقائي كل 5 دقائق', textDirection: TextDirection.rtl),
            Text('• إشعارات للحواجز المفضلة', textDirection: TextDirection.rtl),
            Text('• فلترة حسب المدينة', textDirection: TextDirection.rtl),
            Text('• وضع ليلي ونهاري', textDirection: TextDirection.rtl),
            Text('• بحث سريع', textDirection: TextDirection.rtl),
          ],
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
}

class NavigationItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String title;

  NavigationItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.title,
  });
}