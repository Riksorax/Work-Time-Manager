import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_work_time/core/utils/logger.dart';

/// Service für Version-Checks und Update-Management
class VersionService {
  final FirebaseFirestore _firestore;

  VersionService(this._firestore);

  /// Prüft ob ein Update erforderlich ist
  Future<UpdateInfo?> checkForRequiredUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      final configDoc =
          await _firestore.collection('app_config').doc('version').get();

      if (!configDoc.exists) {
        logger.i(
            'Version-Check: Kein app_config/version Dokument in Firestore gefunden');
        return null;
      }

      final data = configDoc.data()!;
      final minVersion = data['min_version'] as String?;
      final forceUpdate = data['force_update'] as bool? ?? false;
      final updateMessage = data['update_message'] as String?;

      if (minVersion == null) {
        logger.i('Version-Check: Kein min_version Feld gefunden');
        return null;
      }

      logger.i(
          'Version-Check: Aktuelle Version: $currentVersion, Min Version: $minVersion');

      if (_isUpdateRequired(currentVersion, minVersion)) {
        logger.w('Update erforderlich: $currentVersion < $minVersion');
        return UpdateInfo(
          currentVersion: currentVersion,
          minVersion: minVersion,
          forceUpdate: forceUpdate,
          message: updateMessage,
        );
      }

      logger.i('Version-Check: Keine Aktualisierung erforderlich');
      return null;
    } on FirebaseException catch (e) {
      if (e.code == 'permission-denied') {
        logger.w('Version-Check: Firestore Permission Denied');
      } else {
        logger.e('Version-Check Fehler: ${e.code} - ${e.message}');
      }
      return null;
    } catch (e) {
      logger.e('Version-Check Fehler: $e');
      return null;
    }
  }

  /// Startet den Android In-App-Update Flow (falls verfügbar)
  ///
  /// Ein flexibles Update wird nach dem Download sofort installiert
  /// (kontrollierter Neustart der App). Ohne `completeFlexibleUpdate` würde
  /// Play es irgendwann im Hintergrund einspielen, während noch ein alter
  /// Prozess läuft (#453).
  Future<bool> startAndroidInAppUpdate({bool immediate = false}) async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return false;

    StreamSubscription<InstallStatus>? installSubscription;
    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      // Update aus einer früheren Sitzung bereits geladen, aber nicht installiert.
      if (updateInfo.installStatus == InstallStatus.downloaded) {
        await InAppUpdate.completeFlexibleUpdate();
        return true;
      }

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (immediate) {
          await InAppUpdate.performImmediateUpdate();
        } else {
          // Vor dem Start abonnieren, damit kein Status verpasst wird.
          installSubscription = completeFlexibleUpdateWhenDownloaded(
            InAppUpdate.installUpdateListener,
            InAppUpdate.completeFlexibleUpdate,
          );
          final result = await InAppUpdate.startFlexibleUpdate();
          if (result != AppUpdateResult.success) {
            await installSubscription.cancel();
            return false;
          }
        }
        return true;
      }
    } catch (e) {
      await installSubscription?.cancel();
      logger.e('Fehler beim Android In-App-Update: $e');
    }

    return false;
  }

  /// Installiert ein flexibles Update, sobald [installStatus] `downloaded`
  /// meldet, und beendet das Abonnement bei jedem Endstatus.
  @visibleForTesting
  static StreamSubscription<InstallStatus> completeFlexibleUpdateWhenDownloaded(
    Stream<InstallStatus> installStatus,
    Future<void> Function() completeFlexibleUpdate,
  ) {
    late final StreamSubscription<InstallStatus> subscription;
    subscription = installStatus.listen((status) async {
      switch (status) {
        case InstallStatus.downloaded:
          await subscription.cancel();
          try {
            await completeFlexibleUpdate();
          } catch (e) {
            logger.e('Flexibles Update konnte nicht installiert werden: $e');
          }
        case InstallStatus.installed ||
              InstallStatus.failed ||
              InstallStatus.canceled:
          await subscription.cancel();
        default:
          break;
      }
    });
    return subscription;
  }

  /// Öffnet den Store zum Update
  Future<void> openStore() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final packageName = packageInfo.packageName;

    Uri? storeUrl;

    if (kIsWeb) {
      // Web fallback: Keine Store URL oder spezifische URL
      return;
    } else if (defaultTargetPlatform == TargetPlatform.android) {
      storeUrl = Uri.parse(
          'https://play.google.com/store/apps/details?id=$packageName');
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      storeUrl = Uri.parse('https://apps.apple.com/');
    }

    if (storeUrl != null && await canLaunchUrl(storeUrl)) {
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    }
  }

  bool _isUpdateRequired(String currentVersion, String minVersion) {
    final current = _parseVersion(currentVersion);
    final minimum = _parseVersion(minVersion);

    for (int i = 0; i < 3; i++) {
      if (current[i] < minimum[i]) return true;
      if (current[i] > minimum[i]) return false;
    }

    return false;
  }

  List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      int.tryParse(parts.elementAtOrNull(0) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(2) ?? '0') ?? 0,
    ];
  }
}

class UpdateInfo {
  final String currentVersion;
  final String minVersion;
  final bool forceUpdate;
  final String? message;

  UpdateInfo({
    required this.currentVersion,
    required this.minVersion,
    required this.forceUpdate,
    this.message,
  });
}
