import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../widgets/nativ_ad_card.dart';
import '../services/cache_service.dart';
import '../services/share_service.dart';
import '../widgets/checkpoint_card.dart';

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
  // المتغيرات الأساسية
  List<Checkpoint> allCheckpoints = [];
  List<String> cities = [];
  Set<String> favoriteIds = {};
  Map<String, String> lastFavoriteStatuses = {};
  String selectedCity = "الكل";
  Timer? _refreshTimer;
  bool notificationsEnabled = true;

  // متغيرات الإشعارات
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();
  String notificationStatusMessage = "";

  // متغيرات التمرير والقراءة
  final ScrollController _scrollController = ScrollController();
  int newItemsCount = 0;
  List<Checkpoint> lastDisplayed = [];
  int? _lastReadIndex;
  int lastReadIndex = 0;
  int _newMessagesCount = 0;
  bool _isLoading = true;
  bool _showScrollToTop = false;

  // متغيرات البحث والفلترة
  bool _isAutoRefreshEnabled = true;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _showOnlyFavorites = false;
  List<String>? _quickStatusFilter;

  // 🔥 الميزة الجديدة: التبديل بين عرض جميع الرسائل أو آخر حالة فقط
  bool _showAllMessages = true;

  @override
  void initState() {
    super.initState();

    CacheService.updateUsageStats();

    initNotifications();
    loadFavorites();
    loadNotificationSetting();
    loadLastReadIndex();
    _loadLastReadIndex();
    loadAutoRefreshSetting();
    _loadShowAllMessagesSetting(); // 🔥 تحميل إعداد عرض الرسائل
    fetchCheckpoints();
    startAutoRefresh();

    _scrollController.addListener(_scrollListener);
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final showButton = _scrollController.offset > 200;
      if (showButton != _showScrollToTop) {
        setState(() {
          _showScrollToTop = showButton;
        });
      }
    }
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

  // 🔥 تحميل إعداد عرض الرسائل
  Future<void> _loadShowAllMessagesSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _showAllMessages = prefs.getBool('show_all_messages') ?? true;
    });
  }

  // 🔥 حفظ إعداد عرض الرسائل
  Future<void> _saveShowAllMessagesSetting() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('show_all_messages', _showAllMessages);
  }

  // 🔥 تبديل وضع عرض الرسائل
  Future<void> _toggleShowAllMessages() async {
    setState(() {
      _showAllMessages = !_showAllMessages;
    });

    await _saveShowAllMessagesSetting();

    // إعادة تحميل البيانات بناء على الوضع الجديد
    await fetchCheckpoints(showToast: true);

    // إظهار رسالة توضيحية
    final message = _showAllMessages
        ? "✅ تم تفعيل عرض جميع الرسائل"
        : "📌 تم تفعيل عرض آخر حالة فقط";

    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
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

  Future<void> _loadLastReadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lastReadIndex = prefs.getInt('lastReadIndex');
    });
  }

  Future<void> _saveLastReadIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lastReadIndex', index);
  }

  void _calculateNewMessages() {
    final displayed = getFilteredCheckpoints();
    if (_lastReadIndex == null) {
      _newMessagesCount = displayed.length;
    } else {
      _newMessagesCount = displayed.length - _lastReadIndex! - 1;
      if (_newMessagesCount < 0) _newMessagesCount = 0;
    }
  }

  void _markAsRead(int index) {
    _saveLastReadIndex(index);
    setState(() {
      _lastReadIndex = index;
      _calculateNewMessages();
      _newMessagesCount = 0;
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.removeListener(_scrollListener);
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

  // 🔥 دالة تحميل البيانات المحدثة
  Future<void> fetchCheckpoints({bool showToast = true}) async {
    setState(() => _isLoading = true);

    try {
      List<Checkpoint>? data;

      // محاولة تحميل من الكاش أولاً
      data = await CacheService.getCachedCheckpoints();

      // إذا لم يكن هناك كاش صالح، تحميل من API
      if (data == null) {
        if (selectedCity != "الكل") {
          // تحميل حسب المدينة المختارة
          data = await ApiService.getCheckpointsByCity(selectedCity);
        } else {
          // 🔥 تحميل بناء على الإعداد: جميع الرسائل أم آخر حالة فقط
          data = _showAllMessages
              ? await ApiService.getAllCheckpoints() // جميع الرسائل
              : await ApiService.getLatestCheckpointsOnly(); // آخر حالة فقط
        }

        // حفظ في الكاش
        if (data != null) {
          await CacheService.cacheCheckpoints(data);
        }
      }

      detectChanges(data ?? []);

      setState(() {
        allCheckpoints = data ?? [];
        _isLoading = false;
        cities = [
          "الكل",
          ...allCheckpoints
              .map((cp) => cp.city)
              .toSet()
              .where((c) => c != "غير معروف"),
        ];

        final List<Checkpoint> displayedNow = getFilteredCheckpoints();

        _calculateNewMessages();

        if (lastDisplayed.isNotEmpty &&
            displayedNow.length > lastDisplayed.length) {
          newItemsCount = displayedNow.length - lastDisplayed.length;
        }
        lastDisplayed = displayedNow;
      });

      if (_newMessagesCount > 0 && showToast) {
        _notifyNewMessages();
      }

      if (showToast) {
        HapticFeedback.lightImpact();

        final modeText = _showAllMessages ? "جميع الرسائل" : "آخر حالة فقط";
        Fluttertoast.showToast(
          msg: "✅ تم تحديث البيانات (${allCheckpoints.length} حاجز) - $modeText",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);

      if (showToast) {
        HapticFeedback.heavyImpact();

        Fluttertoast.showToast(
          msg: "❌ فشل الاتصال بالخادم",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  Future<void> _notifyNewMessages() async {
    final hasVibrator = await Vibration.hasVibrator();
    if (hasVibrator == true) {
      Vibration.vibrate(duration: 300);
    }
    Fluttertoast.showToast(
      msg: "📩 وصلتك $_newMessagesCount رسائل جديدة",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
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

    if (selectedCity != "الكل") {
      filtered = filtered.where((cp) => cp.city == selectedCity).toList();
    }

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

    if (_showOnlyFavorites) {
      filtered = filtered.where((cp) => favoriteIds.contains(cp.id)).toList();
    }

    if (_quickStatusFilter != null) {
      filtered = filtered.where((cp) =>
          _quickStatusFilter!.any((status) =>
              cp.status.toLowerCase().contains(status.toLowerCase())
          )
      ).toList();
    }

    filtered.sort((a, b) {
      if (favoriteIds.contains(a.id) && !favoriteIds.contains(b.id)) return -1;
      if (!favoriteIds.contains(a.id) && favoriteIds.contains(b.id)) return 1;

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

  int _countByStatus(List<Checkpoint> checkpoints, List<String> statuses) {
    return checkpoints.where((cp) =>
        statuses.any((status) => cp.status.toLowerCase().contains(status.toLowerCase()))
    ).length;
  }

  // 🔥 دوال مساعدة للإعلانات

  /// حساب العدد الإجمالي للعناصر (checkpoints + إعلانات)
  int _calculateTotalItemsWithAds(int checkpointCount) {
    if (checkpointCount == 0) return 0;

    // كل 3 checkpoints نضيف إعلان واحد
    final adCount = (checkpointCount / 3).floor();
    return checkpointCount + adCount;
  }

  /// تحديد ما إذا كان المؤشر الحالي يمثل إعلان
  bool _isAdIndex(int index) {
    // الإعلانات تظهر في المواضع: 3, 7, 11, 15...
    return (index + 1) % 4 == 0;
  }

  /// الحصول على مؤشر الـ checkpoint الحقيقي من مؤشر ListView
  int _getCheckpointIndex(int listViewIndex) {
    // حساب عدد الإعلانات قبل هذا المؤشر
    final adsBefore = (listViewIndex / 4).floor();
    return listViewIndex - adsBefore;
  }

  Widget _buildQuickStat(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$count',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilterButton(String label, List<String>? statuses) {
    final isSelected = (_quickStatusFilter == statuses) ||
        (statuses == null && _quickStatusFilter == null);

    Color color;
    if (statuses == null) {
      color = Colors.grey;
    } else if (statuses.contains('مفتوح') || statuses.contains('سالكة')) {
      color = Colors.green;
    } else if (statuses.contains('مغلق')) {
      color = Colors.red;
    } else {
      color = Colors.orange;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: ElevatedButton(
          onPressed: () {
            setState(() {
              _quickStatusFilter = statuses;
            });
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? color : Colors.transparent,
            foregroundColor: isSelected ? Colors.white : color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
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

  void scrollToNewMessages() async {
    if (_scrollController.hasClients && _lastReadIndex != null) {
      final targetIndex = _lastReadIndex! + 1;
      final targetOffset = targetIndex * 120.0;

      _scrollController.animateTo(
        targetOffset,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  void scrollToTop() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
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
    setState(() {
      newItemsCount = 0;
      _newMessagesCount = 0;
      _lastReadIndex = displayed.length - 1;
    });
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
            // 🔥 خيار عرض الرسائل الجديد
            SwitchListTile(
              title: const Text(
                'عرض جميع الرسائل',
                textDirection: TextDirection.rtl,
              ),
              subtitle: Text(
                _showAllMessages ? 'جميع الرسائل والتحديثات' : 'آخر حالة فقط',
                textDirection: TextDirection.rtl,
              ),
              value: _showAllMessages,
              onChanged: (value) async {
                Navigator.pop(context);
                await _toggleShowAllMessages();
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
        .where((c) => c.effectiveAtDateTime != null)
        .map((c) => c.effectiveAtDateTime!)
        .fold<DateTime?>(
      null,
          (prev, el) => prev == null || el.isAfter(prev) ? el : prev,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(_showAllMessages ? "جميع التحديثات" : "آخر حالة"),
        actions: [
          // 🔥 زر تبديل وضع عرض الرسائل
          IconButton(
            icon: Icon(
              _showAllMessages ? Icons.history : Icons.fiber_new,
              color: _showAllMessages ? Colors.blue : Colors.green,
            ),
            tooltip: _showAllMessages ? 'عرض آخر حالة فقط' : 'عرض جميع الرسائل',
            onPressed: _toggleShowAllMessages,
          ),
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

              final hasVibrator = await Vibration.hasVibrator();
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
          // 🔥 زر مشاركة الإحصائيات
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'مشاركة إحصائيات',
            onPressed: () async {
              HapticFeedback.lightImpact();
              final openCount = _countByStatus(displayed, ['مفتوح', 'سالكة', 'سالكه', 'سالك']);
              final closedCount = _countByStatus(displayed, ['مغلق']);
              final congestionCount = _countByStatus(displayed, ['ازدحام']);

              await ShareService.shareGeneralStats(
                displayed.length,
                openCount,
                closedCount,
                congestionCount,
              );

              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم مشاركة الإحصائيات'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.green,
                  ),
                );
              }

              Fluttertoast.showToast(
                msg: "تم مشاركة الإحصائيات",
                toastLength: Toast.LENGTH_SHORT,
              );
            },
          ),
          // 🔥 قائمة المزيد
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            tooltip: 'المزيد',
            onSelected: (value) async {
              switch (value) {
                case 'share_favorites':
                  final favoriteCheckpoints = displayed.where((cp) => favoriteIds.contains(cp.id)).toList();
                  if (favoriteCheckpoints.isNotEmpty) {
                    await ShareService.shareFavoriteCheckpoints(favoriteCheckpoints);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('تم مشاركة قائمة المفضلة'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.green,
                        ),
                      );
                    }
                  } else {
                    Fluttertoast.showToast(msg: "لا توجد حواجز مفضلة");
                  }
                  break;
                case 'share_city':
                  if (selectedCity != "الكل") {
                    final cityCheckpoints = displayed;
                    final openCount = _countByStatus(cityCheckpoints, ['مفتوح', 'سالكة', 'سالكه', 'سالك']);
                    final closedCount = _countByStatus(cityCheckpoints, ['مغلق']);
                    final congestionCount = _countByStatus(cityCheckpoints, ['ازدحام']);

                    await ShareService.shareCityStats(selectedCity, openCount, closedCount, congestionCount);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('تم مشاركة إحصائيات $selectedCity'),
                          duration: const Duration(seconds: 2),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }
                  } else {
                    Fluttertoast.showToast(msg: "اختر مدينة محددة أولاً");
                  }
                  break;
                case 'share_app':
                  await ShareService.shareApp();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('تم مشاركة معلومات التطبيق'),
                        duration: Duration(seconds: 2),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  }
                  break;
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'share_favorites',
                child: Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'مشاركة المفضلة',
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
              if (selectedCity != "الكل")
                PopupMenuItem(
                  value: 'share_city',
                  child: Row(
                    children: [
                      const Icon(Icons.location_city, color: Colors.green, size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'مشاركة إحصائيات $selectedCity',
                          textDirection: TextDirection.rtl,
                        ),
                      ),
                    ],
                  ),
                ),
              const PopupMenuItem(
                value: 'share_app',
                child: Row(
                  children: [
                    Icon(Icons.app_shortcut, color: Colors.blue, size: 20),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'مشاركة التطبيق',
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Column(
            children: [
              // 🔥 شريط المعلومات مع مؤشر الوضع
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  border: Border(
                    bottom: BorderSide(
                      color: _showAllMessages ? Colors.blue.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        if (latestUpdate != null)
                          Text(
                            "آخر تحديث: ${formatRelativeTime(latestUpdate)}",
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        Row(
                          children: [
                            // 🔥 مؤشر الوضع الحالي
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: _showAllMessages ? Colors.blue.withValues(alpha: 0.1) : Colors.green.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: _showAllMessages ? Colors.blue.withValues(alpha: 0.3) : Colors.green.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    _showAllMessages ? Icons.history : Icons.fiber_new,
                                    size: 12,
                                    color: _showAllMessages ? Colors.blue : Colors.green,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    _showAllMessages ? "جميع الرسائل" : "آخر حالة",
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: _showAllMessages ? Colors.blue : Colors.green,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              "${displayed.length} حاجز",
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildQuickFilterButton('الكل', null),
                          _buildQuickFilterButton('سالك', ['مفتوح', 'سالكة', 'سالكه', 'سالك']),
                          _buildQuickFilterButton('مغلق', ['مغلق']),
                          _buildQuickFilterButton('ازدحام', ['ازدحام']),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

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
                    if (value.isNotEmpty) {
                      CacheService.addToSearchHistory(value);
                    }
                  },
                ),
              ),

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
                            _newMessagesCount = 0;
                          });
                          if (value != "الكل") {
                            CacheService.trackCityView(value!);
                          }
                          // إعادة تحميل البيانات عند تغيير المدينة
                          fetchCheckpoints(showToast: false);
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

              Expanded(
                child: displayed.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _showAllMessages ? Icons.search_off : Icons.fiber_new,
                        size: 64,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        _showAllMessages ? 'لا توجد نتائج' : 'لا توجد تحديثات جديدة',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _showAllMessages
                            ? 'جرب تغيير معايير البحث أو الفلترة'
                            : 'اضغط على زر التاريخ لعرض جميع الرسائل',
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(color: Colors.grey[500]),
                        textDirection: TextDirection.rtl,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                )
                    : RefreshIndicator(
                  onRefresh: () => fetchCheckpoints(),
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: _calculateTotalItemsWithAds(displayed.length),
                    itemBuilder: (context, index) {
                      // 🔥 تحديد ما إذا كان العنصر الحالي إعلان أم checkpoint
                      if (_isAdIndex(index)) {
                        // عرض إعلان Native
                        return const NativeAdCard();
                      }

                      // حساب فهرس الـ checkpoint الحقيقي
                      final checkpointIndex = _getCheckpointIndex(index);

                      if (checkpointIndex >= displayed.length) {
                        return const SizedBox.shrink();
                      }

                      final checkpoint = displayed[checkpointIndex];
                      final relativeTime = checkpoint.effectiveAtDateTime != null
                          ? formatRelativeTime(checkpoint.effectiveAtDateTime!)
                          : 'غير محدد';

                      return GestureDetector(
                        onTap: () => _markAsRead(checkpointIndex),
                        child: Column(
                          children: [
                            if (_lastReadIndex != null &&
                                checkpointIndex == _lastReadIndex! + 1 &&
                                _newMessagesCount > 0)
                              Container(
                                width: double.infinity,
                                margin: const EdgeInsets.symmetric(vertical: 8),
                                padding: const EdgeInsets.symmetric(vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  border: Border.all(
                                    color: Colors.blue.withValues(alpha: 0.3),
                                    width: 1,
                                  ),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.fiber_new,
                                      color: Colors.blue,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      "— $_newMessagesCount رسائل جديدة —",
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            CheckpointCard(
                              checkpoint: checkpoint,
                              isFavorite: favoriteIds.contains(checkpoint.id),
                              onToggleFavorite: () => toggleFavorite(checkpoint.id),
                              statusColor: getStatusColor(checkpoint.status),
                              statusIcon: getStatusIcon(checkpoint.status),
                              relativeTime: relativeTime,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          Positioned(
            bottom: 16,
            right: 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showScrollToTop)
                  FloatingActionButton(
                    heroTag: "scroll_to_top",
                    mini: true,
                    onPressed: scrollToTop,
                    backgroundColor: Colors.grey[600],
                    foregroundColor: Colors.white,
                    child: const Icon(Icons.arrow_upward),
                  ),

                if (_showScrollToTop)
                  const SizedBox(height: 8),

                // الزر جديد  - يبقى ظاهراً دائماً إذا كان هناك رسائل جديدة
                if (_newMessagesCount > 0)
                  FloatingActionButton.extended(
                    heroTag: "new_messages",
                    onPressed: scrollToNewMessages,
                    icon: const Icon(Icons.mark_as_unread),
                    label: Text('جديد $_newMessagesCount'),
                    backgroundColor: Theme.of(context).primaryColor,
                    foregroundColor: Colors.white,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}