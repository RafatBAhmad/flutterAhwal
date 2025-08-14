import 'package:flutter/material.dart';
import '../services/cache_service.dart';

class UsageStatsScreen extends StatefulWidget {
  const UsageStatsScreen({super.key});

  @override
  State<UsageStatsScreen> createState() => _UsageStatsScreenState();
}

class _UsageStatsScreenState extends State<UsageStatsScreen> {
  Map<String, dynamic> usageStats = {};
  List<String> searchHistory = [];
  List<MapEntry<String, int>> mostViewedCities = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    loadUsageStats();
  }

  Future<void> loadUsageStats() async {
    setState(() => isLoading = true);

    try {
      final stats = await CacheService.getUsageStats();
      final history = await CacheService.getSearchHistory();
      final cities = await CacheService.getMostViewedCities();

      setState(() {
        usageStats = stats;
        searchHistory = history;
        mostViewedCities = cities;
        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
  }

  String _formatLastUsed(String? lastUsedStr) {
    if (lastUsedStr == null) return 'لم يتم التسجيل';

    try {
      final lastUsed = DateTime.parse(lastUsedStr);
      final now = DateTime.now();
      final difference = now.difference(lastUsed);

      if (difference.inDays > 0) {
        return 'قبل ${difference.inDays} يوم';
      } else if (difference.inHours > 0) {
        return 'قبل ${difference.inHours} ساعة';
      } else if (difference.inMinutes > 0) {
        return 'قبل ${difference.inMinutes} دقيقة';
      } else {
        return 'منذ قليل';
      }
    } catch (e) {
      return 'غير محدد';
    }
  }

  Widget _buildStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
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
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCityRankCard(String cityName, int visits, int rank) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getRankColor(rank).withValues(alpha: 0.1),
          child: Text(
            '$rank',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: _getRankColor(rank),
            ),
          ),
        ),
        title: Text(
          cityName,
          textDirection: TextDirection.rtl,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _getRankColor(rank).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$visits زيارة',
            style: TextStyle(
              color: _getRankColor(rank),
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            textDirection: TextDirection.rtl,
          ),
        ),
      ),
    );
  }

  Color _getRankColor(int rank) {
    switch (rank) {
      case 1:
        return Colors.amber;
      case 2:
        return Colors.grey[600]!;
      case 3:
        return Colors.orange[800]!;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // الإحصائيات العامة
            Text(
              '📊 إحصائيات عامة',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textDirection: TextDirection.rtl,
            ),
            const SizedBox(height: 12),

            _buildStatCard(
              title: 'مرات فتح التطبيق',
              value: '${usageStats['appOpenCount'] ?? 0}',
              icon: Icons.open_in_new,
              color: Colors.blue,
              subtitle: 'منذ تثبيت التطبيق',
            ),

            const SizedBox(height: 8),

            _buildStatCard(
              title: 'آخر استخدام',
              value: _formatLastUsed(usageStats['lastUsed']),
              icon: Icons.schedule,
              color: Colors.green,
            ),

            const SizedBox(height: 8),

            _buildStatCard(
              title: 'عمليات البحث',
              value: '${searchHistory.length}',
              icon: Icons.search,
              color: Colors.orange,
              subtitle: 'في تاريخ البحث',
            ),

            const SizedBox(height: 24),

            // أكثر المدن زيارة
            Row(
              children: [
                Text(
                  '🏆 أكثر المدن زيارة',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const Spacer(),
                if (mostViewedCities.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('مسح إحصائيات المدن', textDirection: TextDirection.rtl),
                          content: const Text(
                            'هل تريد مسح إحصائيات زيارة المدن؟',
                            textDirection: TextDirection.rtl,
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context),
                              child: const Text('إلغاء'),
                            ),
                            TextButton(
                              onPressed: () async {
                                Navigator.pop(context);
                                // مسح إحصائيات المدن
                                final stats = await CacheService.getUsageStats();
                                stats['mostViewedCities'] = <String, int>{};
                                await CacheService.updateUsageStats();
                                loadUsageStats();
                              },
                              child: const Text('مسح', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('مسح', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (mostViewedCities.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.location_city,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا توجد إحصائيات بعد',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ بتصفح المدن لرؤية الإحصائيات',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              )
            else
              ...mostViewedCities.asMap().entries.map((entry) {
                final rank = entry.key + 1;
                final cityData = entry.value;
                return _buildCityRankCard(cityData.key, cityData.value, rank);
              }),

            const SizedBox(height: 24),

            // تاريخ البحث
            Row(
              children: [
                Text(
                  '🔍 تاريخ البحث',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const Spacer(),
                if (searchHistory.isNotEmpty)
                  TextButton.icon(
                    onPressed: () {
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
                                Navigator.pop(context);
                                await CacheService.clearSearchHistory();
                                loadUsageStats();
                              },
                              child: const Text('مسح', style: TextStyle(color: Colors.red)),
                            ),
                          ],
                        ),
                      );
                    },
                    icon: const Icon(Icons.clear_all, size: 16),
                    label: const Text('مسح', style: TextStyle(fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            if (searchHistory.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(
                        Icons.search_off,
                        size: 48,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'لا يوجد تاريخ بحث',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 16,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'ابدأ بالبحث لرؤية التاريخ هنا',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 14,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ],
                  ),
                ),
              )
            else
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'عمليات البحث الأخيرة:',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: searchHistory.take(10).map((search) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.blue.withValues(alpha: 0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.search,
                                  size: 14,
                                  color: Colors.blue,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  search,
                                  style: const TextStyle(
                                    color: Colors.blue,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  textDirection: TextDirection.rtl,
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      if (searchHistory.length > 10)
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '... و ${searchHistory.length - 10} عمليات بحث أخرى',
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 12,
                              fontStyle: FontStyle.italic,
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                    ],
                  ),
                ),
              ),

            const SizedBox(height: 24),

            // معلومات إضافية
            Card(
              color: Colors.blue.withValues(alpha: 0.05),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.blue[700],
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'معلومات مهمة',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.blue[700],
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'جميع الإحصائيات محفوظة محلياً على جهازك فقط. لا يتم إرسال أي بيانات شخصية للخارج.',
                      style: TextStyle(fontSize: 14),
                      textDirection: TextDirection.rtl,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}