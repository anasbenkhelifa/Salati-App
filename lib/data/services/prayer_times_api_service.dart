import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Response model for Prayer Times API
class AlAdhanTimings {
  final String fajr;
  final String sunrise;
  final String dhuhr;
  final String asr;
  final String maghrib;
  final String isha;
  final String imsak;
  final String midnight;

  AlAdhanTimings({
    required this.fajr,
    required this.sunrise,
    required this.dhuhr,
    required this.asr,
    required this.maghrib,
    required this.isha,
    required this.imsak,
    required this.midnight,
  });

  /// Parse from IslamicAPI response format (times already in local timezone)
  factory AlAdhanTimings.fromIslamicApi(Map<String, dynamic> json) {
    return AlAdhanTimings(
      fajr: json['Fajr'] ?? '',
      sunrise: json['Sunrise'] ?? '',
      dhuhr: json['Dhuhr'] ?? '',
      asr: json['Asr'] ?? '',
      maghrib: json['Maghrib'] ?? '',
      isha: json['Isha'] ?? '',
      imsak: json['Imsak'] ?? '',
      midnight: json['Midnight'] ?? '',
    );
  }

  /// Parse from cached JSON format
  factory AlAdhanTimings.fromJson(Map<String, dynamic> json) {
    String cleanTime(String time) {
      return time.replaceAll(RegExp(r'\s*\(.*\)'), '').trim();
    }

    return AlAdhanTimings(
      fajr: cleanTime(json['Fajr'] ?? json['fajr'] ?? ''),
      sunrise: cleanTime(json['Sunrise'] ?? json['sunrise'] ?? ''),
      dhuhr: cleanTime(json['Dhuhr'] ?? json['dhuhr'] ?? ''),
      asr: cleanTime(json['Asr'] ?? json['asr'] ?? ''),
      maghrib: cleanTime(json['Maghrib'] ?? json['maghrib'] ?? ''),
      isha: cleanTime(json['Isha'] ?? json['isha'] ?? ''),
      imsak: cleanTime(json['Imsak'] ?? json['imsak'] ?? ''),
      midnight: cleanTime(json['Midnight'] ?? json['midnight'] ?? ''),
    );
  }
}

/// Metadata from API response
class AlAdhanMeta {
  final String timezone;
  final String method;
  final String school;
  final double latitude;
  final double longitude;

  AlAdhanMeta({
    required this.timezone,
    required this.method,
    required this.school,
    required this.latitude,
    required this.longitude,
  });

  factory AlAdhanMeta.fromJson(Map<String, dynamic> json) {
    return AlAdhanMeta(
      timezone: json['timezone'] ?? '',
      method: json['method']?['name'] ?? json['method'] ?? '',
      school: json['school'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}

/// Full API response
class AlAdhanResponse {
  final AlAdhanTimings timings;
  final AlAdhanMeta meta;
  final String dateReadable;
  final bool isFromCache;
  final String requestUrl;

  AlAdhanResponse({
    required this.timings,
    required this.meta,
    required this.dateReadable,
    this.isFromCache = false,
    this.requestUrl = '',
  });

  /// Parse from IslamicAPI response format
  factory AlAdhanResponse.fromIslamicApi(
    Map<String, dynamic> json, {
    String requestUrl = '',
    double latitude = 0.0,
    double longitude = 0.0,
  }) {
    final data = json['data'] ?? {};
    final times = data['times'] ?? {};
    final timezone = data['timezone'] ?? {};

    return AlAdhanResponse(
      timings: AlAdhanTimings.fromIslamicApi(times),
      meta: AlAdhanMeta(
        timezone: timezone['name'] ?? '',
        method: '',
        school: '',
        latitude: latitude,
        longitude: longitude,
      ),
      dateReadable: data['date']?['readable'] ?? '',
      isFromCache: false,
      requestUrl: requestUrl,
    );
  }

  /// Parse from cached JSON format
  factory AlAdhanResponse.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
    String requestUrl = '',
    double latitude = 0.0,
    double longitude = 0.0,
  }) {
    final data = json['data'] ?? json;
    final timingsData = data['timings'] ?? data['times'] ?? {};

    return AlAdhanResponse(
      timings: AlAdhanTimings.fromJson(timingsData),
      meta:
          data['meta'] != null
              ? AlAdhanMeta.fromJson(data['meta'])
              : AlAdhanMeta(
                timezone: data['timezone']?['name'] ?? '',
                method: '',
                school: '',
                latitude: latitude,
                longitude: longitude,
              ),
      dateReadable: data['date']?['readable'] ?? '',
      isFromCache: isFromCache,
      requestUrl: requestUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': {
        'timings': {
          'Fajr': timings.fajr,
          'Sunrise': timings.sunrise,
          'Dhuhr': timings.dhuhr,
          'Asr': timings.asr,
          'Maghrib': timings.maghrib,
          'Isha': timings.isha,
          'Imsak': timings.imsak,
          'Midnight': timings.midnight,
        },
        'meta': {
          'timezone': meta.timezone,
          'method': {'name': meta.method},
          'school': meta.school,
          'latitude': meta.latitude,
          'longitude': meta.longitude,
        },
        'date': {'readable': dateReadable},
      },
    };
  }
}

