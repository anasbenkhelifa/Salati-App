import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/localization/app_locale_provider.dart';
import '../services/apk_update_service.dart';
import '../services/update_service.dart';

/// Update dialog with full in-app flow: downloads the APK with a progress
/// bar and hands it straight to the system installer — no browser needed.
/// Falls back to the website when no direct APK URL is configured.
Future<void> showUpdateDialog(
  BuildContext context, {
  bool forced = false,
  String changelog = '',
}) async {
  await showDialog<void>(
    context: context,
    barrierDismissible: !forced,
    builder: (_) => _UpdateDialog(forced: forced, changelog: changelog),
  );
}

class _UpdateDialog extends StatefulWidget {
  final bool forced;
  final String changelog;

  const _UpdateDialog({this.forced = false, this.changelog = ''});

  @override
  State<_UpdateDialog> createState() => _UpdateDialogState();
}

enum _Phase { idle, needsPermission, downloading, readyToInstall, error }

class _UpdateDialogState extends State<_UpdateDialog>
    with WidgetsBindingObserver {
  _Phase _phase = _Phase.idle;
  double _progress = 0;

  // Foreground tracking: launching the system installer (startActivity) is
  // blocked while the app is backgrounded (Android 10+ background-activity
  // restriction). If the download finishes while away, hold the APK and
  // install on resume instead of silently failing.
  bool _foreground = true;
  String? _pendingPath;
  bool _integrityFailed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (_foreground && _pendingPath != null) {
      final path = _pendingPath!;
      _pendingPath = null;
      _install(path);
    }
  }

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
      _integrityFailed = false;
    });

    final path = await ApkUpdateService.downloadApk(apkUrl, (p) {
      if (mounted) setState(() => _progress = p);
    });

    if (!mounted) return;
    if (path == null) {
      setState(() => _phase = _Phase.error);
      return;
    }

    // Integrity check: reject a corrupted/tampered download before installing
    final ok = await ApkUpdateService.verifySha256(
      path,
      UpdateService.getApkSha256(),
    );
    if (!mounted) return;
    if (!ok) {
      _integrityFailed = true;
      setState(() => _phase = _Phase.error);
      return;
    }

    // Only launch the installer in the foreground; otherwise defer to resume
    if (_foreground) {
      _install(path);
    } else {
      _pendingPath = path;
      if (mounted) setState(() => _phase = _Phase.readyToInstall);
    }
  }

  Future<void> _install(String path) async {
    final ok = await ApkUpdateService.installApk(path);
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(); // system installer takes over
    } else {
      // Background launch may still be blocked — keep the dialog with a
      // manual "Install" button rather than failing silently
      _pendingPath = path;
      setState(() => _phase = _Phase.readyToInstall);
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
      case _Phase.readyToInstall:
        body = _l(lang,
            ar: 'اكتمل التنزيل. اضغط "تثبيت" لإكمال التحديث.',
            fr: 'Téléchargement terminé. Appuyez sur « Installer » pour terminer.',
            en: 'Download complete. Tap "Install" to finish the update.');
        break;
      case _Phase.error:
        body = _integrityFailed
            ? _l(lang,
                ar: 'فشل التحقق من سلامة الملف. لم يتم التثبيت. حاول مجدداً.',
                fr: 'Échec de la vérification d\'intégrité. Installation annulée. Réessayez.',
                en: 'Integrity check failed. The update was not installed. Please try again.')
            : _l(lang,
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
    final installButton =
        _l(lang, ar: 'تثبيت', fr: 'Installer', en: 'Install');
    final laterButton = _l(lang, ar: 'لاحقاً', fr: 'Plus tard', en: 'Later');

    final String actionLabel;
    final VoidCallback actionTap;
    switch (_phase) {
      case _Phase.readyToInstall:
        actionLabel = installButton;
        actionTap = () {
          final path = _pendingPath;
          if (path != null) _install(path);
        };
        break;
      case _Phase.error:
        actionLabel = retryButton;
        actionTap = _startUpdate;
        break;
      default:
        actionLabel = updateButton;
        actionTap = _startUpdate;
    }

    // Forced update: block dismissal (no Later, swallow back button)
    final showLater = !widget.forced && _phase != _Phase.downloading;

    return PopScope(
      canPop: !widget.forced,
      child: AlertDialog(
        backgroundColor: colorScheme.surface,
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            // "What's new" from Remote Config (idle phase only)
            if (_phase == _Phase.idle && widget.changelog.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.changelog,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
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
          if (showLater)
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(laterButton),
            ),
          if (_phase != _Phase.downloading)
            FilledButton(
              onPressed: actionTap,
              child: Text(actionLabel),
            ),
        ],
      ),
    );
  }
}
