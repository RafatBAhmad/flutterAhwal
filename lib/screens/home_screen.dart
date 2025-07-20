import 'dart:async';
import 'package:flutter/material.dart';
import '../models/checkpoint.dart';
import '../services/api_service.dart';
import 'package:fluttertoast/fluttertoast.dart';

import '../utils/date_utils.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Checkpoint> allCheckpoints = [];
  List<String> cities = [];
  String selectedCity = "الكل";
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    fetchCheckpoints();
    startAutoRefresh(); // ← التحديث التلقائي
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void startAutoRefresh() {
    _refreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      fetchCheckpoints();
    });
  }

  Future<void> fetchCheckpoints() async {
    try {
      final data = await ApiService.getAllCheckpoints();
      setState(() {
        allCheckpoints = data;
        cities = data.map((cp) => cp.city).toSet().toList();
        if (!cities.contains("الكل")) {
          cities.insert(0, "الكل");
        }
      });
      Fluttertoast.showToast(
        msg: "✅ تم تحديث البيانات",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
      );
    } catch (e) {
      Fluttertoast.showToast(
        msg: "❌ فشل الاتصال بالخادم",
        toastLength: Toast.LENGTH_LONG,
        gravity: ToastGravity.BOTTOM,
      );
      print("❌ Error fetching checkpoints: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    List<Checkpoint> displayed = selectedCity == "الكل"
        ? allCheckpoints
        : allCheckpoints.where((cp) => cp.city == selectedCity).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('أحوال الطرق'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: fetchCheckpoints, // ← التحديث اليدوي
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: DropdownButton<String>(
              value: selectedCity,
              isExpanded: true,
              items: cities.map((city) {
                return DropdownMenuItem(
                  value: city,
                  child: Text(city, textDirection: TextDirection.rtl),
                );
              }).toList(),
              onChanged: (value) {
                setState(() {
                  selectedCity = value!;
                });
              },
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: displayed.length,
              itemBuilder: (context, index) {
                final cp = displayed[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: ListTile(
                    title: Text(cp.name,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                        textDirection: TextDirection.rtl),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("المدينة: ${cp.city}",
                            textDirection: TextDirection.rtl),
                        Text("الحالة: ${cp.status}",
                            textDirection: TextDirection.rtl),
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
      ),
    );
  }
}
