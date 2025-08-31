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
import 'utils/theme.dart'; // 🔥 إضافة import للثيم
import 'services/share_service.dart'; // إضافة import للمشاركة
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:vibration/vibration.dart';


final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

// Export the check function for manual testing
Future<void> triggerFavoriteCheck() async {
  await _checkForUpdates();
}

Future<void> showNotification(String title, String body) async {
  if (kIsWeb) {
    debugPrint('Notifications not supported on web');
    return;
  }

  final prefs = await SharedPreferences.getInstance();
  final vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
  final soundEnabled = prefs.getBool('sound_enabled') ?? true;

  // التحقق من إمكانية الاهتزاز
  if (vibrationEnabled) {
    bool? hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 500);
    }
  }

  final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
    'checkpoint_channel',
    'Checkpoint Updates',
    channelDescription: 'تنبيهات تحديث حالة الحواجز',
    importance: Importance.max,
    priority: Priority.high,
    styleInformation: const BigTextStyleInformation(''),
    enableVibration: vibrationEnabled,
    playSound: soundEnabled,
  );
  final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
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
      notificationChannelId: 'checkpoint_background',
      initialNotificationTitle: 'طريقي يعمل في الخلفية',
      initialNotificationContent: 'فحص التحديثات للحواجز المفضلة',
      foregroundServiceNotificationId: 888,
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

  // تحقق من التحديثات كل 90 ثانية (1.5 دقيقة)
  Timer.periodic(const Duration(seconds: 90), (timer) async {
    final prefs = await SharedPreferences.getInstance();
    final notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    
    if (notificationsEnabled) {
      debugPrint('⏰ Background check triggered (90-second interval)');
      await _checkForUpdates();
    }
  });
}

Future<void> _checkForUpdates() async {
  try {
    debugPrint('🔍 Checking for updates...');
    final prefs = await SharedPreferences.getInstance();
    final favoriteIds = prefs.getStringList('favorites')?.toSet() ?? {};

    debugPrint('📋 Found ${favoriteIds.length} favorite checkpoints');
    if (favoriteIds.isEmpty) {
      debugPrint('ℹ️ No favorites to check');
      return;
    }

    final allCheckpoints = await ApiService.getAllCheckpoints();
    debugPrint('🔄 Fetched ${allCheckpoints.length} checkpoints');
    
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
        debugPrint('🎯 Checking favorite: ${cp.name} (${cp.id})');
        debugPrint('   Previous: $prev');
        debugPrint('   Current: ${cp.status}');
        
        if (prev != null && prev != cp.status) {
          debugPrint('🚨 Status changed! Sending notification...');
          await showNotification(
              "🔔 تحديث حالة حاجز مفضل",
              "${cp.name}\nمن: $prev ← إلى: ${cp.status}"
          );
          changedCheckpoints.add("${cp.name}: ${cp.status}");
          hasChanges = true;
        } else if (prev == null) {
          debugPrint('🆕 First time seeing this favorite, storing status');
        }
        lastStatuses[cp.id] = cp.status;
      }
    }

    if (hasChanges) {
      prefs.setString('last_update_time', DateTime.now().toIso8601String());
      prefs.setStringList('recent_changes', changedCheckpoints);
      debugPrint('✅ Saved ${changedCheckpoints.length} status changes');
    }

    prefs.setString('last_statuses', _buildQueryString(lastStatuses));
    debugPrint('💾 Status check completed');
  } catch (e) {
    debugPrint('❌ Error checking updates: $e');
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
  
  // بدء تشغيل التطبيق فوراً مع تأجيل التهيئة الثقيلة
  runApp(const AhwalApp());
  
  // تهيئة الإعلانات والميزات الأخرى في الخلفية
  _initializeBackgroundFeatures();
}

// تهيئة الميزات الثقيلة في الخلفية لتسريع بدء التطبيق
Future<void> _initializeBackgroundFeatures() async {
  try {
    // تهيئة الإعلانات
    await MobileAds.instance.initialize();
    
    // تهيئة باقي الميزات إذا لم يكن التطبيق على الويب
    if (!kIsWeb) {
      await _initializePlatformSpecificFeatures();
    }
  } catch (e) {
    debugPrint('❌ Error during background initialization: $e');
  }
}

