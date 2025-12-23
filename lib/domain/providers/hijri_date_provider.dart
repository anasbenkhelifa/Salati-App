import 'package:flutter/foundation.dart';
import '../../data/services/hijri_date_service.dart';

/// Provider to manage Hijri date state
class HijriDateProvider extends ChangeNotifier {
  final HijriDateService _service = HijriDateService();

  HijriDate? _hijriDate;
  bool _isLoading = false;
  String? _error;

  HijriDate? get hijriDate => _hijriDate;
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Formatted date for Arabic
  String get arabicDate => _hijriDate?.formatArabic() ?? '—';

  /// Formatted date for English
  String get englishDate => _hijriDate?.formatEnglish() ?? '—';

  /// Get formatted date based on language
  String getFormattedDate(bool isArabic) {
    if (_hijriDate == null) return '—';
    return isArabic ? _hijriDate!.formatArabic() : _hijriDate!.formatEnglish();
  }

  /// Get weekday based on language
  String getWeekday(bool isArabic) {
    if (_hijriDate == null) return '';
    return isArabic ? _hijriDate!.weekdayAr : _hijriDate!.weekdayEn;
  }

  /// Initialize and fetch today's Hijri date
  Future<void> initialize() async {
    if (_hijriDate != null) return; // Already loaded

    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final today = DateTime.now();
      _hijriDate = await _service.getHijriDate(today);

      if (_hijriDate == null) {
        _error = 'Could not fetch Hijri date';
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[HijriDateProvider] Error: $e');
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Refresh the Hijri date
  Future<void> refresh() async {
    _hijriDate = null;
    await initialize();
  }
}
