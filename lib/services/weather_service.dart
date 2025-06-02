import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import '../models/weather_model.dart';
import '../models/city_suggestion.dart';

class WeatherService {
  // Replace with your API key from OpenWeatherMap
  static const String _apiKey =
      '37ed9df251818f111a4d455a6cdb779b'; // Replace this with your actual API key
  static const String _baseUrl =
      'https://api.openweathermap.org/data/2.5/weather';
  static const String _forecastUrl =
      'https://api.openweathermap.org/data/2.5/forecast';
  static const String _oneCallUrl =
      'https://api.openweathermap.org/data/3.0/onecall';
  static const String _geocodingUrl =
      'https://api.openweathermap.org/geo/1.0/direct';
  static const int _maxResults = 5; // Max number of city suggestions

  // Get complete weather data by city name
  Future<WeatherData> getWeatherByCity(String city) async {
    try {
      // Get current weather
      final currentWeatherResponse = await http
          .get(Uri.parse('$_baseUrl?q=$city&units=metric&appid=$_apiKey'))
          .timeout(const Duration(seconds: 10));

      if (currentWeatherResponse.statusCode == 200) {
        final currentWeatherData = jsonDecode(currentWeatherResponse.body);
        final lat = currentWeatherData['coord']['lat'];
        final lon = currentWeatherData['coord']['lon'];

        // Create initial weather data from current weather
        WeatherData weatherData = WeatherData.fromJson(currentWeatherData);

        // Add forecast data
        return _addForecastData(weatherData, lat, lon);
      } else if (currentWeatherResponse.statusCode == 404) {
        throw Exception(
          'City not found. Please check the city name and try again.',
        );
      } else {
        throw Exception(
          'Failed to load weather data: ${currentWeatherResponse.statusCode}',
        );
      }
    } on Exception catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception(
          'Network connection error. Please check your internet connection and try again.',
        );
      }
      // Re-throw the original exception if it's not a connection issue
      rethrow;
    }
  }

  // Get complete weather data by coordinates (lat/lon)
  Future<WeatherData> getWeatherByCoordinates(double lat, double lon) async {
    try {
      // Get current weather
      final currentWeatherResponse = await http
          .get(
            Uri.parse(
              '$_baseUrl?lat=$lat&lon=$lon&units=metric&appid=$_apiKey',
            ),
          )
          .timeout(const Duration(seconds: 10));

      if (currentWeatherResponse.statusCode == 200) {
        // Create initial weather data from current weather
        WeatherData weatherData = WeatherData.fromJson(
          jsonDecode(currentWeatherResponse.body),
        );

        // Add forecast data
        return _addForecastData(weatherData, lat, lon);
      } else {
        throw Exception(
          'Failed to load weather data: ${currentWeatherResponse.statusCode}',
        );
      }
    } on Exception catch (e) {
      if (e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception(
          'Network connection error. Please check your internet connection and try again.',
        );
      }
      // Re-throw the original exception if it's not a connection issue
      rethrow;
    }
  }

  // Helper to add forecast data to weather data
  Future<WeatherData> _addForecastData(
    WeatherData weatherData,
    double lat,
    double lon,
  ) async {
    // Get hourly forecast for today
    final hourlyForecastResponse = await http.get(
      Uri.parse('$_forecastUrl?lat=$lat&lon=$lon&units=metric&appid=$_apiKey'),
    );

    // Get daily forecast
    final dailyForecastResponse = await http.get(
      Uri.parse(
        '$_oneCallUrl?lat=$lat&lon=$lon&exclude=minutely,hourly,alerts&units=metric&appid=$_apiKey',
      ),
    );

    // Process hourly forecast data if available
    if (hourlyForecastResponse.statusCode == 200) {
      final forecastData = jsonDecode(hourlyForecastResponse.body);
      final List<dynamic> hourlyList = forecastData['list'];

      // Get today's date
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final tomorrow = today.add(Duration(days: 1));

      // Filter for today's forecasts only
      final todayForecasts =
          hourlyList.where((item) {
            final forecastTime = DateTime.fromMillisecondsSinceEpoch(
              item['dt'] * 1000,
            );
            return forecastTime.isAfter(now) && forecastTime.isBefore(tomorrow);
          }).toList();

      // Convert to hourly forecast objects
      final hourlyForecasts =
          todayForecasts.map((item) => HourlyForecast.fromJson(item)).toList();

      // Update city info if available
      final cityInfo = forecastData['city'];
      if (cityInfo != null) {
        weatherData = WeatherData(
          temperature: weatherData.temperature,
          description: weatherData.description,
          icon: weatherData.icon,
          cityName: weatherData.cityName,
          humidity: weatherData.humidity,
          windSpeed: weatherData.windSpeed,
          country: cityInfo['country'],
          region: null, // OpenWeatherMap doesn't provide region info
          hourlyForecast: hourlyForecasts,
          dailyForecast: weatherData.dailyForecast,
        );
      } else {
        weatherData = WeatherData(
          temperature: weatherData.temperature,
          description: weatherData.description,
          icon: weatherData.icon,
          cityName: weatherData.cityName,
          humidity: weatherData.humidity,
          windSpeed: weatherData.windSpeed,
          country: weatherData.country,
          region: weatherData.region,
          hourlyForecast: hourlyForecasts,
          dailyForecast: weatherData.dailyForecast,
        );
      }
    }

    // Process daily forecast data if available
    if (dailyForecastResponse.statusCode == 200) {
      final dailyData = jsonDecode(dailyForecastResponse.body);
      final List<dynamic> dailyList = dailyData['daily'] ?? [];

      // Convert to daily forecast objects (skip today, get next 7 days)
      final dailyForecasts =
          dailyList
              .take(7)
              .map((item) => DailyForecast.fromJson(item))
              .toList();

      weatherData = WeatherData(
        temperature: weatherData.temperature,
        description: weatherData.description,
        icon: weatherData.icon,
        cityName: weatherData.cityName,
        humidity: weatherData.humidity,
        windSpeed: weatherData.windSpeed,
        country: weatherData.country,
        region: weatherData.region,
        hourlyForecast: weatherData.hourlyForecast,
        dailyForecast: dailyForecasts,
      );
    }

    return weatherData;
  }

  // Get weather by current location
  Future<WeatherData> getWeatherByLocation() async {
    // Check and request location permissions
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied');
      }
    }

    // Get current position
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Get weather data based on coordinates
    return getWeatherByCoordinates(position.latitude, position.longitude);
  }

  // Get city suggestions as the user types in the search bar
  Future<List<CitySuggestion>> getCitySuggestions(String query) async {
    if (query.isEmpty) {
      return [];
    }

    final response = await http.get(
      Uri.parse('$_geocodingUrl?q=$query&limit=$_maxResults&appid=$_apiKey'),
    );

    if (response.statusCode == 200) {
      final List<dynamic> data = jsonDecode(response.body);
      return data.map((json) => CitySuggestion.fromJson(json)).toList();
    } else {
      throw Exception(
        'Failed to load city suggestions: ${response.statusCode}',
      );
    }
  }
}