Future<void> _initializePlatformSpecificFeatures() async {
  try {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsIOS =
    DarwinInitializationSettings(
      requestAlertPermission: false, // تأجيل طلب الأذونات
      requestBadgePermission: false,
      requestSoundPermission: false,
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

    // تأجيل طلب الأذونات إلى ما بعد تحميل التطبيق
    Future.delayed(const Duration(seconds: 3), () async {
      await _requestNotificationPermissions();
    });

    // بدء الخدمة في الخلفية بعد تأخير
    Future.delayed(const Duration(seconds: 2), () async {
      await initializeService();
    });
    
    debugPrint('✅ Platform-specific features initialized');
  } catch (e) {
    debugPrint('❌ Error during platform initialization: $e');
  }
}

Future<void> _requestNotificationPermissions() async {
  try {
    // طلب الأذونات على iOS
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // طلب الأذونات على Android 13+
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  } catch (e) {
    debugPrint('❌ Error requesting permissions: $e');
  }
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
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: _themeMode,
      home: SplashScreen(
        nextScreen: MainNavigationScreen(toggleTheme: toggleTheme, themeMode: _themeMode),
      ),
      routes: {
        '/settings': (context) => const SettingsScreen(),
      },
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
  DateTime? _lastUpdate;
  final GlobalKey<HomeScreenState> _homeScreenKey = GlobalKey<HomeScreenState>();

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
      HomeScreen(
        key: _homeScreenKey,
        toggleTheme: widget.toggleTheme, 
        themeMode: widget.themeMode,
        onLastUpdateChanged: (DateTime? lastUpdate) {
          setState(() {
            _lastUpdate = lastUpdate;
          });
        },
      ),
      CityFilterScreen(
        onRefreshRequested: () {
          // Handle city filter refresh if needed
        },
      ),
      MapScreen(
        onRefreshRequested: () {
          // Handle map refresh if needed  
        },
      ),
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
    NavigationItem(icon: Icons.home_outlined, activeIcon: Icons.home, label: 'الرئيسية', title: 'طريقي'),
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

  void _triggerHomeScreenRefresh() {
    // We'll use a more sophisticated approach by rebuilding the screen
    setState(() {
      screens[0] = HomeScreen(
        key: _homeScreenKey,
        toggleTheme: widget.toggleTheme, 
        themeMode: widget.themeMode,
        onLastUpdateChanged: (DateTime? lastUpdate) {
          setState(() {
            _lastUpdate = lastUpdate;
          });
        },
      );
    });
  }

  void _triggerRefreshForCurrentScreen() {
    switch (currentIndex) {
      case 0: // Home Screen
        _triggerHomeScreenRefresh();
        break;
      case 1: // City Filter Screen
        // Rebuild the city filter screen to trigger refresh
        setState(() {
          screens[1] = CityFilterScreen(
            onRefreshRequested: () {
              // Handle city filter refresh if needed
            },
          );
        });
        break;
      case 2: // Map Screen
        // Rebuild the map screen to trigger refresh
        setState(() {
          screens[2] = MapScreen(
            onRefreshRequested: () {
              // Handle map refresh if needed  
            },
          );
        });
        break;
      default:
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('التحديث غير متاح في هذه الصفحة'),
            duration: Duration(seconds: 2),
          ),
        );
        break;
    }
  }

  void _testNotifications() {
    // Test notification by calling the triggerFavoriteCheck
    triggerFavoriteCheck();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم تشغيل فحص الإشعارات للمفضلة'),
        duration: Duration(seconds: 2),
      ),
    );
  }

  String formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "الآن";
    if (diff.inMinutes < 60) return "قبل ${diff.inMinutes} د";
    if (diff.inHours < 24) return "قبل ${diff.inHours} س";
    return "قبل ${diff.inDays} يوم";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        centerTitle: true,
        title: Column(
          children: [
            Text(navigationItems[currentIndex].title),
            if (_lastUpdate != null && currentIndex == 0)
              Text(
                "آخر تحديث: ${formatRelativeTime(_lastUpdate!)}",
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontSize: 10,
                ),
              ),
          ],
        ),
        actions: [
          // Menu popup with all actions
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (String value) async {
              switch (value) {
                case 'refresh':
                  _triggerRefreshForCurrentScreen();
                  break;
                case 'test_notifications':
                  if (currentIndex == 0) {
                    _testNotifications();
                  }
                  break;
                case 'theme':
                  widget.toggleTheme();
                  // Force rebuild to update theme icon immediately
                  setState(() {
                    // Rebuild screens with new theme
                    screens[0] = HomeScreen(
                      key: _homeScreenKey,
                      toggleTheme: widget.toggleTheme, 
                      themeMode: widget.themeMode,
                      onLastUpdateChanged: (DateTime? lastUpdate) {
                        setState(() {
                          _lastUpdate = lastUpdate;
                        });
                      },
                    );
                  });
                  break;
                case 'settings':
                  final result = await Navigator.push(
                    context,
                    PageRouteBuilder(
                      pageBuilder: (context, animation, _) => const SettingsScreen(),
                      transitionDuration: const Duration(milliseconds: 200),
                      transitionsBuilder: (context, animation, secondaryAnimation, child) {
                        return SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(1.0, 0.0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        );
                      },
                    ),
                  );
                  // Reload home screen settings when returning from settings
                  if (currentIndex == 0 && result != false) {
                    _homeScreenKey.currentState?.reloadRefreshSettings();
                  }
                  break;
                case 'app_info':
                  _showAppInfo(context);
                  break;
                case 'share_stats':
                  _shareGeneralStats();
                  break;
                case 'share_favorites':
                  _shareFavoriteCheckpoints();
                  break;
                case 'share_app':
                  _shareApp();
                  break;
              }
            },
            itemBuilder: (BuildContext context) => [
              // Refresh - show for home, city filter, and map screens
              if (currentIndex <= 2)
                PopupMenuItem<String>(
                  value: 'refresh',
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.refresh),
                      const SizedBox(width: 8),
                      const Text('تحديث', textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
              
              // Test notifications - only show in home screen
              if (currentIndex == 0)
                PopupMenuItem<String>(
                  value: 'test_notifications',
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.notifications_active),
                      const SizedBox(width: 8),
                      const Text('اختبار الإشعارات', textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
              
              // Theme toggle - available in all screens
              PopupMenuItem<String>(
                value: 'theme',
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    Icon(_getCurrentThemeIcon()),
                    const SizedBox(width: 8),
                    Text(
                      _getCurrentThemeTooltip(),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
              
              // Sharing options - only show in home screen
              if (currentIndex == 0) ...[
                PopupMenuItem<String>(
                  value: 'share_stats',
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.analytics, color: Colors.green),
                      const SizedBox(width: 8),
                      const Text('مشاركة الإحصائيات', textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share_favorites',
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.star, color: Colors.amber),
                      const SizedBox(width: 8),
                      const Text('مشاركة المفضلة', textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'share_app',
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.share, color: Colors.blue),
                      const SizedBox(width: 8),
                      const Text('مشاركة التطبيق', textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
              ],

              // Settings - available in all screens
              PopupMenuItem<String>(
                value: 'settings',
                child: Row(
                  textDirection: TextDirection.rtl,
                  children: [
                    const Icon(Icons.settings),
                    const SizedBox(width: 8),
                    const Text('الإعدادات', textDirection: TextDirection.rtl),
                  ],
                ),
              ),
              
              // App info - available in all screens except support
              if (currentIndex != 3)
                PopupMenuItem<String>(
                  value: 'app_info',
                  child: Row(
                    textDirection: TextDirection.rtl,
                    children: [
                      const Icon(Icons.info_outline),
                      const SizedBox(width: 8),
                      const Text('معلومات التطبيق', textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
            ],
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

  Future<void> _shareGeneralStats() async {
    try {
      // الحصول على الإحصائيات من الشاشة الرئيسية
      final homeScreenState = _homeScreenKey.currentState;
      if (homeScreenState != null) {
        final checkpoints = homeScreenState.allCheckpoints;
        
        if (checkpoints.isNotEmpty) {
          final open = checkpoints.where((c) => 
            c.status.toLowerCase().contains('مفتوح') || 
            c.status.toLowerCase().contains('سالك')).length;
          final closed = checkpoints.where((c) => 
            c.status.toLowerCase().contains('مغلق')).length;
          final congestion = checkpoints.where((c) => 
            c.status.toLowerCase().contains('ازدحام')).length;
            
          await ShareService.shareGeneralStats(checkpoints.length, open, closed, congestion);
        } else {
          await ShareService.shareApp();
        }
      } else {
        await ShareService.shareApp();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم مشاركة الإحصائيات'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في مشاركة الإحصائيات'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareFavoriteCheckpoints() async {
    try {
      // الحصول على المفضلة من الشاشة الرئيسية
      final homeScreenState = _homeScreenKey.currentState;
      if (homeScreenState != null) {
        final allCheckpoints = homeScreenState.allCheckpoints;
        final favoriteIds = homeScreenState.favoriteIds;
        
        final favorites = allCheckpoints
            .where((checkpoint) => favoriteIds.contains(checkpoint.id))
            .toList();
            
        await ShareService.shareFavoriteCheckpoints(favorites);
      } else {
        await ShareService.shareApp();
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('تم مشاركة قائمة المفضلة'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في مشاركة المفضلة'),
            duration: Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _shareApp() async {
    await ShareService.shareApp();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم مشاركة معلومات التطبيق'),
          duration: Duration(seconds: 2),
          backgroundColor: Colors.blue,
        ),
      );
    }
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
              Text('الإصدار: 1.0.8'),
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