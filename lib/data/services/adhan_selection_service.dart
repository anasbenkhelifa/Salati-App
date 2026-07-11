import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import '../models/adhan_option.dart';

/// Service for managing per-prayer adhan selections and custom adhans
class AdhanSelectionService extends ChangeNotifier {
  static final AdhanSelectionService _instance = AdhanSelectionService._();
  static AdhanSelectionService get instance => _instance;
  AdhanSelectionService._();

  static const List<String> prayerKeys = [
    'fajr',
    'dhuhr',
    'asr',
    'maghrib',
    'isha',
  ];
  static const String _selectionsKey = 'adhan_selections';
  static const String _customAdhansKey = 'custom_adhans';

  // Supported audio formats
  static const List<String> supportedExtensions = [
    'mp3',
    'wav',
    'm4a',
    'ogg',
    'aac',
    'flac',
  ];
  static const Duration maxDuration = Duration(minutes: 5);

  SharedPreferences? _prefs;
  Map<String, String> _selections = {}; // prayerKey -> adhanId
  List<AdhanOption> _customAdhans = [];
  bool _initialized = false;

  bool get isInitialized => _initialized;
  List<AdhanOption> get customAdhans => List.unmodifiable(_customAdhans);

  /// Get all available adhans (default + custom)
  List<AdhanOption> get allAdhans => [
    AdhanOption.defaultAdhan,
    AdhanOption.medinaAdhan,
    ..._customAdhans,
  ];

  /// Initialize the service
  Future<void> initialize() async {
    if (_initialized) return;
    _prefs = await SharedPreferences.getInstance();
    await _loadSelections();
    await _loadCustomAdhans();
    _initialized = true;
    notifyListeners();
  }

  /// Get selected adhan for a prayer
  AdhanOption getSelectedAdhan(String prayerKey) {
    final adhanId = _selections[prayerKey] ?? 'medina';
    return allAdhans.firstWhere(
      (a) => a.id == adhanId,
      orElse: () => AdhanOption.medinaAdhan,
    );
  }

  /// Set selected adhan for a prayer
  Future<void> setSelectedAdhan(String prayerKey, String adhanId) async {
    _selections[prayerKey] = adhanId;
    await _saveSelections();
    notifyListeners();
  }

  /// Set selected adhan for all prayers
  Future<void> setSelectedAdhanForAll(String adhanId) async {
    for (final key in prayerKeys) {
      _selections[key] = adhanId;
    }
    await _saveSelections();
    notifyListeners();
  }

  /// Pick and add a custom adhan file
  /// Returns error message if failed, null if successful
  Future<String?> addCustomAdhan() async {
    try {
      // Pick audio file
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) {
        return null; // User cancelled
      }

      final file = result.files.first;
      if (file.path == null) {
        return 'Could not access file';
      }

      // Validate extension
      final extension = file.extension?.toLowerCase() ?? '';
      if (!supportedExtensions.contains(extension)) {
        return 'Unsupported format. Use: ${supportedExtensions.join(", ")}';
      }

      // Validate duration
      final duration = await _getAudioDuration(file.path!);
      if (duration == null) {
        return 'Could not read audio file';
      }
      if (duration > maxDuration) {
        return 'Audio too long (max 5 minutes)';
      }

      // Copy to app storage
      final appDir = await getApplicationDocumentsDirectory();
      final adhansDir = Directory('${appDir.path}/custom_adhans');
      if (!await adhansDir.exists()) {
        await adhansDir.create(recursive: true);
      }

      final fileName =
          'custom_${DateTime.now().millisecondsSinceEpoch}.$extension';
      final destPath = '${adhansDir.path}/$fileName';
      await File(file.path!).copy(destPath);

      // Create adhan option
      final displayName = file.name.replaceAll(
        RegExp(r'\.[^.]+$'),
        '',
      ); // Remove extension
      final adhanOption = AdhanOption(
        id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
        name: displayName,
        nameAr: displayName,
        filePath: destPath,
        isCustom: true,
        isAsset: false,
        duration: duration,
      );

      _customAdhans.add(adhanOption);
      await _saveCustomAdhans();
      notifyListeners();
      return null; // Success
    } catch (e) {
      return 'Error: ${e.toString()}';
    }
  }

  /// Delete a custom adhan
  Future<void> deleteCustomAdhan(String adhanId) async {
    final adhan = _customAdhans.firstWhere(
      (a) => a.id == adhanId,
      orElse: () => AdhanOption.defaultAdhan,
    );

    if (!adhan.isCustom) return;

    // Delete file
    try {
      final file = File(adhan.filePath);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}

    // Remove from list
    _customAdhans.removeWhere((a) => a.id == adhanId);

    // Reset selections using this adhan to default
    for (final key in prayerKeys) {
      if (_selections[key] == adhanId) {
        _selections[key] = 'default';
      }
    }

    await _saveCustomAdhans();
    await _saveSelections();
    notifyListeners();
  }

  /// Get audio duration using just_audio
  Future<Duration?> _getAudioDuration(String filePath) async {
    final player = AudioPlayer();
    try {
      final duration = await player.setFilePath(filePath);
      await player.dispose();
      return duration;
    } catch (_) {
      await player.dispose();
      return null;
    }
  }

  Future<void> _loadSelections() async {
    final json = _prefs?.getString(_selectionsKey);
    if (json != null) {
      try {
        _selections = Map<String, String>.from(jsonDecode(json));
      } catch (_) {}
    }
  }

  Future<void> _saveSelections() async {
    await _prefs?.setString(_selectionsKey, jsonEncode(_selections));
  }

  Future<void> _loadCustomAdhans() async {
    final json = _prefs?.getString(_customAdhansKey);
    if (json != null) {
      try {
        final list = jsonDecode(json) as List;
        _customAdhans =
            list
                .map((e) => AdhanOption.fromJson(e as Map<String, dynamic>))
                .where(
                  (a) => File(a.filePath).existsSync(),
                ) // Only keep existing files
                .toList();
      } catch (_) {}
    }
  }

  Future<void> _saveCustomAdhans() async {
    final json = jsonEncode(_customAdhans.map((a) => a.toJson()).toList());
    await _prefs?.setString(_customAdhansKey, json);
  }
}
