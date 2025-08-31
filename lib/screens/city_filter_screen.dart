import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/checkpoint_statistics_utils.dart';
import '../utils/data_filter_utils.dart';

class CityFilterScreen extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const CityFilterScreen({
    super.key,
    this.onRefreshRequested,
  });

  @override
  State<CityFilterScreen> createState() => _CityFilterScreenState();
}

class _CityFilterScreenState extends State<CityFilterScreen> {
  List<Checkpoint> allCheckpoints = [];
  Map<String, List<Checkpoint>> checkpointsByCity = {};
  bool isLoading = true;
  String? selectedCity;

  @override
  void initState() {
    super.initState();
    loadCheckpoints();
  }




  // Public refresh method for main navigation
  void refreshData() {
    if (!isLoading) {
      loadCheckpoints();
      widget.onRefreshRequested?.call();
    }
  }


  Future<void> loadCheckpoints() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      debugPrint('🔄 CityFilter: بدء تحميل البيانات...');

      // محاولة تحميل من الكاش أولاً
      final cachedData = await CacheService.getCachedCheckpoints();
      
      if (cachedData != null && cachedData.isNotEmpty) {
        // استخدام الكاش فوراً
        _processAndDisplayData(cachedData);
        debugPrint('📋 CityFilter: تم تحميل من الكاش (${cachedData.length} حاجز)');
        
        // تحديث في الخلفية
        _backgroundRefresh();
        return;
      }

      // إذا لم يكن هناك كاش، تحميل من API
      final data = await _fetchDataFromAPI();
      
      // حفظ في الكاش
      if (data.isNotEmpty) {
        await CacheService.cacheCheckpoints(data);
      }

