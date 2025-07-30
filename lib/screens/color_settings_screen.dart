import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class ColorSettingsScreen extends StatefulWidget {
  const ColorSettingsScreen({super.key});

  @override
  State<ColorSettingsScreen> createState() => _ColorSettingsScreenState();
}

class _ColorSettingsScreenState extends State<ColorSettingsScreen> {
  late Color openColor;
  late Color closedColor;
  late Color congestionColor;

  bool isLoading = true;

  // ألوان محددة مسبقاً
  final List<Color> predefinedColors = [
    Colors.green,
    Colors.lightGreen,
    Colors.teal,
    Colors.blue,
    Colors.cyan,
    Colors.red,
    Colors.pink,
    Colors.deepOrange,
    Colors.orange,
    Colors.amber,
    Colors.yellow,
    Colors.purple,
    Colors.indigo,
    Colors.brown,
    Colors.grey,
  ];

  @override
  void initState() {
    super.initState();
    loadColors();
  }

  Future<void> loadColors() async {
    setState(() => isLoading = true);

    try {
      final colors = await CacheService.getCustomColors();
      setState(() {
        openColor = Color(colors['openColor']!);
        closedColor = Color(colors['closedColor']!);
        congestionColor = Color(colors['congestionColor']!);
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        openColor = Colors.green;
        closedColor = Colors.red;
        congestionColor = Colors.orange;
        isLoading = false;
      });
    }
  }

  Future<void> saveColors() async {
    final colors = {
      'openColor': openColor.value,
      'closedColor': closedColor.value,
      'congestionColor': congestionColor.value,
    };

    await CacheService.saveCustomColors(colors);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم حفظ الألوان بنجاح'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> resetToDefaults() async {
    setState(() {
      openColor = Colors.green;
      closedColor = Colors.red;
      congestionColor = Colors.orange;
    });

    await saveColors();
  }

  void showColorPicker(String statusType, Color currentColor) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'اختر لون $statusType',
          textDirection: TextDirection.rtl,
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 5,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: predefinedColors.length,
            itemBuilder: (context, index) {
              final color = predefinedColors[index];
              final isSelected = color.value == currentColor.value;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    switch (statusType) {
                      case 'سالك':
                        openColor = color;
                        break;
                      case 'مغلق':
                        closedColor = color;
                        break;
                      case 'ازدحام':
                        congestionColor = color;
                        break;
                    }
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(8),
                    border: isSelected
                        ? Border.all(color: Colors.white, width: 3)
                        : null,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.2),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: isSelected
                      ? const Icon(
                    Icons.check,
                    color: Colors.white,
                    size: 20,
                  )
                      : null,
                ),
              );
            },
          ),
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

  Widget _buildColorCard(String title, Color color, String statusType) {
    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => showColorPicker(statusType, color),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'اضغط للتغيير',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 12,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.edit,
                    color: Colors.grey,
                    size: 20,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: color.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _getStatusIcon(statusType),
                      color: color,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      statusType,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
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
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('إعدادات الألوان'),
        centerTitle: true,
        actions: [
          TextButton(
            onPressed: resetToDefaults,
            child: const Text(
              'الافتراضي',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // مقدمة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.palette,
                    color: Theme.of(context).primaryColor,
                    size: 32,
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'خصص ألوان حالة الحواجز',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'اختر الألوان التي تفضلها لكل حالة',
                    style: TextStyle(fontSize: 14),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // إعدادات الألوان
            Text(
              '🎨 إعدادات الألوان',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),

            _buildColorCard('حالة سالك/مفتوح', openColor, 'سالك'),
            const SizedBox(height: 12),
            _buildColorCard('حالة مغلق', closedColor, 'مغلق'),
            const SizedBox(height: 12),
            _buildColorCard('حالة ازدحام', congestionColor, 'ازدحام'),

            const SizedBox(height: 24),

            // معاينة
            Text(
              '👁️ معاينة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 16),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'مثال على الحواجز:',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                    const SizedBox(height: 12),

                    _buildPreviewItem('حاجز القدس', 'سالك', openColor),
                    const SizedBox(height: 8),
                    _buildPreviewItem('حاجز الخليل', 'مغلق', closedColor),
                    const SizedBox(height: 8),
                    _buildPreviewItem('حاجز رام الله', 'ازدحام', congestionColor),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // أزرار الحفظ والإلغاء
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      await saveColors();
                      if (mounted) {
                        Navigator.pop(context, true);
                      } // إرجاع true للإشارة للتحديث
                    },
                    icon: const Icon(Icons.save),
                    label: const Text('حفظ التغييرات'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.cancel),
                    label: const Text('إلغاء'),
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

            const SizedBox(height: 16),

            // ملاحظة
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.amber.withValues(alpha: 0.3),
                ),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.lightbulb_outline,
                    color: Colors.amber,
                    size: 20,
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'ملاحظة: ستطبق الألوان الجديدة على جميع أجزاء التطبيق بعد الحفظ',
                      style: TextStyle(fontSize: 12),
                      textDirection: TextDirection.rtl,
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

  Widget _buildPreviewItem(String name, String status, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getStatusIcon(status),
            color: color,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: color,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}