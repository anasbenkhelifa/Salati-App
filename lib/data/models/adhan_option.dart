/// Model for adhan audio options
class AdhanOption {
  final String id;
  final String name;
  final String nameAr;
  final String filePath;
  final bool isCustom;
  final bool isAsset;
  final Duration? duration;

  const AdhanOption({
    required this.id,
    required this.name,
    required this.nameAr,
    required this.filePath,
    this.isCustom = false,
    this.isAsset = true,
    this.duration,
  });

  /// Default adhan (bundled with app)
  static const AdhanOption defaultAdhan = AdhanOption(
    id: 'default',
    name: 'Mecca Adhan',
    nameAr: 'أذان مكة المكرمة',
    filePath: 'assets/audio/adhan.mp3',
    isAsset: true,
  );

  /// Medina Adhan (bundled with app)
  static const AdhanOption medinaAdhan = AdhanOption(
    id: 'medina',
    name: 'Medina Adhan',
    nameAr: 'أذان المدينة المنورة',
    filePath: 'assets/audio/medina_adhan.mp3',
    isAsset: true,
  );

  /// Create from JSON (for SharedPreferences storage)
  factory AdhanOption.fromJson(Map<String, dynamic> json) {
    return AdhanOption(
      id: json['id'] as String,
      name: json['name'] as String,
      nameAr: json['nameAr'] as String? ?? json['name'] as String,
      filePath: json['filePath'] as String,
      isCustom: json['isCustom'] as bool? ?? false,
      isAsset: json['isAsset'] as bool? ?? false,
      duration:
          json['durationMs'] != null
              ? Duration(milliseconds: json['durationMs'] as int)
              : null,
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'nameAr': nameAr,
      'filePath': filePath,
      'isCustom': isCustom,
      'isAsset': isAsset,
      'durationMs': duration?.inMilliseconds,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AdhanOption &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
