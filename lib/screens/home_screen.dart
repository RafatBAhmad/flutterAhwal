
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback toggleTheme;
  final ThemeMode themeMode;

  const HomeScreen({super.key, required this.toggleTheme, required this.themeMode});

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
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  String notificationStatusMessage = "";
  final ScrollController _scrollController = ScrollController();
  int newItemsCount = 0;
  List<Checkpoint> lastDisplayed = [];
  int lastReadIndex = 0;

  @override
  void initState() {
    super.initState();
    initNotifications();
    loadFavorites();
    loadNotificationSetting();
    loadLastReadIndex();
    fetchCheckpoints();
    startAutoRefresh();
  }

  void initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings = InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  void showNotification(String title, String body) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'checkpoint_channel',
      'Checkpoint Updates',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);
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
      } else {
        favoriteIds.add(id);
      }
      prefs.setStringList('favorites', favoriteIds.toList());
    });
  }

  Future<void> loadNotificationSetting() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
    });
  }

  Future<void> loadLastReadIndex() async {
    final prefs = await SharedPreferences.getInstance();
    lastReadIndex = prefs.getInt('lastReadMessageIndex') ?? 0;
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  void startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      fetchCheckpoints();
    });
  }

  Future<void> fetchCheckpoints() async {
    try {
      final data = await ApiService.getAllCheckpoints();
      detectChanges(data);

      setState(() {
        allCheckpoints = data;
        cities = data.map((cp) => cp.city).toSet().toList();
        if (!cities.contains("الكل")) {
          cities.insert(0, "الكل");
        }

        final List<Checkpoint> displayedNow = selectedCity == "الكل"
            ? data
            : data.where((cp) => cp.city == selectedCity).toList();

        if (lastDisplayed.isNotEmpty && displayedNow.length > lastDisplayed.length) {
          newItemsCount = displayedNow.length - lastDisplayed.length;
        }
        lastDisplayed = displayedNow;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.jumpTo(lastReadIndex * 130.0);
        }
      });

      Fluttertoast.showToast(
        msg: "✅ تم تحديث البيانات",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ فشل الاتصال بالخادم",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
    }
  }

  void detectChanges(List<Checkpoint> newData) {
    for (final cp in newData) {
      if (favoriteIds.contains(cp.id)) {
        final prev = lastFavoriteStatuses[cp.id];
        if (notificationsEnabled && prev != null && prev != cp.status) {
          showNotification("📢 تحديث حالة حاجز", "${cp.name} أصبح ${cp.status}");
        }
        lastFavoriteStatuses[cp.id] = cp.status;
      }
    }
  }

  String formatRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "قبل ثوانٍ";
    if (diff.inMinutes < 60) return "قبل ${diff.inMinutes} دقيقة";
    return "قبل ${diff.inHours} ساعة";
  }

  Color getStatusColor(String status) {
    switch (status) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
        return Colors.green;
      case 'مغلق':
        return Colors.red;
      case 'ازدحام':
        return Colors.orange;
      default:
        return Colors.grey;
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
    await prefs.setInt('lastReadMessageIndex', lastDisplayed.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    List<Checkpoint> displayed = selectedCity == "الكل"
        ? allCheckpoints
        : allCheckpoints.where((cp) => cp.city == selectedCity).toList();

    DateTime? latestUpdate = displayed
        .where((c) => c.updatedAt != null)
        .map((c) => c.updatedAtDateTime)
        .where((dt) => dt != null)
        .cast<DateTime>()
        .fold<DateTime?>(null, (prev, el) => prev == null || el.isAfter(prev) ? el : prev);

    return Scaffold(
      appBar: AppBar(
        title: const Text('أحوال الطرق'),
        actions: [
          IconButton(
            icon: Icon(
              notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
              color: Colors.amber,
            ),
            tooltip: notificationsEnabled ? 'إيقاف التنبيهات' : 'تشغيل التنبيهات',
            onPressed: () async {
              final prefs = await SharedPreferences.getInstance();
              setState(() {
                notificationsEnabled = !notificationsEnabled;
              });
              await prefs.setBool('notifications_enabled', notificationsEnabled);
              bool? hasVibrator = await Vibration.hasVibrator();
              if (notificationsEnabled && (hasVibrator ?? false)) {
                Vibration.vibrate(duration: 100);
              }

            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (latestUpdate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text("آخر تحديث: ${formatRelativeTime(latestUpdate)}",
                      style: Theme.of(context).textTheme.bodySmall),
                ),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: DropdownButton<String>(
                  value: selectedCity,
                  isExpanded: true,
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
              Expanded(
                child: RefreshIndicator(
                  onRefresh: fetchCheckpoints,
                  child: ListView.builder(
                    controller: _scrollController,
                    itemCount: displayed.length + 1,
                    itemBuilder: (context, index) {
                      if (index == displayed.length) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Center(
                            child: ElevatedButton.icon(
                              onPressed: fetchCheckpoints,
                              icon: const Icon(Icons.refresh),
                              label: const Text("تحديث"),
                            ),
                          ),
                        );
                      }
                      final cp = displayed[index];
                      final isFavorite = favoriteIds.contains(cp.id);
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        child: ListTile(
                          leading: IconButton(
                            icon: Icon(
                              isFavorite ? Icons.star : Icons.star_border,
                              color: isFavorite ? Colors.amber : Colors.grey,
                            ),
                            onPressed: () => toggleFavorite(cp.id),
                          ),
                          title: Text(cp.name,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                              textDirection: TextDirection.rtl),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("المدينة: ${cp.city}", textDirection: TextDirection.rtl),
                              Text("الحالة: ${cp.status}",
                                  style: TextStyle(color: getStatusColor(cp.status)),
                                  textDirection: TextDirection.rtl),
                              if (cp.updatedAt != null)
                                Text("آخر تحديث: ${formatDateTime(cp.updatedAt)}",
                                    textDirection: TextDirection.rtl),
                              if (cp.sourceText.isNotEmpty)
                                Text("النص: ${cp.sourceText}",
                                    style: TextStyle(color: Colors.grey[600]),
                                    textDirection: TextDirection.rtl),
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
          if (newItemsCount > 0)
            Positioned(
              bottom: 20,
              right: 20,
              child: FloatingActionButton.extended(
                onPressed: () {
                  scrollToBottom();
                  setState(() => newItemsCount = 0);
                },
                label: Text('$newItemsCount جديد'),
                icon: const Icon(Icons.arrow_downward),
              ),
            ),
        ],
      ),
    );
  }
}
