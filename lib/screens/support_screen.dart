import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'dart:async';
import '../services/ad_helper.dart';
import '../services/ad_click_protection.dart';
import '../services/url_launcher_helper.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {

  @override
  void initState() {
    super.initState();
  }


  void _copyToClipboard(String text, String message) {
    Clipboard.setData(ClipboardData(text: text));
    Fluttertoast.showToast(
      msg: message,
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
    );
  }

  void _showDonationDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.favorite, color: Colors.red),
            SizedBox(width: 8),
            Text('ادعم التطبيق', textDirection: TextDirection.rtl),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'إذا كان التطبيق مفيداً لك، يمكنك دعمنا بالطرق التالية:',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 16),
              Text('• تقييم التطبيق في المتجر ⭐', textDirection: TextDirection.rtl),
              Text('• مشاركة التطبيق مع الأصدقاء 📤', textDirection: TextDirection.rtl),
              Text('• إرسال اقتراحاتك وملاحظاتك 💡', textDirection: TextDirection.rtl),
              SizedBox(height: 16),
              Text(
                'شكراً لدعمك المستمر! ❤️',
                textDirection: TextDirection.rtl,
                style: TextStyle(fontWeight: FontWeight.bold),
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

  Widget _buildContactCard(
      BuildContext context, {
        required IconData icon,
        required String title,
        required String subtitle,
        required String value,
        required Color color,
        required VoidCallback onTap,
      }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      child: ListTile(
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          textDirection: TextDirection.rtl,
        ),
        subtitle: Text(
          subtitle,
          textDirection: TextDirection.rtl,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.copy, size: 20),
              onPressed: () => _copyToClipboard(value, 'تم نسخ $title'),
              tooltip: 'نسخ',
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 14,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // رأس الصفحة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).primaryColor,
                    Theme.of(context).primaryColor.withValues(alpha: 0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.support_agent,
                    size: 48,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'مرحباً بك في صفحة الدعم',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'نحن هنا لمساعدتك في أي وقت',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // قسم التواصل
            Text(
              '📞 طرق التواصل',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),

            _buildContactCard(
              context,
              icon: Icons.email,
              title: 'البريد الإلكتروني',
              subtitle: 'للاستفسارات والدعم الفني',
              value: 'apptariqi@gmail.com',
              color: Colors.blue,
              onTap: () async {
                await UrlLauncherHelper.openEmail(
                  'apptariqi@gmail.com',
                  subject: 'استفسار حول تطبيق طريقي',
                  body: 'السلام عليكم،\n\nأود الاستفسار عن:\n\n',
                );
              },
            ),

            _buildContactCard(
              context,
              icon: Icons.phone,
              title: 'رقم الهاتف',
              subtitle: 'للتواصل المباشر',
              value: '+970 598662581',
              color: Colors.green,
              onTap: () async {
                await UrlLauncherHelper.makePhoneCall('+970598662581');
              },
            ),

            _buildContactCard(
              context,
              icon: Icons.message,
              title: 'واتساب',
              subtitle: 'التواصل السريع عبر الواتساب',
              value: '+970 598662581',
              color: Colors.green[700]!,
              onTap: () async {
                await UrlLauncherHelper.openWhatsApp(
                  '+970598662581',
                  message: 'السلام عليكم، أود التواصل بخصوص تطبيق طريقي',
                );
              },
            ),

            const SizedBox(height: 24),

            // قسم مميزات التطبيق
            Text(
              '✨ مميزات التطبيق',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),

            _buildFeatureCard(
              icon: Icons.notifications_active,
              title: 'تنبيهات فورية',
              description: 'اشعارات عند تغير حالة الحواجز المفضلة',
              color: Colors.orange,
            ),

            _buildFeatureCard(
              icon: Icons.auto_awesome,
              title: 'تحديث تلقائي',
              description: 'تحديث البيانات كل 5 دقائق تلقائياً',
              color: Colors.blue,
            ),

            _buildFeatureCard(
              icon: Icons.filter_list,
              title: 'فلترة متقدمة',
              description: 'فلترة حسب المدينة والحالة والمفضلة',
              color: Colors.purple,
            ),

            _buildFeatureCard(
              icon: Icons.dark_mode,
              title: 'وضع ليلي',
              description: 'تجربة مريحة للعينين في الظلام',
              color: Colors.indigo,
            ),

            const SizedBox(height: 24),

            // قسم التقييم
            Text(
              '❤️ ادعم التطبيق',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      // 🔥 فتح Google Play Store للتقييم
                      await UrlLauncherHelper.openPlayStore('com.tariqi.roads');
                    },
                    icon: const Icon(Icons.star),
                    label: const Text('قيّم التطبيق'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // معلومات المطور
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Colors.grey.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 30,
                    backgroundColor: Colors.blue,
                    child: Icon(
                      Icons.code,
                      size: 30,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'فريق ضاد التقني',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'نطور التطبيقات لخدمة المجتمع',
                    style: TextStyle(
                      color: Colors.grey[600],
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'الإصدار 1.0.8',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // 🔥 زر اختبار جميع وسائل التواصل (للتطوير فقط)
            if (AdHelper.isTestMode) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    const Text(
                      '🧪 وضع التطوير',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await UrlLauncherHelper.testAllMethods();
                      },
                      icon: const Icon(Icons.bug_report, size: 16),
                      label: const Text('اختبار جميع وسائل التواصل'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.orange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}