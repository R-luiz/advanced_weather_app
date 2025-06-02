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
  } // Get city suggestions as the user types in the search bar

  Future<List<CitySuggestion>> getCitySuggestions(String query) async {
    if (query.trim().isEmpty || query.trim().length < 2) {
      return [];
    }

    // Clean the query - remove extra spaces and normalize
    final cleanQuery = query.trim().toLowerCase();

    try {
      // Use a higher limit to get more results for better filtering
      final response = await http
          .get(
            Uri.parse(
              '$_geocodingUrl?q=${Uri.encodeComponent(query)}&limit=20&appid=$_apiKey',
            ),
          )
          .timeout(const Duration(seconds: 8));

      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        final suggestions =
            data.map((json) => CitySuggestion.fromJson(json)).toList();

        // Debug: Print original suggestions
        print('Debug: Original API returned ${suggestions.length} suggestions');
        for (var i = 0; i < suggestions.length && i < 10; i++) {
          print(
            '  $i: ${suggestions[i].name}, ${suggestions[i].region ?? 'No region'}, ${suggestions[i].country}',
          );
        }

        // Remove duplicates and improve relevance
        final filtered = _filterAndRankSuggestions(suggestions, cleanQuery);

        // Debug: Print final filtered suggestions
        print('Debug: Final filtered list has ${filtered.length} suggestions');
        for (var i = 0; i < filtered.length; i++) {
          print(
            '  $i: ${filtered[i].name}, ${filtered[i].region ?? 'No region'}, ${filtered[i].country}',
          );
        }

        return filtered;
      } else {
        throw Exception(
          'Failed to load city suggestions: ${response.statusCode}',
        );
      }
    } catch (e) {
      if (e.toString().contains('TimeoutException')) {
        throw Exception('Search timeout. Please try again.');
      }
      rethrow;
    }
  }

  /// Filters suggestions to remove duplicates and ranks them by relevance
  List<CitySuggestion> _filterAndRankSuggestions(
    List<CitySuggestion> suggestions,
    String query,
  ) {
    // Remove duplicates using Map to track unique cities
    final uniqueMap = <String, CitySuggestion>{};

    for (final suggestion in suggestions) {
      final key = suggestion.uniqueId;
      // Only add if we haven't seen this city before, or if this one has a better score
      if (!uniqueMap.containsKey(key)) {
        uniqueMap[key] = suggestion;
      } else {
        // If we have a duplicate, keep the one with the better relevance score
        final existingScore = _calculateRelevanceScore(uniqueMap[key]!, query);
        final newScore = _calculateRelevanceScore(suggestion, query);
        if (newScore > existingScore) {
          uniqueMap[key] = suggestion;
        }
      }
    }

    // Convert to list and sort by relevance
    final filteredList = uniqueMap.values.toList();
    filteredList.sort(
      (a, b) => _calculateRelevanceScore(
        b,
        query,
      ).compareTo(_calculateRelevanceScore(a, query)),
    ); // Final deduplication by city name and country to avoid similar cities
    final finalUniqueList = <CitySuggestion>[];
    final cityCountryTracker = <String, bool>{};

    for (final suggestion in filteredList) {
      final normalizedCityName = _normalizeCityName(suggestion.name);
      final cityCountryKey =
          '${normalizedCityName}_${suggestion.country.toLowerCase().trim()}';

      if (!cityCountryTracker.containsKey(cityCountryKey)) {
        cityCountryTracker[cityCountryKey] = true;
        finalUniqueList.add(suggestion);

        // Stop when we reach the maximum number of results
        if (finalUniqueList.length >= _maxResults) {
          break;
        }
      }
    }

    return finalUniqueList;
  }

  /// Normalizes city names to catch similar variations
  String _normalizeCityName(String cityName) {
    return cityName
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .replaceAll('saint', 'st')
        .replaceAll('sainte', 'st')
        .replaceAll('mount', 'mt')
        .replaceAll('fort', 'ft');
  }

  /// Calculates relevance score for ranking suggestions
  int _calculateRelevanceScore(CitySuggestion suggestion, String query) {
    int score = 0;
    final cityName = suggestion.name.toLowerCase().trim();
    final region = (suggestion.region ?? '').toLowerCase().trim();
    final country = suggestion.country.toLowerCase().trim();
    final normalizedQuery = query.toLowerCase().trim();

    // Exact match gets highest score
    if (cityName == normalizedQuery) {
      score += 1000; // Very high score for exact matches
    }
    // Starts with query gets high score
    else if (cityName.startsWith(normalizedQuery)) {
      score += 800;
      // Bonus for shorter names (likely more important cities)
      if (cityName.length <= normalizedQuery.length + 3) {
        score += 100;
      }
    }
    // Contains query gets medium score
    else if (cityName.contains(normalizedQuery)) {
      score += 400;
      // Bonus if the match is near the beginning
      final index = cityName.indexOf(normalizedQuery);
      if (index <= 2) {
        score += 200;
      }
    }

    // Check if query matches region/state
    if (region.isNotEmpty) {
      if (region == normalizedQuery) {
        score += 300;
      } else if (region.startsWith(normalizedQuery)) {
        score += 150;
      } else if (region.contains(normalizedQuery)) {
        score += 75;
      }
    }

    // Check if query matches country
    if (country == normalizedQuery) {
      score += 200;
    } else if (country.startsWith(normalizedQuery)) {
      score += 100;
    } else if (country.contains(normalizedQuery)) {
      score += 50;
    }

    // Prefer well-known major cities (shorter names often indicate major cities)
    if (cityName.length <= 8) {
      score += 50;
    } else if (cityName.length <= 12) {
      score += 25;
    }

    // Bonus for cities with regions (often more important/specific)
    if (region.isNotEmpty) {
      score += 10;
    }

    return score;
  }
}
