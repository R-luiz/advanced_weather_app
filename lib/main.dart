import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:async';
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

  // Debouncing timer for search suggestions
  Timer? _debounceTimer;
  static const Duration _debounceDuration = Duration(milliseconds: 500);
  @override
  Widget build(BuildContext context) {
    final appBarHeight = kToolbarHeight + 48; // AppBar + TabBar height

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text(
          'Weather App',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
            shadows: [
              Shadow(
                offset: Offset(1, 1),
                blurRadius: 3,
                color: Colors.black54,
              ),
            ],
          ),
        ),
        backgroundColor: Colors.black.withOpacity(0.4),
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelStyle: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          tabs: const [
            Tab(text: 'Currently', icon: Icon(Icons.wb_sunny, size: 18)),
            Tab(text: 'Today', icon: Icon(Icons.schedule, size: 18)),
            Tab(text: 'Weekly', icon: Icon(Icons.calendar_month, size: 18)),
          ],
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          image: DecorationImage(
            image: AssetImage('assets/images/weather-app-background.png'),
            fit: BoxFit.cover,
            alignment: Alignment.center,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top spacing for app bar
              SizedBox(height: appBarHeight),

              // Search section with proper background
              Container(
                margin: const EdgeInsets.all(12.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(16.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      spreadRadius: 1,
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    // Search bar
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            decoration: InputDecoration(
                              labelText: 'Search for a city',
                              hintText: 'e.g., London, Paris, New York',
                              filled: true,
                              fillColor: Colors.grey.shade50,
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                                vertical: 12.0,
                              ),
                              suffixIcon: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (_searchController.text.isNotEmpty)
                                    IconButton(
                                      icon: const Icon(Icons.clear),
                                      onPressed: () {
                                        _searchController.clear();
                                        setState(() {
                                          _citySuggestions = [];
                                        });
                                      },
                                    ),
                                  IconButton(
                                    icon: const Icon(Icons.search),
                                    onPressed: _searchLocation,
                                  ),
                                ],
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12.0),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onSubmitted: (_) => _searchLocation(),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Location button with background
                        Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(12.0),
                            border: Border.all(color: Colors.blue.shade200),
                          ),
                          child: IconButton(
                            onPressed: _getLocationAndWeather,
                            tooltip: 'Get Current Location',
                            icon:
                                _isLoadingLocation
                                    ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                    : const Icon(
                                      Icons.my_location,
                                      color: Colors.blue,
                                    ),
                          ),
                        ),
                      ],
                    ),

                    // City suggestions
                    if (_citySuggestions.isNotEmpty || _isLoadingSuggestions)
                      Container(
                        margin: const EdgeInsets.only(top: 12.0),
                        constraints: const BoxConstraints(maxHeight: 200),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(12.0),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child:
                            _isLoadingSuggestions
                                ? const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(16.0),
                                    child: CircularProgressIndicator(),
                                  ),
                                )
                                : ListView.separated(
                                  shrinkWrap: true,
                                  itemCount: _citySuggestions.length,
                                  separatorBuilder:
                                      (context, index) => Divider(
                                        height: 1,
                                        color: Colors.grey.shade200,
                                      ),
                                  itemBuilder: (context, index) {
                                    final suggestion = _citySuggestions[index];
                                    return ListTile(
                                      dense: true,
                                      leading: const Icon(
                                        Icons.location_city,
                                        color: Colors.blue,
                                        size: 20,
                                      ),
                                      title: Text(
                                        suggestion.name,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 14,
                                        ),
                                      ),
                                      subtitle: Text(
                                        suggestion.region != null &&
                                                suggestion.region!.isNotEmpty
                                            ? '${suggestion.region}, ${suggestion.country}'
                                            : suggestion.country,
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 12,
                                        ),
                                      ),
                                      trailing: const Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Colors.grey,
                                      ),
                                      onTap:
                                          () => _searchByCitySuggestion(
                                            suggestion,
                                          ),
                                    );
                                  },
                                ),
                      ),
                  ],
                ),
              ),

              // Error message with proper background
              if (_weatherErrorMessage != null)
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 12.0),
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.red.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
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
                          style: const TextStyle(
                            color: Colors.red,
                            fontWeight: FontWeight.w500,
                          ),
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

              if (_weatherErrorMessage != null) const SizedBox(height: 12),

              // Tab content with proper spacing
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
        ),
      ),
    );
  } // State variables

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
    // Cancel previous timer
    _debounceTimer?.cancel();

    // Set new timer
    _debounceTimer = Timer(_debounceDuration, () async {
      final query = _searchController.text.trim();

      if (query.length >= 2) {
        setState(() {
          _isLoadingSuggestions = true;
          _citySuggestions = [];
        });

        try {
          final suggestions = await _weatherService.getCitySuggestions(query);

          // Only update if the search text hasn't changed
          if (_searchController.text.trim() == query && mounted) {
            setState(() {
              _citySuggestions = suggestions;
              _isLoadingSuggestions = false;
            });
          }
        } catch (e) {
          if (mounted && _searchController.text.trim() == query) {
            setState(() {
              _citySuggestions = [];
              _isLoadingSuggestions = false;
            });

            // Show error only if search field still has text
            if (query.isNotEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error fetching suggestions: ${e.toString()}'),
                  backgroundColor: Colors.orange,
                  duration: const Duration(seconds: 2),
                ),
              );
            }
          }
        }
      } else {
        if (mounted) {
          setState(() {
            _citySuggestions = [];
            _isLoadingSuggestions = false;
          });
        }
      }
    });
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
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a city name'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isLoadingWeather = true;
      _weatherErrorMessage = null; // Clear any previous weather errors
      _citySuggestions = []; // Clear suggestions when performing a search
    });

    try {
      final weather = await _weatherService.getWeatherByCity(query);
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
    _debounceTimer?.cancel();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Helper method to build tab content
  Widget _buildTabContent(String tabName) {
    switch (tabName) {
      case 'Currently':
        return _buildCurrentContent();
      case 'Today':
        return _buildTodayContent();
      case 'Weekly':
        return _buildWeeklyContent();
      default:
        return _buildDefaultContent();
    }
  }

  // Location header that's common across all tabs
  Widget _locationHeader() {
    String locationText = '';
    if (_weatherData != null) {
      locationText = _weatherData!.cityName;
      if (_weatherData!.region != null && _weatherData!.region!.isNotEmpty) {
        locationText += ', ${_weatherData!.region}';
      }
      if (_weatherData!.country != null && _weatherData!.country!.isNotEmpty) {
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

  // Helper method to get tab icons
  IconData _getTabIcon(String tabName) {
    switch (tabName) {
      case 'Currently':
        return Icons.wb_sunny;
      case 'Today':
        return Icons.schedule;
      case 'Weekly':
        return Icons.calendar_month;
      default:
        return Icons.info;
    }
  }

  // Build default content when no weather data is available
  Widget _buildDefaultContent() {
    return Container(
      margin: const EdgeInsets.all(16.0),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(32.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.95),
            borderRadius: BorderRadius.circular(20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                spreadRadius: 2,
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12.0),
                ),
                child: Icon(
                  _getTabIcon('Currently'),
                  size: 48,
                  color: Colors.blue.shade600,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Weather App',
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12.0),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  children: [
                    // Show loading indicator when fetching location
                    if (_isLoadingLocation)
                      Column(
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 16),
                          const Text(
                            'Getting your location...',
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      )
                    // Show error message if there's an error
                    else if (_errorMessage != null)
                      Column(
                        children: [
                          Icon(
                            Icons.location_off,
                            color: Colors.orange.shade600,
                            size: 40,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Unable to access location',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Please enter a city name in the search bar above',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ],
                      )
                    // Show location information when available
                    else if (_currentPosition != null)
                      Column(
                        children: [
                          Icon(
                            Icons.location_on,
                            color: Colors.green.shade600,
                            size: 40,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Your Current Location',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _displayText,
                            style: const TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                              vertical: 8.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(8.0),
                              border: Border.all(color: Colors.green.shade200),
                            ),
                            child: Text(
                              'Ready to fetch weather data',
                              style: TextStyle(
                                color: Colors.green.shade700,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      )
                    // Show a default message
                    else
                      Column(
                        children: [
                          Icon(
                            Icons.search,
                            color: Colors.blue.shade600,
                            size: 40,
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Search for a location or use your current location',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Build content for "Currently" tab
  Widget _buildCurrentContent() {
    if (_isLoadingWeather) {
      return Container(
        margin: const EdgeInsets.all(16.0),
        child: Center(
          child: Container(
            padding: const EdgeInsets.all(32.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: const Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircularProgressIndicator(strokeWidth: 3),
                SizedBox(height: 24),
                Text(
                  'Loading current weather data...',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else if (_weatherData != null) {
      return Container(
        margin: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: BorderRadius.circular(20.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Column(
              children: [
                // Location header with weather icon
                Container(
                  padding: const EdgeInsets.all(16.0),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    borderRadius: BorderRadius.circular(12.0),
                    border: Border.all(color: Colors.blue.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.location_on, color: Colors.blue.shade600),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _weatherData!.cityName +
                              (_weatherData!.region != null &&
                                      _weatherData!.region!.isNotEmpty
                                  ? ', ${_weatherData!.region}'
                                  : '') +
                              (_weatherData!.country != null &&
                                      _weatherData!.country!.isNotEmpty
                                  ? ', ${_weatherData!.country}'
                                  : ''),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.blue.shade800,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      Text(
                        _getWeatherEmoji(_weatherData!.icon),
                        style: const TextStyle(fontSize: 32),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Main temperature display
                Container(
                  padding: const EdgeInsets.all(24.0),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Colors.orange.shade50, Colors.yellow.shade50],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Column(
                    children: [
                      Text(
                        '${_weatherData!.temperature.toStringAsFixed(1)}°C',
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange.shade800,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _weatherData!.description.toUpperCase(),
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.orange.shade700,
                          letterSpacing: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_weatherData!.feelsLike != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Feels like ${_weatherData!.feelsLike!.toStringAsFixed(1)}°C',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.orange.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Detailed weather information grid
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Column(
                    children: [
                      // First row - Wind and Humidity
                      Row(
                        children: [
                          Expanded(
                            child: _buildCurrentDetailItem(
                              icon: Icons.air,
                              label: 'Wind Speed',
                              value:
                                  '${_weatherData!.windSpeed.toStringAsFixed(1)} km/h',
                              color: Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCurrentDetailItem(
                              icon: Icons.water_drop,
                              label: 'Humidity',
                              value: '${_weatherData!.humidity}%',
                              color: Colors.cyan,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Second row - Wind Direction and Pressure
                      Row(
                        children: [
                          Expanded(
                            child: _buildCurrentDetailItem(
                              icon: Icons.navigation,
                              label: 'Wind Direction',
                              value: _weatherData!.windDirection ?? 'N/A',
                              color: Colors.purple,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildCurrentDetailItem(
                              icon: Icons.compress,
                              label: 'Pressure',
                              value:
                                  _weatherData!.pressure != null
                                      ? '${_weatherData!.pressure} hPa'
                                      : 'N/A',
                              color: Colors.teal,
                            ),
                          ),
                        ],
                      ),

                      if (_weatherData!.visibility != null) ...[
                        const SizedBox(height: 16),
                        // Third row - Visibility
                        _buildCurrentDetailItem(
                          icon: Icons.visibility,
                          label: 'Visibility',
                          value:
                              '${_weatherData!.visibility!.toStringAsFixed(1)} km',
                          color: Colors.green,
                        ),
                      ],
                    ],
                  ),
                ),

                // Sun times if available
                if (_weatherData!.sunrise != null &&
                    _weatherData!.sunset != null) ...[
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20.0),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.amber.shade50, Colors.orange.shade50],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16.0),
                      border: Border.all(color: Colors.amber.shade200),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildSunTimeItem(
                            icon: Icons.wb_sunny,
                            label: 'Sunrise',
                            time: _weatherData!.sunrise!,
                            color: Colors.orange,
                          ),
                        ),
                        const SizedBox(width: 20),
                        Container(
                          height: 50,
                          width: 1,
                          color: Colors.amber.shade300,
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: _buildSunTimeItem(
                            icon: Icons.brightness_3,
                            label: 'Sunset',
                            time: _weatherData!.sunset!,
                            color: Colors.deepOrange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    } else {
      return _buildDefaultContent();
    }
  }

  // Helper method to build detail items for current weather
  Widget _buildCurrentDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  // Helper method to build sun time items
  Widget _buildSunTimeItem({
    required IconData icon,
    required String label,
    required DateTime time,
    required Color color,
  }) {
    final timeString =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';

    return Column(
      children: [
        Icon(icon, color: color, size: 32),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          timeString,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  // Build content for "Today" tab
  Widget _buildTodayContent() {
    if (_isLoadingWeather) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading hourly forecast data...'),
            ],
          ),
        ),
      );
    } else if (_weatherData != null &&
        _weatherData!.hourlyForecast != null &&
        _weatherData!.hourlyForecast!.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _locationHeader(),
            // Temperature Chart Section
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '24-Hour Temperature Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 200, child: _buildTemperatureChart()),
                ],
              ),
            ),
            // Detailed Hourly Forecast Cards
            ListView.builder(
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(
                horizontal: 8.0,
                vertical: 8.0,
              ),
              itemCount: _weatherData!.hourlyForecast!.length,
              itemBuilder: (context, index) {
                final hourlyData = _weatherData!.hourlyForecast![index];
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.95),
                    borderRadius: BorderRadius.circular(16.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        spreadRadius: 1,
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Time and main temperature row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '${hourlyData.time.hour.toString().padLeft(2, '0')}:00',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 18,
                                color: Colors.black87,
                              ),
                            ),
                            Row(
                              children: [
                                // Weather icon (using emoji representation)
                                Text(
                                  _getWeatherEmoji(hourlyData.icon),
                                  style: const TextStyle(fontSize: 24),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '${hourlyData.temperature.toStringAsFixed(1)}°C',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: Colors.black87,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Weather description
                        Text(
                          hourlyData.description.toUpperCase(),
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Detailed weather information in a grid
                        Row(
                          children: [
                            Expanded(
                              child: _buildDetailItem(
                                icon: Icons.water_drop,
                                label: 'Humidity',
                                value: '${hourlyData.humidity}%',
                                color: Colors.blue,
                              ),
                            ),
                            Expanded(
                              child: _buildDetailItem(
                                icon: Icons.air,
                                label: 'Wind',
                                value:
                                    '${hourlyData.windSpeed.toStringAsFixed(1)} km/h',
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // Additional details row
                        Row(
                          children: [
                            if (hourlyData.feelsLike != null)
                              Expanded(
                                child: _buildDetailItem(
                                  icon: Icons.thermostat,
                                  label: 'Feels like',
                                  value:
                                      '${hourlyData.feelsLike!.toStringAsFixed(1)}°C',
                                  color: Colors.orange,
                                ),
                              ),
                            if (hourlyData.windDirection != null)
                              Expanded(
                                child: _buildDetailItem(
                                  icon: Icons.navigation,
                                  label: 'Direction',
                                  value: hourlyData.windDirection!,
                                  color: Colors.purple,
                                ),
                              ),
                          ],
                        ),

                        if (hourlyData.visibility != null) ...[
                          const SizedBox(height: 8),
                          _buildDetailItem(
                            icon: Icons.visibility,
                            label: 'Visibility',
                            value:
                                '${hourlyData.visibility!.toStringAsFixed(1)} km',
                            color: Colors.teal,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    } else if (_weatherData != null) {
      return Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _locationHeader(),
            const Text(
              "No hourly forecast available for today",
              style: TextStyle(color: Colors.black87),
            ),
          ],
        ),
      );
    } else {
      return _buildDefaultContent();
    }
  }

  // Helper method to build detail items for hourly forecast
  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 8.0),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get weather emoji from icon code
  String _getWeatherEmoji(String iconCode) {
    switch (iconCode) {
      case '01d': // clear sky day
        return '☀️';
      case '01n': // clear sky night
        return '🌙';
      case '02d': // few clouds day
        return '🌤️';
      case '02n': // few clouds night
        return '🌙';
      case '03d':
      case '03n': // scattered clouds
        return '☁️';
      case '04d':
      case '04n': // broken clouds
        return '☁️';
      case '09d':
      case '09n': // shower rain
        return '🌦️';
      case '10d': // rain day
        return '🌧️';
      case '10n': // rain night
        return '🌧️';
      case '11d':
      case '11n': // thunderstorm
        return '⛈️';
      case '13d':
      case '13n': // snow
        return '❄️';
      case '50d':
      case '50n': // mist
        return '🌫️';
      default:
        return '🌤️';
    }
  }

  // Build temperature chart for the Today tab
  Widget _buildTemperatureChart() {
    if (_weatherData == null ||
        _weatherData!.hourlyForecast == null ||
        _weatherData!.hourlyForecast!.isEmpty) {
      return const Center(
        child: Text(
          'No temperature data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final spots = <FlSpot>[];
    final labels = <String>[];

    // Create a full 24-hour data structure
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);

    // Create 24 data points for each hour of the day
    for (int hour = 0; hour < 24; hour++) {
      final hourTime = startOfDay.add(Duration(hours: hour));
      labels.add('${hour.toString().padLeft(2, '0')}:00');

      // Find matching forecast data for this hour
      HourlyForecast? matchingForecast;
      for (final forecast in _weatherData!.hourlyForecast!) {
        if (forecast.time.hour == hour &&
            forecast.time.day == hourTime.day &&
            forecast.time.month == hourTime.month &&
            forecast.time.year == hourTime.year) {
          matchingForecast = forecast;
          break;
        }
      }

      // Use forecast data if available, otherwise interpolate or use a default
      if (matchingForecast != null) {
        spots.add(FlSpot(hour.toDouble(), matchingForecast.temperature));
      } else {
        // If no data for this hour, try to interpolate from available data
        // or use the current temperature as fallback
        double temperature = _weatherData!.temperature;

        // Try to find the closest available forecast data
        HourlyForecast? closestForecast;
        int minTimeDiff = 25; // More than 24 hours

        for (final forecast in _weatherData!.hourlyForecast!) {
          final timeDiff = (forecast.time.hour - hour).abs();
          if (timeDiff < minTimeDiff) {
            minTimeDiff = timeDiff;
            closestForecast = forecast;
          }
        }

        if (closestForecast != null && minTimeDiff <= 3) {
          // Use closest forecast if within 3 hours
          temperature = closestForecast.temperature;
        }

        spots.add(FlSpot(hour.toDouble(), temperature));
      }
    }

    if (spots.isEmpty) {
      return const Center(
        child: Text(
          'No temperature data to display',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    // Calculate min and max temperatures for better chart scaling
    final temperatures = spots.map((spot) => spot.y).toList();
    final minTemp = temperatures.reduce((a, b) => a < b ? a : b);
    final maxTemp = temperatures.reduce((a, b) => a > b ? a : b);
    final tempRange = maxTemp - minTemp;
    final margin = tempRange * 0.1; // 10% margin for better visualization

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: tempRange > 0 ? tempRange / 4 : 5,
          verticalInterval: 4,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Colors.grey, strokeWidth: 0.5);
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(color: Colors.grey, strokeWidth: 0.5);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              interval: 4, // Show every 4 hours (0, 4, 8, 12, 16, 20)
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < labels.length && index % 4 == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: tempRange > 0 ? tempRange / 4 : 5,
              reservedSize: 40,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '${value.toInt()}°',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: Colors.grey.withOpacity(0.3)),
        ),
        minX: 0,
        maxX: 23,
        minY: minTemp - margin,
        maxY: maxTemp + margin,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            gradient: LinearGradient(
              colors: [
                Colors.blue.withOpacity(0.8),
                Colors.lightBlue.withOpacity(0.8),
              ],
            ),
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: true,
              getDotPainter:
                  (spot, percent, barData, index) => FlDotCirclePainter(
                    radius: 4,
                    color: Colors.blue,
                    strokeWidth: 2,
                    strokeColor: Colors.white,
                  ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.blue.withOpacity(0.1),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                if (index >= 0 && index < labels.length) {
                  return LineTooltipItem(
                    '${labels[index]}\n${barSpot.y.toStringAsFixed(1)}°C',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              }).toList();
            },
            getTooltipColor: (touchedSpot) => Colors.blue.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  // Build content for "Weekly" tab
  Widget _buildWeeklyContent() {
    if (_isLoadingWeather) {
      return Center(
        child: Container(
          padding: const EdgeInsets.all(24.0),
          margin: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.9),
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Loading weekly forecast data...'),
            ],
          ),
        ),
      );
    } else if (_weatherData != null &&
        _weatherData!.dailyForecast != null &&
        _weatherData!.dailyForecast!.isNotEmpty) {
      return SingleChildScrollView(
        child: Column(
          children: [
            _locationHeader(),

            // Weekly Temperature Chart Section
            Container(
              margin: const EdgeInsets.all(16.0),
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.95),
                borderRadius: BorderRadius.circular(16.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    spreadRadius: 1,
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '7-Day Temperature Trend',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(height: 250, child: _buildWeeklyTemperatureChart()),
                ],
              ),
            ),

            // Weekly Forecast List
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.all(16.0),
                    child: Text(
                      '7-Day Detailed Forecast',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  ListView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    itemCount: _weatherData!.dailyForecast!.length,
                    itemBuilder: (context, index) {
                      final dailyData = _weatherData!.dailyForecast![index];
                      return _buildWeeklyForecastCard(dailyData, index);
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    } else if (_weatherData != null) {
      return Container(
        margin: const EdgeInsets.all(16.0),
        padding: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.9),
          borderRadius: BorderRadius.circular(16.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            _locationHeader(),
            const Expanded(
              child: Center(
                child: Text(
                  "No weekly forecast data available",
                  style: TextStyle(fontSize: 16, color: Colors.black87),
                ),
              ),
            ),
          ],
        ),
      );
    } else {
      return _buildDefaultContent();
    }
  }

  // Build temperature chart for the Weekly tab
  Widget _buildWeeklyTemperatureChart() {
    if (_weatherData == null ||
        _weatherData!.dailyForecast == null ||
        _weatherData!.dailyForecast!.isEmpty) {
      return const Center(
        child: Text(
          'No weekly temperature data available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final minSpots = <FlSpot>[];
    final maxSpots = <FlSpot>[];
    final labels = <String>[];

    // Days of the week
    const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    for (int i = 0; i < _weatherData!.dailyForecast!.length && i < 7; i++) {
      final forecast = _weatherData!.dailyForecast![i];
      minSpots.add(FlSpot(i.toDouble(), forecast.minTemperature));
      maxSpots.add(FlSpot(i.toDouble(), forecast.maxTemperature));

      // Get day of week
      final dayIndex = (forecast.date.weekday - 1) % 7; // Convert to 0-6 index
      labels.add(dayNames[dayIndex]);
    }

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          getDrawingHorizontalLine: (value) {
            return const FlLine(color: Colors.grey, strokeWidth: 0.5);
          },
          getDrawingVerticalLine: (value) {
            return const FlLine(color: Colors.grey, strokeWidth: 0.5);
          },
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          topTitles: const AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (double value, TitleMeta meta) {
                final index = value.toInt();
                if (index >= 0 && index < labels.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      labels[index],
                      style: const TextStyle(
                        color: Colors.grey,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  );
                }
                return const Text('');
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 5,
              getTitlesWidget: (double value, TitleMeta meta) {
                return Text(
                  '${value.toInt()}°',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                );
              },
              reservedSize: 32,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d)),
        ),
        minX: 0,
        maxX: (labels.length - 1).toDouble(),
        minY:
            minSpots.map((spot) => spot.y).reduce((a, b) => a < b ? a : b) - 3,
        maxY:
            maxSpots.map((spot) => spot.y).reduce((a, b) => a > b ? a : b) + 3,
        lineBarsData: [
          // Min temperature line
          LineChartBarData(
            spots: minSpots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
          // Max temperature line
          LineChartBarData(
            spots: maxSpots,
            isCurved: true,
            color: Colors.red,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(show: false),
          ),
        ],
        lineTouchData: LineTouchData(
          enabled: true,
          touchTooltipData: LineTouchTooltipData(
            getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
              return touchedBarSpots.map((barSpot) {
                final index = barSpot.x.toInt();
                final isMinTemp = barSpot.barIndex == 0;
                final tempType = isMinTemp ? 'Min' : 'Max';
                if (index >= 0 && index < labels.length) {
                  return LineTooltipItem(
                    '${labels[index]}\n$tempType: ${barSpot.y.toStringAsFixed(1)}°C',
                    TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return null;
              }).toList();
            },
            getTooltipColor: (touchedSpot) => Colors.black87.withOpacity(0.8),
          ),
        ),
      ),
    );
  }

  // Build weekly forecast card for each day
  Widget _buildWeeklyForecastCard(DailyForecast dailyData, int index) {
    const dayNames = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final dayIndex = (dailyData.date.weekday - 1) % 7;
    final dayName = dayNames[dayIndex];

    // Format the date
    final formattedDate =
        '${dailyData.date.day}/${dailyData.date.month}/${dailyData.date.year}';

    // Determine if it's today or tomorrow
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final cardDate = DateTime(
      dailyData.date.year,
      dailyData.date.month,
      dailyData.date.day,
    );

    String dayLabel = dayName;
    if (cardDate == today) {
      dayLabel = 'Today';
    } else if (cardDate == today.add(const Duration(days: 1))) {
      dayLabel = 'Tomorrow';
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6.0),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.95),
        borderRadius: BorderRadius.circular(16.0),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day and date row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dayLabel,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: Colors.black87,
                      ),
                    ),
                    Text(
                      formattedDate,
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
                // Weather icon and description
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _getWeatherEmoji(dailyData.icon),
                      style: const TextStyle(fontSize: 32),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dailyData.description.toUpperCase(),
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey[700],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Temperature information
            Container(
              padding: const EdgeInsets.all(16.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blue.shade50, Colors.red.shade50],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(12.0),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                children: [
                  // Min temperature
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.thermostat, color: Colors.blue, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Min',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${dailyData.minTemperature.toStringAsFixed(1)}°C',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Separator
                  Container(height: 50, width: 1, color: Colors.grey.shade400),

                  // Max temperature
                  Expanded(
                    child: Column(
                      children: [
                        Icon(Icons.thermostat, color: Colors.red, size: 24),
                        const SizedBox(height: 4),
                        Text(
                          'Max',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.red.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          '${dailyData.maxTemperature.toStringAsFixed(1)}°C',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
