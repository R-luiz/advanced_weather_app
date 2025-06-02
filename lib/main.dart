import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'services/location_service.dart';
import 'services/weather_service.dart';
import 'models/city_suggestion.dart';
import 'models/weather_model.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Weather App',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final LocationService _locationService = LocationService();
  final WeatherService _weatherService = WeatherService();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Weather App'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Currently'),
            Tab(text: 'Today'),
            Tab(text: 'Weekly'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                // Search field
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: 'Search for a city',
                      suffixIcon: IconButton(
                        icon: const Icon(Icons.search),
                        onPressed: _searchLocation,
                      ),
                      border: const OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _searchLocation(),
                  ),
                ),

                // Location button
                IconButton(
                  onPressed: _getLocationAndWeather,
                  tooltip: 'Get Current Location',
                  icon:
                      _isLoadingLocation
                          ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                          : const Icon(Icons.my_location),
                  padding: const EdgeInsets.all(8.0),
                ),
              ],
            ),
          ),

          // City suggestions
          if (_citySuggestions.isNotEmpty)
            Container(
              height: 200,
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              color: Colors.grey[200],
              child:
                  _isLoadingSuggestions
                      ? const Center(child: CircularProgressIndicator())
                      : ListView.builder(
                        itemCount: _citySuggestions.length,
                        itemBuilder: (context, index) {
                          final suggestion = _citySuggestions[index];
                          return ListTile(
                            title: Text(suggestion.toString()),
                            onTap: () => _searchByCitySuggestion(suggestion),
                          );
                        },
                      ),
            ),

          // Persistent error message for city not found or API connection issues
          if (_weatherErrorMessage != null)
            Container(
              padding: const EdgeInsets.all(12.0),
              margin: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                border: Border.all(color: Colors.red.shade200),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Icon(
                    _weatherErrorMessage!.contains('city')
                        ? Icons.location_off
                        : Icons.wifi_off,
                    color: Colors.red,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _weatherErrorMessage!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.red),
                    onPressed:
                        () => setState(() => _weatherErrorMessage = null),
                  ),
                ],
              ),
            ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildTabContent('Currently'),
                _buildTabContent('Today'),
                _buildTabContent('Weekly'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // State variables
  String _displayText = '';
  Position? _currentPosition;
  String? _errorMessage;
  String? _weatherErrorMessage;
  bool _isLoadingLocation = false;
  List<CitySuggestion> _citySuggestions = [];
  bool _isLoadingSuggestions = false;
  WeatherData? _weatherData;
  bool _isLoadingWeather = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {});
    });

    // Set up a listener for the search text field
    _searchController.addListener(_onSearchChanged);

    // Try to get location when app starts
    _getLocation();
  }

  // Debounce mechanism to prevent too many API calls
  Future<void> _onSearchChanged() async {
    if (_searchController.text.length > 2) {
      // Only search if text is long enough
      setState(() {
        _isLoadingSuggestions = true;
      });

      try {
        final suggestions = await _weatherService.getCitySuggestions(
          _searchController.text,
        );
        setState(() {
          _citySuggestions = suggestions;
          _isLoadingSuggestions = false;
        });
      } catch (e) {
        setState(() {
          _citySuggestions = [];
          _isLoadingSuggestions = false;
        });

        // Only show error if the search field still has text and widget is still mounted
        if (_searchController.text.isNotEmpty && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching suggestions: ${e.toString()}'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } else {
      setState(() {
        _citySuggestions = [];
        _isLoadingSuggestions = false;
      });
    }
  }

  // Try to get the current location of the user
  Future<void> _getLocation() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      setState(() {
        _currentPosition = position;
        if (position != null) {
          _displayText = _locationService.formatLocation(position);
        }
        _isLoadingLocation = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingLocation = false;
        _displayText = 'Please enter a city name to get weather information';
      });

      // Show error message to user if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Get location and weather data
  Future<void> _getLocationAndWeather() async {
    setState(() {
      _isLoadingLocation = true;
      _errorMessage = null;
    });

    try {
      final position = await _locationService.getCurrentLocation();
      setState(() {
        _currentPosition = position;
        if (position != null) {
          _displayText = _locationService.formatLocation(position);
        }
        _isLoadingLocation = false;
      });

      // Fetch weather data for the current location
      if (position != null) {
        _fetchWeatherData(position.latitude, position.longitude);
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoadingLocation = false;
        _displayText = 'Please enter a city name to get weather information';
      });

      // Show error message to user if widget is still mounted
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Location error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Fetch weather data by coordinates
  Future<void> _fetchWeatherData(double latitude, double longitude) async {
    setState(() {
      _isLoadingWeather = true;
      _weatherErrorMessage = null; // Clear any previous weather errors
    });

    try {
      final weather = await _weatherService.getWeatherByCoordinates(
        latitude,
        longitude,
      );
      setState(() {
        _weatherData = weather;
        _displayText = 'Weather for ${weather.cityName}';
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWeather = false;
        _weatherErrorMessage = e.toString(); // Store the error message
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching weather: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Search using the entered text directly
  Future<void> _searchLocation() async {
    if (_searchController.text.isEmpty) return;

    setState(() {
      _isLoadingWeather = true;
      _weatherErrorMessage = null; // Clear any previous weather errors
      _citySuggestions = []; // Clear suggestions when performing a search
    });

    try {
      final weather = await _weatherService.getWeatherByCity(
        _searchController.text,
      );
      setState(() {
        _weatherData = weather;
        _displayText = 'Weather for ${weather.cityName}';
        _isLoadingWeather = false;
      });

      _searchController.clear();
    } catch (e) {
      setState(() {
        _isLoadingWeather = false;
        _weatherErrorMessage = e.toString(); // Store the error message
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching weather: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Search using a specific city suggestion
  Future<void> _searchByCitySuggestion(CitySuggestion suggestion) async {
    setState(() {
      _isLoadingWeather = true;
      _weatherErrorMessage = null; // Clear any previous weather errors
      _citySuggestions = []; // Clear suggestions
      _searchController.clear(); // Clear search field
    });

    try {
      final weather = await _weatherService.getWeatherByCoordinates(
        suggestion.lat,
        suggestion.lon,
      );
      setState(() {
        _weatherData = weather;
        _displayText = 'Weather for ${suggestion.toString()}';
        _isLoadingWeather = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingWeather = false;
        _weatherErrorMessage = e.toString(); // Store the error message
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error fetching weather: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to build tab content
  Widget _buildTabContent(String tabName) {
    // Location header that's common across all tabs
    Widget locationHeader() {
      String locationText = '';
      if (_weatherData != null) {
        locationText = _weatherData!.cityName;
        if (_weatherData!.region != null && _weatherData!.region!.isNotEmpty) {
          locationText += ', ${_weatherData!.region}';
        }
        if (_weatherData!.country != null &&
            _weatherData!.country!.isNotEmpty) {
          locationText += ', ${_weatherData!.country}';
        }
      } else {
        locationText = _displayText;
      }

      return Column(
        children: [
          Text(
            'Location: $locationText',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
        ],
      );
    }

    // Build default content when no weather data is available
    Widget buildDefaultContent() {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                tabName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),

              // Show loading indicator when fetching location
              if (_isLoadingLocation)
                Column(
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    const Text('Getting your location...'),
                  ],
                )
              // Show error message if there's an error
              else if (_errorMessage != null)
                Column(
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to access location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Please enter a city name in the search bar',
                      textAlign: TextAlign.center,
                    ),
                  ],
                )
              // Show location information when available
              else if (_currentPosition != null)
                Column(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: Colors.green,
                      size: 48,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Your Current Location',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _displayText,
                      style: const TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Ready to fetch weather data',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                )
              // Show a default message
              else
                const Text(
                  'Search for a location or use your current location',
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      );
    }

    // Build content for "Currently" tab
    Widget buildCurrentContent() {
      if (_isLoadingWeather) {
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading current weather data...'),
          ],
        );
      } else if (_weatherData != null) {
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            locationHeader(),
            const SizedBox(height: 8),
            Text(
              '${_weatherData!.temperature.toStringAsFixed(1)}°C',
              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              _weatherData!.description,
              style: const TextStyle(fontSize: 18),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.air),
                const SizedBox(width: 8),
                Text('Wind: ${_weatherData!.windSpeed} km/h'),
              ],
            ),
          ],
        );
      } else {
        return buildDefaultContent();
      }
    }

    // Build content for "Today" tab
    Widget buildTodayContent() {
      if (_isLoadingWeather) {
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading hourly forecast data...'),
          ],
        );
      } else if (_weatherData != null &&
          _weatherData!.hourlyForecast != null &&
          _weatherData!.hourlyForecast!.isNotEmpty) {
        return Column(
          children: [
            locationHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: _weatherData!.hourlyForecast!.length,
                itemBuilder: (context, index) {
                  final hourlyData = _weatherData!.hourlyForecast![index];
                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            '${hourlyData.time.hour}:00',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Column(
                            children: [
                              Text(
                                '${hourlyData.temperature.toStringAsFixed(1)}°C',
                              ),
                              Text(hourlyData.description),
                            ],
                          ),
                          Text('${hourlyData.windSpeed} km/h'),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      } else if (_weatherData != null) {
        return Column(
          children: [
            locationHeader(),
            const Text("No hourly forecast available for today"),
          ],
        );
      } else {
        return buildDefaultContent();
      }
    }

    // Build content for "Weekly" tab
    Widget buildWeeklyContent() {
      if (_isLoadingWeather) {
        return const Column(
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading weekly forecast data...'),
          ],
        );
      } else if (_weatherData != null &&
          _weatherData!.dailyForecast != null &&
          _weatherData!.dailyForecast!.isNotEmpty) {
        return Column(
          children: [
            locationHeader(),
            Expanded(
              child: ListView.builder(
                itemCount: _weatherData!.dailyForecast!.length,
                itemBuilder: (context, index) {
                  final dailyData = _weatherData!.dailyForecast![index];
                  // Format the date
                  final date = dailyData.date;
                  final formattedDate =
                      '${date.day}/${date.month}/${date.year}';

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      vertical: 4,
                      horizontal: 8,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Date
                          Text(
                            formattedDate,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          // Temperature range
                          Column(
                            children: [
                              Text(
                                'Min: ${dailyData.minTemperature.toStringAsFixed(1)}°C',
                              ),
                              Text(
                                'Max: ${dailyData.maxTemperature.toStringAsFixed(1)}°C',
                              ),
                            ],
                          ),
                          Text(dailyData.description), // Weather description
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      } else if (_weatherData != null) {
        return Column(
          children: [
            locationHeader(),
            const Expanded(
              child: Center(
                child: Text(
                  "No weekly forecast data available",
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ),
          ],
        );
      } else {
        return buildDefaultContent();
      }
    }

    // Return the appropriate content based on the tab name
    switch (tabName) {
      case 'Currently':
        return buildCurrentContent();
      case 'Today':
        return buildTodayContent();
      case 'Weekly':
        return buildWeeklyContent();
      default:
        return buildDefaultContent();
    }
  }
}
