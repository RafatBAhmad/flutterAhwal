import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../services/cache_service.dart';

// هذا Widget سيُستخدم كعنصر واجهة على شاشة الهاتف الرئيسية
// يتطلب إعداد إضافي في Android/iOS للعمل كـ Home Screen Widget فعلي

class CheckpointWidget extends StatefulWidget {
  const CheckpointWidget({super.key});

  @override
  State<CheckpointWidget> createState() => _CheckpointWidgetState();
}

class _CheckpointWidgetState extends State<CheckpointWidget> {
  List<Checkpoint> favoriteCheckpoints = [];
  bool isLoading = true;
  int openCount = 0;
  int closedCount = 0;
  int congestionCount = 0;

  @override
  void initState() {
    super.initState();
    loadFavoriteCheckpoints();
  }

  Future<void> loadFavoriteCheckpoints() async {
    setState(() => isLoading = true);

    try {
      // محاولة تحميل من الكاش أولاً
      var checkpoints = await CacheService.getCachedCheckpoints();

      // إذا لم يكن هناك كاش صالح، تحميل من API
      if (checkpoints == null) {
        checkpoints = await ApiService.getAllCheckpoints();
        await CacheService.cacheCheckpoints(checkpoints);
      }

      // تحميل المفضلة
      final prefs = await SharedPreferences.getInstance();
      final favoriteIds = prefs.getStringList('favorites')?.toSet() ?? {};

      setState(() {
        favoriteCheckpoints = checkpoints!
            .where((cp) => favoriteIds.contains(cp.id))
            .take(5) // أظهار أول 5 فقط
            .toList();

        // حساب الإحصائيات للمفضلة
        openCount = favoriteCheckpoints
            .where((cp) => ['مفتوح', 'سالكة', 'سالكه', 'سالك']
            .contains(cp.status.toLowerCase()))
            .length;

        closedCount = favoriteCheckpoints
            .where((cp) => cp.status.toLowerCase() == 'مغلق')
            .length;

        congestionCount = favoriteCheckpoints
            .where((cp) => cp.status.toLowerCase() == 'ازدحام')
            .length;

        isLoading = false;
      });
    } catch (e) {
      setState(() => isLoading = false);
    }
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

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.blue.shade700,
            Colors.blue.shade500,
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // العنوان
          Row(
            children: [
              const Icon(
                Icons.location_on,
                color: Colors.white,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'أحوال الطرق',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textDirection: TextDirection.rtl,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(
                  Icons.refresh,
                  color: Colors.white70,
                  size: 18,
                ),
                onPressed: loadFavoriteCheckpoints,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (isLoading)
            const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                strokeWidth: 2,
              ),
            )
          else if (favoriteCheckpoints.isEmpty)
            const Center(
              child: Column(
                children: [
                  Icon(
                    Icons.star_border,
                    color: Colors.white70,
                    size: 32,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'لا توجد حواجز مفضلة',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                    ),
                    textDirection: TextDirection.rtl,
                  ),
                ],
              ),
            )
          else
            Column(
              children: [
                // إحصائيات سريعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildMiniStat('سالك', openCount, Colors.green),
                    _buildMiniStat('مغلق', closedCount, Colors.red),
                    _buildMiniStat('ازدحام', congestionCount, Colors.orange),
                  ],
                ),

                const SizedBox(height: 12),

                // قائمة الحواجز المفضلة
                ...favoriteCheckpoints.map((checkpoint) =>
                    _buildCheckpointItem(checkpoint)
                ),
              ],
            ),

          const SizedBox(height: 8),

          // وقت التحديث
          Center(
            child: Text(
              'آخر تحديث: ${DateTime.now().toString().split(' ')[1].substring(0, 5)}',
              style: const TextStyle(
                color: Colors.white60,
                fontSize: 10,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniStat(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            color: color.withValues(alpha: 0.9),
            fontSize: 9,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckpointItem(Checkpoint checkpoint) {
    final statusColor = getStatusColor(checkpoint.status);
    final statusIcon = getStatusIcon(checkpoint.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            statusIcon,
            color: statusColor,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkpoint.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                  textDirection: TextDirection.rtl,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  checkpoint.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                  ),
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Widget مصغر للاستخدام في أماكن أخرى
class CompactCheckpointWidget extends StatelessWidget {
  final List<Checkpoint> checkpoints;

  const CompactCheckpointWidget({
    super.key,
    required this.checkpoints,
  });

  @override
  Widget build(BuildContext context) {
    final openCount = checkpoints
        .where((cp) => ['مفتوح', 'سالكة', 'سالكه', 'سالك']
        .contains(cp.status.toLowerCase()))
        .length;

    final closedCount = checkpoints
        .where((cp) => cp.status.toLowerCase() == 'مغلق')
        .length;

    final congestionCount = checkpoints
        .where((cp) => cp.status.toLowerCase() == 'ازدحام')
        .length;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).primaryColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildCompactStat('سالك', openCount, Colors.green),
          _buildCompactStat('مغلق', closedCount, Colors.red),
          _buildCompactStat('ازدحام', congestionCount, Colors.orange),
        ],
      ),
    );
  }

  Widget _buildCompactStat(String label, int count, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$count',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}