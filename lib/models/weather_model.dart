class WeatherData {
  final double temperature;
  final String description;
  final String icon;
  final String cityName;
  final int humidity;
  final double windSpeed;
  final String? country;
  final String? region;
  final double? feelsLike;
  final double? visibility;
  final int? pressure;
  final String? windDirection;
  final double? uvIndex;
  final DateTime? sunrise;
  final DateTime? sunset;
  final List<HourlyForecast>? hourlyForecast;
  final List<DailyForecast>? dailyForecast;

  WeatherData({
    required this.temperature,
    required this.description,
    required this.icon,
    required this.cityName,
    required this.humidity,
    required this.windSpeed,
    this.country,
    this.region,
    this.feelsLike,
    this.visibility,
    this.pressure,
    this.windDirection,
    this.uvIndex,
    this.sunrise,
    this.sunset,
    this.hourlyForecast,
    this.dailyForecast,
  });

  factory WeatherData.fromJson(Map<String, dynamic> json) {
    return WeatherData(
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
      cityName: json['name'] as String,
      humidity: json['main']['humidity'] as int,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      country: json['sys']?['country'],
      region: null, // OpenWeatherMap doesn't provide region in current weather
      feelsLike:
          json['main']['feels_like'] != null
              ? (json['main']['feels_like'] as num).toDouble()
              : null,
      visibility:
          json['visibility'] != null
              ? (json['visibility'] as num).toDouble() /
                  1000 // Convert from meters to km
              : null,
      pressure:
          json['main']['pressure'] != null
              ? (json['main']['pressure'] as num).toInt()
              : null,
      windDirection: _getWindDirection(json['wind']?['deg']),
      sunrise:
          json['sys']?['sunrise'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                json['sys']['sunrise'] * 1000,
              )
              : null,
      sunset:
          json['sys']?['sunset'] != null
              ? DateTime.fromMillisecondsSinceEpoch(
                json['sys']['sunset'] * 1000,
              )
              : null,
    );
  }

  static String? _getWindDirection(dynamic degrees) {
    if (degrees == null) return null;
    final deg = (degrees as num).toDouble();
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    final index = ((deg + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String description;
  final String icon;
  final double windSpeed;
  final int humidity;
  final double? feelsLike;
  final double? visibility;
  final String? windDirection;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.description,
    required this.icon,
    required this.windSpeed,
    required this.humidity,
    this.feelsLike,
    this.visibility,
    this.windDirection,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
      humidity: json['main']['humidity'] as int,
      feelsLike:
          json['main']['feels_like'] != null
              ? (json['main']['feels_like'] as num).toDouble()
              : null,
      visibility:
          json['visibility'] != null
              ? (json['visibility'] as num).toDouble() /
                  1000 // Convert from meters to km
              : null,
      windDirection: _getWindDirection(json['wind']['deg']),
    );
  }

  static String? _getWindDirection(dynamic degrees) {
    if (degrees == null) return null;
    final deg = (degrees as num).toDouble();
    const directions = [
      'N',
      'NNE',
      'NE',
      'ENE',
      'E',
      'ESE',
      'SE',
      'SSE',
      'S',
      'SSW',
      'SW',
      'WSW',
      'W',
      'WNW',
      'NW',
      'NNW',
    ];
    final index = ((deg + 11.25) / 22.5).floor() % 16;
    return directions[index];
  }
}

class DailyForecast {
  final DateTime date;
  final double minTemperature;
  final double maxTemperature;
  final String description;
  final String icon;

  DailyForecast({
    required this.date,
    required this.minTemperature,
    required this.maxTemperature,
    required this.description,
    required this.icon,
  });

  factory DailyForecast.fromJson(Map<String, dynamic> json) {
    return DailyForecast(
      date: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      minTemperature: (json['temp']['min'] as num).toDouble(),
      maxTemperature: (json['temp']['max'] as num).toDouble(),
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
    );
  }
}