      _processAndDisplayData(data);

    } catch (e) {
      debugPrint('❌ CityFilter: خطأ في التحميل: $e');
      setState(() => isLoading = false);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في تحميل البيانات: ${e.toString()}'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
              textColor: Colors.white,
              onPressed: loadCheckpoints,
            ),
          ),
        );
      }
    }
  }

  // استخراج منطق API
  Future<List<Checkpoint>> _fetchDataFromAPI() async {
    try {
      final data = await ApiService.getAllCheckpoints();
      debugPrint('✅ CityFilter: getAllCheckpoints نجح - ${data.length} رسالة');
      return data;
    } catch (e) {
      debugPrint('❌ CityFilter: getAllCheckpoints فشل: $e');

      try {
        final data = await ApiService.getLatestCheckpointsOnly();
        debugPrint('✅ CityFilter: getLatestCheckpointsOnly نجح');
        return data;
      } catch (e2) {
        debugPrint('❌ CityFilter: getLatestCheckpointsOnly فشل: $e2');

        final data = await ApiService.fetchLatestOnly();
        debugPrint('✅ CityFilter: fetchLatestOnly نجح');
        return data;
      }
    }
  }

  // تحديث في الخلفية
  Future<void> _backgroundRefresh() async {
    try {
      final data = await _fetchDataFromAPI();
      
      if (data.isNotEmpty) {
        await CacheService.cacheCheckpoints(data);
        _processAndDisplayData(data);
      }
    } catch (e) {
      debugPrint('Background refresh failed: $e');
    }
  }

  // معالجة وعرض البيانات
  void _processAndDisplayData(List<Checkpoint> data) {
    if (!mounted) return;

    // 🔥 تطبيق فلترة الحواجز الحديثة (خلال يومين فقط)
    final recentCheckpoints = DataFilterUtils.filterRecentCheckpoints(data, maxHours: 48);
    debugPrint(
        '🔄 CityFilter: تم فلترة ${recentCheckpoints.length} حاجز من أصل ${data
            .length} (خلال يومين)');

    final Map<String, List<Checkpoint>> cityGroups = {};
    for (final checkpoint in recentCheckpoints) {
      final city = checkpoint.city == "غير معروف" ? "أخرى" : checkpoint.city;
      cityGroups[city] = cityGroups[city] ?? [];
      cityGroups[city]!.add(checkpoint);
    }

    // ترتيب الحواجز في كل مدينة حسب آخر تحديث
    for (final cityCheckpoints in cityGroups.values) {
      cityCheckpoints.sort((a, b) {
        final dateA = a.effectiveAtDateTime ?? a.updatedAtDateTime;
        final dateB = b.effectiveAtDateTime ?? b.updatedAtDateTime;

        if (dateA == null && dateB == null) return 0;
        if (dateA == null) return 1;
        if (dateB == null) return -1;

        return dateB.compareTo(dateA); // الأحدث أولاً
      });
    }

    setState(() {
      allCheckpoints = recentCheckpoints;
      checkpointsByCity = cityGroups;
      isLoading = false;
    });

    debugPrint('✅ CityFilter: تم تحميل ${cityGroups.length} مدن بنجاح');
  }


  Widget _buildCityCard(String cityName, CheckpointStatistics stats,
      List<Checkpoint> checkpoints) {
    // 🔥 فلترة إضافية للتأكد من أن الحواجز حديثة
    final recentCheckpoints = DataFilterUtils.filterRecentCheckpoints(checkpoints, maxHours: 48);

    if (recentCheckpoints.isEmpty) {
      // لا تعرض المدينة إذا لم تكن لديها حواجز حديثة
      return const SizedBox.shrink();
    }

    // إعادة حساب الإحصائيات للحواجز الحديثة فقط
    final recentStats = CheckpointStatisticsUtils.calculateStatistics(
        recentCheckpoints);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () =>
            setState(() {
              selectedCity = selectedCity == cityName ? null : cityName;
            }),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                cityName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                                textDirection: TextDirection.rtl,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${recentCheckpoints.length} حاجز محدث خلال يومين',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    selectedCity == cityName
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Theme
                        .of(context)
                        .primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildCityStatusCard('سالك', Colors.green, recentStats.open),
                  _buildCityStatusCard('مغلق', Colors.red, recentStats.closed),
                  _buildCityStatusCard(
                      'ازدحام', Colors.orange, recentStats.congestion),
                ],
              ),
              if (selectedCity == cityName) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ...recentCheckpoints.map((checkpoint) =>
                    _buildCheckpointTile(checkpoint)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget buildSummarySection() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (allCheckpoints.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.info_outline, size: 48, color: Colors.grey),
              SizedBox(height: 8),
              Text(
                'لا توجد حواجز محدثة خلال اليومين الماضيين',
                style: TextStyle(fontSize: 16, color: Colors.grey),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final allStats = CheckpointStatisticsUtils.calculateStatisticsByCity(
        allCheckpoints);
    final citySummaries = allStats.entries.map((e) =>
    {
      'city': e.key,
      'stats': e.value,
    }).toList();

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: citySummaries.length,
        itemBuilder: (_, index) {
          final summary = citySummaries[index];
          final cityName = summary['city'] as String;
          final stats = summary['stats'] as CheckpointStatistics;
          final cityCheckpoints = checkpointsByCity[cityName] ?? [];

          return Container(
            width: 140,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme
                      .of(context)
                      .primaryColor
                      .withValues(alpha: 0.1),
                  Theme
                      .of(context)
                      .primaryColor
                      .withValues(alpha: 0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Theme
                    .of(context)
                    .primaryColor
                    .withValues(alpha: 0.2),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cityName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildMiniStatusIndicator('س', Colors.green, stats.open),
                    _buildMiniStatusIndicator('م', Colors.red, stats.closed),
                    _buildMiniStatusIndicator(
                        'ز', Colors.orange, stats.congestion),
                  ],
                ),
                const Spacer(),
                Text(
                  '${cityCheckpoints.length} حاجز',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildMiniStatusIndicator(String label, Color color, int count) {
    return Column(
      children: [
        Container(
          width: 24,
          height: 20,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.3)),
          ),
          child: Center(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          '$count',
          style: TextStyle(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  Widget _buildCityStatusCard(String status, Color color, int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _buildCheckpointTile(Checkpoint checkpoint) {
    final statusColor = getStatusColor(checkpoint.status);
    final statusIcon = getStatusIcon(checkpoint.status);
    final lastUpdate = checkpoint.effectiveAtDateTime ??
        checkpoint.updatedAtDateTime;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme
            .of(context)
            .cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(statusIcon, color: statusColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkpoint.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        checkpoint.status,
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (lastUpdate != null)
                      Text(
                        formatRelativeTime(lastUpdate),
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
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

  String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'الآن';
    } else if (difference.inMinutes < 60) {
      return 'منذ ${difference.inMinutes} د';
    } else if (difference.inHours < 24) {
      return 'منذ ${difference.inHours} س';
    } else if (difference.inDays == 1) {
      return 'أمس';
    } else if (difference.inDays < 7) {
      return 'منذ ${difference.inDays} يوم';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cities = checkpointsByCity.keys.toList()
      ..sort();

    return Scaffold(
      body: isLoading
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل البيانات...'),
          ],
        ),
      )
          : allCheckpoints.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.update_disabled,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            const Text(
              'لا توجد حواجز محدثة',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'لم يتم تحديث أي حاجز خلال اليومين الماضيين',
              style: TextStyle(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: loadCheckpoints,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة التحميل'),
            ),
          ],
        ),
      )
          : Column(
        children: [
          // قسم الملخص
          buildSummarySection(),
          const Divider(height: 1),

          // قائمة المدن
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadCheckpoints,
              child: ListView.builder(
                itemCount: cities.length,
                itemBuilder: (context, index) {
                  final cityName = cities[index];
                  final cityCheckpoints = checkpointsByCity[cityName] ?? [];
                  final recentCheckpoints = DataFilterUtils.filterRecentCheckpoints(
                      cityCheckpoints, maxHours: 48);

                  // تخطي المدن التي لا تحتوي على حواجز حديثة
                  if (recentCheckpoints.isEmpty) {
                    return const SizedBox.shrink();
                  }

                  final stats = CheckpointStatisticsUtils.calculateStatistics(
                      recentCheckpoints);
                  return _buildCityCard(cityName, stats, recentCheckpoints);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}