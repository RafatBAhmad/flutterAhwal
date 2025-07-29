import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../utils/checkpoint_statistics_utils.dart'; // استيراد الكلاس الجديد

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
      if (!mounted) return;

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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("❌ فشل في تحميل البيانات: $e"),
          backgroundColor: Colors.red,
        ),
      );
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

  Widget _buildCityCard(String cityName, CheckpointStatistics stats, List<Checkpoint> checkpoints) {
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
                  _buildStatusSummary('مفتوح', stats.open, Colors.green),
                  _buildStatusSummary('مغلق', stats.closed, Colors.red),
                  _buildStatusSummary('ازدحام', stats.congestion, Colors.orange),
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

  Widget buildSummarySection() {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      );
    }

    final allStats = CheckpointStatisticsUtils.calculateStatisticsByCity(allCheckpoints);
    final citySummaries = allStats.entries.map((e) => {
      'city': e.key,
      'open': e.value.open,
      'closed': e.value.closed,
      'congestion': e.value.congestion,
    }).toList();

    if (citySummaries.isEmpty) return const SizedBox.shrink();

    return SizedBox(
      height: 100,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.all(8),
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemCount: citySummaries.length,
        itemBuilder: (_, index) {
          final item = citySummaries[index];
          return Container(
            width: 160,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: Theme.of(context).cardColor,
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['city']! as String, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text("مفتوح: ${item['open']}", style: const TextStyle(color: Colors.green)),
                Text("مغلق: ${item['closed']}", style: const TextStyle(color: Colors.red)),
                Text("ازدحام: ${item['congestion']}", style: const TextStyle(color: Colors.orange)),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cities = checkpointsByCity.keys.toList()..sort();

    return Scaffold(
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          buildSummarySection(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: loadCheckpoints,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: cities.length,
                itemBuilder: (context, index) {
                  final cityName = cities[index];
                  final cityCheckpoints = checkpointsByCity[cityName]!;
                  final stats = CheckpointStatisticsUtils.calculateStatistics(cityCheckpoints);
                  return _buildCityCard(cityName, stats, cityCheckpoints);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}


