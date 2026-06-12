import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_motion.dart';
import '../../core/localization/strings.dart';
import '../../core/localization/app_locale_provider.dart';
import '../../data/services/adhan_selection_service.dart';
import '../../data/models/adhan_option.dart';
import 'app_sheet.dart';
import 'salati_logo.dart';

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
    return AppSheet.show(
      context,
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

    // Stagger index counter so every visible row cascades in order
    int stagger = 0;

    return AppSheet(
      maxHeightFactor: 0.7,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(
            icon: Icons.mosque,
            iconWidget: const Center(child: SalatiLogo(size: 28)),
            title: t(context, 'selectAdhan'),
            subtitle: widget.prayerName,
          ),

          // Adhan list
          Flexible(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                _buildSectionHeader(t(context, 'defaultAdhan'), stagger++),
                ...allAdhans.where((a) => !a.isCustom).map(
                      (adhan) => StaggerIn(
                        index: stagger++,
                        child: _buildAdhanTile(
                          adhan,
                          selectedAdhan.id == adhan.id,
                          isArabic,
                        ),
                      ),
                    ),

                // Custom adhans section
                if (customAdhans.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildSectionHeader(t(context, 'customAdhans'), stagger++),
                  ...customAdhans.map(
                    (adhan) => StaggerIn(
                      index: stagger++,
                      child: _buildAdhanTile(
                        adhan,
                        selectedAdhan.id == adhan.id,
                        isArabic,
                      ),
                    ),
                  ),
                ],

                // Add custom adhan button
                const SizedBox(height: 12),
                StaggerIn(index: stagger++, child: _buildAddCustomButton(context)),

                // Apply to all checkbox
                const SizedBox(height: 6),
                StaggerIn(
                  index: stagger++,
                  child: _buildApplyToAllRow(context),
                ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, int staggerIndex) {
    return StaggerIn(
      index: staggerIndex,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8, left: 4, right: 4, top: 4),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                color: AppTheme.currentActiveGlow.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.currentActiveGlow.withValues(alpha: 0.35),
                      AppTheme.currentActiveGlow.withValues(alpha: 0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdhanTile(AdhanOption adhan, bool isSelected, bool isArabic) {
    return SheetTile(
      icon: adhan.isCustom ? Icons.library_music : Icons.mosque,
      leadingWidget: adhan.isCustom
          ? null
          : const Center(child: SalatiLogo(size: 26)),
      title: isArabic ? adhan.nameAr : adhan.name,
      subtitle: adhan.duration != null ? _formatDuration(adhan.duration!) : null,
      selected: isSelected,
      onTap: () => _selectAdhan(adhan),
      onLongPress: adhan.isCustom ? () => _showDeleteDialog(adhan) : null,
      trailing: _buildPlayButton(adhan),
    );
  }

  /// Circular preview button; fills with the accent gradient while playing.
  Widget _buildPlayButton(AdhanOption adhan) {
    final isPlaying = _playingAdhanId == adhan.id;
    final glow = AppTheme.currentActiveGlow;

    return GestureDetector(
      onTap: () => _togglePlayPreview(adhan),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: AppMotion.pop,
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          gradient: isPlaying ? AppTheme.currentAccentGradient : null,
          color: isPlaying ? null : glow.withValues(alpha: 0.10),
          shape: BoxShape.circle,
          border: Border.all(
            color: glow.withValues(alpha: isPlaying ? 0.0 : 0.4),
            width: 1.5,
          ),
          boxShadow: isPlaying ? AppTheme.glowShadow(intensity: 0.8) : null,
        ),
        child: Icon(
          isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
          color: isPlaying
              ? (AppTheme.currentAccentGradient.colors.first
                          .computeLuminance() >
                      0.5
                  ? Colors.black87
                  : Colors.white)
              : glow,
          size: 22,
        ),
      ),
    );
  }

  Widget _buildAddCustomButton(BuildContext context) {
    final glow = AppTheme.currentActiveGlow;
    return GestureDetector(
      onTap: _isLoading ? null : _addCustomAdhan,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: glow.withValues(alpha: 0.45), width: 1.2),
          color: glow.withValues(alpha: 0.06),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: glow),
              )
            else
              Icon(Icons.add_circle_outline, color: glow, size: 22),
            const SizedBox(width: 10),
            Text(
              t(context, 'addCustomAdhan'),
              style: TextStyle(
                color: glow,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildApplyToAllRow(BuildContext context) {
    final selectedAdhan = _service.getSelectedAdhan(widget.prayerKey);
    final glow = AppTheme.currentActiveGlow;

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
                backgroundColor: glow,
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
            AnimatedContainer(
              duration: AppMotion.fast,
              curve: AppMotion.pop,
              width: 23,
              height: 23,
              decoration: BoxDecoration(
                gradient: _applyToAll ? AppTheme.currentAccentGradient : null,
                borderRadius: BorderRadius.circular(7),
                border: Border.all(
                  color: _applyToAll
                      ? Colors.transparent
                      : AppTheme.currentTextSecondary.withValues(alpha: 0.5),
                  width: 2,
                ),
                boxShadow:
                    _applyToAll ? AppTheme.glowShadow(intensity: 0.5) : null,
              ),
              child: _applyToAll
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
                AppTheme.isLightMode ? Colors.white : AppTheme.currentSurface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
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
