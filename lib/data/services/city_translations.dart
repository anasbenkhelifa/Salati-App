/// Local translation dictionary for common city and country names.
/// Used as a fallback because native geocoding cannot reliably force Arabic locale.
class CityTranslations {
  static const Map<String, String> _arabicMap = {
    // Saudi Arabia
    "Riyadh": "الرياض",
    "Jeddah": "جدة",
    "Mecca": "مكة المكرمة",
    "Makkah": "مكة المكرمة",
    "Medina": "المدينة المنورة",
    "Madinah": "المدينة المنورة",
    "Al Madinah Al Munawwarah": "المدينة المنورة",
    "Dammam": "الدمام",
    "Khobar": "الخبر",
    "Dhahran": "الظهران",
    "Abha": "أبها",
    "Tabuk": "تبوك",
    "Buraydah": "بريدة",
    "Khamis Mushait": "خميس مشيط",
    "Ta'if": "الطائف",
    "Taif": "الطائف",
    "Jizan": "جازان",
    "Hail": "حائل",
    "Najran": "نجران",
    "Yanbu": "ينبع",
    "Saudi Arabia": "السعودية",

    // UAE
    "Dubai": "دبي",
    "Abu Dhabi": "أبو ظبي",
    "Sharjah": "الشارقة",
    "Ajman": "عجمان",
    "Al Ain": "العين",
    "Ras Al Khaimah": "رأس الخيمة",
    "Fujairah": "الفجيرة",
    "United Arab Emirates": "الإمارات العربية المتحدة",

    // Egypt
    "Cairo": "القاهرة",
    "Alexandria": "الإسكندرية",
    "Giza": "الجيزة",
    "Shubra El Kheima": "شبرا الخيمة",
    "Port Said": "بورسعيد",
    "Suez": "السويس",
    "Mansoura": "المنصورة",
    "Tanta": "طنطا",
    "Asyut": "أسيوط",
    "Ismailia": "الإسماعيلية",
    "Faiyum": "الفيوم",
    "Zagazig": "الزقازيق",
    "Damietta": "دمياط",
    "Aswan": "أسوان",
    "Minya": "المنيا",
    "Damanhur": "دمنهور",
    "Luxor": "الأقصر",
    "Egypt": "مصر",

    // Algeria
    "Algiers": "الجزائر",
    "Oran": "وهران",
    "Constantine": "قسنطينة",
    "Annaba": "عنابة",
    "Blida": "البليدة",
    "Batna": "باتنة",
    "Djelfa": "الجلفة",
    "Sétif": "سطيف",
    "Setif": "سطيف",
    "Sidi Bel Abbès": "سيدي بلعباس",
    "Biskra": "بسكرة",
    "Algeria": "الجزائر",

    // Morocco
    "Casablanca": "الدار البيضاء",
    "Rabat": "الرباط",
    "Fes": "فاس",
    "Tangier": "طنجة",
    "Marrakesh": "مراكش",
    "Marrakech": "مراكش",
    "Salé": "سلا",
    "Meknes": "مكناس",
    "Oujda": "وجدة",
    "Kenitra": "القنيطرة",
    "Agadir": "أكادير",
    "Tetouan": "تطوان",
    "Morocco": "المغرب",

    // Iraq
    "Baghdad": "بغداد",
    "Basra": "البصرة",
    "Basrah": "البصرة",
    "Mosul": "الموصل",
    "Erbil": "أربيل",
    "Kirkuk": "كركوك",
    "Najaf": "النجف",
    "Karbala": "كربلاء",
    "Nasiriyah": "الناصرية",
    "Amara": "العمارة",
    "Hillah": "الحلة",
    "Ramadi": "الرمادي",
    "Iraq": "العراق",

    // Jordan
    "Amman": "عمان",
    "Zarqa": "الزرقاء",
    "Irbid": "إربد",
    "Russeifa": "الرصيفة",
    "Aqaba": "العقبة",
    "Madaba": "مادبا",
    "Jerash": "جرش",
    "Jordan": "الأردن",

    // Rest of MENA
    "Jerusalem": "القدس",
    "Gaza": "غزة",
    "Palestine": "فلسطين",
    "Kuwait City": "مدينة الكويت",
    "Hawalli": "حولي",
    "Kuwait": "الكويت",
    "Doha": "الدوحة",
    "Qatar": "قطر",
    "Manama": "المنامة",
    "Bahrain": "البحرين",
    "Muscat": "مسقط",
    "Salalah": "صلالة",
    "Oman": "عمان",
    "Damascus": "دمشق",
    "Aleppo": "حلب",
    "Homs": "حمص",
    "Latakia": "اللاذقية",
    "Hama": "حماة",
    "Syria": "سوريا",
    "Beirut": "بيروت",
    "Tripoli": "طرابلس",
    "Sidon": "صيدا",
    "Tyr": "صور",
    "Lebanon": "لبنان",
    "Sanaa": "صنعاء",
    "Aden": "عدن",
    "Taiz": "تعز",
    "Yemen": "اليمن",
    "Khartoum": "الخرطوم",
    "Omdurman": "أم درمان",
    "Sudan": "السودان",
    "Tunis": "تونس",
    "Sfax": "صفاقس",
    "Sousse": "سوسة",
    "Tunisia": "تونس",
    "Mogadishu": "مقديشو",
    "Somalia": "الصومال",
    "Nouakchott": "نواكشوط",
    "Mauritania": "موريتانيا",
    "Djibouti": "جيبوتي",

    // Global Hubs
    "London": "لندن",
    "Paris": "باريس",
    "New York": "نيويورك",
    "Washington": "واشنطن",
    "Berlin": "برلين",
    "Rome": "روما",
    "Madrid": "مدريد",
    "Tehran": "طهران",
    "Istanbul": "إسطنبول",
    "Ankara": "أنقرة",
    "Jakarta": "جاكرتا",
    "Kuala Lumpur": "كوالالمبور",
    "Karachi": "كراتشي",
    "Lahore": "لاهور",
    "Islamabad": "إسلام آباد",
    "Dhaka": "دكا",
    
    // Countries
    "United States": "الولايات المتحدة",
    "United Kingdom": "المملكة المتحدة",
    "France": "فرنسا",
    "Germany": "ألمانيا",
    "Spain": "إسبانيا",
    "Italy": "إيطاليا",
    "Canada": "كندا",
    "Australia": "أستراليا",
    "India": "الهند",
    "Pakistan": "باكستان",
    "Bangladesh": "بنغلاديش",
    "Malaysia": "ماليزيا",
    "Indonesia": "إندونيسيا",
    "Turkey": "تركيا",
    "Iran": "إيران",
    "Russia": "روسيا",
    "China": "الصين",
    "Japan": "اليابان"
  };

  /// Lookup the Arabic translation. If not found, returns null.
  /// Handles case-insensitivity manually to keep the dictionary simple.
  static String? lookup(String? englishName) {
    if (englishName == null || englishName.isEmpty) return null;
    
    final match = _arabicMap[englishName];
    if (match != null) return match;

    // Fallback: lowercase search (slower but robust)
    final lowerInput = englishName.toLowerCase();
    for (final entry in _arabicMap.entries) {
      if (entry.key.toLowerCase() == lowerInput) {
        return entry.value;
      }
    }
    return null;
  }
}
