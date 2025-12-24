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
    return SafeArea(
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
                style: const TextStyle(
                  color: AppTheme.textPrimary,
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
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: AppTheme.activeGlow),
          SizedBox(height: 16),
          Text(
            'Getting location...',
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
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
            Icon(
              Icons.location_off,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Location Permission Required',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'We need your location to calculate accurate prayer times for your area.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
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
                    backgroundColor: AppTheme.activeGlow,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Grant Permission'),
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
                  child: const Text('Open Settings'),
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
            Icon(Icons.gps_off, size: 64, color: Colors.white.withOpacity(0.5)),
            const SizedBox(height: 16),
            const Text(
              'Location Services Disabled',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please enable GPS to get accurate prayer times.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
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
                    backgroundColor: AppTheme.activeGlow,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Enable GPS'),
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
                  child: const Text('Retry'),
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
            Icon(
              Icons.cloud_off,
              size: 64,
              color: Colors.white.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to load prayer times',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _provider.errorMessage ?? 'Please check your internet connection',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.textSecondary.withOpacity(0.7),
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
                backgroundColor: AppTheme.activeGlow,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text('Retry'),
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
        _buildLocationHeader(context, isArabic),
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

  Widget _buildLocationHeader(BuildContext context, bool isArabic) {
    final locationName = _provider.getLocationName(isArabic);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: AppTheme.glassDecoration(opacity: 0.06, borderRadius: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.location_on, color: AppTheme.activeGlow, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      locationName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (_provider.lastUpdatedDisplay.isNotEmpty)
                      Text(
                        'Updated: ${_provider.lastUpdatedDisplay}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
              ),
              // Change Location button - IconButton for reliable hit-testing in RTL
              IconButton(
                icon: const Icon(
                  Icons.edit_location_alt,
                  color: AppTheme.activeGlow,
                  size: 22,
                ),
                tooltip: isArabic ? 'تغيير الموقع' : 'Change location',
                onPressed: () {
                  debugPrint('ChangeLocation tapped');
                  _openLocationPicker(context, isArabic);
                },
              ),
              // Update Location button
              IconButton(
                icon: Icon(
                  Icons.my_location,
                  color: Colors.white.withOpacity(0.5),
                ),
                tooltip: isArabic ? 'تحديث الموقع' : 'Update Location',
                onPressed: () => _handleUpdateLocation(context, isArabic),
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
                    style: const TextStyle(color: Colors.orange, fontSize: 12),
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
        backgroundColor: AppTheme.activeGlow,
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
        cityAr: result.cityName, // Will use same for both if only one available
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

  Widget _buildDebugPanel(BuildContext context) {
    final response = _provider.response;
    final lat = _provider.latitude;
    final lon = _provider.longitude;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.bug_report, color: Colors.orange, size: 18),
              const SizedBox(width: 8),
              const Text(
                'DEBUG INFO',
                style: TextStyle(
                  color: Colors.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const Divider(color: Colors.orange, height: 16),
          _debugRow('Source', _provider.isFromCache ? 'CACHE' : 'NETWORK'),
          if (lat != null && lon != null) ...[
            _debugRow('Lat', westernDigits(lat.toStringAsFixed(6))),
            _debugRow('Lon', westernDigits(lon.toStringAsFixed(6))),
          ],
          _debugRow('Location', _provider.locationNameEn),
          _debugRow(
            'Method',
            '${_provider.method.nameEn} (ID: ${_provider.method.id})',
          ),
          _debugRow(
            'Madhab',
            '${_provider.madhab.nameEn} (ID: ${_provider.madhab.id})',
          ),
          _debugRow('Device TZ', _provider.deviceTimezone),
          if (response != null) ...[
            _debugRow('API TZ', response.meta.timezone),
          ],
          _debugRow('API URL', _provider.requestUrl, isUrl: true),
        ],
      ),
    );
  }

  Widget _debugRow(String label, String value, {bool isUrl = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.white.withOpacity(0.6),
                fontSize: 11,
              ),
            ),
          ),
          Expanded(
            child: Text(
              westernDigits(value),
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
                fontSize: isUrl ? 9 : 11,
                fontFamily: 'monospace',
              ),
              maxLines: isUrl ? 2 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
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
    String countdownStr = '';
    if (isNext && _countdown.inSeconds > 0) {
      // Use shared formatter that handles "hide hours when 0" + western digits
      countdownStr = formatCountdownWithSign(_countdown, sign: '-');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(isNext ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color:
              isNext
                  ? AppTheme.activeGlow.withOpacity(0.3)
                  : Colors.white.withOpacity(0.1),
          width: isNext ? 1.5 : 1,
        ),
        boxShadow:
            isNext
                ? [
                  BoxShadow(
                    color: AppTheme.activeGlow.withOpacity(0.15),
                    blurRadius: 20,
                    spreadRadius: 2,
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
              color: AppTheme.textPrimary,
              fontSize: 20,
              fontWeight: isNext ? FontWeight.bold : FontWeight.w500,
            ),
          ),
          const Spacer(),
          // Time or countdown
          if (isNext && countdownStr.isNotEmpty) ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  timeStr,
                  style: TextStyle(
                    color: AppTheme.textSecondary.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  countdownStr,
                  style: TextStyle(
                    color: AppTheme.activeGlow,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ] else ...[
            Text(
              timeStr,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
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
