import 'dart:convert';
import 'package:http/http.dart' as http;

/// Response model for IslamicAPI Prayer Times
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

  factory AlAdhanTimings.fromJson(Map<String, dynamic> json) {
    // Remove any "DST" or timezone annotations from time strings
    String cleanTime(String time) {
      return time.replaceAll(RegExp(r'\s*\(.*\)'), '').trim();
    }

    return AlAdhanTimings(
      fajr: cleanTime(json['Fajr'] ?? ''),
      sunrise: cleanTime(json['Sunrise'] ?? ''),
      dhuhr: cleanTime(json['Dhuhr'] ?? ''),
      asr: cleanTime(json['Asr'] ?? ''),
      maghrib: cleanTime(json['Maghrib'] ?? ''),
      isha: cleanTime(json['Isha'] ?? ''),
      imsak: cleanTime(json['Imsak'] ?? ''),
      midnight: cleanTime(json['Midnight'] ?? ''),
    );
  }
}

/// Metadata from IslamicAPI response
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

  factory AlAdhanMeta.fromJson(
    Map<String, dynamic> json,
    double lat,
    double lon,
  ) {
    // IslamicAPI puts timezone in a separate object
    final tz = json['timezone'];
    return AlAdhanMeta(
      timezone: tz?['name'] ?? '',
      method: '', // IslamicAPI doesn't return method name in response
      school: '', // School not returned in response
      latitude: lat,
      longitude: lon,
    );
  }
}

/// Full IslamicAPI response (keeping class name for compatibility)
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

  factory AlAdhanResponse.fromJson(
    Map<String, dynamic> json, {
    bool isFromCache = false,
    String requestUrl = '',
    double latitude = 0.0,
    double longitude = 0.0,
  }) {
    final data = json['data'];
    // IslamicAPI uses 'times' instead of 'timings'
    final times = data['times'] ?? data['timings'] ?? {};

    return AlAdhanResponse(
      timings: AlAdhanTimings.fromJson(times),
      meta: AlAdhanMeta.fromJson(data, latitude, longitude),
      dateReadable: data['date']?['readable'] ?? '',
      isFromCache: isFromCache,
      requestUrl: requestUrl,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'data': {
        'times': {
          'Fajr': timings.fajr,
          'Sunrise': timings.sunrise,
          'Dhuhr': timings.dhuhr,
          'Asr': timings.asr,
          'Maghrib': timings.maghrib,
          'Isha': timings.isha,
          'Imsak': timings.imsak,
          'Midnight': timings.midnight,
        },
        'timezone': {'name': meta.timezone},
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
/// IslamicAPI uses: 1 = Shafi, 2 = Hanafi
enum MadhabId {
  shafi(1, 'Shafi (Standard)', 'الشافعي'),
  hanafi(2, 'Hanafi', 'الحنفي');

  final int id;
  final String nameEn;
  final String nameAr;

  const MadhabId(this.id, this.nameEn, this.nameAr);
}

/// Service to fetch prayer times from IslamicAPI using coordinates
class PrayerTimesApiService {
  // IslamicAPI endpoint
  static const String _baseUrl = 'https://islamicapi.com/api/v1/prayer-time/';

  // API key (optional - try without first)
  static const String _apiKey = '';

  /// Fetch prayer times by coordinates
  Future<AlAdhanResponse> fetchPrayerTimesByCoordinates({
    required double latitude,
    required double longitude,
    required CalculationMethodId method,
    required MadhabId madhab,
    DateTime? date,
  }) async {
    final queryParams = <String, String>{
      'lat': latitude.toString(),
      'lon': longitude.toString(),
      'method': method.id.toString(),
      'school': madhab.id.toString(),
    };

    // Add API key if available
    if (_apiKey.isNotEmpty) {
      queryParams['api_key'] = _apiKey;
    }

    final uri = Uri.parse(_baseUrl).replace(queryParameters: queryParams);
    final requestUrl = uri.toString();

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        // IslamicAPI uses "success" status
        if (json['code'] == 200 && json['status'] == 'success') {
          return AlAdhanResponse.fromJson(
            json,
            requestUrl: requestUrl,
            latitude: latitude,
            longitude: longitude,
          );
        } else {
          throw Exception(
            'API returned error: ${json['message'] ?? json['status']}',
          );
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
