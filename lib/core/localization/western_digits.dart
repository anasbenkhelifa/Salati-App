/// Global helper to convert ALL Arabic-Indic and Eastern Arabic-Indic digits to Western digits
/// MUST be used on every number displayed in the UI
String westernDigits(String input) {
  const map = {
    '٠': '0',
    '١': '1',
    '٢': '2',
    '٣': '3',
    '٤': '4',
    '٥': '5',
    '٦': '6',
    '٧': '7',
    '٨': '8',
    '٩': '9',
    '۰': '0',
    '۱': '1',
    '۲': '2',
    '۳': '3',
    '۴': '4',
    '۵': '5',
    '۶': '6',
    '۷': '7',
    '۸': '8',
    '۹': '9',
  };

  var out = input;
  map.forEach((k, v) => out = out.replaceAll(k, v));

  // Debug assertion - uncomment to catch any missed digits
  // assert(!RegExp(r'[٠-٩۰-۹]').hasMatch(out), 'Arabic digits found in: $out');

  return out;
}
