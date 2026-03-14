import 'dart:io';

void main() {
  final file = File('lib/presentation/screens/settings_screen.dart');
  String content = file.readAsStringSync();

  content = content.replaceFirst(
    'Widget build(BuildContext context) {\n    return SafeArea(\n      child: Column(',
    'Widget build(BuildContext context) {\n    return SafeArea(\n      child: Center(\n        child: ConstrainedBox(\n          constraints: const BoxConstraints(maxWidth: 600),\n          child: Column('
  );
  
  content = content.replaceFirst(
    '          const SizedBox(height: 24),\n        ],\n      ),\n    );\n  }\n}',
    '          const SizedBox(height: 24),\n            ],\n          ),\n        ),\n      ),\n    );\n  }\n}'
  );

  file.writeAsStringSync(content);
  print('settings_screen.dart updated');
}
