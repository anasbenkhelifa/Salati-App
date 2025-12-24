import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/models/place_result.dart';
import '../../data/services/place_search_service.dart';

/// Modal bottom sheet for searching and selecting a location
/// Returns the selected PlaceResult or null if cancelled
class LocationPickerSheet extends StatefulWidget {
  const LocationPickerSheet({super.key});

  /// Show the location picker and return selected place (or null)
  static Future<PlaceResult?> show(BuildContext context) {
    return showModalBottomSheet<PlaceResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder:
          (sheetContext) => Localizations(
            locale: Localizations.localeOf(context),
            delegates: const [
              DefaultMaterialLocalizations.delegate,
              DefaultWidgetsLocalizations.delegate,
            ],
            child: const LocationPickerSheet(),
          ),
    );
  }

  @override
  State<LocationPickerSheet> createState() => _LocationPickerSheetState();
}

class _LocationPickerSheetState extends State<LocationPickerSheet> {
  final PlaceSearchService _searchService = PlaceSearchService();
  final TextEditingController _searchController = TextEditingController();

  List<PlaceResult> _results = [];
  PlaceResult? _selectedPlace;
  bool _isLoading = false;
  bool _hasError = false;
  Timer? _debounceTimer;

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
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
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            // App's blue gradient background
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF1B263B), // Lighter navy at top
                Color(0xFF0D1B2A), // Darker navy at bottom
              ],
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Column(
                children: [
                  // Header
                  _buildHeader(context, isArabic),

                  // Search field
                  _buildSearchField(context, isArabic),

                  // Results list
                  Expanded(child: _buildResultsList(context, isArabic)),

                  // Footer buttons
                  _buildFooter(context, isArabic),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isArabic) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              t(context, 'selectLocation'),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: AppTheme.textSecondary),
            onPressed: _cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildSearchField(BuildContext context, bool isArabic) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: TextField(
        controller: _searchController,
        textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,
        onChanged: (query) => _onSearchChanged(query, isArabic),
        style: const TextStyle(color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: t(context, 'searchPlaceholder'),
          hintStyle: TextStyle(color: AppTheme.textSecondary.withOpacity(0.5)),
          prefixIcon: Icon(
            Icons.search,
            color: AppTheme.textSecondary.withOpacity(0.5),
          ),
          suffixIcon:
              _isLoading
                  ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppTheme.activeGlow,
                        ),
                      ),
                    ),
                  )
                  : null,
          filled: true,
          fillColor: Colors.white.withOpacity(0.08),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
      ),
    );
  }

  Widget _buildResultsList(BuildContext context, bool isArabic) {
    if (_hasError && _results.isEmpty) {
      return Center(
        child: Text(
          _searchController.text.isEmpty
              ? ''
              : t(context, 'searchRequiresInternet'),
          style: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    if (_results.isEmpty && _searchController.text.isNotEmpty && !_isLoading) {
      return Center(
        child: Text(
          t(context, 'noResults'),
          style: TextStyle(
            color: AppTheme.textSecondary.withOpacity(0.5),
            fontSize: 14,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      itemCount: _results.length,
      itemBuilder: (context, index) {
        final place = _results[index];
        final isSelected = _selectedPlace == place;

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color:
                isSelected
                    ? AppTheme.activeGlow.withOpacity(0.15)
                    : Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border:
                isSelected
                    ? Border.all(
                      color: AppTheme.activeGlow.withOpacity(0.5),
                      width: 1,
                    )
                    : null,
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 4,
            ),
            leading: Icon(
              Icons.location_on_outlined,
              color: isSelected ? AppTheme.activeGlow : AppTheme.textSecondary,
            ),
            title: Text(
              place.cityName.isNotEmpty
                  ? place.cityName
                  : place.displayLabel.split(',').first,
              style: TextStyle(
                color: isSelected ? AppTheme.activeGlow : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            subtitle:
                place.countryName.isNotEmpty
                    ? Text(
                      place.countryName,
                      style: TextStyle(
                        color: AppTheme.textSecondary.withOpacity(0.6),
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    )
                    : null,
            trailing:
                isSelected
                    ? const Icon(Icons.check_circle, color: AppTheme.activeGlow)
                    : null,
            onTap: () => _selectPlace(place),
          ),
        );
      },
    );
  }

  Widget _buildFooter(BuildContext context, bool isArabic) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _cancel,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                side: BorderSide(color: Colors.white.withOpacity(0.2)),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(t(context, 'cancel')),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: ElevatedButton(
              onPressed: _selectedPlace != null ? _confirm : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.activeGlow,
                foregroundColor: Colors.white,
                disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                disabledForegroundColor: Colors.white.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(t(context, 'confirm')),
            ),
          ),
        ],
      ),
    );
  }
}
