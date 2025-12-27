import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';

/// Response model for AlAdhan API
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
    // Remove any "(DST)" or timezone annotations from time strings
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

/// Metadata from AlAdhan API response
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
      method: json['method']?['name'] ?? '',
      school: json['school'] ?? '',
      latitude: (json['latitude'] ?? 0.0).toDouble(),
      longitude: (json['longitude'] ?? 0.0).toDouble(),
    );
  }
}

/// Full AlAdhan API response
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
    // Support both 'timings' (AlAdhan) and 'times' (IslamicAPI) keys
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

/// Calculation methods supported by AlAdhan API
enum CalculationMethodId {
  mwl(3, 'Muslim World League', 'رابطة العالم الإسلامي'),
  isna(2, 'ISNA (North America)', 'الجمعية الإسلامية لأمريكا الشمالية'),
  egypt(5, 'Egyptian General Authority', 'الهيئة العامة المصرية'),
  ummAlQura(4, 'Umm Al-Qura University', 'جامعة أم القرى'),
  karachi(1, 'University of Karachi', 'جامعة كراتشي'),
  dubai(16, 'Dubai (UAE)', 'دبي'),
  qatar(8, 'Qatar', 'قطر'),
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
  shafi(0, 'Shafi (Standard)', 'الشافعي'),
  hanafi(1, 'Hanafi', 'الحنفي');

  final int id;
  final String nameEn;
  final String nameAr;

  const MadhabId(this.id, this.nameEn, this.nameAr);
}

/// Service to fetch prayer times from AlAdhan API using coordinates
class PrayerTimesApiService {
  // Use timings endpoint with lat/lon (more accurate than city-based)
  static const String _baseUrl = 'https://api.aladhan.com/v1/timings';

  /// Fetch prayer times by coordinates (preferred method)
  Future<AlAdhanResponse> fetchPrayerTimesByCoordinates({
    required double latitude,
    required double longitude,
    required CalculationMethodId method,
    required MadhabId madhab,
    DateTime? date,
  }) async {
    final targetDate = date ?? DateTime.now();
    final dateStr = DateFormat('dd-MM-yyyy').format(targetDate);

    final uri = Uri.parse('$_baseUrl/$dateStr').replace(
      queryParameters: {
        'latitude': latitude.toString(),
        'longitude': longitude.toString(),
        'method': method.id.toString(),
        'school': madhab.id.toString(),
      },
    );

    final requestUrl = uri.toString();

    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 15));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        if (json['code'] == 200 && json['status'] == 'OK') {
          return AlAdhanResponse.fromJson(
            json,
            requestUrl: requestUrl,
            latitude: latitude,
            longitude: longitude,
          );
        } else {
          throw Exception('API returned error: ${json['status']}');
        }
      } else {
        throw Exception('HTTP error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }
}
