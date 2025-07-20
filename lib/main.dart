import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'screens/city_filter_screen.dart';
import 'screens/map_screen.dart';

void main() {
  runApp(const AhwalApp());
}

class AhwalApp extends StatelessWidget {
  const AhwalApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'أحوال الطرق',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        fontFamily: 'Cairo',
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int currentIndex = 0;

  final List<Widget> screens = const [
    HomeScreen(),
    CityFilterScreen(),
    MapScreen(),
  ];

  final List<String> titles = [
    'أحوال الطرق',
    'فلترة حسب المدينة',
    'الخريطة',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(titles[currentIndex])),
      body: screens[currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        onTap: (index) => setState(() => currentIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.list),
            label: 'الرئيسية',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.filter_list),
            label: 'الفلترة',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.map),
            label: 'الخريطة',
          ),
        ],
      ),
    );
  }
}
