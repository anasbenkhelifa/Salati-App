import 'dart:io';

void main() {
  final file = File('lib/presentation/screens/controls_screen.dart');
  String content = file.readAsStringSync();

  content = content.replaceFirst(
    'Widget build(BuildContext context) {\n    final isArabic = AppLocaleProvider.of(context).isArabic;\n\n    return Scaffold(\n      backgroundColor: Colors.transparent,\n      body: SafeArea(\n        child: Column(',
    'Widget build(BuildContext context) {\n    final isArabic = AppLocaleProvider.of(context).isArabic;\n\n    return Scaffold(\n      backgroundColor: Colors.transparent,\n      body: SafeArea(\n        child: Center(\n          child: ConstrainedBox(\n            constraints: const BoxConstraints(maxWidth: 600),\n            child: Column('
  );
  
  content = content.replaceFirst(
    '              ],\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n',
    '                ],\n              ),\n            ),\n          ),\n        ),\n      ),\n    );\n  }\n'
  );

  file.writeAsStringSync(content);
  print('controls_screen.dart updated');
}
