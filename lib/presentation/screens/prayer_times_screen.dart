import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/tour/tour_key_registry.dart';
import '../../core/localization/western_digits.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../domain/providers/prayer_times_api_provider.dart';
import '../../domain/providers/hijri_date_provider.dart';
import '../../data/services/hijri_date_service.dart'; // for HijriDate class
import '../../data/services/prayer_times_api_service.dart';
import '../../data/services/alert_mode_service.dart';
import '../../data/services/islamic_event_service.dart';
import '../../data/services/bilingual_location_service.dart';
import '../widgets/prayer_alert_mode_button.dart';
import '../widgets/pressable_scale.dart';
import '../widgets/location_picker_sheet.dart';
import '../widgets/adhan_selection_sheet.dart';
import '../widgets/fasting_tracker_sheet.dart';
import '../widgets/prayer_log_sheet.dart';
import '../../data/services/prayer_log_service.dart';
import '../../data/services/notification_service.dart';
import '../widgets/glass_container.dart';
import '../widgets/app_sheet.dart' show StaggerIn;
import '../../core/theme/app_motion.dart';
import '../../data/services/adhan_selection_service.dart';
import '../../services/update_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prayer times screen with AlAdhan API + GPS integration
class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> {
  late final PrayerTimesApiProvider _provider;
  final HijriDateProvider _hijriProvider = HijriDateProvider();
  final AlertModeService _alertModeService = AlertModeService();
  Timer? _countdownTimer;
  Duration _countdown = Duration.zero;
  SharedPreferences? _prefs;
  bool _showSunrise = true;

  // Prayer journal: today's marks + the day they belong to
  Map<String, bool> _prayerLog = {};
  String _logDateKey = '';
  bool _journalEnabled = true;

  // Per-prayer alert modes
  Map<String, AlertMode> _alertModes = {};
  static const _prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  bool _isLocationRefreshing = false;

  @override
  void initState() {
    super.initState();
    _provider = context.read<PrayerTimesApiProvider>();
    _initializePrayerTimes();
    SharedPreferences.getInstance().then((p) {
      if (mounted) {
        setState(() {
          _prefs = p;
          _showSunrise = p.getBool('show_sunrise') ?? true;
        });
      }
    });
  }

  Future<void> _initializePrayerTimes() async {
    // _provider is initialized globally in main.dart
    await _hijriProvider.initialize();
    await _loadAlertModes();
    await _loadPrayerLog();
    _startCountdownTimer();
    if (mounted) setState(() {});
  }

  Future<void> _loadPrayerLog() async {
    // Settle "missed" states first (next adhan already passed)
    await PrayerLogService.instance.reconcile();
    final now = DateTime.now();
    _logDateKey = '${now.year}-${now.month}-${now.day}';
    _prayerLog = await PrayerLogService.instance.loadDay(now);
    if (mounted) setState(() {});
  }

  Future<void> _togglePrayed(String prayerKey) async {
    final newValue = !(_prayerLog[prayerKey] ?? false);
    HapticFeedback.lightImpact();
    setState(() => _prayerLog[prayerKey] = newValue);
    await PrayerLogService.instance.setPrayed(
      DateTime.now(),
      prayerKey,
      newValue,
    );
    if (newValue) {
      // Marked prayed → its "did you pray?" nudge is no longer needed
      NotificationService().cancelPrayedReminder(
        _prayerKeys.indexOf(prayerKey),
      );
    }
  }

