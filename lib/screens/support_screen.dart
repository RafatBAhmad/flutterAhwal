import 'package:flutter/material.dart';

class SupportScreen extends StatelessWidget {
  const SupportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('الدعم والإعلانات'),
      ),
      body: const SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'مرحباً بك في صفحة الدعم والإعلانات!',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 16),
            Text(
              'هذه الصفحة مخصصة لعرض معلومات الدعم، بالإضافة إلى عرض الإعلانات التي تساعد في استمرارية تطوير التطبيق وتقديم خدمة أفضل لكم.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 24),
            Text(
              'للدعم الفني أو للاستفسارات:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 8),
            ListTile(
              leading: Icon(Icons.email),
              title: Text('تواصل معنا عبر البريد الإلكتروني'),
              subtitle: Text('rafat.b.ahmad@gmial.com'),
            /*  onTap: () {
                // TODO: إضافة منطق لفتح تطبيق البريد الإلكتروني
              },*/
            ),
            ListTile(
              leading: Icon(Icons.phone),
              title: Text('تواصل معنا عبر الهاتف'),
              subtitle: Text('+970 598662581'),
             /* onTap: () {
                // TODO: إضافة منطق لفتح تطبيق الاتصال
              },*/
            ),
            SizedBox(height: 24),
            Text(
              'الإعلانات:',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.right,
            ),
            SizedBox(height: 8),
            Text(
              'نحن نستخدم الإعلانات لدعم التطوير المستمر وتقديم ميزات جديدة. شكراً لدعمكم!',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.right,
            ),
            // TODO: هنا يمكنك إضافة إعلانات بانر أو إعلانات أصلية إضافية إذا أردت
            // مثال:
            // AdWidget(ad: myBannerAd),
            // NativeAdWidget(),
          ],
        ),
      ),
    );
  }
}
