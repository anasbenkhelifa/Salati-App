import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization/app_locale_provider.dart';

Future<void> showUpdateDialog(BuildContext context) async {
  final colorScheme = Theme.of(context).colorScheme;
  final locale = AppLocaleProvider.of(context).locale.languageCode;

  final title =
      locale == 'ar'
          ? 'تحديث متاح 🚀'
          : locale == 'fr'
        ? 'Mise à jour disponible 🚀'
          : 'Update Available 🚀';

  final body =
      locale == 'ar'
          ? 'نسخة جديدة من صلاتي جاهزة. احصل على أحدث التحسينات والإصلاحات.'
          : locale == 'fr'
          ? 'Une nouvelle version de Salati est prête. Obtenez les dernières améliorations et corrections.'
          : 'A new version of Salati is ready. Get the latest improvements and fixes.';

  final updateButton =
      locale == 'ar'
          ? 'تحديث الآن'
          : locale == 'fr'
        ? 'Mettre à jour'
          : 'Update Now';

  final laterButton =
      locale == 'ar'
          ? 'لاحقاً'
          : locale == 'fr'
          ? 'Plus tard'
          : 'Later';

  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(
            onPressed: () {
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(laterButton),
          ),
          FilledButton(
            onPressed: () async {
              final uri = Uri.parse('https://salatiapp.vercel.app');
              try {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } catch (_) {
                // Intentionally ignored to keep UX smooth if no browser is available.
              }
              if (dialogContext.mounted) {
                Navigator.of(dialogContext).pop();
              }
            },
            child: Text(updateButton),
          ),
        ],
      );
    },
  );
}
