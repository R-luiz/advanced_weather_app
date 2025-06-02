class WeatherData {
  final double temperature;
  final String description;
  final String icon;
  final String cityName;
  final int humidity;
  final double windSpeed;
  final String? country;
  final String? region;
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
    );
  }
}

class HourlyForecast {
  final DateTime time;
  final double temperature;
  final String description;
  final String icon;
  final double windSpeed;

  HourlyForecast({
    required this.time,
    required this.temperature,
    required this.description,
    required this.icon,
    required this.windSpeed,
  });

  factory HourlyForecast.fromJson(Map<String, dynamic> json) {
    return HourlyForecast(
      time: DateTime.fromMillisecondsSinceEpoch(json['dt'] * 1000),
      temperature: (json['main']['temp'] as num).toDouble(),
      description: json['weather'][0]['description'] as String,
      icon: json['weather'][0]['icon'] as String,
      windSpeed: (json['wind']['speed'] as num).toDouble(),
    );
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
