class CitySuggestion {
  final String name;
  final String country;
  final String? region;
  final double lat;
  final double lon;
  final Map<String, String>? localNames;

  CitySuggestion({
    required this.name,
    required this.country,
    this.region,
    required this.lat,
    required this.lon,
    this.localNames,
  });

  factory CitySuggestion.fromJson(Map<String, dynamic> json) {
    return CitySuggestion(
      name: json['name'] ?? '',
      country: json['country'] ?? '',
      region: json['state'],
      lat: (json['lat'] as num).toDouble(),
      lon: (json['lon'] as num).toDouble(),
      localNames:
          json['local_names'] != null
              ? Map<String, String>.from(json['local_names'])
              : null,
    );
  }

  @override
  String toString() {
    if (region != null && region!.isNotEmpty) {
      return '$name, $region, $country';
    }
    return '$name, $country';
  }

  /// Returns a display name that prioritizes local language names
  String getDisplayName({String? preferredLanguage}) {
    String displayName = name;

    // Try to get local name in preferred language
    if (preferredLanguage != null && localNames != null) {
      displayName = localNames![preferredLanguage] ?? name;
    }

    if (region != null && region!.isNotEmpty) {
      return '$displayName, $region, $country';
    }
    return '$displayName, $country';
  }

  /// Creates a unique identifier for deduplication
  String get uniqueId {
    // Normalize strings to handle case sensitivity and special characters
    final normalizedName = name.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );
    final normalizedRegion = (region ?? '').toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );
    final normalizedCountry = country.toLowerCase().trim().replaceAll(
      RegExp(r'[^\w\s]'),
      '',
    );

    // Create a compound key that's more robust
    // Include coordinates rounded to avoid minor differences
    final roundedLat = (lat * 100).round() / 100;
    final roundedLon = (lon * 100).round() / 100;

    return '${normalizedName}_${normalizedRegion}_${normalizedCountry}_${roundedLat}_$roundedLon';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CitySuggestion && other.uniqueId == uniqueId;
  }

  @override
  int get hashCode => uniqueId.hashCode;
}
