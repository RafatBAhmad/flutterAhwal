import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';

class CityFilterScreen extends StatefulWidget {
  const CityFilterScreen({super.key});

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

  Future<void> loadCheckpoints() async {
    if (!mounted) return;
    setState(() => isLoading = true);

    try {
      final data = await ApiService.getAllCheckpoints();

      if (!mounted) return; // تحقق مرة أخرى بعد العملية غير المتزامنة

      // تجميع البيانات حسب المدينة
      final Map<String, List<Checkpoint>> cityGroups = {};
      for (final checkpoint in data) {
        final city = checkpoint.city == "غير معروف" ? "أخرى" : checkpoint.city;
        cityGroups[city] = cityGroups[city] ?? [];
        cityGroups[city]!.add(checkpoint);
      }

      setState(() {
        allCheckpoints = data;
        checkpointsByCity = cityGroups;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
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

  Widget _buildCityCard(String cityName, List<Checkpoint> checkpoints) {
    final openCount = checkpoints.where((cp) =>
    cp.status.toLowerCase() == 'مفتوح' ||
        cp.status.toLowerCase() == 'سالكة' ||
        cp.status.toLowerCase() == 'سالكه'
    ).length;

    final closedCount = checkpoints.where((cp) =>
    cp.status.toLowerCase() == 'مغلق'
    ).length;

    final congestionCount = checkpoints.where((cp) =>
    cp.status.toLowerCase() == 'ازدحام'
    ).length;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() {
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
                    child: Text(
                      cityName,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textDirection: TextDirection.rtl,
                    ),
                  ),
                  Icon(
                    selectedCity == cityName
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: Theme.of(context).primaryColor,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatusSummary('مفتوح', openCount, Colors.green),
                  _buildStatusSummary('مغلق', closedCount, Colors.red),
                  _buildStatusSummary('ازدحام', congestionCount, Colors.orange),
                ],
              ),
              if (selectedCity == cityName) ...[
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),
                ...checkpoints.map((checkpoint) => _buildCheckpointTile(checkpoint)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusSummary(String status, int count, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          status,
          style: TextStyle(
            fontSize: 12,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildCheckpointTile(Checkpoint checkpoint) {
    final statusColor = getStatusColor(checkpoint.status);
    final statusIcon = getStatusIcon(checkpoint.status);

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: statusColor.withOpacity(0.3),
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
                Text(
                  checkpoint.status,
                  style: TextStyle(
                    color: statusColor,
                    fontSize: 12,
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('جاري تحميل البيانات...'),
            ],
          ),
        ),
      );
    }

    final cities = checkpointsByCity.keys.toList()..sort();

    return Scaffold(
      body: Column(
        children: [
          // شريط المعلومات العلوي
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            color: Theme.of(context).primaryColor.withOpacity(0.1),
            child: Column(
              children: [
                Text(
                  'فلترة الحواجز حسب المدينة',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textDirection: TextDirection.rtl,
                ),
                const SizedBox(height: 8),
                Text(
                  'إجمالي ${allCheckpoints.length} حاجز في ${cities.length} مدينة',
                  style: Theme.of(context).textTheme.bodySmall,
                  textDirection: TextDirection.rtl,
                ),
              ],
            ),
          ),

          // قائمة المدن
          Expanded(
            child: cities.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.location_city, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('لا توجد بيانات متاحة'),
                ],
              ),
            )
                : RefreshIndicator(
              onRefresh: loadCheckpoints,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: cities.length + 1,
                itemBuilder: (context, index) {
                  if (index == cities.length) {
                    return Padding(
                      padding: const EdgeInsets.all(16),
                      child: Center(
                        child: ElevatedButton.icon(
                          onPressed: loadCheckpoints,
                          icon: const Icon(Icons.refresh),
                          label: const Text("تحديث البيانات"),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                          ),
                        ),
                      ),
                    );
                  }

                  final cityName = cities[index];
                  final cityCheckpoints = checkpointsByCity[cityName]!;
                  return _buildCityCard(cityName, cityCheckpoints);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}