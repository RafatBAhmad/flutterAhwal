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
import '../widgets/checkpoint_card.dart';
import '../widgets/checkpoint_history_dialog.dart';
import '../services/city_voting_service.dart';
import '../services/checkpoint_history_service.dart';
import '../services/favorite_checkpoint_service.dart';
import '../utils/data_filter_utils.dart';

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
  State<HomeScreen> createState() => HomeScreenState();
}

class HomeScreenState extends State<HomeScreen> {
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
  int _refreshInterval = 3; // بالدقائق - توازن بين حداثة البيانات والأداء
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";
  bool _showOnlyFavorites = false;
  final Set<String> _activeFilters = {}; // مجموعة الفلاتر النشطة
  List<String>? _quickStatusFilter;

  // الألوان المخصصة
  Map<String, int> _customColors = {};

  // 🔥 الميزة الجديدة: التبديل بين عرض جميع الرسائل أو آخر حالة فقط

  @override
  void initState() {
    super.initState();
    
    // تحميل الإعدادات الأساسية أولاً (متزامن)
    _initializeApp();
    
    _scrollController.addListener(_scrollListener);
  }
  
  // تحميل التطبيق بشكل محسّن
  Future<void> _initializeApp() async {
    // الإعدادات الأساسية فقط
    await loadFavorites();
    await loadNotificationSetting();
    await loadAutoRefreshSetting();
    await _loadCustomColors();
    
    // بدء تحميل البيانات فوراً
    fetchCheckpoints();
    
    // الإعدادات الثانوية بشكل غير متزامن
    _initializeSecondaryFeatures();
  }
  
  // تحميل الميزات الثانوية بدون توقف
  void _initializeSecondaryFeatures() {
    // تشغيل بشكل غير متزامن
    Future.microtask(() {
      CacheService.updateUsageStats();
      initNotifications();
      loadLastReadIndex();
      _loadLastReadIndex();
      _loadShowAllMessagesSetting();
      startAutoRefresh();
    });
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
    final favoriteCheckpoints = await FavoriteCheckpointService.getFavoriteCheckpoints();
    setState(() {
      favoriteIds = favoriteCheckpoints;
    });
  }

