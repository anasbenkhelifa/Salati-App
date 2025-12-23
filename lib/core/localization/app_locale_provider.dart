import 'package:flutter/material.dart';
import 'app_locale_controller.dart';

/// InheritedNotifier to provide AppLocaleController throughout the app
class AppLocaleProvider extends InheritedNotifier<AppLocaleController> {
  const AppLocaleProvider({
    super.key,
    required AppLocaleController controller,
    required super.child,
  }) : super(notifier: controller);

  static AppLocaleController of(BuildContext context) {
    final provider =
        context.dependOnInheritedWidgetOfExactType<AppLocaleProvider>();
    assert(provider != null, 'No AppLocaleProvider found in context');
    return provider!.notifier!;
  }

  /// Get controller without listening to changes (for one-time access)
  static AppLocaleController read(BuildContext context) {
    final provider = context.getInheritedWidgetOfExactType<AppLocaleProvider>();
    assert(provider != null, 'No AppLocaleProvider found in context');
    return provider!.notifier!;
  }
}
