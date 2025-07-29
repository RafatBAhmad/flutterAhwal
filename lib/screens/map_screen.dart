import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../utils/checkpoint_statistics_utils.dart'; // استيراد الكلاس الجديد

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  List<Checkpoint> checkpoints = [];
  bool isLoading = true;
  String? selectedCity;
  List<String> cities = [];
  CheckpointStatistics? currentStatistics; // لتخزين الإحصائيات المحسوبة

  @override
  void initState() {
    super.initState();
    loadCheckpoints();
  }

  Future<void> loadCheckpoints() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.getAllCheckpoints();

      setState(() {
        checkpoints = data;
        cities = CheckpointStatisticsUtils.getAvailableCities(data); // استخدام Utility
        selectedCity = "الكل";
        // حساب الإحصائيات بعد تحميل البيانات
        currentStatistics = CheckpointStatisticsUtils.calculateStatistics(getFilteredCheckpoints());
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("❌ فشل في تحميل البيانات: $e"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Checkpoint> getFilteredCheckpoints() {
    // استخدام Utility لفلترة الحواجز
    return CheckpointStatisticsUtils.filterByCity(checkpoints, selectedCity);
  }

  // هذه الدوال لم تعد ضرورية هنا إذا تم استخدامها فقط لحساب الإحصائيات
  // ولكن يمكن الاحتفاظ بها إذا كانت تستخدم لأغراض عرض أخرى (مثل ألوان الأيقونات)
  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
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

  IconData getStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'مفتوح':
      case 'سالكة':
      case 'سالكه':
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
    final filteredCheckpoints = getFilteredCheckpoints();
    // إعادة حساب الإحصائيات عند تغيير الفلتر
    currentStatistics = CheckpointStatisticsUtils.calculateStatistics(filteredCheckpoints);

    return Scaffold(
      body: Column(
        children: [
          // شريط التحكم
          Container(
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.05),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: selectedCity,
                        decoration: InputDecoration(
                          labelText: 'اختر المدينة',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: cities.map((city) {
                          return DropdownMenuItem(
                            value: city,
                            child: Text(city, textDirection: TextDirection.rtl),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedCity = value;
                            // إعادة حساب الإحصائيات عند تغيير المدينة
                            currentStatistics = CheckpointStatisticsUtils.calculateStatistics(getFilteredCheckpoints());
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: loadCheckpoints,
                      icon: const Icon(Icons.refresh),
                      tooltip: 'تحديث البيانات',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إجمالي الحواجز: ${filteredCheckpoints.length}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (selectedCity != null && selectedCity != "الكل")
                      Text(
                        'في $selectedCity',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),

          // المحتوى الرئيسي
          Expanded(
            child: isLoading
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('جاري تحميل الخريطة...'),
                ],
              ),
            )
                : Column(
              children: [
                // إحصائيات سريعة - استخدام currentStatistics
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'إحصائيات الحواجز',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _buildStatusCard('مفتوح', Colors.green, currentStatistics?.open ?? 0),
                              _buildStatusCard('مغلق', Colors.red, currentStatistics?.closed ?? 0),
                              _buildStatusCard('ازدحام', Colors.orange, currentStatistics?.congestion ?? 0),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // رسالة حول الخريطة
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.map_outlined,
                          size: 80,
                          color: Colors.grey[400],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خريطة الحواجز',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w600,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 8),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'ستكون متاحة قريباً لعرض الحواجز على الخريطة التفاعلية',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 16,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            // يمكن إضافة navigation إلى شاشة القائمة أو التفاصيل
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('الخريطة التفاعلية قيد التطوير'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          },
                          icon: const Icon(Icons.location_on),
                          label: const Text('عرض قائمة الحواجز'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusCard(String title, Color color, int count) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              textDirection: TextDirection.rtl,
            ),
          ],
        ),
      ),
    );
  }
}

