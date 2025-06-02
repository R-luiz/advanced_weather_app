class CitySuggestion {
  final String name;
  final String country;
  final String? region;
  final double lat;
  final double lon;

  CitySuggestion({
    required this.name,
    required this.country,
    this.region,
    required this.lat,
    required this.lon,
  });

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      region: json['state'],
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
    );
  }

  @override
  String toString() {
    if (region != null && region!.isNotEmpty) {
      return '$name, $region, $country';
    }
    return '$name, $country';
  }
}
