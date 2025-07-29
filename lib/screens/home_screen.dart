import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';
import '../widgets/checkpoint_card.dart'; // إضافة الاستيراد الجديد

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const HomeScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Checkpoint> allCheckpoints = [];
  List<String> cities = [];
  Set<String> favoriteIds = {};
  Map<String, String> lastFavoriteStatuses = {};
  String selectedCity = "الكل";
  Timer? _refreshTimer;
  bool notificationsEnabled = true;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  String notificationStatusMessage = "";
  final ScrollController _scrollController = ScrollController();
  int newItemsCount = 0;
  List<Checkpoint> lastDisplayed = [];
  int lastReadIndex = 0;
  bool _isAutoRefreshEnabled = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _showOnlyFavorites = false;

  @override
  void initState() {
    super.initState();
    initNotifications();
    loadFavorites();
    loadNotificationSetting();
    loadLastReadIndex();
    loadAutoRefreshSetting();
    fetchCheckpoints();
    startAutoRefresh();
  }

  void initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
    InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails =
    AndroidNotificationDetails(
      'checkpoint_channel',
      'Checkpoint Updates',
      importance: Importance.max,
      priority: Priority.high,
      styleInformation: BigTextStyleInformation(''),
    );
    const NotificationDetails platformDetails = NotificationDetails(
      android: androidDetails,
    );
    await flutterLocalNotificationsPlugin.show(0, title, body, platformDetails);
  }

  Future<void> loadFavorites() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      favoriteIds = prefs.getStringList('favorites')?.toSet() ?? {};
    });
  }

  Future<void> toggleFavorite(String id) async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      if (favoriteIds.contains(id)) {
        favoriteIds.remove(id);
        lastFavoriteStatuses.remove(id);
      } else {
        favoriteIds.add(id);
      }
      prefs.setStringList('favorites', favoriteIds.toList());
    });

    // إضافة تنبيه للمستخدم
    final checkpoint = allCheckpoints.firstWhere((cp) => cp.id == id);
    final action = favoriteIds.contains(id) ? "أُضيف إلى" : "أُزيل من";
    Fluttertoast.showToast(
      msg: "${checkpoint.name} $action المفضلة",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  Future<void> loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> loadAutoRefreshSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoRefreshEnabled = prefs.getBool('auto_refresh_enabled') ?? true;
    });
  }

  Future<void> toggleAutoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
    });
    await prefs.setBool('auto_refresh_enabled', _isAutoRefreshEnabled);

    if (_isAutoRefreshEnabled) {
      startAutoRefresh();
      Fluttertoast.showToast(msg: "✅ تم تفعيل التحديث التلقائي");
    } else {
      _refreshTimer?.cancel();
      Fluttertoast.showToast(msg: "⏸️ تم إيقاف التحديث التلقائي");
    }
  }

  Future<void> loadLastReadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    lastReadIndex = prefs.getInt('lastReadMessageIndex') ?? 0;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void startAutoRefresh() {
    if (!_isAutoRefreshEnabled) return;

    _refreshTimer?.cancel();
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      if (_isAutoRefreshEnabled) {
        fetchCheckpoints(showToast: false);
      }
    });
  }

  Future<void> fetchCheckpoints({bool showToast = true}) async {
    try {
      final data = await ApiService.getAllCheckpoints();
      detectChanges(data);

      setState(() {
        allCheckpoints = data;
        cities = [
          "الكل",
          ...data
              .map((cp) => cp.city)
              .toSet()
              .where((c) => c != "غير معروف")
              .toList(),
        ];

        final List<Checkpoint> displayedNow = getFilteredCheckpoints();

        if (lastDisplayed.isNotEmpty &&
            displayedNow.length > lastDisplayed.length) {
          newItemsCount = displayedNow.length - lastDisplayed.length;
        }
        lastDisplayed = displayedNow;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients && lastReadIndex > 0) {
          _scrollController.jumpTo(lastReadIndex * 130.0);
        }
      });

      if (showToast) {
        Fluttertoast.showToast(
          msg: "✅ تم تحديث البيانات (${allCheckpoints.length} حاجز)",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      if (showToast) {
        Fluttertoast.showToast(
          msg: "❌ فشل الاتصال بالخادم",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  void detectChanges(List<Checkpoint> newData) {
    for (final cp in newData) {
      if (favoriteIds.contains(cp.id)) {
        final prev = lastFavoriteStatuses[cp.id];
        if (notificationsEnabled && prev != null && prev != cp.status) {
          showNotification(
            "📢 تحديث حالة حاجز مفضل",
            "${cp.name} أصبح ${cp.status}",
          );
          // إضافة اهتزاز عند التغيير - using null-aware operator
          Vibration.hasVibrator().then((hasVibrator) {
            if (hasVibrator == true) {
              Vibration.vibrate(duration: 200);
            }
          });
        }
        lastFavoriteStatuses[cp.id] = cp.status;
      }
    }
  }

  List<Checkpoint> getFilteredCheckpoints() {
    List<Checkpoint> filtered = allCheckpoints;

    // فلترة حسب المدينة
    if (selectedCity != "الكل") {
      filtered = filtered.where((cp) => cp.city == selectedCity).toList();
    }

    // فلترة حسب البحث
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (cp) =>
        cp.name.contains(_searchQuery) ||
            cp.city.contains(_searchQuery) ||
            cp.status.contains(_searchQuery),
      )
          .toList();
    }

    // فلترة المفضلة فقط
    if (_showOnlyFavorites) {
      filtered = filtered.where((cp) => favoriteIds.contains(cp.id)).toList();
    }

    // ترتيب حسب الحالة والوقت
    filtered.sort((a, b) {
      // أولاً المفضلة
      if (favoriteIds.contains(a.id) && !favoriteIds.contains(b.id)) return -1;
      if (!favoriteIds.contains(a.id) && favoriteIds.contains(b.id)) return 1;

      // ثم حسب الحالة (المغلق أولاً للتحذير)
      final statusPriority = {
        'مغلق': 0,
        'ازدحام': 1,
        'مفتوح': 2,
        'سالكة': 2,
        'سالكه': 2,
        'سالك': 2,
      };
      final aPriority = statusPriority[a.status] ?? 3;
      final bPriority = statusPriority[b.status] ?? 3;
      if (aPriority != bPriority) return aPriority.compareTo(bPriority);

      // أخيراً حسب توقيت النشر الفعلي
      if (a.effectiveAtDateTime != null && b.effectiveAtDateTime != null) {
        return b.effectiveAtDateTime!.compareTo(a.effectiveAtDateTime!);
      }
      return 0;
    });

    return filtered;
  }

  String formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "الآن";
    if (diff.inMinutes < 60) return "قبل ${diff.inMinutes} د";
    if (diff.inHours < 24) return "قبل ${diff.inHours} س";
    return "قبل ${diff.inDays} يوم";
  }

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
      case 'سالك':
        return Colors.green;
      case 'مغلق':
        return Colors.red;
      case 'ازدحام':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
      case 'سالك':
        return Icons.check_circle;
      case 'مغلق':
        return Icons.cancel;
      case 'ازدحام':
        return Icons.warning;
      default:
        return Icons.help;
    }
  }

  void scrollToBottom() async {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final displayed = getFilteredCheckpoints();
    await prefs.setInt('lastReadMessageIndex', displayed.length - 1);
    setState(() => newItemsCount = 0);
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خيارات الفلترة', textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SwitchListTile(
              title: const Text(
                'عرض المفضلة فقط',
                textDirection: TextDirection.rtl,
              ),
              value: _showOnlyFavorites,
              onChanged: (value) {
                setState(() => _showOnlyFavorites = value);
                Navigator.pop(context);
              },
            ),
            SwitchListTile(
              title: const Text(
                'التحديث التلقائي',
                textDirection: TextDirection.rtl,
              ),
              subtitle: Text(
                _isAutoRefreshEnabled ? 'كل 5 دقائق' : 'متوقف',
                textDirection: TextDirection.rtl,
              ),
              value: _isAutoRefreshEnabled,
              onChanged: (value) {
                toggleAutoRefresh();
                Navigator.pop(context);
              },
            ),
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

  @override
  Widget build(BuildContext context) {
    final displayed = getFilteredCheckpoints();

    DateTime? latestUpdate = displayed
        .where((c) => c.updatedAt != null)
        .map((c) => c.effectiveAtDateTime)
        .where((dt) => dt != null)
        .cast<DateTime>()
        .fold<DateTime?>(
      null,
          (prev, el) => prev == null || el.isAfter(prev) ? el : prev,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('الصفحة الرئيسية'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            tooltip: 'خيارات الفلترة',
            onPressed: _showFilterDialog,
          ),
          IconButton(
            icon: Icon(
              notificationsEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              color: notificationsEnabled ? Colors.amber : Colors.grey,
            ),
            tooltip: notificationsEnabled
                ? 'إيقاف التنبيهات'
                : 'تشغيل التنبيهات',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                notificationsEnabled = !notificationsEnabled;
              });
              await prefs.setBool(
                'notifications_enabled',
                notificationsEnabled,
              );

              bool? hasVibrator = await Vibration.hasVibrator();
              if (notificationsEnabled && hasVibrator == true) {
                Vibration.vibrate(duration: 100);
              }

              Fluttertoast.showToast(
                msg: notificationsEnabled
                    ? "🔔 تم تفعيل التنبيهات"
                    : "🔕 تم إيقاف التنبيهات",
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              // شريط المعلومات العلوي
              Container(
                padding: const EdgeInsets.all(8.0),
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (latestUpdate != null)
                      Text(
                        "آخر تحديث: ${formatRelativeTime(latestUpdate)}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    Text(
                      "${displayed.length} حاجز",
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),

              // شريط البحث
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'البحث في الحواجز...',
                    hintTextDirection: TextDirection.rtl,
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = "");
                      },
                    )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(25),
                    ),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ),

              // اختيار المدينة
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCity,
                        decoration: InputDecoration(
                          labelText: 'المدينة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        items: cities.map((city) {
                          return DropdownMenuItem(
                            value: city,
                            child: Text(city, textDirection: TextDirection.rtl),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCity = value!;
                            newItemsCount = 0;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: Icon(
                        _showOnlyFavorites ? Icons.star : Icons.star_border,
                        color: _showOnlyFavorites ? Colors.amber : Colors.grey,
                      ),
                      tooltip: 'عرض المفضلة فقط',
                      onPressed: () {
                        setState(
                              () => _showOnlyFavorites = !_showOnlyFavorites,
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // قائمة النتائج - هنا التغيير الرئيسي
              Expanded(
                child: displayed.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد نتائج',
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'جرب تغيير معايير البحث أو الفلترة',
                        style: Theme.of(context).textTheme.bodyMedium
                            ?.copyWith(color: Colors.grey[500]),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: () => fetchCheckpoints(),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: displayed.length,
                    itemBuilder: (context, index) {
                      final checkpoint = displayed[index];
                      final relativeTime =
                      checkpoint.effectiveAtDateTime != null
                          ? formatRelativeTime(
                        checkpoint.effectiveAtDateTime!,
                      )
                          : 'غير محدد';

                      return CheckpointCard(
                        checkpoint: checkpoint,
                        isFavorite: favoriteIds.contains(checkpoint.id),
                        onFavoriteToggle: () =>
                            toggleFavorite(checkpoint.id),
                        statusColor: getStatusColor(checkpoint.status),
                        statusIcon: getStatusIcon(checkpoint.status),
                        relativeTime: relativeTime,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // زر العناصر الجديدة
          if (newItemsCount > 0)
            Positioned(
              bottom: 16,
              right: 16,
              child: FloatingActionButton.extended(
                onPressed: scrollToBottom,
                icon: const Icon(Icons.arrow_downward),
                label: Text('$newItemsCount جديد'),
                backgroundColor: Theme.of(context).primaryColor,
                foregroundColor: Colors.white,
              ),
            ),
        ],
      ),
    );
  }
}
