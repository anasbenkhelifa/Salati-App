import 'dart:io';

void main() {
  final file = File('lib/presentation/screens/home_screen.dart');
  String content = file.readAsStringSync();

  content = content.replaceFirst(
    'Widget build(BuildContext context) {\n    return SafeArea(\n      child: Column(',
    'Widget build(BuildContext context) {\n    return SafeArea(\n      child: Center(\n        child: ConstrainedBox(\n          constraints: const BoxConstraints(maxWidth: 600),\n          child: Column('
  );
  
  content = content.replaceFirst(
    '          const SizedBox(height: 24), // Bottom padding for floating nav bar\n        ],\n      ),\n    );\n  }\n}',
    '          const SizedBox(height: 24), // Bottom padding for floating nav bar\n            ],\n          ),\n        ),\n      ),\n    );\n  }\n}'
  );

  file.writeAsStringSync(content);
  print('home_screen.dart updated');
}
