import 'dart:async';
import 'screens/home_screen.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'screens/city_filter_screen.dart';
import 'screens/map_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/support_screen.dart';
import 'screens/splash_screen.dart';
import 'services/api_service.dart';
import 'widgets/banner_ad_widget.dart'; // 🔥 إضافة import للبانر
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vibration/vibration.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> showNotification(String title, String body) async {
  if (kIsWeb) {
    debugPrint('Notifications not supported on web');
    return;
  }

  // التحقق من إمكانية الاهتزاز
  bool? hasVibrator = await Vibration.hasVibrator();
  if (hasVibrator == true) {
    Vibration.vibrate(duration: 500);
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
  WidgetsFlutterBinding.ensureInitialized();
  await _checkForUpdates();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized(); // ضروري لضمان تهيئة SharedPreferences

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

  // تحقق من التحديثات كل 1 دقائق
  Timer.periodic(const Duration(minutes: 1), (timer) async {
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

    final allCheckpoints = await ApiService.fetchLatestOnly();
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

    prefs.setString('last_statuses', _buildQueryString(lastStatuses));
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
  // تأكد من تهيئة كل شيء قبل تشغيل التطبيق
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  // إذا كان التطبيق يعمل على الويب، لا تقم بتهيئة الخدمات
  if (kIsWeb) {
    debugPrint('🌐 Running on web - skipping platform-specific features');
  } else {
    // تهيئة التنبيهات والخدمات للمنصات الأخرى
    try {
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

      // طلب الأذونات على iOS
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(alert: true, badge: true, sound: true);

      // بدء الخدمة في الخلفية
      await initializeService();
      debugPrint('✅ Platform-specific features initialized');
    } catch (e) {
      debugPrint('❌ Error during initialization: $e');
    }
  }

  // الآن قم بتشغيل التطبيق مع Splash Screen
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
    if (mounted) {
      setState(() {
        _themeMode = ThemeMode.values[themeModeIndex];
      });
    }
  }

  Future<void> toggleTheme() async {
    final newThemeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    setState(() {
      _themeMode = newThemeMode;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('theme_mode', newThemeMode.index);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'طريقي - دليل الطرق الذكي',
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
            color: Colors.black87,
          ),
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
      ),
      themeMode: _themeMode,
      home: SplashScreen(
        nextScreen: MainNavigationScreen(toggleTheme: toggleTheme, themeMode: _themeMode),
      ),
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
      const SupportScreen(),
    ];

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  final List<NavigationItem> navigationItems = [
    NavigationItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية', title: 'أحوال الطرق'),
    NavigationItem(icon: Icons.filter_list_outlined, activeIcon: Icons.filter_list, label: 'الفلترة', title: 'فلترة حسب المدينة'),
    NavigationItem(icon: Icons.map_outlined, activeIcon: Icons.map, label: 'الخريطة', title: 'خريطة الحواجز'),
    NavigationItem(icon: Icons.support_outlined, activeIcon: Icons.support, label: 'الدعم', title: 'الدعم'),
  ];

  void _onTabTapped(int index) {
    if (index != currentIndex) {
      _animationController.reset();
      setState(() => currentIndex = index);
      _animationController.forward();
    }
  }

  // 🔥 دالة تحديد أيقونة الثيم الصحيحة
  IconData _getCurrentThemeIcon() {
    final brightness = Theme.of(context).brightness;
    if (widget.themeMode == ThemeMode.system) {
      // في وضع النظام، نعتمد على brightness الحالي
      return brightness == Brightness.dark
          ? Icons.wb_sunny_outlined  // شمس في الوضع الداكن
          : Icons.nightlight_round;  // هلال في الوضع الفاتح
    } else {
      // في الأوضاع اليدوية
      return widget.themeMode == ThemeMode.dark
          ? Icons.wb_sunny_outlined  // شمس في الوضع الداكن
          : Icons.nightlight_round;  // هلال في الوضع الفاتح
    }
  }

  // 🔥 دالة تحديد نص التلميح الصحيح
  String _getCurrentThemeTooltip() {
    final brightness = Theme.of(context).brightness;
    if (widget.themeMode == ThemeMode.system) {
      return brightness == Brightness.dark
          ? 'تفعيل الوضع النهاري'
          : 'تفعيل الوضع الليلي';
    } else {
      return widget.themeMode == ThemeMode.dark
          ? 'تفعيل الوضع النهاري'
          : 'تفعيل الوضع الليلي';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(navigationItems[currentIndex].title),
        actions: [
          // زر الإعدادات
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
            },
            tooltip: 'الإعدادات',
          ),

          // 🔥 إصلاح زر الوضع الليلي
          IconButton(
            icon: Icon(_getCurrentThemeIcon()),
            onPressed: () {
              widget.toggleTheme();
              // 🔥 إضافة تحديث فوري للواجهة
              setState(() {});
            },
            tooltip: _getCurrentThemeTooltip(),
          ),

          if (currentIndex != 3)
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () => _showAppInfo(context),
              tooltip: 'معلومات التطبيق',
            ),
        ],
      ),
      body: Column(
        children: [
          // المحتوى الرئيسي
          Expanded(
            child: FadeTransition(
              opacity: _animation,
              child: screens[currentIndex],
            ),
          ),
          // إعلان البانر في أسفل كل صفحة
          const BannerAdWidget(),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Theme.of(context).colorScheme.primary,
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
    );
  }

  void _showAppInfo(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('معلومات التطبيق'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('تطبيق طريقي - دليل الطرق الذكي', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('الإصدار: 1.0.1'),
              SizedBox(height: 8),
              Text('تطبيق لمتابعة حالة الحواجز والطرق في الوقت الفعلي.'),
              SizedBox(height: 12),
              Text('المميزات:', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 4),
              Text('• تحديث تلقائي دوري'),
              Text('• إشعارات للحواجز المفضلة'),
              Text('• فلترة حسب المدينة'),
              Text('• وضع ليلي ونهاري'),
              Text('• عرض جميع الرسائل أو آخر حالة'),
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