  /// Whether this prayer's time has already passed today.
  bool _isPrayerPassed(int index) {
    final response = _provider.response;
    if (response == null) return false;
    final parts = _getTimeByIndex(response.timings, index).split(':');
    if (parts.length < 2) return false;
    final now = DateTime.now();
    final time = DateTime(
      now.year,
      now.month,
      now.day,
      int.tryParse(parts[0]) ?? 0,
      int.tryParse(parts[1].split(' ')[0]) ?? 0,
    );
    return now.isAfter(time);
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
          // Cheap sync reads — pick up Controls toggles within a second
          _showSunrise = _prefs?.getBool('show_sunrise') ?? _showSunrise;
          // Local toggle AND remote kill-switch (feature_journal, default on)
          _journalEnabled =
              (_prefs?.getBool('prayer_journal_enabled') ?? _journalEnabled) &&
                  UpdateService.isFeatureEnabled('journal');
        });
        // New day → fresh journal page
        final now = DateTime.now();
        if (_logDateKey != '${now.year}-${now.month}-${now.day}') {
          _loadPrayerLog();
        }
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  // Title + prayer journal entry
                  Stack(
                    alignment: Alignment.center,
                    children: [
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
                      if (_journalEnabled)
                        PositionedDirectional(
                          end: 0,
                          child: PressableScale(
                            key: TourKeyRegistry.instance.journalIconKey,
                            onTap: () => PrayerLogSheet.show(context),
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppTheme.currentActiveGlow
                                  .withValues(alpha: 0.10),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppTheme.currentActiveGlow
                                    .withValues(alpha: 0.35),
                              ),
                            ),
                            child: Icon(
                              Icons.spa_outlined,
                              size: 20,
                              color: AppTheme.currentActiveGlow,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Content based on state
                  Expanded(child: _buildContent(context)),
                ],
              ),
            ),
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
                color: AppTheme.currentTextSecondary.withValues(alpha: 0.7),
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
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
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
                color: AppTheme.currentTextSecondary.withValues(alpha: 0.7),
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
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
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
                color: AppTheme.currentTextSecondary.withValues(alpha: 0.7),
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
    final hijriDate = _hijriProvider.hijriDate;

    return ListView(
      children: [
        // Islamic event banner (Ramadan, Eid, etc.)
        if (hijriDate != null)
          _buildIslamicEventBanner(context, isArabic, hijriDate),

        // Location header
        _buildLocationHeader(context, isArabic, rootContext: context),
        const SizedBox(height: 24),

        // Prayer cards: cascade in with a stagger on first build.
        // A slim sunrise (Shuruq) row sits between Fajr and Dhuhr.
        ...List.generate(5, (index) {
          final isNext = index == _provider.nextPrayerIndex;
          final card = Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _buildPrayerCard(
              context: context,
              index: index,
              isNext: isNext,
              hijriDate: hijriDate,
            ),
          );
          return StaggerIn(
            index: index + 1,
            child:
                (index == 1 && _showSunrise)
                    ? Column(children: [_buildSunriseRow(context), card])
                    : card,
          );
        }),
      ],
    );
  }

  /// Build Islamic event banner (Ramadan mode, Eid, special days)
  Widget _buildIslamicEventBanner(
    BuildContext context,
    bool isArabic,
    HijriDate hijriDate,
  ) {
    final isRamadan = IslamicEventService.isRamadan(hijriDate);
    final isEid = IslamicEventService.isEid(hijriDate);
    final currentEvent = IslamicEventService.getCurrentEvent(hijriDate);

    // No banner if no special day
    if (!isRamadan && !isEid && currentEvent == null) {
      return const SizedBox.shrink();
    }

    // Determine banner content
    String title;
    String subtitle;
    String emoji;
    Color bannerColor;

    if (isEid) {
      title = IslamicEventService.getEidGreeting(hijriDate, isArabic: isArabic);
      subtitle = t(context, 'eidGreeting');
      emoji = IslamicEventService.isEidAlFitr(hijriDate) ? '🎉' : '🐑';
      bannerColor = Colors.amber;
    } else if (isRamadan) {
      title = t(context, 'ramadanGreeting');
      subtitle = IslamicEventService.getRamadanStatus(
        hijriDate,
        isArabic: isArabic,
      );
      emoji = '🌙';
      bannerColor = Colors.purple;
    } else if (currentEvent != null) {
      title =
          '${currentEvent.emoji} ${isArabic ? currentEvent.nameAr : currentEvent.nameEn}';
      subtitle = _hijriProvider.getFormattedDate(isArabic);
      emoji = currentEvent.emoji;
      bannerColor = Colors.teal;
    } else {
      return const SizedBox.shrink();
    }

    // Avoid "Ramadan Kareem / Ramadan Kareem": when the status line just
    // repeats the greeting, show the Hijri date instead
    if (subtitle == title) {
      subtitle = _hijriProvider.getFormattedDate(isArabic);
    }

    final ramadanCountdown = isRamadan ? _ramadanCountdownText(context) : null;

    return PressableScale(
      pressedScale: 0.985,
      // Ramadan: banner opens the fasting tracker
      onTap: isRamadan ? () => FastingTrackerSheet.show(context) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              bannerColor.withValues(alpha: 0.3),
              bannerColor.withValues(alpha: 0.1),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: bannerColor.withValues(alpha: 0.4),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Text(emoji, style: const TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.replaceAll(emoji, '').trim(),
                    style: TextStyle(
                      color: AppTheme.currentTextPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.currentTextSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  // Live Suhoor/Iftar countdown (ticks with the screen timer)
                  if (ramadanCountdown != null) ...[
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Icon(
                          Icons.timer_outlined,
                          size: 15,
                          color: AppTheme.currentActiveGlow,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          ramadanCountdown,
                          style: AppTheme.displayDigits(
                            fontSize: 14,
                            color: AppTheme.currentActiveGlow,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLocationHeader(
    BuildContext context,
    bool isArabic, {
    required BuildContext rootContext,
  }) {
    final locationName = _provider.getLocationName(isArabic);

    // Uses the Directionality from parent context - properly flips in RTL
    // Entire location box is clickable to open location picker
    return PressableScale(
      pressedScale: 0.985,
      onTap: () => _openLocationPicker(rootContext, isArabic),
      child: GlassContainer(
        key: TourKeyRegistry.instance.locationHeaderKey,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 20,
          vertical: 16,
        ),
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
                          onTap:
                              () => _openLocationPicker(rootContext, isArabic),
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
                              () =>
                                  _handleUpdateLocation(rootContext, isArabic),
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.cloud_off, color: Colors.orange, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      t(context, 'offlineMode'),
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleUpdateLocation(
    BuildContext context,
    bool isArabic,
  ) async {
    if (_isLocationRefreshing) return;
    _isLocationRefreshing = true;

    final statusNotifier = ValueNotifier<_GpsToastStatus>(
      _GpsToastStatus.loading,
    );
    final cityNotifier = ValueNotifier<String>('');

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder:
          (_) => _GpsToast(
            status: statusNotifier,
            city: cityNotifier,
            isArabic: isArabic,
          ),
    );

    Overlay.of(context).insert(entry);

    final success = await _provider.refreshLocation();

    if (mounted) {
      cityNotifier.value = _provider.getCityOnly(isArabic);
      statusNotifier.value =
          success ? _GpsToastStatus.success : _GpsToastStatus.error;

      await Future.delayed(const Duration(milliseconds: 2400));
      entry.remove();
      statusNotifier.dispose();
      cityNotifier.dispose();
      _isLocationRefreshing = false;
      setState(() {});
    }
  }

  Future<void> _openLocationPicker(BuildContext context, bool isArabic) async {
    final result = await LocationPickerSheet.show(context);

    if (result != null && mounted) {
      // Same glass toast as the GPS flow (replaces the old SnackBar strip)
      final statusNotifier = ValueNotifier<_GpsToastStatus>(
        _GpsToastStatus.loading,
      );
      final cityNotifier = ValueNotifier<String>('');

      late OverlayEntry entry;
      entry = OverlayEntry(
        builder:
            (_) => _GpsToast(
              status: statusNotifier,
              city: cityNotifier,
              isArabic: isArabic,
            ),
      );
      Overlay.of(context).insert(entry);

      // The Nominatim search result is in the current UI language only.
      // Resolve the picked coordinates in BOTH languages so the header
      // keeps following the app language afterwards.
      final bilingual = await BilingualLocationService().getLocationNames(
        result.lat,
        result.lng,
      );

      final success = await _provider.setManualLocation(
        lat: result.lat,
        lng: result.lng,
        cityAr:
            (bilingual != null && bilingual.cityAr.isNotEmpty)
                ? bilingual.cityAr
                : result.cityName,
        cityEn:
            (bilingual != null && bilingual.cityEn.isNotEmpty)
                ? bilingual.cityEn
                : result.cityName,
        countryAr:
            (bilingual != null && bilingual.countryAr.isNotEmpty)
                ? bilingual.countryAr
                : result.countryName,
        countryEn:
            (bilingual != null && bilingual.countryEn.isNotEmpty)
                ? bilingual.countryEn
                : result.countryName,
        isoCountryCode:
            result.isoCountryCode.isNotEmpty
                ? result.isoCountryCode
                : (bilingual?.isoCountryCode ?? ''),
      );

      if (mounted) {
        cityNotifier.value = _provider.getCityOnly(isArabic);
        statusNotifier.value =
            success ? _GpsToastStatus.success : _GpsToastStatus.error;
        setState(() {});
      }

      await Future.delayed(const Duration(milliseconds: 2400));
      entry.remove();
      statusNotifier.dispose();
      cityNotifier.dispose();
    }
  }

  /// Slim, non-interactive sunrise (Shuruq) row between Fajr and Dhuhr —
  /// marks the end of Fajr time. Deliberately quieter than prayer cards.
  Widget _buildSunriseRow(BuildContext context) {
    final response = _provider.response;
    if (response == null) return const SizedBox.shrink();
    final timeStr = westernDigits(response.timings.sunrise);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: AppTheme.currentTextSecondary.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          children: [
            const Icon(Icons.wb_twilight, color: Color(0xFFFFB74D), size: 20),
            const SizedBox(width: 14),
            Text(
              t(context, 'sunrise'),
              style: TextStyle(
                color: AppTheme.currentTextSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            Text(
              timeStr,
              style: TextStyle(
                color: AppTheme.currentTextSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Soft journal check: quiet outline → tap → gradient bloom + haptic.
  /// Unmarked stays neutral — never red, never nagging.
  Widget _buildPrayedCheck(String prayerKey) {
    final prayed = _prayerLog[prayerKey] ?? false;
    final onGradient = AppTheme.currentAccentGradient.colors.first
                .computeLuminance() >
            0.5
        ? Colors.black87
        : Colors.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _togglePrayed(prayerKey),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.pop,
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          gradient: prayed ? AppTheme.currentAccentGradient : null,
          shape: BoxShape.circle,
          border: prayed
              ? null
              : Border.all(
                  color:
                      AppTheme.currentTextSecondary.withValues(alpha: 0.35),
                  width: 1.5,
                ),
          boxShadow: prayed ? AppTheme.glowShadow(intensity: 0.4) : null,
        ),
        child: AnimatedScale(
          duration: AppMotion.fast,
          curve: AppMotion.pop,
          scale: prayed ? 1 : 0,
          child: Icon(Icons.check, size: 16, color: onGradient),
        ),
      ),
    );
  }

  Widget _buildPrayerCard({
    required BuildContext context,
    required int index,
    bool isNext = false,
    HijriDate? hijriDate,
  }) {
    final response = _provider.response;
    if (response == null) return const SizedBox();

    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;
    final timings = response.timings;
    final timeStr = westernDigits(_getTimeByIndex(timings, index));
    final name = getPrayerName(context, index);

    // Get Ramadan label (Suhoor/Iftar) if applicable
    String? ramadanLabel;
    if (hijriDate != null) {
      final prayerKey = _prayerKeys[index]; // fajr, dhuhr, asr, maghrib, isha
      ramadanLabel = IslamicEventService.getRamadanPrayerLabel(
        prayerKey,
        hijriDate,
        isArabic: isArabic,
      );
    }

    // Format countdown using shared formatter (matches notification logic)
    // Normal countdown to next prayer: MINUS sign "- MM:SS" or "- HH:MM:SS"
    CountdownParts? countdownParts;
    if (isNext && _countdown.inSeconds > 0) {
      // Use shared formatter that handles "hide hours when 0" + western digits
      countdownParts = formatCountdownParts(_countdown, sign: '-');
    }

    return PressableScale(
      key: index == 0 ? TourKeyRegistry.instance.prayerCardKey : null,
      onTap: () => _showAdhanSelection(context, index, name),
      child: Builder(
        builder: (context) {
          final glassStyle = GlassStyle.of(context);
          final bool isBlurLayer = glassStyle?.isBlurLayer ?? true;
          final bool isContentLayer = glassStyle?.isContentLayer ?? true;

          Widget blurWidget = Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 3, sigmaY: 3),
                child: const SizedBox(),
              ),
            ),
          );

          // The next prayer is a "live" card: accent-gradient fill, glowing
          // border and an interval progress bar underneath the row.
          Widget contentWidget = Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            decoration: BoxDecoration(
              gradient:
                  isNext
                      ? LinearGradient(
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                        colors:
                            AppTheme.currentAccentGradient.colors
                                .map(
                                  (c) => c.withValues(
                                    alpha: AppTheme.isLightMode ? 0.10 : 0.16,
                                  ),
                                )
                                .toList(),
                      )
                      : null,
              color:
                  isNext
                      ? null
                      : (AppTheme.isLightMode
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.08)),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                    isNext
                        ? AppTheme.currentActiveGlow.withValues(alpha: 0.55)
                        : AppTheme.isLightMode
                        ? AppTheme.lightDivider
                        : AppTheme.inactiveBorder,
                width: isNext ? 1.5 : 1,
              ),
              boxShadow:
                  isNext
                      ? AppTheme.glowShadow(intensity: 0.7)
                      : AppTheme.isLightMode
                      ? [
                        BoxShadow(
                          color: const Color(
                            0xFF8A7A55,
                          ).withValues(alpha: 0.10),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ]
                      : null,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    // Alert mode toggle button
                    PrayerAlertModeButton(
                      key:
                          index == 0
                              ? TourKeyRegistry.instance.prayerAlertModeKey
                              : null,
                      mode: _alertModes[_prayerKeys[index]] ?? AlertMode.sound,
                      onTap: () => _toggleAlertMode(index),
                    ),
                    const SizedBox(width: 16),
                    // Prayer name + Ramadan label
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              color: AppTheme.currentTextPrimary,
                              fontSize: 20,
                              fontWeight:
                                  isNext ? FontWeight.bold : FontWeight.w500,
                            ),
                          ),
                          if (ramadanLabel != null) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.purple.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: Colors.purple.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Text(
                                ramadanLabel,
                                style: TextStyle(
                                  color: Colors.purple.shade300,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                          // Jumu'ah chip on Dhuhr every Friday
                          if (index == 1 &&
                              DateTime.now().weekday == DateTime.friday) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.currentActiveGlow.withValues(
                                  alpha: 0.15,
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: AppTheme.currentActiveGlow.withValues(
                                    alpha: 0.45,
                                  ),
                                ),
                              ),
                              child: Text(
                                t(context, 'jumuah'),
                                style: TextStyle(
                                  color: AppTheme.currentActiveGlow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    // Journal check — appears once the prayer time passes
                    if (_journalEnabled && _isPrayerPassed(index)) ...[
                      _buildPrayedCheck(_prayerKeys[index]),
                      const SizedBox(width: 12),
                    ],
                    // Time or countdown
                    if (isNext && countdownParts != null) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            timeStr,
                            style: TextStyle(
                              color: AppTheme.currentTextSecondary.withValues(
                                alpha: 0.7,
                              ),
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
                                  color: AppTheme.currentActiveGlow.withValues(
                                    alpha: 0.7,
                                  ),
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                countdownParts.time,
                                style: AppTheme.displayDigits(
                                  fontSize: 18,
                                  color: AppTheme.currentActiveGlow,
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
                if (isNext) ...[
                  const SizedBox(height: 14),
                  _buildIntervalProgressBar(),
                ],
              ],
            ),
          );

          if (isBlurLayer && !isContentLayer) {
            return Stack(
              fit: StackFit.loose,
              children: [
                blurWidget,
                Opacity(opacity: 0.0, child: contentWidget),
              ],
            );
          } else if (!isBlurLayer && isContentLayer) {
            return contentWidget;
          }

          return Stack(
            fit: StackFit.loose,
            children: [blurWidget, contentWidget],
          );
        },
      ),
    );
  }

  /// Live Suhoor/Iftar countdown line during Ramadan, null without data.
  /// Before Fajr → Suhoor ends in X; before Maghrib → Iftar in X;
  /// after Maghrib → countdown to tomorrow's Suhoor end.
  String? _ramadanCountdownText(BuildContext context) {
    final response = _provider.response;
    if (response == null) return null;

    final now = DateTime.now();
    DateTime? parse(String s) {
      final parts = s.split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]);
      final m = int.tryParse(parts[1].split(' ')[0]);
      if (h == null || m == null) return null;
      return DateTime(now.year, now.month, now.day, h, m);
    }

    final fajr = parse(response.timings.fajr);
    final maghrib = parse(response.timings.maghrib);
    if (fajr == null || maghrib == null) return null;

    final String label;
    final Duration remaining;
    if (now.isBefore(fajr)) {
      label = t(context, 'suhoorEndsIn');
      remaining = fajr.difference(now);
    } else if (now.isBefore(maghrib)) {
      label = t(context, 'iftarIn');
      remaining = maghrib.difference(now);
    } else {
      label = t(context, 'suhoorEndsIn');
      remaining = fajr.add(const Duration(days: 1)).difference(now);
    }

    final parts = formatCountdownParts(remaining, sign: '');
    return '$label ${parts.time}';
  }

  /// Fraction (0..1) of the interval between the previous prayer and the
  /// next one that has already elapsed, or null without data.
  double? _nextPrayerIntervalProgress() {
    final response = _provider.response;
    if (response == null) return null;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final times = <DateTime>[];
    for (int i = 0; i < 5; i++) {
      final parts = _getTimeByIndex(response.timings, i).split(':');
      if (parts.length < 2) return null;
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1].split(' ')[0]) ?? 0;
      times.add(DateTime(today.year, today.month, today.day, h, m));
    }

    DateTime? prev;
    DateTime? next;
    for (final t in times) {
      if (now.isBefore(t)) {
        next = t;
        break;
      }
      prev = t;
    }
    prev ??= times[4].subtract(const Duration(days: 1));
    next ??= times[0].add(const Duration(days: 1));

    final total = next.difference(prev).inSeconds;
    if (total <= 0) return null;
    return (now.difference(prev).inSeconds / total).clamp(0.0, 1.0);
  }

  /// Thin gradient bar inside the live card filling toward the next prayer.
  Widget _buildIntervalProgressBar() {
    final progress = _nextPrayerIntervalProgress();
    if (progress == null) return const SizedBox.shrink();

    return Container(
      height: 5,
      decoration: BoxDecoration(
        color: AppTheme.currentTextSecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(3),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return Align(
            alignment: AlignmentDirectional.centerStart,
            child: AnimatedContainer(
              duration: AppMotion.fast,
              width: constraints.maxWidth * progress,
              decoration: BoxDecoration(
                gradient: AppTheme.currentAccentGradient,
                borderRadius: BorderRadius.circular(3),
                boxShadow: AppTheme.glowShadow(intensity: 0.5),
              ),
            ),
          );
        },
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

// ─── GPS toast helpers ────────────────────────────────────────────────────────

enum _GpsToastStatus { loading, success, error }

class _GpsToast extends StatefulWidget {
  final ValueNotifier<_GpsToastStatus> status;
  final ValueNotifier<String> city;
  final bool isArabic;

  const _GpsToast({
    required this.status,
    required this.city,
    required this.isArabic,
  });

  @override
  State<_GpsToast> createState() => _GpsToastState();
}

class _GpsToastState extends State<_GpsToast> with TickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final AnimationController _pulseCtrl;
  late final Animation<Offset> _slideAnim;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 380),
    );
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat(reverse: true);

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 2),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideCtrl, curve: Curves.easeOutCubic));

    _pulseAnim = Tween<double>(
      begin: 0.5,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));

    _slideCtrl.forward();
    widget.status.addListener(_rebuild);
    widget.city.addListener(_rebuild);
  }

  void _rebuild() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.status.removeListener(_rebuild);
    widget.city.removeListener(_rebuild);
    _slideCtrl.dispose();
    _pulseCtrl.dispose();
    super.dispose();
  }

  Color get _accentColor {
    switch (widget.status.value) {
      case _GpsToastStatus.loading:
        return AppTheme.currentActiveGlow;
      case _GpsToastStatus.success:
        return const Color(0xFF4CAF50);
      case _GpsToastStatus.error:
        return const Color(0xFFFF9800);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.status.value;
    final city = widget.city.value;
    final isArabic = widget.isArabic;

    return Positioned(
      bottom: MediaQuery.of(context).padding.bottom + 28,
      left: 20,
      right: 20,
      child: SlideTransition(
        position: _slideAnim,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            decoration: BoxDecoration(
              color:
                  AppTheme.isLightMode
                      ? Colors.white.withValues(alpha: 0.96)
                      : const Color(0xFF1A2740).withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _accentColor.withValues(alpha: 0.35),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _accentColor.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: Directionality(
              textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
              child: Row(
                children: [
                  _buildIconSlot(status),
                  const SizedBox(width: 14),
                  Expanded(child: _buildTextSlot(status, city, isArabic)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconSlot(_GpsToastStatus status) {
    if (status == _GpsToastStatus.loading) {
      return AnimatedBuilder(
        animation: _pulseAnim,
        builder:
            (_, __) => Opacity(
              opacity: _pulseAnim.value,
              child: _iconContainer(
                icon: Icons.gps_fixed,
                color: AppTheme.currentActiveGlow,
              ),
            ),
      );
    }
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      switchInCurve: Curves.easeOutBack,
      transitionBuilder:
          (child, anim) => ScaleTransition(scale: anim, child: child),
      child: _iconContainer(
        key: ValueKey(status),
        icon:
            status == _GpsToastStatus.success
                ? Icons.check_circle_outline_rounded
                : Icons.warning_amber_rounded,
        color: _accentColor,
      ),
    );
  }

  Widget _iconContainer({
    Key? key,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      key: key,
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withValues(alpha: 0.12),
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }

  Widget _buildTextSlot(_GpsToastStatus status, String city, bool isArabic) {
    late String title;
    late String subtitle;

    switch (status) {
      case _GpsToastStatus.loading:
        title = isArabic ? 'جاري تحديد موقعك...' : 'Finding your location…';
        subtitle = isArabic ? 'يرجى الانتظار' : 'Please wait';
        break;
      case _GpsToastStatus.success:
        title =
            city.isNotEmpty
                ? city
                : (isArabic ? 'تم تحديد الموقع' : 'Location found');
        subtitle = isArabic ? 'تم تحديث أوقات الصلاة' : 'Prayer times updated';
        break;
      case _GpsToastStatus.error:
        title = isArabic ? 'تعذّر تحديد الموقع' : 'Location unavailable';
        subtitle =
            isArabic ? 'يتم استخدام البيانات المحفوظة' : 'Using saved data';
        break;
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 240),
      child: Column(
        key: ValueKey(status),
        crossAxisAlignment:
            isArabic ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title,
            style: TextStyle(
              color: AppTheme.currentTextPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            subtitle,
            style: TextStyle(
              color: AppTheme.currentTextSecondary.withValues(alpha: 0.65),
              fontSize: 12,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}
