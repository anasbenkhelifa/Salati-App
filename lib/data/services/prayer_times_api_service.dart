import 'package:flutter/foundation.dart';
import 'package:adhan/adhan.dart';
import 'package:intl/intl.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:lat_lng_to_timezone/lat_lng_to_timezone.dart' as tzmap;

/// Legacy models kept for backwards compatibility with the app architecture
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
    final data = json['data'] ?? json;
    final timingsData = data['timings'] ?? data['times'] ?? {};
    return AlAdhanResponse(
      timings: AlAdhanTimings.fromJson(timingsData),
      meta: data['meta'] != null
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
  algeria(19, 'Algeria (Ministry of Religious Affairs)', 'الجزائر (وزارة الشؤون الدينية)');

  final int id;
  final String nameEn;
  final String nameAr;
  const CalculationMethodId(this.id, this.nameEn, this.nameAr);

  CalculationParameters get parameters {
    switch (this) {
      case CalculationMethodId.mwl:
        return CalculationMethod.muslim_world_league.getParameters();
      case CalculationMethodId.isna:
        return CalculationMethod.north_america.getParameters();
      case CalculationMethodId.egypt:
        return CalculationMethod.egyptian.getParameters();
      case CalculationMethodId.ummAlQura:
        return CalculationMethod.umm_al_qura.getParameters();
      case CalculationMethodId.karachi:
        return CalculationMethod.karachi.getParameters();
      case CalculationMethodId.dubai:
        return CalculationMethod.dubai.getParameters();
      case CalculationMethodId.qatar:
        return CalculationMethod.qatar.getParameters();
      case CalculationMethodId.kuwait:
        return CalculationMethod.kuwait.getParameters();
      case CalculationMethodId.singapore:
        return CalculationMethod.singapore.getParameters();
      case CalculationMethodId.tehran:
        return CalculationMethod.tehran.getParameters();
      case CalculationMethodId.turkey:
        return CalculationMethod.turkey.getParameters();
      case CalculationMethodId.algeria:
        // Algerian parameters are typically 18 deg Fajr and 17 deg Isha, exactly matching MWL.
        return CalculationMethod.muslim_world_league.getParameters();
    }
  }
}

enum MadhabId {
  shafi(1, 'Shafi (Standard)', 'الشافعي'),
  hanafi(2, 'Hanafi', 'الحنفي');

  final int id;
  final String nameEn;
  final String nameAr;
  const MadhabId(this.id, this.nameEn, this.nameAr);

  Madhab get adhanMadhab {
    return this == MadhabId.hanafi ? Madhab.hanafi : Madhab.shafi;
  }
}

/// Service to calculate prayer times entirely OFFLINE using package:adhan
class PrayerTimesApiService {
  Future<AlAdhanResponse> fetchPrayerTimesByCoordinates({
    required double latitude,
    required double longitude,
    required CalculationMethodId method,
    required MadhabId madhab,
    DateTime? date,
  }) async {
    date ??= DateTime.now();

    // Fix: Resolve offline timezone string precisely from lat/lng
    String tzName = tzmap.latLngToTimezoneString(latitude, longitude);
    if (tzName == 'unknown' || tzName.isEmpty) {
      tzName = 'UTC'; // Fallback if absolutely necessary
    }

    // Get current offset for that timezone (this dynamically handles Daylight Savings Time)
    final location = tz.getLocation(tzName);
    final nowTimezone = tz.TZDateTime.from(date, location);
    final offsetSeconds = nowTimezone.timeZoneOffset.inSeconds;

    final utcOffset = Duration(seconds: offsetSeconds);
    
    // We also want to correctly set the meta timezone to the resolved one
    final metaTimezoneOffset = nowTimezone.timeZoneName;

    debugPrint('[PrayerTimesApiService] ========== OFFLINE CALCULATION ==========');
    debugPrint('[PrayerTimesApiService] Lat: $latitude, Lng: $longitude');
    debugPrint('[PrayerTimesApiService] Timezone: $tzName (Offset: ${utcOffset.inHours}h ${utcOffset.inMinutes.remainder(60)}m)');
    debugPrint('[PrayerTimesApiService] Method: ${method.nameEn}, School: ${madhab.nameEn}');

    final coordinates = Coordinates(latitude, longitude);
    final params = method.parameters;
    params.madhab = madhab.adhanMadhab;
    
    // Calculate Prayer Times natively using explicit timezone offset
    final dateComponents = DateComponents.from(date);
    final prayers = PrayerTimes(coordinates, dateComponents, params, utcOffset: utcOffset);

    final formatter = DateFormat('HH:mm');

    // Calculate Midnight (between Maghrib and Fajr next day) natively if needed, 
    // or estimate it (halfway between sunset and sunrise)
    final tomorrow = date.add(const Duration(days: 1));
    final tomorrowPrayers = PrayerTimes(coordinates, DateComponents.from(tomorrow), params, utcOffset: utcOffset);
    
    // In Islam, night usually starts at Maghrib and ends at Fajr. Midnight is halfway.
    final nightDuration = tomorrowPrayers.fajr.difference(prayers.maghrib);
    final midnight = prayers.maghrib.add(Duration(minutes: nightDuration.inMinutes ~/ 2));

    // Imsak is typically 10 minutes before Fajr
    final imsak = prayers.fajr.subtract(const Duration(minutes: 10));

    final timings = AlAdhanTimings(
      fajr: formatter.format(prayers.fajr),
      sunrise: formatter.format(prayers.sunrise),
      dhuhr: formatter.format(prayers.dhuhr),
      asr: formatter.format(prayers.asr),
      maghrib: formatter.format(prayers.maghrib),
      isha: formatter.format(prayers.isha),
      imsak: formatter.format(imsak),
      midnight: formatter.format(midnight),
    );

    final readableDate = DateFormat('dd MMM yyyy').format(date);

    return AlAdhanResponse(
      timings: timings,
      meta: AlAdhanMeta(
        timezone: tzName,
        method: method.nameEn,
        school: madhab.nameEn,
        latitude: latitude,
        longitude: longitude,
      ),
      dateReadable: readableDate,
      isFromCache: false,
      requestUrl: 'offline://calculated',
    );
  }
}
