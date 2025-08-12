import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../utils/checkpoint_statistics_utils.dart';

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
  CheckpointStatistics? currentStatistics;

  @override
  void initState() {
    super.initState();
    loadCheckpoints();
  }

  Future<void> loadCheckpoints() async {
    setState(() => isLoading = true);
    try {
      final data = await ApiService.fetchLatestOnly();

      setState(() {
        checkpoints = data;
        cities = CheckpointStatisticsUtils.getAvailableCities(data);
        selectedCity = "الكل";
        currentStatistics =
            CheckpointStatisticsUtils.calculateStatistics(getFilteredCheckpoints());
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
    return CheckpointStatisticsUtils.filterByCity(checkpoints, selectedCity);
  }

  @override
  Widget build(BuildContext context) {
    final filteredCheckpoints = getFilteredCheckpoints();
    currentStatistics =
        CheckpointStatisticsUtils.calculateStatistics(filteredCheckpoints);

    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          // شريط التحكم
          Container(
            padding: const EdgeInsets.all(16),
            color: theme.primaryColor.withValues(alpha: (0.05)),
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
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 8),
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
                            currentStatistics =
                                CheckpointStatisticsUtils.calculateStatistics(
                                    getFilteredCheckpoints());
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'إجمالي الحواجز: ${filteredCheckpoints.length}',
                      style: theme.textTheme.bodySmall,
                    ),
                    if (selectedCity != null && selectedCity != "الكل")
                      Text(
                        'في $selectedCity',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.primaryColor,
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
                // إحصائيات سريعة
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Card(
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    color: theme.cardColor,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.bar_chart,
                                color: theme.primaryColor,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'إحصائيات الحواجز',
                                style: theme.textTheme.titleLarge
                                    ?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment:
                            MainAxisAlignment.spaceEvenly,
                            children: [
                              Expanded(
                                child: _buildCompactStatusCard(
                                    'سالك',
                                    Colors.green,
                                    currentStatistics?.open ?? 0,
                                    theme),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactStatusCard(
                                    'مغلق',
                                    Colors.red,
                                    currentStatistics?.closed ?? 0,
                                    theme),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _buildCompactStatusCard(
                                    'ازدحام',
                                    Colors.orange,
                                    currentStatistics?.congestion ?? 0,
                                    theme),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // رسالة الخريطة
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: theme.cardColor.withValues(alpha: (0.1)),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: theme.dividerColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.map_outlined,
                            size: 80,
                            color: theme.dividerColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خريطة الحواجز التفاعلية',
                          style:
                          theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding:
                          const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'إن شاء الله ستكون متاحة قريباً لعرض الحواجز على الخريطة التفاعلية',
                            textAlign: TextAlign.center,
                            style:
                            theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              fontSize: 16,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton.icon(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content:
                                Text('الخريطة التفاعلية قيد التطوير'),
                                backgroundColor: Colors.lightBlueAccent,
                              ),
                            );
                          },
                          icon: const Icon(Icons.location_on,
                              color: Colors.white),
                          label: const Text(
                            'عرض قائمة الحواجز',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: theme.primaryColor,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 4,
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
      // خلفية من الثيم (فاتح/غامق)
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }

  Widget _buildCompactStatusCard(
      String title, Color color, int count, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: (0.1)),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: (0.3))),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
              color: theme.brightness == Brightness.dark
                  ? Colors.white
                  : Colors.black,
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }
}