  Future<void> toggleFavorite(String id) async {
    final checkpoint = allCheckpoints.firstWhere((cp) => cp.id == id);
    final result = await FavoriteCheckpointService.toggleFavorite(id, checkpoint.name);
    
    if (result.success) {
      // Update local state
      final updatedFavorites = await FavoriteCheckpointService.getFavoriteCheckpoints();
      setState(() {
        favoriteIds = updatedFavorites;
        if (!favoriteIds.contains(id)) {
          lastFavoriteStatuses.remove(id);
        }
      });
      
      Fluttertoast.showToast(
        msg: result.message,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } else {
      if (result.action == FavoriteCheckpointAction.limitReached) {
        _showCheckpointLimitDialog(checkpoint.name);
      } else {
        Fluttertoast.showToast(
          msg: result.message,
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // Method for showing checkpoint limit dialog
  void _showCheckpointLimitDialog(String checkpointName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Row(
          children: [
            Icon(Icons.info, color: Colors.orange, size: 28),
            SizedBox(width: 8),
            Text(
              'حد المفضلة',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.gps_fixed,
                    color: Colors.orange,
                    size: 48,
                  ),
                  SizedBox(height: 12),
                  Text(
                    'وصلت للحد الأقصى من الحواجز المفضلة',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'شاهد إعلان لزيادة عدد الحواجز المفضلة',
                    style: TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('إلغاء'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              FavoriteCheckpointService.showUpgradeDialog(
                context,
                onWatchAd: () => _watchAdForCheckpointUpgrade(checkpointName),
              );
            },
            icon: Icon(Icons.upgrade),
            label: Text('ترقية'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _watchAdForCheckpointUpgrade(String checkpointName) async {
    await FavoriteCheckpointService.showRewardAdForUpgrade(context);
    // After watching ad, try adding the checkpoint again
    await Future.delayed(Duration(seconds: 1));
    // Reload favorites to update the UI
    await loadFavorites();
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
      _refreshInterval = prefs.getInt('refresh_interval') ?? 3;
    });
  }

  // 🔥 تحميل إعداد عرض الرسائل
  Future<void> _loadShowAllMessagesSetting() async {
    // Method intentionally left empty for future use
  }

  // 🔥 حفظ إعداد عرض الرسائل


  Future<void> toggleAutoRefresh() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _isAutoRefreshEnabled = !_isAutoRefreshEnabled;
      // Reload refresh interval in case it was changed in settings
      _refreshInterval = prefs.getInt('refresh_interval') ?? 3;
    });
    await prefs.setBool('auto_refresh_enabled', _isAutoRefreshEnabled);

    if (_isAutoRefreshEnabled) {
      startAutoRefresh();
      Fluttertoast.showToast(msg: "✅ تم تفعيل التحديث التلقائي (كل $_refreshInterval دقيقة)");
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
    _refreshTimer = Timer.periodic(Duration(minutes: _refreshInterval), (_) {
      if (_isAutoRefreshEnabled) {
        fetchCheckpoints(showToast: false);
      }
    });
  }

  // Method to reload settings and restart auto-refresh with new interval
  Future<void> reloadRefreshSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final wasEnabled = _isAutoRefreshEnabled;
    
    setState(() {
      _isAutoRefreshEnabled = prefs.getBool('auto_refresh_enabled') ?? true;
      _refreshInterval = prefs.getInt('refresh_interval') ?? 3;
    });

    // إعادة تحميل الألوان المخصصة
    await _loadCustomColors();

    // Restart timer with new interval if auto-refresh is enabled
    if (_isAutoRefreshEnabled) {
      _refreshTimer?.cancel();
      startAutoRefresh();
      if (wasEnabled) {
        // Show toast only if settings were changed while already enabled
        Fluttertoast.showToast(msg: "🔄 تم تحديث فترة التحديث التلقائي إلى $_refreshInterval دقيقة");
      }
    }
  }

  // 🔥 دالة تحميل البيانات المحدثة - محسّنة
  Future<void> fetchCheckpoints({bool showToast = true}) async {
    // تحديث وقت آخر محاولة استعلام
    await CacheService.updateLastFetchAttempt();
    
    // تحسين الأداء: تجنب setState إذا كانت البيانات متوفرة من الكاش
    final cachedData = await CacheService.getCachedCheckpoints();
    
    if (cachedData != null && cachedData.isNotEmpty) {
      // استخدام الكاش فوراً لتحسين الاستجابة
      _updateUIWithData(cachedData);
      
      // تحديث في الخلفية بصمت
      _backgroundRefresh();
      
      if (showToast) {
        HapticFeedback.lightImpact();
        Fluttertoast.showToast(
          msg: "📋 تم تحميل البيانات من الكاش (${cachedData.length} حاجز)",
          toastLength: Toast.LENGTH_SHORT,
          gravity: ToastGravity.BOTTOM,
        );
      }
      return;
    }
    
    // إذا لم يكن هناك كاش، عرض مؤشر التحميل
    if (_isLoading == false) {
      setState(() => _isLoading = true);
    }

    try {
      final data = await _fetchDataFromAPI();
      
      // حفظ في الكاش
      if (data.isNotEmpty) {
        await CacheService.cacheCheckpoints(data);
      }

      // تحسين الأداء: تنفيذ العمليات الثقيلة خارج setState
      detectChanges(data);

      // Record checkpoint history asynchronously  
      if (data.isNotEmpty) {
        CheckpointHistoryService.recordMultipleCheckpoints(data);
      }

      // تحديث الواجهة بالبيانات الجديدة
      _updateUIWithData(data);

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
          msg: "❌ تعذر الاتصال بالإنترنت",
          toastLength: Toast.LENGTH_LONG,
          gravity: ToastGravity.BOTTOM,
        );
      }
    }
  }

  // تحديث في الخلفية بدون عرض مؤشر تحميل
  Future<void> _backgroundRefresh() async {
    try {
      final data = await _fetchDataFromAPI();
      
      if (data.isNotEmpty) {
        await CacheService.cacheCheckpoints(data);
        detectChanges(data);
        CheckpointHistoryService.recordMultipleCheckpoints(data);
        _updateUIWithData(data);
      }
    } catch (e) {
      // تجاهل الأخطاء في التحديث الخلفي
      debugPrint('Background refresh failed: $e');
    }
  }

  // استخراج منطق API لتحسين القراءة
  Future<List<Checkpoint>> _fetchDataFromAPI() async {
    if (selectedCity != "الكل") {
      final data = await ApiService.getCheckpointsByCity(selectedCity);
      return data ?? [];
    }
    
    // محاولة تدريجية للحصول على البيانات
    try {
      final data = await ApiService.getAllCheckpoints();
      debugPrint('✅ HomeScreen: getAllCheckpoints نجح - ${data.length} رسالة');
      return data;
    } catch (e) {
      debugPrint('❌ HomeScreen: getAllCheckpoints فشل: $e');
      
      try {
        final data = await ApiService.getLatestCheckpointsOnly();
        debugPrint('✅ HomeScreen: getLatestCheckpointsOnly نجح');
        return data;
      } catch (e2) {
        debugPrint('❌ HomeScreen: getLatestCheckpointsOnly فشل: $e2');
        
        final data = await ApiService.fetchLatestOnly();
        debugPrint('✅ HomeScreen: fetchLatestOnly نجح');
        return data;
      }
    }
  }

  // تحديث الواجهة بالبيانات (متزامن وسريع)
  void _updateUIWithData(List<Checkpoint> data) {
    final newCities = [
      "الكل",
      ...data
          .map((cp) => cp.city)
          .toSet()
          .where((c) => c != "غير معروف" && c.isNotEmpty),
    ];

    setState(() {
      allCheckpoints = data;
      cities = newCities;
      _isLoading = false;
    });

    // إزالة كاش الفلترة عند تحديث البيانات
    _cachedFilteredCheckpoints = null;
    _lastFilterState = null;

    // تنفيذ المعالجات الإضافية بشكل غير متزامن
    Future.microtask(() => _processDataPostLoad());
  }

  // معالجة البيانات بعد التحميل لتحسين الأداء
  void _processDataPostLoad() {
    // Apply city voting results asynchronously
    _applyCityVotingResults();
    
    final List<Checkpoint> displayedNow = getFilteredCheckpoints();
    _calculateNewMessages();

    if (lastDisplayed.isNotEmpty && displayedNow.length > lastDisplayed.length) {
      newItemsCount = displayedNow.length - lastDisplayed.length;
    }
    lastDisplayed = displayedNow;
    
    // إرسال آخر تحديث إلى الـ AppBar العام (وقت آخر استعلام بدلاً من آخر رسالة)
    _updateLastFetchTime();
  }

  // دالة لتحديث وقت آخر استعلام
  Future<void> _updateLastFetchTime() async {
    final lastFetchTime = await CacheService.getLastFetchAttempt();
    if (lastFetchTime != null) {
      widget.onLastUpdateChanged?.call(lastFetchTime);
    }
  }

  // تحميل الألوان المخصصة
  Future<void> _loadCustomColors() async {
    final customColors = await CacheService.getCustomColors();
    setState(() {
      _customColors = customColors;
    });
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

  // متغيرات للكاش المحلي لتحسين الأداء
  List<Checkpoint>? _cachedFilteredCheckpoints;
  String? _lastFilterState;

  List<Checkpoint> getFilteredCheckpoints() {
    // إنشاء مفتاح للحالة الحالية للفلترة
    final currentFilterState = '${selectedCity}_${_searchQuery}_${_activeFilters.join(',')}_${_showOnlyFavorites}_${_quickStatusFilter?.join(',') ?? ''}';
    
    // استخدام الكاش إذا لم تتغير حالة الفلترة
    if (_cachedFilteredCheckpoints != null && _lastFilterState == currentFilterState) {
      return _cachedFilteredCheckpoints!;
    }

    // 🔥 أولاً، فلترة البيانات القديمة (أكثر من 48 ساعة)
    List<Checkpoint> filtered = DataFilterUtils.filterRecentCheckpoints(
      allCheckpoints,
      maxHours: 48,
    );

    if (selectedCity != "الكل") {
      filtered = filtered.where((cp) => cp.city == selectedCity).toList();
    }

    if (_searchQuery.isNotEmpty) {
      final searchLower = _searchQuery.toLowerCase();
      filtered = filtered
          .where((cp) =>
        cp.name.toLowerCase().contains(searchLower) ||
            cp.city.toLowerCase().contains(searchLower) ||
            cp.status.toLowerCase().contains(searchLower),
      )
          .toList();
    }

    // Apply active filters - محسّن
    if (_activeFilters.isNotEmpty) {
      if (_activeFilters.length == 1 && _activeFilters.contains('favorites')) {
        filtered = filtered.where((cp) => favoriteIds.contains(cp.id)).toList();
      } else {
        final Set<Checkpoint> results = <Checkpoint>{};
        
        if (_activeFilters.contains('favorites')) {
          results.addAll(filtered.where((cp) => favoriteIds.contains(cp.id)));
        }
        
        // فلاتر الحالة - محسّن
        final statusesToShow = <String>[];
        if (_activeFilters.contains('open')) {
          statusesToShow.addAll(['مفتوح', 'سالكة', 'سالكه', 'سالك']);
        }
        if (_activeFilters.contains('closed')) {
          statusesToShow.add('مغلق');
        }
        if (_activeFilters.contains('congestion')) {
          statusesToShow.add('ازدحام');
        }
        if (_activeFilters.contains('checkpoint')) {
          statusesToShow.add('حاجز');
        }
        
        if (statusesToShow.isNotEmpty) {
          results.addAll(filtered.where((cp) =>
              statusesToShow.any((status) =>
                  cp.status.toLowerCase().contains(status.toLowerCase())
              )
          ));
        }
        
        filtered = results.toList();
      }
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

    // تحسين الترتيب
    filtered.sort((a, b) {
      // أولوية للمفضلة
      final aIsFavorite = favoriteIds.contains(a.id);
      final bIsFavorite = favoriteIds.contains(b.id);
      if (aIsFavorite && !bIsFavorite) return -1;
      if (!aIsFavorite && bIsFavorite) return 1;

      // ثم ترتيب حسب التاريخ (الأحدث أولاً)
      final aTime = a.effectiveAtDateTime ?? a.updatedAtDateTime;
      final bTime = b.effectiveAtDateTime ?? b.updatedAtDateTime;
      
      if (aTime != null && bTime != null) {
        return bTime.compareTo(aTime);
      }
      if (aTime == null && bTime != null) return 1;
      if (aTime != null && bTime == null) return -1;
      
      // ترتيب حسب الحالة كمعيار أخير
      const statusPriority = {
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

    // حفظ النتيجة في الكاش
    _cachedFilteredCheckpoints = filtered;
    _lastFilterState = currentFilterState;

    return filtered;
  }


  String formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "الآن";
    if (diff.inMinutes < 60) return "قبل ${diff.inMinutes} د";
    if (diff.inHours < 24) return "قبل ${diff.inHours} س";
    return "قبل ${diff.inDays} يوم";
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
        // استخدام اللون المخصص للمغلق
        color = Color(_customColors['closedColor'] ?? 0xFFF44336);
        break;
      case 'congestion':
        // استخدام اللون المخصص للازدحام
        color = Color(_customColors['congestionColor'] ?? 0xFFFF9800);
        break;
      case 'open':
        // استخدام اللون المخصص للسالك
        color = Color(_customColors['openColor'] ?? 0xFF4CAF50);
        break;
      case 'checkpoint':
        // استخدام اللون المخصص للحاجز
        color = Color(_customColors['checkpointColor'] ?? 0xFF9C27B0);
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
            splashColor: color.withValues(alpha: 0.3),
            highlightColor: color.withValues(alpha: 0.2),
            onTap: () async {
              // Add haptic feedback for better user experience
              if (filterId == 'favorites') {
                HapticFeedback.selectionClick();
              } else {
                HapticFeedback.lightImpact();
              }
              
              setState(() {
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
                if (_activeFilters.contains('checkpoint')) statusFilters.add('حاجز');
                if (_activeFilters.contains('open')) {
                  statusFilters.addAll(['مفتوح', 'سالكة', 'سالكه', 'سالك']);
                }
                
                _quickStatusFilter = statusFilters.isEmpty ? null : statusFilters;
              });
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color),
                boxShadow: isSelected && filterId == 'favorites' ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ] : null,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (filterId == 'favorites') ...[
                    Icon(
                      isSelected ? Icons.favorite : Icons.favorite_border,
                      size: 14,
                      color: isSelected ? Colors.white : color,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : color,
                    ),
                  ),
                ],
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
                    _buildQuickFilterButton('المفضلة', 'favorites'),
                    _buildQuickFilterButton('سالك', 'open'),
                    _buildQuickFilterButton('مغلق', 'closed'),
                    _buildQuickFilterButton('ازدحام', 'congestion'),
                    _buildQuickFilterButton('حاجز', 'checkpoint'),
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
                    // تحسينات الأداء
                    cacheExtent: 500.0,
                    addAutomaticKeepAlives: false,
                    addRepaintBoundaries: false,
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

                      return RepaintBoundary(
                        child: GestureDetector(
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