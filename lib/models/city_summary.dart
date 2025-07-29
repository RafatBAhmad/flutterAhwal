class CitySummary {
  final String city;
  final int open;
  final int closed;
  final int congestion;

  CitySummary({
    required this.city,
    required this.open,
    required this.closed,
    required this.congestion,
  });

  factory CitySummary.fromJson(String city, Map<String, dynamic> json) {
    return CitySummary(
      city: city,
      open: json['مفتوح'] ?? 0,
      closed: json['مغلق'] ?? 0,
      congestion: json['ازدحام'] ?? 0,
    );
  }
}
