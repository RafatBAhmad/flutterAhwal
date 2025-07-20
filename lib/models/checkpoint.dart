import 'package:intl/intl.dart';


class Checkpoint {
  final String name;
  final String city;
  final double latitude;
  final double longitude;
  final String status;
  final String? updatedAt;
  final String sourceText;

  Checkpoint({
    required this.name,
    required this.city,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.updatedAt,
    required this.sourceText,
  });

  factory Checkpoint.fromJson(Map<String, dynamic> json) {
    return Checkpoint(
      name: json['name'],
      city: json['city'],
      latitude: (json['latitude'] ?? 0).toDouble(),
      longitude: (json['longitude'] ?? 0).toDouble(),
      status: json['status'],
      updatedAt: json['updatedAt'],
      sourceText: json['sourceText'] ?? '',
    );
  }
  /// ✅ Getter لعرض التاريخ بشكل مقروء مثل: 2025/07/16 10:26 ص
  String get formattedDate {
    if (updatedAt == null) return 'غير معروف';
    try {
      final dt = DateTime.parse(updatedAt!);
      return DateFormat('yyyy/MM/dd hh:mm a', 'ar').format(dt);
    } catch (e) {
      return updatedAt!;
    }
  }
}
