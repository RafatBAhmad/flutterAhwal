import 'package:url_launcher/url_launcher.dart';
import 'package:fluttertoast/fluttertoast.dart';

class UrlLauncherHelper {

  // 🔥 فتح تطبيق Gmail لإرسال إيميل
  static Future<void> openEmail(String email, {String? subject, String? body}) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        if (subject != null) 'subject': subject,
        if (body != null) 'body': body,
      },
    );

    try {
      if (await canLaunchUrl(emailUri)) {
        await launchUrl(
          emailUri,
          mode: LaunchMode.externalApplication, // فتح في تطبيق خارجي
        );
      } else {
        // إذا فشل، جرب Gmail مباشرة
        await _openGmailDirect(email, subject: subject, body: body);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ لا يمكن فتح تطبيق البريد الإلكتروني',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 فتح Gmail مباشرة
  static Future<void> _openGmailDirect(String email, {String? subject, String? body}) async {
    String gmailUrl = 'googlegmail://co?to=$email';

    if (subject != null) {
      gmailUrl += '&subject=${Uri.encodeComponent(subject)}';
    }

    if (body != null) {
      gmailUrl += '&body=${Uri.encodeComponent(body)}';
    }

    final Uri gmailUri = Uri.parse(gmailUrl);

    try {
      if (await canLaunchUrl(gmailUri)) {
        await launchUrl(gmailUri);
      } else {
        throw Exception('Gmail app not found');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ تأكد من تثبيت تطبيق Gmail',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 فتح تطبيق الاتصال
  static Future<void> makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );

    try {
      if (await canLaunchUrl(phoneUri)) {
        await launchUrl(
          phoneUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Cannot make phone calls');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ لا يمكن فتح تطبيق الاتصال',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 فتح WhatsApp
  static Future<void> openWhatsApp(String phoneNumber, {String? message}) async {
    // تنظيف رقم الهاتف (إزالة الرموز والمسافات)
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');

    // إضافة كود الدولة إذا لم يكن موجوداً
    String formattedNumber = cleanNumber;
    if (!cleanNumber.startsWith('+')) {
      // للأرقام الفلسطينية، إضافة كود الدولة +970
      if (cleanNumber.startsWith('0')) {
        formattedNumber = '+970${cleanNumber.substring(1)}';
      } else {
        formattedNumber = '+$cleanNumber';
      }
    }

    // بناء رابط WhatsApp
    String whatsappUrl = 'whatsapp://send?phone=$formattedNumber';

    if (message != null && message.isNotEmpty) {
      whatsappUrl += '&text=${Uri.encodeComponent(message)}';
    }

    final Uri whatsappUri = Uri.parse(whatsappUrl);

    try {
      if (await canLaunchUrl(whatsappUri)) {
        await launchUrl(whatsappUri);
      } else {
        // محاولة فتح WhatsApp Web كبديل
        await _openWhatsAppWeb(formattedNumber, message: message);
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ تأكد من تثبيت تطبيق WhatsApp',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 فتح WhatsApp Web كبديل
  static Future<void> _openWhatsAppWeb(String phoneNumber, {String? message}) async {
    String webUrl = 'https://wa.me/$phoneNumber';

    if (message != null && message.isNotEmpty) {
      webUrl += '?text=${Uri.encodeComponent(message)}';
    }

    final Uri webUri = Uri.parse(webUrl);

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Cannot open WhatsApp Web');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ لا يمكن فتح WhatsApp',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 فتح SMS
  static Future<void> sendSMS(String phoneNumber, {String? message}) async {
    final Uri smsUri = Uri(
      scheme: 'sms',
      path: phoneNumber,
      queryParameters: {
        if (message != null) 'body': message,
      },
    );

    try {
      if (await canLaunchUrl(smsUri)) {
        await launchUrl(
          smsUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Cannot send SMS');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ لا يمكن فتح تطبيق الرسائل',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 فتح موقع ويب
  static Future<void> openWebsite(String url) async {
    // التأكد من وجود http/https
    if (!url.startsWith('http://') && !url.startsWith('https://')) {
      url = 'https://$url';
    }

    final Uri webUri = Uri.parse(url);

    try {
      if (await canLaunchUrl(webUri)) {
        await launchUrl(
          webUri,
          mode: LaunchMode.externalApplication,
        );
      } else {
        throw Exception('Cannot open website');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ لا يمكن فتح الموقع الإلكتروني',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 فتح Google Play Store
  static Future<void> openPlayStore(String packageName) async {
    final Uri playStoreUri = Uri.parse('market://details?id=$packageName');
    final Uri playStoreWebUri = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');

    try {
      if (await canLaunchUrl(playStoreUri)) {
        await launchUrl(playStoreUri);
      } else if (await canLaunchUrl(playStoreWebUri)) {
        await launchUrl(playStoreWebUri, mode: LaunchMode.externalApplication);
      } else {
        throw Exception('Cannot open Play Store');
      }
    } catch (e) {
      Fluttertoast.showToast(
        msg: '❌ لا يمكن فتح متجر Google Play',
        toastLength: Toast.LENGTH_LONG,
      );
    }
  }

  // 🔥 دالة عامة للاختبار
  static Future<void> testAllMethods() async {
    Fluttertoast.showToast(msg: '🧪 اختبار جميع وسائل التواصل...');

    await Future.delayed(const Duration(seconds: 1));
    await openEmail('test@example.com', subject: 'Test Email', body: 'This is a test');

    await Future.delayed(const Duration(seconds: 1));
    await makePhoneCall('+970598662581');

    await Future.delayed(const Duration(seconds: 1));
    await openWhatsApp('+970598662581', message: 'Hello from Tariqi App!');
  }
}