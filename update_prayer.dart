import 'dart:io';

void main() {
  final file = File('lib/presentation/screens/prayer_times_screen.dart');
  String content = file.readAsStringSync();

  content = content.replaceFirst(
    'Widget build(BuildContext context) {\n    final localeController = AppLocaleProvider.of(context);\n    final isArabic = localeController.isArabic;\n\n    return Directionality(\n      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,\n      child: SafeArea(\n        child: Padding(\n          padding: const EdgeInsets.symmetric(horizontal: 20),\n          child: Column(',
    'Widget build(BuildContext context) {\n    final localeController = AppLocaleProvider.of(context);\n    final isArabic = localeController.isArabic;\n\n    return Directionality(\n      textDirection: isArabic ? TextDirection.rtl : TextDirection.ltr,\n      child: SafeArea(\n        child: Center(\n          child: ConstrainedBox(\n            constraints: const BoxConstraints(maxWidth: 600),\n            child: Padding(\n              padding: const EdgeInsets.symmetric(horizontal: 20),\n              child: Column('
  );
  
  content = content.replaceFirst(
    '            ],\n          ),\n        ),\n      ),\n    );\n  }\n}',
    '              ],\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n}'
  );

  file.writeAsStringSync(content);
  print('prayer_times_screen.dart updated');
}
