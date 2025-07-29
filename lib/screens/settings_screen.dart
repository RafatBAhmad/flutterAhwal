import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:vibration/vibration.dart';

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
            color: Theme.of(context).primaryColor.withOpacity(0.1),
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
              final prefs = await SharedPreferences.getInstance();
              await prefs.clear();
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
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
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'test_channel',
      'Test Notifications',
      channelDescription: 'تجربة التنبيهات',
      importance: Importance.max,
      priority: Priority.high,
    );
    const NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

    final FlutterLocalNotificationsPlugin notifications = FlutterLocalNotificationsPlugin();
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

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('تم إرسال تنبيه تجريبي'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حول التطبيق', textDirection: TextDirection.rtl),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'تطبيق أحوال الطرق',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 8),
              Text('الإصدار: 1.0.0', textDirection: TextDirection.rtl),
              SizedBox(height: 8),
              Text('تطبيق لمتابعة حالة الحواجز والطرق في الوقت الفعلي', textDirection: TextDirection.rtl),
              SizedBox(height: 16),
              Text(
                'المميزات:',
                style: TextStyle(fontWeight: FontWeight.bold),
                textDirection: TextDirection.rtl,
              ),
              SizedBox(height: 8),
              Text('• تحديث تلقائي للبيانات', textDirection: TextDirection.rtl),
              Text('• إشعارات للحواجز المفضلة', textDirection: TextDirection.rtl),
              Text('• فلترة حسب المدينة', textDirection: TextDirection.rtl),
              Text('• بحث سريع', textDirection: TextDirection.rtl),
              Text('• وضع ليلي ونهاري', textDirection: TextDirection.rtl),
              Text('• إعدادات متقدمة', textDirection: TextDirection.rtl),
              SizedBox(height: 16),
              Text(
                'تم التطوير من قبل فريق ضاد التقني',
                textAlign: TextAlign.center,
                textDirection: TextDirection.rtl,
              ),
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
                    : null, // تم التصحيح هنا: يمكن أن يكون null إذا كان notificationsEnabled خاطئًا
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
                    : null, // تم التصحيح هنا
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
                    : null, // تم التصحيح هنا
              ),
            ),
            _buildSettingTile(
              title: 'تجربة التنبيه',
              subtitle: 'إرسال تنبيه تجريبي',
              icon: Icons.notifications_active,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: notificationsEnabled ? _testNotification : null,
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

            // قسم البيانات
            _buildSectionHeader('البيانات'),
            _buildSettingTile(
              title: 'مسح الذاكرة المؤقتة',
              subtitle: 'حذف البيانات المحفوظة والمفضلة',
              icon: Icons.delete_sweep,
              trailing: const Icon(Icons.arrow_forward_ios, color: Colors.red),
              onTap: _clearCache,
            ),

            // قسم معلومات التطبيق
            _buildSectionHeader('معلومات التطبيق'),
            _buildSettingTile(
              title: 'حول التطبيق',
              subtitle: 'الإصدار والمطور',
              icon: Icons.info_outline,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: _showAboutDialog,
            ),
            _buildSettingTile(
              title: 'تقييم التطبيق',
              subtitle: 'شاركنا رأيك في المتجر',
              icon: Icons.star_rate,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('شكراً لك! سيتم توجيهك للمتجر قريباً'),
                    backgroundColor: Colors.blue,
                  ),
                );
              },
            ),
            _buildSettingTile(
              title: 'مشاركة التطبيق',
              subtitle: 'انشر التطبيق مع أصدقائك',
              icon: Icons.share,
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('سيتم إضافة خاصية المشاركة قريباً'),
                    backgroundColor: Colors.blue,
                  ),
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
                    'لمتابعة أحوال الطرق والحواجز في الوقت الفعلي',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'الإصدار 1.0.0',
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