/// Calculation methods supported by IslamicAPI
enum CalculationMethodId {
  mwl(3, 'Muslim World League', 'رابطة العالم الإسلامي'),
  isna(2, 'ISNA (North America)', 'الجمعية الإسلامية لأمريكا الشمالية'),
  egypt(5, 'Egyptian General Authority', 'الهيئة العامة المصرية'),
  ummAlQura(4, 'Umm Al-Qura University', 'جامعة أم القرى'),
  karachi(1, 'University of Karachi', 'جامعة كراتشي'),
  dubai(16, 'Dubai (UAE)', 'دبي'),
  qatar(10, 'Qatar', 'قطر'),
  kuwait(9, 'Kuwait', 'الكويت'),
  singapore(11, 'Singapore', 'سنغافورة'),
  tehran(7, 'Tehran', 'طهران'),
  turkey(13, 'Turkey (Diyanet)', 'تركيا (ديانت)'),
  algeria(
    19,
    'Algeria (Ministry of Religious Affairs)',
    'الجزائر (وزارة الشؤون الدينية)',
  );

  final int id;
  final String nameEn;
  final String nameAr;

  const CalculationMethodId(this.id, this.nameEn, this.nameAr);
}

/// Madhab/School options
enum MadhabId {
  shafi(1, 'Shafi (Standard)', 'الشافعي'),
  hanafi(2, 'Hanafi', 'الحنفي');

  final int id;
  final String nameEn;
  final String nameAr;

  const MadhabId(this.id, this.nameEn, this.nameAr);
}

/// Service to fetch prayer times from IslamicAPI
/// https://islamicapi.com/doc/prayer-time/
class PrayerTimesApiService {
  static const String _baseUrl = 'https://islamicapi.com/api/v1/prayer-time/';
  static const String _apiKey =
      '0LXJrCmyBRD1KDXf3R4SaSdJgbIQLr5tSzS0Kj9CW6XQZ0yS';

  /// Fetch prayer times by coordinates
  Future<AlAdhanResponse> fetchPrayerTimesByCoordinates({
    required double latitude,
    required double longitude,
    required CalculationMethodId method,
    required MadhabId madhab,
    DateTime? date,
  }) async {
    final uri = Uri.parse(_baseUrl).replace(
      queryParameters: {
        'lat': latitude.toString(),
        'lon': longitude.toString(),
        'method': method.id.toString(),
        'school': madhab.id.toString(),
        'api_key': _apiKey,
      },
    );

    final requestUrl = uri.toString();

    debugPrint('[PrayerTimesApiService] ========== API REQUEST ==========');
    debugPrint('[PrayerTimesApiService] Lat: $latitude, Lng: $longitude');
    debugPrint(
      '[PrayerTimesApiService] Method: ${method.id}, School: ${madhab.id}',
    );
    debugPrint('[PrayerTimesApiService] URL: $requestUrl');
    debugPrint('[PrayerTimesApiService] ===============================');

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['status'] == 'success') {
          debugPrint(
            '[PrayerTimesApiService] SUCCESS - Fajr: ${json['data']?['times']?['Fajr']}',
          );
          return AlAdhanResponse.fromIslamicApi(
            json,
            requestUrl: requestUrl,
            latitude: latitude,
            longitude: longitude,
          );
        } else {
          throw Exception(
            'API returned error: ${json['message'] ?? 'Unknown error'}',
          );
        }
      } else if (response.statusCode == 429) {
        debugPrint('[PrayerTimesApiService] Rate limited! Wait a moment');
        throw Exception('Rate limited. Please wait and try again.');
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[PrayerTimesApiService] ERROR: $e');
      rethrow;
    }
  }
}
