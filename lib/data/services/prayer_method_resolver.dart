import 'package:flutter/foundation.dart';
import 'prayer_times_api_service.dart';

class PrayerMethodResolver {
  /// Resolves the most appropriate calculation method based on ISO Country Code
  static CalculationMethodId resolveFromCountry(String isoCountryCode) {
    switch (isoCountryCode.toUpperCase()) {
      case 'US':
      case 'CA':
        return CalculationMethodId.isna;
      case 'SA':
      case 'AE':
      case 'KW':
      case 'BH':
      case 'QA':
      case 'OM':
      case 'YE':
        return CalculationMethodId.ummAlQura;
      case 'PK':
      case 'AF':
      case 'BD':
      case 'IN':
        return CalculationMethodId.karachi;
      case 'EG':
      case 'SY':
      case 'IQ':
      case 'LB':
      case 'JO':
      case 'LY':
      case 'SD':
        return CalculationMethodId.egypt;
      case 'IR':
        return CalculationMethodId.tehran;
      case 'MY':
        return CalculationMethodId.jakim;
      case 'SG':
      case 'ID':
        return CalculationMethodId.singapore;
      case 'TR':
        return CalculationMethodId.turkey;
      case 'FR':
        return CalculationMethodId.france;
      case 'DZ':
        return CalculationMethodId.algeria;
      default:
        // Default to MWL for Europe and rest of the world
        return CalculationMethodId.mwl;
    }
  }
}
