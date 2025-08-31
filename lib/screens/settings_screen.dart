import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../screens/usage_stats_screen.dart';
import '../screens/color_settings_screen.dart';
import '../services/cache_service.dart';
import '../services/favorite_checkpoint_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool notificationsEnabled = true;
  bool autoRefreshEnabled = true;
  bool vibrationEnabled = true;
  int refreshInterval = 5; // بالدقائق
  bool soundEnabled = true;
  String notificationSound = 'default';
  bool onlyFavoritesNotifications = false;
  int _adminTapCount = 0; // عداد للنقرات المخفية

  @override
  void initState() {
    super.initState();
    loadSettings();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      notificationsEnabled = prefs.getBool('notifications_enabled') ?? true;
      autoRefreshEnabled = prefs.getBool('auto_refresh_enabled') ?? true;
      vibrationEnabled = prefs.getBool('vibration_enabled') ?? true;
      refreshInterval = prefs.getInt('refresh_interval') ?? 5;
      soundEnabled = prefs.getBool('sound_enabled') ?? true;
      notificationSound = prefs.getString('notification_sound') ?? 'default';
      onlyFavoritesNotifications = prefs.getBool('only_favorites_notifications') ?? false;
    });
  }

  Future<void> saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
    } else if (value is int) {
      await prefs.setInt(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Widget _buildSettingTile({
    required String title,
    String? subtitle,
    required IconData icon,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: Theme.of(context).primaryColor),
        ),
        title: Text(title, textDirection: TextDirection.rtl),
        subtitle: subtitle != null
            ? Text(subtitle, textDirection: TextDirection.rtl)
            : null,
        trailing: trailing,
        onTap: onTap,
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
        ),
        textDirection: TextDirection.rtl,
      ),
    );
  }

  void _showRefreshIntervalDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('فترة التحديث التلقائي', textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [1, 3, 5, 10, 15, 30].map((minutes) {
            return RadioListTile<int>(
              title: Text('$minutes دقيقة', textDirection: TextDirection.rtl),
              value: minutes,
              groupValue: refreshInterval,
              onChanged: (value) {
                setState(() => refreshInterval = value!);
                saveSetting('refresh_interval', value!);
                Navigator.pop(context);
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
        ],
      ),
    );
  }

  void _clearCache() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسح الذاكرة المؤقتة', textDirection: TextDirection.rtl),
        content: const Text(
          'هل أنت متأكد من مسح جميع البيانات المحفوظة؟ سيتم حذف المفضلة والإعدادات.',
          textDirection: TextDirection.rtl,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              final messenger = ScaffoldMessenger.of(context);

              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();

              navigator.pop();
              messenger.showSnackBar(
                const SnackBar(
                  content: Text('تم مسح الذاكرة المؤقتة'),
                  backgroundColor: Colors.green,
                ),
              );

              // إعادة تحميل الإعدادات الافتراضية
              loadSettings();
            },
            child: const Text('مسح', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _testNotification() async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'تجربة التنبيهات',
      importance: Importance.max,
      priority: Priority.high,
      enableVibration: vibrationEnabled,
      playSound: soundEnabled,
    );
    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
    final messenger = ScaffoldMessenger.of(context);

    await notifications.show(
      999,
      'تجربة التنبيه',
      'هذا تنبيه تجريبي للتأكد من عمل النظام',
      platformDetails,
    );

    if (vibrationEnabled) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 200);
      }
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('تم إرسال تنبيه تجريبي'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _testFavoriteNotification() async {
    final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'favorite_updates',
      'Favorite Checkpoints Updates',
      channelDescription: 'تحديثات الحواجز المفضلة',
      importance: Importance.high,
      priority: Priority.high,
      styleInformation: const BigTextStyleInformation(''),
      enableVibration: vibrationEnabled,
      playSound: soundEnabled,
    );
    final NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
    final messenger = ScaffoldMessenger.of(context);

    await notifications.show(
      998,
      '🔔 تحديث حالة حاجز مفضل',
      'حاجز القدس تغير من مفتوح إلى مغلق\n(هذا تنبيه تجريبي)',
      platformDetails,
    );

    if (vibrationEnabled) {
      final hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(duration: 500);
      }
    }

    messenger.showSnackBar(
      const SnackBar(
        content: Text('تم إرسال تنبيه تجريبي للحواجز المفضلة'),
        backgroundColor: Colors.green,
      ),
    );
  }

  // Build favorite checkpoints section
  Widget _buildFavoriteCheckpointsSection() {
    return FutureBuilder<FavoriteCheckpointUpgradeInfo>(
      future: FavoriteCheckpointService.getUpgradeInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final info = snapshot.data!;
        return Column(
          children: [
            _buildSettingTile(
              title: 'الحواجز المفضلة المستخدمة',
              subtitle: '${info.usedSlots} من ${info.currentSlots} حواجز',
              icon: Icons.gps_fixed,
              trailing: Text(
                '${info.usedSlots}/${info.currentSlots}',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: Theme.of(context).primaryColor,
                ),
              ),
            ),
            if (info.canUnlockMore)
              _buildSettingTile(
                title: 'زيادة عدد الحواجز المفضلة',
                subtitle: 'شاهد إعلان لإضافة ${FavoriteCheckpointService.slotsPerAd} حواجز إضافية',
                icon: Icons.add_circle_outline,
                trailing: const Icon(Icons.play_arrow, color: Colors.green),
                onTap: () {
                  FavoriteCheckpointService.showUpgradeDialog(
                    context,
                    onWatchAd: () => _watchAdForUpgrade(),
                  );
                },
              ),
            _buildResetInfoTile(),
          ],
        );
      },
    );
  }

  Widget _buildResetInfoTile() {
    return FutureBuilder<Map<String, dynamic>>(
      future: _getResetInfo(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox.shrink();
        }

        final resetInfo = snapshot.data!;
        String resetText;
        IconData resetIcon;
        Color resetColor;

        final hoursUntilReset = resetInfo['hoursUntilReset'] as int;
        final minutesUntilReset = resetInfo['minutesUntilReset'] as int;
        final willResetSoon = resetInfo['willResetSoon'] as bool;
        
        if (hoursUntilReset <= 0 && minutesUntilReset <= 0) {
          resetText = 'ستعود المفضلة لـ 3 حواجز قريباً';
          resetIcon = Icons.refresh;
          resetColor = Colors.orange;
        } else if (willResetSoon) {
          resetText = 'إعادة تعيين خلال ${hoursUntilReset}س ${minutesUntilReset}د';
          resetIcon = Icons.schedule;
          resetColor = Colors.orange;
        } else {
          resetText = 'إعادة تعيين خلال ${hoursUntilReset}س ${minutesUntilReset}د';
          resetIcon = Icons.schedule;
          resetColor = Colors.blue;
        }

        return _buildSettingTile(
          title: 'إعادة تعيين يومية',
          subtitle: resetText,
          icon: resetIcon,
          trailing: Icon(Icons.info_outline, color: resetColor),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getResetInfo() async {
    // Since FavoriteCheckpointService doesn't have getResetInfo, 
    // we'll create a simple implementation based on daily reset
    final prefs = await SharedPreferences.getInstance();
    final lastReset = prefs.getInt('checkpoint_last_reset') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;
    final timeDiff = now - lastReset;
    const resetIntervalMs = 24 * 60 * 60 * 1000; // 24 hours in milliseconds
    
    final timeUntilReset = resetIntervalMs - timeDiff;
    final hoursUntilReset = (timeUntilReset / (60 * 60 * 1000)).floor();
    final minutesUntilReset = ((timeUntilReset % (60 * 60 * 1000)) / (60 * 1000)).floor();
    
    return {
      'hoursUntilReset': hoursUntilReset > 0 ? hoursUntilReset : 0,
      'minutesUntilReset': minutesUntilReset > 0 ? minutesUntilReset : 0,
      'willResetSoon': hoursUntilReset <= 2,
    };
  }

  Future<void> _watchAdForUpgrade() async {
    await FavoriteCheckpointService.showRewardAdForUpgrade(context);
    // Refresh the page to update the counters
    setState(() {});
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول طريقي', textDirection: TextDirection.rtl),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'طريقي - دليل الطرق الذكي',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 8),
              Text('الإصدار: 1.0.8', textDirection: TextDirection.rtl),
              SizedBox(height: 8),
              Text('تطبيق نمط حياة ذكي لتحسين تجربة السفر والتنقل اليومي في فلسطين.', textDirection: TextDirection.rtl),
              SizedBox(height: 16),
              Text(
                'المميزات:',
                style: TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 8),
              Text('• مراقبة حالة الطرق في الوقت الفعلي', textDirection: TextDirection.rtl),
              Text('• تنبيهات ذكية للطرق المفضلة', textDirection: TextDirection.rtl),
              Text('• واجهة عربية سهلة الاستخدام', textDirection: TextDirection.rtl),
              Text('• تحسين تجربة السفر اليومي', textDirection: TextDirection.rtl),
              SizedBox(height: 16),
              Text(
                'تم التطوير من قبل فريق ضاد التقني',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
              Text(
                'طريقي يجعل حياتك أسهل!',
                style: TextStyle(fontStyle: FontStyle.italic),
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              final url = 'https://play.google.com/store/apps/details?id=com.tariqi.roads';
              if (await canLaunchUrl(Uri.parse(url))) {
                await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              }
            },
            child: const Text('تقييم التطبيق'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
        ],
      ),
    );
  }

  bool _checkAdminAccess() {
    _adminTapCount++;
    
    // إذا نقر 7 مرات متتالية على "حول التطبيق"
    if (_adminTapCount >= 7) {
      _adminTapCount = 0; // إعادة تعيين العداد
      _showAdminPasswordDialog();
      return true; // منع إظهار نافذة "حول التطبيق"
    }
    
    // إعادة تعيين العداد بعد 3 ثوان من عدم النقر
    Future.delayed(const Duration(seconds: 3), () {
      if (_adminTapCount < 7) {
        _adminTapCount = 0;
      }
    });
    
    return false; // السماح بإظهار نافذة "حول التطبيق"
  }

  void _showAdminPasswordDialog() {
    final TextEditingController passwordController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('دخول لوحة الإدارة', textDirection: TextDirection.rtl),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'أدخل كلمة مرور الإدارة للوصول للوحة التحكم',
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              textDirection: TextDirection.ltr,
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: () {
              final password = passwordController.text.trim();
              if (password == 'rafat94ahmad') { // كلمة المرور المحدثة
                Navigator.pop(context);
                _openAdminDashboard();
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('كلمة مرور خاطئة'),
                    backgroundColor: Colors.red,
                  ),
                );
              }
            },
            child: const Text('دخول'),
          ),
        ],
      ),
    );
  }

  void _openAdminDashboard() async {
    // Railway domain - admin dashboard URL
    const String adminUrl = 'https://backendspringboot-production-46d6.up.railway.app/admin-dashboard.html';
    
    try {
      final Uri url = Uri.parse(adminUrl);
      if (await canLaunchUrl(url)) {
        await launchUrl(
          url,
          mode: LaunchMode.externalApplication, // فتح في المتصفح
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('لا يمكن فتح لوحة الإدارة. تأكد من تشغيل السيرفر.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('خطأ في فتح لوحة الإدارة'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الإعدادات'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // قسم التنبيهات
            _buildSectionHeader('التنبيهات'),
            _buildSettingTile(
              title: 'تفعيل التنبيهات',
              subtitle: notificationsEnabled ? 'مفعل' : 'معطل',
              icon: notificationsEnabled ? Icons.notifications_active : Icons.notifications_off,
              trailing: Switch(
                value: notificationsEnabled,
                onChanged: (value) {
                  setState(() => notificationsEnabled = value);
                  saveSetting('notifications_enabled', value);
                },
              ),
            ),
            _buildSettingTile(
              title: 'تنبيهات المفضلة فقط',
              subtitle: onlyFavoritesNotifications ? 'مفعل' : 'معطل',
              icon: Icons.star,
              trailing: Switch(
                value: onlyFavoritesNotifications,
                onChanged: notificationsEnabled
                    ? (value) {
                  setState(() => onlyFavoritesNotifications = value);
                  saveSetting('only_favorites_notifications', value);
                }
                    : null,
              ),
            ),
            _buildSettingTile(
              title: 'الاهتزاز',
              subtitle: vibrationEnabled ? 'مفعل' : 'معطل',
              icon: Icons.vibration,
              trailing: Switch(
                value: vibrationEnabled,
                onChanged: notificationsEnabled
                    ? (value) {
                  setState(() => vibrationEnabled = value);
                  saveSetting('vibration_enabled', value);
                }
                    : null,
              ),
            ),
            _buildSettingTile(
              title: 'الصوت',
              subtitle: soundEnabled ? 'مفعل' : 'معطل',
              icon: soundEnabled ? Icons.volume_up : Icons.volume_off,
              trailing: Switch(
                value: soundEnabled,
                onChanged: notificationsEnabled
                    ? (value) {
                  setState(() => soundEnabled = value);
                  saveSetting('sound_enabled', value);
                }
                    : null,
              ),
            ),
            _buildSettingTile(
              title: 'تجربة التنبيه',
              subtitle: 'إرسال تنبيه تجريبي',
              icon: Icons.notifications_active,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: notificationsEnabled ? _testNotification : null,
            ),
            _buildSettingTile(
              title: 'تجربة تنبيه الحواجز المفضلة',
              subtitle: 'محاكاة تغيير حالة حاجز مفضل',
              icon: Icons.favorite_border,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: notificationsEnabled ? _testFavoriteNotification : null,
            ),

            // قسم التحديث
            _buildSectionHeader('التحديث التلقائي'),
            _buildSettingTile(
              title: 'التحديث التلقائي',
              subtitle: autoRefreshEnabled ? 'مفعل' : 'معطل',
              icon: autoRefreshEnabled ? Icons.refresh : Icons.refresh_outlined,
              trailing: Switch(
                value: autoRefreshEnabled,
                onChanged: (value) {
                  setState(() => autoRefreshEnabled = value);
                  saveSetting('auto_refresh_enabled', value);
                },
              ),
            ),
            _buildSettingTile(
              title: 'فترة التحديث',
              subtitle: autoRefreshEnabled ? 'كل $refreshInterval دقيقة' : 'معطل',
              icon: Icons.timer,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: autoRefreshEnabled ? _showRefreshIntervalDialog : null,
            ),

            // قسم الحواجز المفضلة
            _buildSectionHeader('الحواجز المفضلة'),
            _buildFavoriteCheckpointsSection(),

            // قسم التخصيص
            _buildSectionHeader('التخصيص'),
            _buildSettingTile(
              title: 'إعدادات الألوان',
              subtitle: 'تخصيص ألوان حالة الحواجز',
              icon: Icons.palette,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ColorSettingsScreen()),
                );
                if (result == true) {
                  // تم حفظ الألوان، يمكن إضافة تحديث هنا
                }
              },
            ),
            _buildSettingTile(
              title: 'إحصائيات الاستخدام',
              subtitle: 'عرض تفاصيل استخدام التطبيق',
              icon: Icons.analytics,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const UsageStatsScreen()),
                );
              },
            ),

            // قسم البيانات
            _buildSectionHeader('البيانات'),
            _buildSettingTile(
              title: 'مسح الذاكرة المؤقتة',
              subtitle: 'حذف البيانات المحفوظة والمفضلة',
              icon: Icons.delete_sweep,
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
              onTap: _clearCache,
            ),
            _buildSettingTile(
              title: 'مسح تاريخ البحث',
              subtitle: 'حذف جميع عمليات البحث المحفوظة',
              icon: Icons.history,
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.orange),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('مسح تاريخ البحث', textDirection: TextDirection.rtl),
                    content: const Text(
                      'هل تريد مسح تاريخ البحث؟',
                      textDirection: TextDirection.rtl,
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('إلغاء'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          final messenger = ScaffoldMessenger.of(context);

                          navigator.pop();
                          await CacheService.clearSearchHistory();

                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('تم مسح تاريخ البحث'),
                              backgroundColor: Colors.green,
                            ),
                          );
                        },
                        child: const Text('مسح', style: TextStyle(color: Colors.red)),
                      ),
                    ],
                  ),
                );
              },
            ),

            // قسم معلومات التطبيق
            _buildSectionHeader('معلومات التطبيق'),
            _buildSettingTile(
              title: 'حول التطبيق',
              subtitle: 'الإصدار والمطور',
              icon: Icons.info_outline,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                // فحص الوصول للإدارة أولاً، إذا كانت النقرة السابعة لا تظهر نافذة "حول التطبيق"
                if (!_checkAdminAccess()) {
                  _showAboutDialog();
                }
              },
            ),
            _buildSettingTile(
              title: 'تقييم التطبيق',
              subtitle: 'شاركنا رأيك في Google Play',
              icon: Icons.star_rate,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                final url = 'https://play.google.com/store/apps/details?id=com.tariqi.roads';
                if (await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('تعذر فتح متجر Google Play'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
            ),
            _buildSettingTile(
              title: 'مشاركة التطبيق',
              subtitle: 'انشر التطبيق مع أصدقائك',
              icon: Icons.share,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                Share.share(
                  'جرب تطبيق أحوال الطرق - تطبيق ذكي لمتابعة حالة الطرق والحواجز في فلسطين\n\nحمل التطبيق من Google Play:\nhttps://play.google.com/store/apps/details?id=com.tariqi.roads',
                  subject: 'تطبيق أحوال الطرق',
                );
              },
            ),

            // مساحة إضافية في الأسفل
            const SizedBox(height: 32),

            // معلومات إضافية
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Divider(),
                  const SizedBox(height: 16),
                  Text(
                    'تطبيق أحوال الطرق',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'لمتابعة أحوال الطرق والحواجز',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'الإصدار 1.0.8',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}