import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/alert_mode_service.dart';
import '../widgets/prayer_alert_mode_button.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/adhan_selection_sheet.dart';
import '../../data/services/adhan_selection_service.dart';

/// Prayer times screen with AlAdhan API + GPS integration
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  final PrayerTimesApiProvider _provider = PrayerTimesApiProvider();
  final AlertModeService _alertModeService = AlertModeService();
  Timer? _countdownTimer;
  Duration _countdown = Duration.zero;

  // Per-prayer alert modes
  Map<String, AlertMode> _alertModes = {};
  static const _prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  @override
  void initState() {
    super.initState();
    _initializePrayerTimes();
  }

  Future<void> _initializePrayerTimes() async {
    await _provider.initialize();
    await _loadAlertModes();
    _startCountdownTimer();
    if (mounted) setState(() {});
  }

  Future<void> _loadAlertModes() async {
    _alertModes = await _alertModeService.loadAlertModes();
  }

  void _toggleAlertMode(int index) {
    final key = _prayerKeys[index];
    final currentMode = _alertModes[key] ?? AlertMode.sound;
    final newMode = currentMode.next;
    _alertModes[key] = newMode;
    _alertModeService.saveAlertMode(key, newMode);
    setState(() {});
  }

  void _startCountdownTimer() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        setState(() {
          _countdown = _provider.getCountdown();
        });
      }
    });
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 20),
              // Title
              Center(
                child: Text(
                  t(context, 'prayerTimes'),
                  style: TextStyle(
                    color: AppTheme.currentTextPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Content based on state
              Expanded(child: _buildContent(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    switch (_provider.state) {
      case PrayerDataState.loading:
        return _buildLoadingState();
      case PrayerDataState.permissionDenied:
        return _buildPermissionDeniedState(context);
      case PrayerDataState.locationDisabled:
        return _buildLocationDisabledState(context);
      case PrayerDataState.error:
        return _buildErrorState(context);
      case PrayerDataState.success:
      case PrayerDataState.offline:
        return _buildSuccessState(context);
    }
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.currentActiveGlow),
          SizedBox(height: 16),
          Text(
            'Getting location...',
            style: TextStyle(
              color: AppTheme.currentTextSecondary,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.location_off, size: 64, color: AppTheme.iconSecondary),
            const SizedBox(height: 16),
            Text(
              'Location Permission Required',
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We need your location to calculate accurate prayer times for your area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _provider.requestPermission();
                    if (mounted) setState(() {});
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.currentActiveGlow,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Grant Permission'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await _provider.openAppSettings();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Open Settings'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationDisabledState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.gps_off, size: 64, color: AppTheme.iconSecondary),
            const SizedBox(height: 16),
            Text(
              'Location Services Disabled',
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enable GPS to get accurate prayer times.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: () async {
                    await _provider.openLocationSettings();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.currentActiveGlow,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Enable GPS'),
                ),
                const SizedBox(width: 12),
                OutlinedButton(
                  onPressed: () async {
                    await _provider.refreshLocation();
                    if (mounted) setState(() {});
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.3)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text('Retry'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: AppTheme.iconSecondary),
            const SizedBox(height: 16),
            Text(
              'Unable to load prayer times',
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _provider.errorMessage ?? 'Please check your internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () async {
                await _provider.refreshLocation();
                if (mounted) setState(() {});
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.currentActiveGlow,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuccessState(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;

    return ListView(
      children: [
        // Location header
        _buildLocationHeader(context, isArabic, rootContext: context),
        const SizedBox(height: 16),

        // Prayer cards
        ...List.generate(5, (index) {
          final isNext = index == _provider.nextPrayerIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPrayerCard(
              context: context,
              index: index,
              isNext: isNext,
            ),
          );
        }),
      ],
    );
  }

  Widget _buildLocationHeader(
    BuildContext context,
    bool isArabic, {
    required BuildContext rootContext,
  }) {
    final locationName = _provider.getLocationName(isArabic);

    // Uses the Directionality from parent context - properly flips in RTL
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 20,
        vertical: 16,
      ),
      decoration: AppTheme.glassDecoration(opacity: 0.06, borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            alignment: AlignmentDirectional.centerStart,
            children: [
              // 1. Content Layer (Icon + Text)
              // Padding on trailing side to prevent text from going under buttons
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 84),
                child: Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: AppTheme.currentActiveGlow,
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            locationName,
                            style: TextStyle(
                              color: AppTheme.currentTextPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // 2. Interaction Layer (Buttons) - Positioned at End (trailing side)
              // Using PositionedDirectional for RTL support
              PositionedDirectional(
                end: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Change Location Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap: () => _openLocationPicker(rootContext, isArabic),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.edit_location_alt,
                            color: AppTheme.currentActiveGlow,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    // Update Location Button
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(50),
                        onTap:
                            () => _handleUpdateLocation(rootContext, isArabic),
                        child: Container(
                          width: 40,
                          height: 40,
                          alignment: Alignment.center,
                          child: Icon(
                            Icons.my_location,
                            color: AppTheme.iconSecondary,
                            size: 22,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          // Offline mode banner
          if (_provider.isOfflineMode)
            Container(
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.cloud_off, color: Colors.orange, size: 14),
                  const SizedBox(width: 6),
                  Text(
                    isArabic ? 'وضع عدم الاتصال' : 'Offline - using saved data',
                    style: TextStyle(color: Colors.orange, fontSize: 12),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _handleUpdateLocation(
    BuildContext context,
    bool isArabic,
  ) async {
    // Show loading
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          isArabic ? 'جاري تحديث الموقع...' : 'Updating location...',
        ),
        duration: const Duration(seconds: 1),
        backgroundColor: AppTheme.currentActiveGlow,
      ),
    );

    setState(() {}); // Shows loading in provider

    final success = await _provider.refreshLocation();

    if (mounted) {
      setState(() {});

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success
                ? (isArabic ? 'تم تحديث الموقع' : 'Location updated')
                : (isArabic
                    ? 'فشل التحديث - يتم استخدام البيانات المحفوظة'
                    : 'Update failed - using saved data'),
          ),
          backgroundColor: success ? Colors.green : Colors.orange,
        ),
      );
    }
  }

  Future<void> _openLocationPicker(BuildContext context, bool isArabic) async {
    final result = await LocationPickerSheet.show(context);

    if (result != null && mounted) {
      // User confirmed a location
      final success = await _provider.setManualLocation(
        lat: result.lat,
        lng: result.lng,
        cityAr: result.cityName,
        cityEn: result.cityName,
        countryAr: result.countryName,
        countryEn: result.countryName,
      );

      if (mounted) {
        setState(() {});

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? (isArabic ? 'تم تحديث الموقع' : 'Location updated')
                  : (isArabic ? 'فشل التحديث' : 'Update failed'),
            ),
            backgroundColor: success ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildPrayerCard({
    required BuildContext context,
    required int index,
    bool isNext = false,
  }) {
    final response = _provider.response;
    if (response == null) return const SizedBox();

    final timings = response.timings;
    final timeStr = westernDigits(_getTimeByIndex(timings, index));
    final name = getPrayerName(context, index);

    // Format countdown using shared formatter (matches notification logic)
    // Normal countdown to next prayer: MINUS sign "- MM:SS" or "- HH:MM:SS"
    CountdownParts? countdownParts;
    if (isNext && _countdown.inSeconds > 0) {
      // Use shared formatter that handles "hide hours when 0" + western digits
      countdownParts = formatCountdownParts(_countdown, sign: '-');
    }

    return GestureDetector(
      onTap: () => _showAdhanSelection(context, index, name),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          color:
              AppTheme.isLightMode
                  ? (isNext
                      ? AppTheme.currentActiveGlow.withOpacity(0.08)
                      : Colors.white)
                  : Colors.white.withOpacity(isNext ? 0.15 : 0.08),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color:
                isNext
                    ? AppTheme.currentActiveGlow.withOpacity(0.3)
                    : AppTheme.isLightMode
                    ? AppTheme.lightDivider
                    : AppTheme.inactiveBorder,
            width: isNext ? 1.5 : 1,
          ),
          boxShadow:
              isNext
                  ? [
                    BoxShadow(
                      color: AppTheme.currentActiveGlow.withOpacity(0.15),
                      blurRadius: 20,
                      spreadRadius: 2,
                    ),
                  ]
                  : AppTheme.isLightMode
                  ? [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          children: [
            // Alert mode toggle button
            PrayerAlertModeButton(
              mode: _alertModes[_prayerKeys[index]] ?? AlertMode.sound,
              onTap: () => _toggleAlertMode(index),
            ),
            const SizedBox(width: 16),
            // Prayer name
            Text(
              name,
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 20,
                fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
              ),
            ),
            const Spacer(),
            // Time or countdown
            if (isNext && countdownParts != null) ...[
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    timeStr,
                    style: TextStyle(
                      color: AppTheme.currentTextSecondary.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Countdown with separate sign and time for visual balance
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      Text(
                        countdownParts.sign,
                        style: TextStyle(
                          color: AppTheme.currentActiveGlow.withOpacity(0.7),
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        countdownParts.time,
                        style: TextStyle(
                          color: AppTheme.currentActiveGlow,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              Text(
                timeStr,
                style: TextStyle(
                  color: AppTheme.currentTextPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showAdhanSelection(BuildContext context, int index, String prayerName) {
    final prayerKey = _prayerKeys[index];
    AdhanSelectionSheet.show(
      context,
      prayerKey: prayerKey,
      prayerName: prayerName,
      onChanged: () => setState(() {}),
    );
  }

  String _getTimeByIndex(AlAdhanTimings timings, int index) {
    switch (index) {
      case 0:
        return timings.fajr;
      case 1:
        return timings.dhuhr;
      case 2:
        return timings.asr;
      case 3:
        return timings.maghrib;
      case 4:
        return timings.isha;
      default:
        return timings.fajr;
    }
  }
}
