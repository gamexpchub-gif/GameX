import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/api.dart';
import '../../discover/data/pincode.dart';

/// Result of a PIN code lookup.
class PinInfo {
  const PinInfo({
    required this.pin,
    required this.city,
    required this.state,
    this.areas = const [],
    this.exact = true,
  });
  final String pin;
  final String city;
  final String state;

  /// Post-office localities under this PIN (tap to fill "Area").
  final List<String> areas;

  /// false when only estimated offline from the PIN prefix.
  final bool exact;
}

/// Address fields read from the phone's location.
class LocatedAddress {
  const LocatedAddress({
    required this.lat,
    required this.lng,
    this.pincode = '',
    this.city = '',
    this.state = '',
    this.area = '',
    this.street = '',
  });
  final double lat;
  final double lng;
  final String pincode;
  final String city;
  final String state;
  final String area;
  final String street;
}

class LocationProblem implements Exception {
  const LocationProblem(this.message, {this.openSettings = false});
  final String message;

  /// The user must enable location / permission in system settings.
  final bool openSettings;
  @override
  String toString() => message;
}

class AddressService {
  AddressService(this._api);
  final Api _api;
  final _cache = <String, PinInfo>{};

  /// Exact data from India Post via the GAMEX server, or an offline
  /// estimate from the PIN prefix when the server can't be reached.
  Future<PinInfo?> lookup(String pin) async {
    if (!RegExp(r'^[1-9]\d{5}$').hasMatch(pin)) return null;
    final hit = _cache[pin];
    if (hit != null) return hit;
    try {
      final j = await _api.get('/pincode/$pin') as Map<String, dynamic>;
      final v = PinInfo(
        pin: pin,
        city: _titleCase(j['district'] as String? ?? ''),
        state: _titleCase(j['state'] as String? ?? ''),
        areas: (j['areas'] as List? ?? const []).cast<String>(),
      );
      return _cache[pin] = v;
    } on ApiException catch (e) {
      if (e.message.contains('does not exist')) return null;
    } catch (_) {}
    final p = lookupPin(pin);
    return p == null
        ? null
        : PinInfo(pin: pin, city: p.city, state: p.state, exact: false);
  }

  /// Reads the current position and turns it into address fields.
  Future<LocatedAddress> current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationProblem(
        'Turn on Location to fill your address automatically',
        openSettings: true,
      );
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw const LocationProblem('Location permission was not given');
    }
    if (perm == LocationPermission.deniedForever) {
      throw const LocationProblem(
        'Allow location for GAMEX in Settings to use this',
        openSettings: true,
      );
    }
    final pos = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 15),
      ),
    );
    var out = LocatedAddress(lat: pos.latitude, lng: pos.longitude);
    try {
      final marks = await Geocoding().placemarkFromCoordinates(
        pos.latitude,
        pos.longitude,
      );
      if (marks.isNotEmpty) {
        final m = marks.first;
        final street = <String>[
          ?m.subThoroughfare,
          ?m.thoroughfare,
        ].where((s) => s.trim().isNotEmpty).join(' ');
        out = LocatedAddress(
          lat: pos.latitude,
          lng: pos.longitude,
          pincode: m.postalCode ?? '',
          city: (m.locality?.isNotEmpty ?? false)
              ? m.locality!
              : m.subAdministrativeArea ?? '',
          state: m.administrativeArea ?? '',
          area: (m.subLocality?.isNotEmpty ?? false)
              ? m.subLocality!
              : m.name ?? '',
          street: street,
        );
      }
    } catch (_) {
      // Geocoder unavailable: keep coordinates; PIN lookup fills the rest.
    }
    return out;
  }

  Future<void> openSettings() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      await Geolocator.openLocationSettings();
    } else {
      await Geolocator.openAppSettings();
    }
  }
}

String _titleCase(String s) => s
    .toLowerCase()
    .split(' ')
    .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// Cities with next-day express delivery (matches "Mumbai Suburban",
/// "New Delhi", "Bangalore Urban"…).
bool isMetroCity(String? city) {
  final c = (city ?? '').toLowerCase();
  const names = [
    'mumbai',
    'delhi',
    'bengaluru',
    'bangalore',
    'kolkata',
    'chennai',
    'hyderabad',
  ];
  return names.any(c.contains);
}

final addressServiceProvider = Provider<AddressService>(
  (ref) => AddressService(ref.watch(apiProvider)),
);
