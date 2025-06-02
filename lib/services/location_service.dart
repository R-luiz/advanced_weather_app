import 'package:geolocator/geolocator.dart';

class LocationService {
  // Get current location with error handling
  Future<Position?> getCurrentLocation() async {
    bool serviceEnabled;
    LocationPermission permission;

    // Check if location services are enabled
    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      // Location services are disabled
      return Future.error('Location services are disabled.');
    }

    // Check for location permissions
    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      // Request permission
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        // Permission denied
        return Future.error('Location permissions are denied.');
      }
    }

    // Check if permission is permanently denied
    if (permission == LocationPermission.deniedForever) {
      return Future.error(
        'Location permissions are permanently denied, we cannot request permissions.',
      );
    }

    // Get current position
    try {
      return await Geolocator.getCurrentPosition();
    } catch (e) {
      return Future.error('Error getting location: $e');
    }
  }

  // Check permission status without requesting
  Future<bool> hasLocationPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    return permission == LocationPermission.whileInUse ||
        permission == LocationPermission.always;
  }

  // Format location as string for display
  String formatLocation(Position position) {
    return 'Latitude: ${position.latitude.toStringAsFixed(4)}, '
        'Longitude: ${position.longitude.toStringAsFixed(4)}';
  }
}
