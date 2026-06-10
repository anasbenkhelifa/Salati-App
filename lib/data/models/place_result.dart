/// Place search result from Nominatim API
class PlaceResult {
  final double lat;
  final double lng;
  final String cityName;
  final String countryName;
  final String isoCountryCode;
  final String displayLabel;

  const PlaceResult({
    required this.lat,
    required this.lng,
    required this.cityName,
    required this.countryName,
    this.isoCountryCode = '',
    required this.displayLabel,
  });

  /// Create from Nominatim JSON response
  factory PlaceResult.fromNominatim(Map<String, dynamic> json) {
    final address = json['address'] as Map<String, dynamic>? ?? {};

    // Extract city name (try multiple fields)
    final city =
        address['city'] ??
        address['town'] ??
        address['village'] ??
        address['municipality'] ??
        address['state'] ??
        '';

    final country = address['country'] ?? '';
    final countryCode = address['country_code'] ?? '';
    final displayName = json['display_name'] ?? '';

    // Parse coordinates
    final latStr = json['lat']?.toString() ?? '0';
    final lngStr = json['lon']?.toString() ?? '0';

    return PlaceResult(
      lat: double.tryParse(latStr) ?? 0,
      lng: double.tryParse(lngStr) ?? 0,
      cityName: city.toString(),
      countryName: country.toString(),
      isoCountryCode: countryCode.toString().toUpperCase(),
      displayLabel: displayName.toString(),
    );
  }

  @override
  String toString() => 'PlaceResult($cityName, $countryName, $lat, $lng)';
}
