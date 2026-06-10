import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/services/adhan_selection_service.dart';
import '../../data/models/adhan_option.dart';

/// Bottom sheet for selecting adhan for a prayer
class AdhanSelectionSheet extends StatefulWidget {
  final String prayerKey;
  final String prayerName;
  final VoidCallback? onChanged;

  const AdhanSelectionSheet({
    super.key,
    required this.prayerKey,
    required this.prayerName,
    this.onChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required String prayerKey,
    required String prayerName,
    VoidCallback? onChanged,
  }) {
    HapticFeedback.lightImpact();
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder:
          (context) => AdhanSelectionSheet(
            prayerKey: prayerKey,
            prayerName: prayerName,
            onChanged: onChanged,
          ),
    );
  }

  @override
  State<AdhanSelectionSheet> createState() => _AdhanSelectionSheetState();
}

class _AdhanSelectionSheetState extends State<AdhanSelectionSheet> {
  final _service = AdhanSelectionService.instance;
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _applyToAll = false;
  bool _isLoading = false;
  String? _playingAdhanId;

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isArabic = AppLocaleProvider.of(context).isArabic;
    final selectedAdhan = _service.getSelectedAdhan(widget.prayerKey);
    final allAdhans = _service.allAdhans;
    final customAdhans = _service.customAdhans;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: AppTheme.isLightMode ? Colors.white : AppTheme.nightPrimaryNavy,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        border: Border.all(
          color:
              AppTheme.isLightMode
                  ? AppTheme.lightDivider
                  : Colors.white.withValues(alpha: 0.1),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.currentTextSecondary.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Icon(
                  Icons.music_note,
                  color: AppTheme.currentActiveGlow,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t(context, 'selectAdhan'),
                        style: TextStyle(
                          color: AppTheme.currentTextPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.prayerName,
                        style: TextStyle(
                          color: AppTheme.currentTextSecondary,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          Divider(color: AppTheme.currentDivider),

          // Adhan list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                // Built-in adhans section
                _buildSectionHeader(t(context, 'defaultAdhan')),
                ...allAdhans.where((a) => !a.isCustom).map((adhan) => 
                  _buildAdhanTile(
                    adhan,
                    selectedAdhan.id == adhan.id,
                    isArabic,
                  )
                ).toList(),

                // Custom adhans section
                if (customAdhans.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  _buildSectionHeader(t(context, 'customAdhans')),
                  ...customAdhans.map(
                    (adhan) => _buildAdhanTile(
                      adhan,
                      selectedAdhan.id == adhan.id,
                      isArabic,
                    ),
                  ),
                ],

                // Add custom adhan button
                const SizedBox(height: 16),
                _buildAddCustomButton(context),

                // Apply to all checkbox
                const SizedBox(height: 8),
                _buildApplyToAllCheckbox(context),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Text(
        title,
        style: TextStyle(
          color: AppTheme.currentTextSecondary,
          fontSize: 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildAdhanTile(AdhanOption adhan, bool isSelected, bool isArabic) {
    return GestureDetector(
      onTap: () => _selectAdhan(adhan),
      onLongPress: adhan.isCustom ? () => _showDeleteDialog(adhan) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? AppTheme.currentActiveGlow.withValues(alpha: 0.15)
                  : AppTheme.inactiveBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected
                    ? AppTheme.currentActiveGlow.withValues(alpha: 0.4)
                    : AppTheme.inactiveBorder,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color:
                    isSelected
                        ? AppTheme.currentActiveGlow.withValues(alpha: 0.2)
                        : AppTheme.isLightMode
                        ? Colors.grey.shade100
                        : Colors.white.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                adhan.isCustom ? Icons.library_music : Icons.mosque,
                color:
                    isSelected
                        ? AppTheme.currentActiveGlow
                        : AppTheme.currentTextSecondary,
                size: 20,
              ),
            ),
            const SizedBox(width: 14),
            // Name
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isArabic ? adhan.nameAr : adhan.name,
                    style: TextStyle(
                      color:
                          isSelected
                              ? AppTheme.currentActiveGlow
                              : AppTheme.currentTextPrimary,
                      fontSize: 16,
                      fontWeight:
                          isSelected ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                  if (adhan.duration != null)
                    Text(
                      _formatDuration(adhan.duration!),
                      style: TextStyle(
                        color: AppTheme.currentTextSecondary.withValues(alpha: 0.7),
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            // Play button
            GestureDetector(
              onTap: () => _togglePlayPreview(adhan),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color:
                      _playingAdhanId == adhan.id
                          ? AppTheme.currentActiveGlow
                          : AppTheme.isLightMode
                          ? AppTheme.currentActiveGlow.withValues(alpha: 0.1)
                          : Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppTheme.currentActiveGlow.withValues(
                      alpha: _playingAdhanId == adhan.id ? 1.0 : 0.3,
                    ),
                    width: 1.5,
                  ),
                ),
                child: Icon(
                  _playingAdhanId == adhan.id ? Icons.stop : Icons.play_arrow,
                  color:
                      _playingAdhanId == adhan.id
                          ? Colors.white
                          : AppTheme.currentActiveGlow,
                  size: 20,
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Checkmark
            if (isSelected)
              Icon(
                Icons.check_circle,
                color: AppTheme.currentActiveGlow,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildAddCustomButton(BuildContext context) {
    return GestureDetector(
      onTap: _isLoading ? null : _addCustomAdhan,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppTheme.inactiveBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.inactiveBorder,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppTheme.currentActiveGlow,
                ),
              )
            else
              Icon(
                Icons.add_circle_outline,
                color: AppTheme.currentActiveGlow,
                size: 22,
              ),
            const SizedBox(width: 10),
            Text(
              t(context, 'addCustomAdhan'),
              style: TextStyle(
                color: AppTheme.currentActiveGlow,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyToAllCheckbox(BuildContext context) {
    final selectedAdhan = _service.getSelectedAdhan(widget.prayerKey);

    return GestureDetector(
      onTap: () async {
        HapticFeedback.selectionClick();
        final newValue = !_applyToAll;
        setState(() => _applyToAll = newValue);

        // If turning on apply-to-all, immediately apply current selection to all prayers
        if (newValue) {
          await _service.setSelectedAdhanForAll(selectedAdhan.id);
          widget.onChanged?.call();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(t(context, 'applyToAllPrayers')),
                backgroundColor: AppTheme.currentActiveGlow,
                duration: const Duration(seconds: 1),
              ),
            );
          }
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color:
                    _applyToAll
                        ? AppTheme.currentActiveGlow
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color:
                      _applyToAll
                          ? AppTheme.currentActiveGlow
                          : AppTheme.currentTextSecondary.withValues(alpha: 0.5),
                  width: 2,
                ),
              ),
              child:
                  _applyToAll
                      ? const Icon(Icons.check, color: Colors.white, size: 16)
                      : null,
            ),
            const SizedBox(width: 12),
            Text(
              t(context, 'applyToAllPrayers'),
              style: TextStyle(
                color: AppTheme.currentTextPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _togglePlayPreview(AdhanOption adhan) async {
    HapticFeedback.lightImpact();

    // If already playing this adhan, stop it
    if (_playingAdhanId == adhan.id) {
      await _audioPlayer.stop();
      setState(() => _playingAdhanId = null);
      return;
    }

    // Stop any current playback
    await _audioPlayer.stop();

    try {
      // Set up the audio source
      if (adhan.isAsset) {
        await _audioPlayer.setAsset(adhan.filePath);
      } else {
        await _audioPlayer.setFilePath(adhan.filePath);
      }

      setState(() => _playingAdhanId = adhan.id);

      // Play and listen for completion
      _audioPlayer.play();
      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          if (mounted) {
            setState(() => _playingAdhanId = null);
          }
        }
      });
    } catch (e) {
      setState(() => _playingAdhanId = null);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not play: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _selectAdhan(AdhanOption adhan) async {
    HapticFeedback.lightImpact();

    if (_applyToAll) {
      await _service.setSelectedAdhanForAll(adhan.id);
    } else {
      await _service.setSelectedAdhan(widget.prayerKey, adhan.id);
    }

    widget.onChanged?.call();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _addCustomAdhan() async {
    setState(() => _isLoading = true);

    final error = await _service.addCustomAdhan();

    if (mounted) {
      setState(() => _isLoading = false);

      if (error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error), backgroundColor: Colors.red),
        );
      } else {
        // Refresh the list
        setState(() {});
      }
    }
  }

  Future<void> _showDeleteDialog(AdhanOption adhan) async {
    HapticFeedback.heavyImpact();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            backgroundColor:
                AppTheme.isLightMode ? Colors.white : AppTheme.nightPrimaryNavy,
            title: Text(
              t(context, 'deleteAdhan'),
              style: TextStyle(color: AppTheme.currentTextPrimary),
            ),
            content: Text(
              adhan.name,
              style: TextStyle(color: AppTheme.currentTextSecondary),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(
                  t(context, 'cancel'),
                  style: TextStyle(color: AppTheme.currentTextSecondary),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(
                  t(context, 'deleteAdhan'),
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      await _service.deleteCustomAdhan(adhan.id);
      widget.onChanged?.call();
      if (mounted) {
        setState(() {});
      }
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }
}
