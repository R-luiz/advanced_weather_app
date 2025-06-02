import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
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
              children: [
                // Location header
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
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Temperature display
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
                        _weatherData!.description,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                          color: Colors.orange.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Weather details
                Container(
                  padding: const EdgeInsets.all(20.0),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.circular(16.0),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Icon(
                            Icons.air,
                            color: Colors.blue.shade600,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Wind',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_weatherData!.windSpeed} km/h',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        height: 50,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      Column(
                        children: [
                          Icon(
                            Icons.visibility,
                            color: Colors.green.shade600,
                            size: 28,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Humidity',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          Text(
                            '${_weatherData!.humidity}%',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
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
    } else {
      return _buildDefaultContent();
    }
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
      return Column(
        children: [
          _locationHeader(),
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
                  color: Colors.white.withOpacity(0.9),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${hourlyData.time.hour}:00',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        Column(
                          children: [
                            Text(
                              '${hourlyData.temperature.toStringAsFixed(1)}°C',
                              style: const TextStyle(color: Colors.black87),
                            ),
                            Text(
                              hourlyData.description,
                              style: TextStyle(
                                color: Colors.grey[700],
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${hourlyData.windSpeed} km/h',
                          style: const TextStyle(color: Colors.black87),
                        ),
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
      return Column(
        children: [
          _locationHeader(),
          Expanded(
            child: ListView.builder(
              itemCount: _weatherData!.dailyForecast!.length,
              itemBuilder: (context, index) {
                final dailyData = _weatherData!.dailyForecast![index];
                // Format the date
                final date = dailyData.date;
                final formattedDate = '${date.day}/${date.month}/${date.year}';
                return Card(
                  margin: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 8,
                  ),
                  color: Colors.white.withOpacity(0.9),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Date
                        Text(
                          formattedDate,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                        // Temperature range
                        Column(
                          children: [
                            Text(
                              'Min: ${dailyData.minTemperature.toStringAsFixed(1)}°C',
                              style: const TextStyle(color: Colors.black87),
                            ),
                            Text(
                              'Max: ${dailyData.maxTemperature.toStringAsFixed(1)}°C',
                              style: const TextStyle(color: Colors.black87),
                            ),
                          ],
                        ),
                        // Weather description
                        Flexible(
                          child: Text(
                            dailyData.description,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
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
}
