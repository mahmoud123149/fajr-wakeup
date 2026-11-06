import 'package:geolocator/geolocator.dart';

/// Thin wrapper over geolocator. All usage is optional: the user can always
/// enter latitude/longitude manually (see Prayer settings screen).
class LocationService {
  Future<bool> isServiceEnabled() => Geolocator.isLocationServiceEnabled();

  Future<LocationPermission> checkPermission() => Geolocator.checkPermission();

  Future<bool> ensurePermission() async {
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    return perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
  }

  /// Returns the current position, or null if unavailable/denied.
  Future<Position?> current() async {
    if (!await isServiceEnabled()) return null;
    if (!await ensurePermission()) return null;
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
    } catch (_) {
      // Fall back to the last known position if a fresh fix times out.
      return Geolocator.getLastKnownPosition();
    }
  }
}
