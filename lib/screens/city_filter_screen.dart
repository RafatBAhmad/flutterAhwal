import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import '../utils/date_utils.dart';

class CityFilterScreen extends StatefulWidget {
  const CityFilterScreen({super.key});

  @override
  State<CityFilterScreen> createState() => _CityFilterScreenState();
}

class _CityFilterScreenState extends State<CityFilterScreen> {
  List<String> cities = [];
  List<Checkpoint> filteredCheckpoints = [];
  String? selectedCity;

  @override
  void initState() {
    super.initState();
    loadCities();
  }

  Future<void> loadCities() async {
    try {
      final allCheckpoints = await ApiService.getAllCheckpoints();
      final distinctCities = allCheckpoints
          .map((cp) => cp.city)
          .toSet()
          .where((c) => c != "غير معروف")
          .toList();
      setState(() {
        cities = distinctCities;
      });
    } catch (e) {
      print("❌ Failed to load cities: $e");
    }
  }

  Future<void> fetchByCity(String city) async {
    try {
      final data = await ApiService.getCheckpointsByCity(city);
      setState(() {
        filteredCheckpoints = data;
      });
    } catch (e) {
      print("❌ Failed to load checkpoints: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: DropdownButton<String>(
            hint: const Text("اختر المدينة"),
            value: selectedCity,
            isExpanded: true,
            items: cities.map((city) {
              return DropdownMenuItem(
                value: city,
                child: Text(city, textDirection: TextDirection.rtl),
              );
            }).toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => selectedCity = value);
                fetchByCity(value);
              }
            },
          ),
        ),
        Expanded(
          child: ListView.builder(
            itemCount: filteredCheckpoints.length,
            itemBuilder: (context, index) {
              final cp = filteredCheckpoints[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ListTile(
                  title: Text(cp.name,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                      textDirection: TextDirection.rtl),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("المدينة: ${cp.city}", textDirection: TextDirection.rtl),
                      Text("الحالة: ${cp.status}", textDirection: TextDirection.rtl),
                      if (cp.updatedAt != null)
                        Text("آخر تحديث: ${formatDateTime(cp.updatedAt)}",
                            textDirection: TextDirection.rtl),


                      if (cp.sourceText.isNotEmpty)
                        Text("النص: ${cp.sourceText}",
                            style: TextStyle(color: Colors.grey[600]),
                            textDirection: TextDirection.rtl),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
