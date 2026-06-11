import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/models/place_result.dart';
import '../../data/services/place_search_service.dart';
import 'app_sheet.dart';

/// Modal bottom sheet for searching and selecting a location
/// Returns the selected PlaceResult or null if cancelled
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  /// Show the location picker and return selected place (or null)
  static Future<PlaceResult?> show(BuildContext context) {
    return AppSheet.show<PlaceResult>(
      context,
      builder: (_) => const LocationPickerSheet(),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final PlaceSearchService _searchService = PlaceSearchService();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  List<PlaceResult> _results = [];
  PlaceResult? _selectedPlace;
  bool _isLoading = false;
  bool _hasError = false;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query, bool isArabic) {
    _debounceTimer?.cancel();

    if (query.trim().isEmpty) {
      setState(() {
        _results = [];
        _hasError = false;
      });
      return;
    }

    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _performSearch(query, isArabic);
    });
  }

  Future<void> _performSearch(String query, bool isArabic) async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      final results = await _searchService.search(query, isArabic: isArabic);
      if (mounted) {
        setState(() {
          _results = results;
          _isLoading = false;
          _hasError = results.isEmpty && query.isNotEmpty;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _hasError = true;
          _results = [];
        });
      }
    }
  }

  void _selectPlace(PlaceResult place) {
    setState(() {
      _selectedPlace = place;
    });
  }

  void _confirm() {
    Navigator.of(context).pop(_selectedPlace);
  }

  void _cancel() {
    Navigator.of(context).pop(null);
  }

  @override
  Widget build(BuildContext context) {
    final localeController = AppLocaleProvider.of(context);
    final isArabic = localeController.isArabic;

    return Directionality(
      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
      child: Material(
        type: MaterialType.transparency,
        child: AppSheet(
          maxHeightFactor: 0.78,
          child: Column(
            children: [
              SheetHeader(
                icon: Icons.location_on,
                title: t(context, 'selectLocation'),
                trailing: IconButton(
                  icon: Icon(
                    Icons.close,
                    color: AppTheme.currentTextSecondary,
                  ),
                  onPressed: _cancel,
                ),
              ),

              _buildSearchField(context, isArabic),

              // Results list
              Expanded(child: _buildResultsList(context, isArabic)),

              // Footer buttons
              _buildFooter(context, isArabic),
            ],
          ),
        ),
      ),
    );
  }

  /// Glass search field with an accent glow when focused.
  Widget _buildSearchField(BuildContext context, bool isArabic) {
    final glow = AppTheme.currentActiveGlow;
    final focused = _searchFocus.hasFocus;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: focused
                ? glow.withValues(alpha: 0.7)
                : (AppTheme.isLightMode
                    ? AppTheme.lightDivider
                    : Colors.white.withValues(alpha: 0.12)),
            width: focused ? 1.5 : 1,
          ),
          boxShadow: focused ? AppTheme.glowShadow(intensity: 0.5) : null,
        ),
        child: TextField(
          controller: _searchController,
          focusNode: _searchFocus,
          textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
          onChanged: (query) => _onSearchChanged(query, isArabic),
          style: TextStyle(color: AppTheme.currentTextPrimary),
          decoration: InputDecoration(
            hintText: t(context, 'searchPlaceholder'),
            hintStyle: TextStyle(
              color: AppTheme.currentTextSecondary.withValues(alpha: 0.5),
            ),
            prefixIcon: Icon(
              Icons.search,
              color: focused
                  ? glow
                  : AppTheme.currentTextSecondary.withValues(alpha: 0.5),
            ),
            suffixIcon: _isLoading
                ? Padding(
                    padding: const EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(glow),
                      ),
                    ),
                  )
                : null,
            filled: true,
            fillColor: AppTheme.isLightMode
                ? AppTheme.inactiveBackground
                : Colors.white.withValues(alpha: 0.07),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, bool isArabic) {
    if (_hasError && _results.isEmpty) {
      return _buildEmptyState(
        icon: Icons.wifi_off_rounded,
        message: _searchController.text.isEmpty
            ? ''
            : t(context, 'searchRequiresInternet'),
      );
    }

    if (_results.isEmpty && _searchController.text.isNotEmpty && !_isLoading) {
      return _buildEmptyState(
        icon: Icons.search_off_rounded,
        message: t(context, 'noResults'),
      );
    }

    if (_results.isEmpty) {
      // Idle state before any search: a soft hint instead of blank space
      return _buildEmptyState(
        icon: Icons.travel_explore,
        message: t(context, 'searchPlaceholder'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final place = _results[index];
        final isSelected = _selectedPlace == place;

        return StaggerIn(
          index: index.clamp(0, 12),
          child: SheetTile(
            icon: isSelected ? Icons.location_on : Icons.location_on_outlined,
            title: place.cityName.isNotEmpty
                ? place.cityName
                : place.displayLabel.split(',').first,
            subtitle: place.countryName.isNotEmpty ? place.countryName : null,
            selected: isSelected,
            onTap: () => _selectPlace(place),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState({required IconData icon, required String message}) {
    if (message.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.currentActiveGlow.withValues(alpha: 0.08),
              border: Border.all(
                color: AppTheme.currentActiveGlow.withValues(alpha: 0.25),
              ),
            ),
            child: Icon(
              icon,
              color: AppTheme.currentActiveGlow.withValues(alpha: 0.7),
              size: 32,
            ),
          ),
          const SizedBox(height: 14),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppTheme.currentTextSecondary.withValues(alpha: 0.6),
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(BuildContext context, bool isArabic) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(
            color: AppTheme.currentActiveGlow.withValues(alpha: 0.15),
          ),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: SheetSecondaryButton(
              label: t(context, 'cancel'),
              onPressed: _cancel,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GradientButton(
              label: t(context, 'confirm'),
              icon: Icons.check_rounded,
              onPressed: _selectedPlace != null ? _confirm : null,
            ),
          ),
        ],
      ),
    );
  }
}
