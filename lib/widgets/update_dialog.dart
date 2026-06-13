import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization/app_locale_provider.dart';
import '../services/apk_update_service.dart';
import '../services/update_service.dart';

/// Update dialog with full in-app flow: downloads the APK with a progress
/// bar and hands it straight to the system installer — no browser needed.
/// Falls back to the website when no direct APK URL is configured.
Future<void> showUpdateDialog(BuildContext context) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _UpdateDialog(),
  );
}

class _UpdateDialog extends StatefulWidget {
  const _UpdateDialog();

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

enum _Phase { idle, needsPermission, downloading, error }

class _UpdateDialogState extends State<_UpdateDialog> {
  _Phase _phase = _Phase.idle;
  double _progress = 0;

  String _l(String lang,
      {required String ar, required String fr, required String en}) {
    if (lang == 'ar') return ar;
    if (lang == 'fr') return fr;
    return en;
  }

  Future<void> _startUpdate() async {
    final apkUrl = UpdateService.getApkUrl();

    // No direct APK configured → old behavior: open the website
    if (apkUrl.isEmpty) {
      try {
        await launchUrl(
          Uri.parse('https://salatiapp.vercel.app'),
          mode: LaunchMode.externalApplication,
        );
      } catch (_) {}
      if (mounted) Navigator.of(context).pop();
      return;
    }

    // One-time Android permission: allow Salati to install updates
    if (!await ApkUpdateService.canRequestPackageInstalls()) {
      setState(() => _phase = _Phase.needsPermission);
      await ApkUpdateService.openInstallPermissionSettings();
      return;
    }

    setState(() {
      _phase = _Phase.downloading;
      _progress = 0;
    });

    final path = await ApkUpdateService.downloadApk(apkUrl, (p) {
      if (mounted) setState(() => _progress = p);
    });

    if (!mounted) return;
    if (path == null) {
      setState(() => _phase = _Phase.error);
      return;
    }

    final ok = await ApkUpdateService.installApk(path);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(); // system installer takes over
    } else {
      setState(() => _phase = _Phase.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final lang = AppLocaleProvider.of(context).locale.languageCode;

    final title = _l(lang,
        ar: 'تحديث متاح 🚀',
        fr: 'Mise à jour disponible 🚀',
        en: 'Update Available 🚀');

    final String body;
    switch (_phase) {
      case _Phase.needsPermission:
        body = _l(lang,
            ar: 'اسمح لصلاتي بتثبيت التحديثات من إعدادات النظام، ثم اضغط "تحديث الآن" مجدداً.',
            fr: 'Autorisez Salati à installer les mises à jour dans les réglages système, puis réessayez.',
            en: 'Allow Salati to install updates in the system settings, then tap "Update Now" again.');
        break;
      case _Phase.downloading:
        body = _l(lang,
            ar: 'جاري تنزيل التحديث...',
            fr: 'Téléchargement de la mise à jour...',
            en: 'Downloading the update...');
        break;
      case _Phase.error:
        body = _l(lang,
            ar: 'تعذر التنزيل. تحقق من الاتصال وحاول مجدداً.',
            fr: 'Échec du téléchargement. Vérifiez la connexion et réessayez.',
            en: 'Download failed. Check your connection and try again.');
        break;
      case _Phase.idle:
        body = _l(lang,
            ar: 'نسخة جديدة من صلاتي جاهزة. سيتم التنزيل والتثبيت داخل التطبيق.',
            fr: 'Une nouvelle version de Salati est prête. Téléchargement et installation dans l\'application.',
            en: 'A new version of Salati is ready. It downloads and installs right inside the app.');
    }

    final updateButton = _l(lang,
        ar: 'تحديث الآن', fr: 'Mettre à jour', en: 'Update Now');
    final retryButton =
        _l(lang, ar: 'إعادة المحاولة', fr: 'Réessayer', en: 'Retry');
    final laterButton = _l(lang, ar: 'لاحقاً', fr: 'Plus tard', en: 'Later');

    return AlertDialog(
      backgroundColor: colorScheme.surface,
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          if (_phase == _Phase.downloading) ...[
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _progress > 0 ? _progress : null,
                minHeight: 8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(_progress * 100).toStringAsFixed(0)}%',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
      actions: [
        if (_phase != _Phase.downloading)
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(laterButton),
          ),
        if (_phase != _Phase.downloading)
          FilledButton(
            onPressed: _startUpdate,
            child: Text(_phase == _Phase.error ? retryButton : updateButton),
          ),
      ],
    );
  }
}
