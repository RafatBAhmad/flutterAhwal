import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';
import '../utils/checkpoint_statistics_utils.dart';
import '../utils/data_filter_utils.dart';
import '../widgets/checkpoint_history_dialog.dart';

class MapScreen extends StatefulWidget {
  final VoidCallback? onRefreshRequested;

  const MapScreen({
    super.key,
    this.onRefreshRequested,
  });

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

  // Public refresh method for main navigation
  void refreshData() {
    if (!isLoading) {
      loadCheckpoints();
      widget.onRefreshRequested?.call();
    }
  }

  Future<void> loadCheckpoints() async {
    setState(() => isLoading = true);
    try {
      print('🔄 MapScreen: Starting data load...');

      // محاولة تحميل من الكاش أولاً
      final cachedData = await CacheService.getCachedCheckpoints();
      
      if (cachedData != null && cachedData.isNotEmpty) {
        // استخدام الكاش فوراً
        _updateUIWithData(cachedData);
        print('📋 MapScreen: Loaded from cache (${cachedData.length} checkpoints)');
        
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

      _updateUIWithData(data);
      print('🎯 MapScreen loaded ${data.length} checkpoints');

    } catch (e) {
      print('❌ MapScreen loadCheckpoints failed: $e');
      setState(() => isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("❌ تعذر تحميل البيانات. تحقق من اتصال الإنترنت"),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'إعادة المحاولة',
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
      final data = await ApiService.getLatestCheckpointsOnly();
      print('✅ MapScreen: getLatestCheckpointsOnly succeeded');
      return data;
    } catch (e) {
      print('❌ MapScreen: getLatestCheckpointsOnly failed: $e');
      try {
        final data = await ApiService.fetchLatestOnly();
        print('✅ MapScreen: fetchLatestOnly succeeded');
        return data;
      } catch (e2) {
        print('❌ MapScreen: fetchLatestOnly failed: $e2');
        final data = await ApiService.getAllCheckpoints();
        print('✅ MapScreen: getAllCheckpoints succeeded');
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
        _updateUIWithData(data);
      }
    } catch (e) {
      print('Background refresh failed: $e');
    }
  }

  // تحديث الواجهة
  void _updateUIWithData(List<Checkpoint> data) {
    setState(() {
      checkpoints = data;
      cities = CheckpointStatisticsUtils.getAvailableCities(data);
      selectedCity ??= "الكل";
      currentStatistics =
          CheckpointStatisticsUtils.calculateStatistics(getFilteredCheckpoints());
      isLoading = false;
    });
  }

  List<Checkpoint> getFilteredCheckpoints() {
    // 🔥 فلترة البيانات القديمة أولاً (أكثر من يومين)
    List<Checkpoint> recentCheckpoints = DataFilterUtils.filterRecentCheckpoints(
      checkpoints,
      maxHours: 48,
    );
    
    // ثم فلترة حسب المدينة
    return CheckpointStatisticsUtils.filterByCity(recentCheckpoints, selectedCity);
  }

  // 🔥 إضافة دالة تشخيص للخريطة
  void _showMapDiagnostics() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تشخيص الخريطة'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('إجمالي الحواجز: ${checkpoints.length}'),
            Text('المدن المتاحة: ${cities.length}'),
            Text('المدينة المختارة: ${selectedCity ?? "غير محدد"}'),
            const SizedBox(height: 8),
            if (currentStatistics != null) ...[
              const Text('الإحصائيات الحالية:', style: TextStyle(fontWeight: FontWeight.bold)),
              Text('سالك: ${currentStatistics!.open}'),
              Text('مغلق: ${currentStatistics!.closed}'),
              Text('ازدحام: ${currentStatistics!.congestion}'),
              Text('حاجز: ${currentStatistics!.checkpoint}'),
            ],
            const SizedBox(height: 8),
            Text('حالة التحميل: ${isLoading ? "جاري التحميل" : "مكتمل"}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إغلاق'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              loadCheckpoints();
            },
            child: const Text('إعادة التحميل'),
          ),
          // 🔥 زر اختبار API
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              final results = await ApiService.testAllEndpoints();
              if (mounted) {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('تشخيص API'),
                    content: SingleChildScrollView(
                      child: Text(
                        'حالة: ${results['overall_status']}\n'
                            'تعمل: ${results['working_endpoints']}/${results['tested_endpoints']}\n'
                            'خادم: ${results['server']}',
                        style: const TextStyle(fontSize: 12),
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
            },
            child: const Text('اختبار API'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredCheckpoints = getFilteredCheckpoints();
    currentStatistics =
        CheckpointStatisticsUtils.calculateStatistics(filteredCheckpoints);

    final theme = Theme.of(context);

    return Scaffold(
      body: SafeArea(
        child: Column(
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
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          boxShadow: [
                            BoxShadow(
                              color: theme.shadowColor.withValues(alpha: 0.1),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: DropdownButtonFormField<String>(
                          value: selectedCity,
                          decoration: InputDecoration(
                            labelText: 'فلترة حسب المدينة',
                            labelStyle: TextStyle(
                              color: theme.primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                            prefixIcon: Icon(
                              Icons.location_city,
                              color: theme.primaryColor,
                              size: 20,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.primaryColor.withValues(alpha: 0.3),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.primaryColor,
                                width: 2,
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                color: theme.dividerColor,
                              ),
                            ),
                            filled: true,
                            fillColor: theme.cardColor,
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 16),
                          ),
                          dropdownColor: theme.cardColor,
                          borderRadius: BorderRadius.circular(16),
                          icon: Icon(
                            Icons.keyboard_arrow_down,
                            color: theme.primaryColor,
                            size: 24,
                          ),
                          iconSize: 24,
                          style: TextStyle(
                            color: theme.textTheme.bodyLarge?.color,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          isExpanded: true,
                          selectedItemBuilder: (context) => cities.map((city) {
                            return Container(
                              alignment: Alignment.centerRight,
                              child: Text(
                                city,
                                textDirection: TextDirection.rtl,
                                style: TextStyle(
                                  color: theme.textTheme.bodyLarge?.color,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            );
                          }).toList(),
                          items: cities.map((city) {
                            final isSelected = city == selectedCity;
                            return DropdownMenuItem(
                              value: city,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                                margin: const EdgeInsets.symmetric(vertical: 2),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? theme.primaryColor.withValues(alpha: 0.1)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(8),
                                  border: isSelected
                                      ? Border.all(color: theme.primaryColor.withValues(alpha: 0.3))
                                      : null,
                                ),
                                child: Row(
                                  textDirection: TextDirection.rtl,
                                  children: [
                                    Icon(
                                      city == "الكل" ? Icons.all_inclusive : Icons.location_on,
                                      size: 20,
                                      color: isSelected
                                          ? theme.primaryColor
                                          : (theme.brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600]),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        city,
                                        textDirection: TextDirection.rtl,
                                        style: TextStyle(
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? theme.primaryColor
                                              : theme.textTheme.bodyLarge?.color,
                                          fontSize: 16,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle,
                                        size: 18,
                                        color: theme.primaryColor,
                                      ),
                                  ],
                                ),
                              ),
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
                : checkpoints.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[400],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'لا توجد بيانات متاحة',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: Colors.red[600],
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'تحقق من اتصال الإنترنت',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton.icon(
                    onPressed: loadCheckpoints,
                    icon: const Icon(Icons.refresh),
                    label: const Text('إعادة المحاولة'),
                  ),
                ],
              ),
            )
                : Column(
              children: [
                // إحصائيات سريعة قابلة للضغط
                Container(
                  margin: const EdgeInsets.all(16),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => _showCheckpointsListDialog(),
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
                                  Expanded(
                                    child: Text(
                                      'إحصائيات الحواجز',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textDirection: TextDirection.rtl,
                                    ),
                                  ),
                                  Icon(
                                    Icons.touch_app,
                                    color: theme.primaryColor.withValues(alpha: 0.7),
                                    size: 20,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'اضغط لعرض قائمة الحواجز',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.primaryColor,
                                  fontSize: 12,
                                ),
                                textDirection: TextDirection.rtl,
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
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: _buildCompactStatusCard(
                                        'حاجز',
                                        Colors.purple,
                                        currentStatistics?.checkpoint ?? 0,
                                        theme),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
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
                            color: theme.brightness == Brightness.dark
                      ? theme.cardColor.withValues(alpha: 0.15)
                      : theme.cardColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(100),
                            border: Border.all(
                              color: theme.brightness == Brightness.dark
                                  ? theme.dividerColor.withValues(alpha: 0.4)
                                  : theme.dividerColor,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            Icons.map_outlined,
                            size: 80,
                            color: theme.brightness == Brightness.dark
                                ? theme.dividerColor.withValues(alpha: 0.6)
                                : theme.dividerColor,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خريطة الحواجز التفاعلية',
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                        const SizedBox(height: 16),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'ستكون متاحة قريباً إن شاء الله لعرض الحواجز على الخريطة التفاعلية',
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              height: 1.6,
                              fontSize: 16,
                              color: theme.textTheme.bodyLarge?.color?.withValues(alpha: 0.8),
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        ),
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
    );
  }

  Widget _buildCompactStatusCard(String title, Color color, int count, ThemeData theme) {
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
                  ? Colors.white.withValues(alpha: 0.9)
                  : Colors.black87,
              fontWeight: FontWeight.w600,
            ),
            textDirection: TextDirection.rtl,
          ),
        ],
      ),
    );
  }

  void _showCheckpointsListDialog() {
    final filteredCheckpoints = getFilteredCheckpoints();

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Container(
          width: MediaQuery.of(context).size.width * 0.9,
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.8,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(16),
                    topRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.map,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'حواجز الخريطة',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).primaryColor,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      iconSize: 20,
                    ),
                  ],
                ),
              ),

              // Content
              Flexible(
                child: filteredCheckpoints.isEmpty
                    ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.location_off,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 16),
                        Text(
                          'لا توجد حواجز',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          textDirection: TextDirection.rtl,
                        ),
                      ],
                    ),
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  shrinkWrap: true,
                  itemCount: filteredCheckpoints.length,
                  itemBuilder: (context, index) {
                    final checkpoint = filteredCheckpoints[index];
                    return _buildCheckpointListItem(checkpoint);
                  },
                ),
              ),

              // Footer
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.05),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(16),
                    bottomRight: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      size: 16,
                      color: Colors.grey[600],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'اضغط على أي حاجز لعرض تفاصيله وتاريخ التحديثات',
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 12,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
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

  Widget _buildCheckpointListItem(Checkpoint checkpoint) {
    final statusColor = _getStatusColor(checkpoint.status);
    final lastUpdate = checkpoint.effectiveAtDateTime ?? checkpoint.updatedAtDateTime;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            Navigator.of(context).pop(); // Close the list dialog first
            _showCheckpointDetailsDialog(checkpoint);
          },
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              border: Border.all(
                color: statusColor.withValues(alpha: 0.3),
                width: 1,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        checkpoint.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        textDirection: TextDirection.rtl,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: statusColor.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: statusColor.withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              checkpoint.status,
                              style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                              textDirection: TextDirection.rtl,
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (lastUpdate != null)
                            Text(
                              _formatRelativeTime(lastUpdate),
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.grey[600],
                              ),
                            ),
                        ],
                      ),
                      if (checkpoint.city.isNotEmpty && checkpoint.city != "غير معروف")
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            checkpoint.city,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey[500],
                            ),
                            textDirection: TextDirection.rtl,
                          ),
                        ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.arrow_forward_ios,
                  size: 12,
                  color: Colors.grey,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showCheckpointDetailsDialog(Checkpoint checkpoint) {
    showDialog(
      context: context,
      builder: (context) => CheckpointHistoryDialog(
        checkpoint: checkpoint,
      ),
    );
  }

  Color _getStatusColor(String status) {
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
      case 'حاجز':
        return Colors.purple;
      default:
        return Colors.grey;
    }
  }

  String _formatRelativeTime(DateTime dateTime) {
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
}