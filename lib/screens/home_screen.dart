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
import '../widgets/checkpoint_history_dialog.dart';
import '../services/city_voting_service.dart';
import '../services/checkpoint_history_service.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;
  final Function(DateTime?)? onLastUpdateChanged;

  const HomeScreen({
    super.key,
    required this.toggleTheme,
    required this.themeMode,
    this.onLastUpdateChanged,
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
  Set<String> _activeFilters = {}; // مجموعة الفلاتر النشطة
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
          // Use the same strategy as city filter screen for faster updates
          try {
            // محاولة جلب جميع الرسائل أولاً
            data = await ApiService.getAllCheckpoints();
            debugPrint('✅ HomeScreen: getAllCheckpoints نجح - ${data.length} رسالة');
          } catch (e) {
            debugPrint('❌ HomeScreen: getAllCheckpoints فشل: $e');

            try {
              // fallback للطريقة البديلة
              data = await ApiService.getLatestCheckpointsOnly();
              debugPrint('✅ HomeScreen: getLatestCheckpointsOnly نجح');
            } catch (e2) {
              debugPrint('❌ HomeScreen: getLatestCheckpointsOnly فشل: $e2');

              // fallback أخير
              data = await ApiService.fetchLatestOnly();
              debugPrint('✅ HomeScreen: fetchLatestOnly نجح');
            }
          }
        }

        // حفظ في الكاش
        if (data != null) {
          await CacheService.cacheCheckpoints(data);
        }
      }

      detectChanges(data ?? []);

      // Record checkpoint history for all fetched checkpoints
      if (data != null && data.isNotEmpty) {
        await CheckpointHistoryService.recordMultipleCheckpoints(data);
      }

      setState(() {
        allCheckpoints = data ?? [];
        _isLoading = false;
        // Apply city voting results asynchronously
        _applyCityVotingResults();
        
        cities = [
          "الكل",
          ...allCheckpoints
              .map((cp) => cp.city)
              .toSet()
              .where((c) => c != "غير معروف" && c.isNotEmpty),
        ];

        final List<Checkpoint> displayedNow = getFilteredCheckpoints();

        _calculateNewMessages();

        if (lastDisplayed.isNotEmpty &&
            displayedNow.length > lastDisplayed.length) {
          newItemsCount = displayedNow.length - lastDisplayed.length;
        }
        lastDisplayed = displayedNow;
        
        // إرسال آخر تحديث إلى الـ AppBar العام
        final latestUpdate = displayedNow
            .where((c) => c.effectiveAtDateTime != null)
            .map((c) => c.effectiveAtDateTime!)
            .fold<DateTime?>(
          null,
              (prev, el) => prev == null || el.isAfter(prev) ? el : prev,
        );
        widget.onLastUpdateChanged?.call(latestUpdate);
      });

      if (_newMessagesCount > 0 && showToast) {
        _notifyNewMessages();
      }

      if (showToast) {
        HapticFeedback.lightImpact();

        Fluttertoast.showToast(
          msg: "✅ تم تحديث البيانات (${allCheckpoints.length} حاجز)",
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
          
          // Record the status change in history
          CheckpointHistoryService.recordStatusChange(cp);
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

    // Apply active filters
    if (_activeFilters.isNotEmpty) {
      List<Checkpoint> results = [];
      
      // إذا كان فلتر المفضلة مفعل
      if (_activeFilters.contains('favorites')) {
        var favoriteFiltered = filtered.where((cp) => favoriteIds.contains(cp.id));
        results.addAll(favoriteFiltered);
      }
      
      // فلاتر الحالة
      List<String> statusesToShow = [];
      if (_activeFilters.contains('open')) {
        statusesToShow.addAll(['مفتوح', 'سالكة', 'سالكه', 'سالك']);
      }
      if (_activeFilters.contains('closed')) {
        statusesToShow.add('مغلق');
      }
      if (_activeFilters.contains('congestion')) {
        statusesToShow.add('ازدحام');
      }
      
      if (statusesToShow.isNotEmpty) {
        var statusFiltered = filtered.where((cp) =>
            statusesToShow.any((status) =>
                cp.status.toLowerCase().contains(status.toLowerCase())
            )
        );
        results.addAll(statusFiltered);
      }
      
      // إزالة المكررات وإرجاع النتائج
      filtered = results.toSet().toList();
    }

    // Fallback to old logic for compatibility
    if (_showOnlyFavorites && _activeFilters.isEmpty) {
      filtered = filtered.where((cp) => favoriteIds.contains(cp.id)).toList();
    }

    if (_quickStatusFilter != null && _activeFilters.isEmpty) {
      filtered = filtered.where((cp) =>
          _quickStatusFilter!.any((status) =>
              cp.status.toLowerCase().contains(status.toLowerCase())
          )
      ).toList();
    }

    filtered.sort((a, b) {
      // أولوية للمفضلة
      if (favoriteIds.contains(a.id) && !favoriteIds.contains(b.id)) return -1;
      if (!favoriteIds.contains(a.id) && favoriteIds.contains(b.id)) return 1;

      // ثم ترتيب حسب التاريخ (الأحدث أولاً) بغض النظر عن الحالة
      if (a.effectiveAtDateTime != null && b.effectiveAtDateTime != null) {
        return b.effectiveAtDateTime!.compareTo(a.effectiveAtDateTime!);
      }
      
      // إذا لم يكن هناك تاريخ فعال، نستخدم تاريخ التحديث
      if (a.updatedAtDateTime != null && b.updatedAtDateTime != null) {
        return b.updatedAtDateTime!.compareTo(a.updatedAtDateTime!);
      }
      
      // في النهاية، ترتيب حسب الحالة كمعيار أخير إذا لم تكن هناك تواريخ
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
      return aPriority.compareTo(bPriority);
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

  Widget _buildQuickFilterButton(String label, String filterId) {
    bool isSelected = _activeFilters.contains(filterId);
    
    Color color;
    switch (filterId) {
      case 'all':
        color = Colors.grey;
        break;
      case 'favorites':
        color = Colors.amber;
        break;
      case 'closed':
        color = Colors.red;
        break;
      case 'congestion':
        color = Colors.orange;
        break;
      case 'open':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () {
              setState(() {
                if (filterId == 'all') {
                  // إذا كان "المفضلة" (الكل سابقاً)، مسح جميع الفلاتر
                  _activeFilters.clear();
                  _showOnlyFavorites = false;
                  _quickStatusFilter = null;
                } else {
                  // تبديل الفلتر
                  if (_activeFilters.contains(filterId)) {
                    _activeFilters.remove(filterId);
                  } else {
                    _activeFilters.add(filterId);
                  }
                  
                  // تحديث المتغيرات القديمة للتوافق
                  _showOnlyFavorites = _activeFilters.contains('favorites');
                  
                  // تحديث فلتر الحالة
                  List<String> statusFilters = [];
                  if (_activeFilters.contains('closed')) statusFilters.add('مغلق');
                  if (_activeFilters.contains('congestion')) statusFilters.add('ازدحام');
                  if (_activeFilters.contains('open')) {
                    statusFilters.addAll(['مفتوح', 'سالكة', 'سالكه', 'سالك']);
                  }
                  
                  _quickStatusFilter = statusFilters.isEmpty ? null : statusFilters;
                }
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
              ),
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : color,
                ),
              ),
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


  @override
  Widget build(BuildContext context) {
    final displayed = getFilteredCheckpoints();

    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Stack(
        children: [
          Column(
            children: [
              // أزرار الفلتر المبسطة
              Container(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildQuickFilterButton('المفضلة', 'all'),
                    _buildQuickFilterButton('سالك', 'open'),
                    _buildQuickFilterButton('مغلق', 'closed'),
                    _buildQuickFilterButton('ازدحام', 'congestion'),
                  ],
                ),
              ),

              // Search Section Only
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: _searchController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    hintText: 'البحث في الحواجز والمدن...',
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

              const SizedBox(height: 8),

              Expanded(
                child: displayed.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.search_off,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد نتائج',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.grey[600]),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'جرب تغيير معايير البحث أو الفلترة',
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
                        onTap: () {
                          _markAsRead(checkpointIndex);
                          _showCheckpointHistory(checkpoint);
                        },
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
                              themeMode: widget.themeMode,
                              showCityAndSource: true,
                              onTap: () => _showCheckpointHistory(checkpoint),
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

                // New messages button removed as requested
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCheckpointHistory(Checkpoint checkpoint) {
    showDialog(
      context: context,
      builder: (context) => CheckpointHistoryDialog(
        checkpoint: checkpoint,
      ),
    );
  }

  // Apply city voting results asynchronously
  Future<void> _applyCityVotingResults() async {
    final Map<String, String> votedCities = {};
    
    // Get voted cities for checkpoints with unknown locations
    for (final cp in allCheckpoints) {
      if (cp.city == "غير معروف" || cp.city.isEmpty) {
        final votedCity = await CityVotingService.getMostVotedCity(cp.id);
        if (votedCity != null) {
          votedCities[cp.id] = votedCity;
        }
      }
    }
    
    // Apply voted cities to checkpoints
    if (votedCities.isNotEmpty && mounted) {
      setState(() {
        for (final cp in allCheckpoints) {
          if (votedCities.containsKey(cp.id)) {
            // Create a new checkpoint with the voted city
            final index = allCheckpoints.indexOf(cp);
            allCheckpoints[index] = Checkpoint(
              id: cp.id,
              name: cp.name,
              status: cp.status,
              city: votedCities[cp.id]!,
              latitude: cp.latitude,
              longitude: cp.longitude,
              sourceText: cp.sourceText,
              effectiveAt: cp.effectiveAt,
              updatedAt: cp.updatedAt,
            );
          }
        }
        
        // Update cities list
        cities = [
          "الكل",
          ...allCheckpoints
              .map((cp) => cp.city)
              .toSet()
              .where((c) => c != "غير معروف" && c.isNotEmpty),
        ];
      });
    }
  }
}