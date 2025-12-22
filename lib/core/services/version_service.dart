import 'dart:io';

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
  /// Gibt null zurück wenn kein Update nötig ist
  /// Gibt UpdateInfo zurück wenn Update benötigt wird
  Future<UpdateInfo?> checkForRequiredUpdate() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Hole minimale erforderliche Version aus Firestore
      final configDoc = await _firestore.collection('app_config').doc('version').get();

      if (!configDoc.exists) {
        logger.i('Version-Check: Kein app_config/version Dokument in Firestore gefunden');
        return null; // Keine Version-Konfiguration vorhanden
      }

      final data = configDoc.data()!;
      final minVersion = data['min_version'] as String?;
      final forceUpdate = data['force_update'] as bool? ?? false;
      final updateMessage = data['update_message'] as String?;

      if (minVersion == null) {
        logger.i('Version-Check: Kein min_version Feld gefunden');
        return null;
      }

      logger.i('Version-Check: Aktuelle Version: $currentVersion, Min Version: $minVersion');

      // Vergleiche Versionen
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
        logger.w('   Bitte Firestore Security Rules anpassen:');
        logger.w('   match /app_config/{document} { allow read: if true; }');
      } else {
        logger.e('Version-Check Fehler: ${e.code} - ${e.message}');
      }
      return null; // Bei Fehler: Kein Update-Dialog anzeigen
    } catch (e) {
      logger.e('Version-Check Fehler: $e');
      return null; // Bei Fehler: Kein Update-Dialog anzeigen
    }
  }

  /// Startet den Android In-App-Update Flow (falls verfügbar)
  /// Gibt true zurück wenn erfolgreich gestartet
  Future<bool> startAndroidInAppUpdate({bool immediate = false}) async {
    if (!Platform.isAndroid) return false;

    try {
      final updateInfo = await InAppUpdate.checkForUpdate();

      if (updateInfo.updateAvailability == UpdateAvailability.updateAvailable) {
        if (immediate) {
          await InAppUpdate.performImmediateUpdate();
        } else {
          await InAppUpdate.startFlexibleUpdate();
          // Nach Download: InAppUpdate.completeFlexibleUpdate() aufrufen
        }
        return true;
      }
    } catch (e) {
      logger.e('Fehler beim Android In-App-Update: $e');
    }

    return false;
  }

  /// Öffnet den Store zum Update
  Future<void> openStore() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final packageName = packageInfo.packageName;

    Uri? storeUrl;

    if (Platform.isAndroid) {
      storeUrl = Uri.parse('https://play.google.com/store/apps/details?id=$packageName');
    } else if (Platform.isIOS) {
      // iOS App Store ID muss hier eingetragen werden
      // storeUrl = Uri.parse('https://apps.apple.com/app/idXXXXXXXXX');
      storeUrl = Uri.parse('https://apps.apple.com/');
    }

    if (storeUrl != null && await canLaunchUrl(storeUrl)) {
      await launchUrl(storeUrl, mode: LaunchMode.externalApplication);
    }
  }

  /// Vergleicht zwei Versions-Strings (Semantic Versioning)
  /// Gibt true zurück wenn currentVersion < minVersion
  bool _isUpdateRequired(String currentVersion, String minVersion) {
    final current = _parseVersion(currentVersion);
    final minimum = _parseVersion(minVersion);

    for (int i = 0; i < 3; i++) {
      if (current[i] < minimum[i]) return true;
      if (current[i] > minimum[i]) return false;
    }

    return false; // Versionen sind gleich
  }

  /// Parsed einen Version-String in eine Liste von Zahlen
  List<int> _parseVersion(String version) {
    final parts = version.split('.');
    return [
      int.tryParse(parts.elementAtOrNull(0) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(1) ?? '0') ?? 0,
      int.tryParse(parts.elementAtOrNull(2) ?? '0') ?? 0,
    ];
  }
}

/// Informationen über ein verfügbares Update
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

  String get defaultMessage => forceUpdate
      ? 'Ein Update ist erforderlich. Bitte aktualisieren Sie die App auf Version $minVersion oder höher.'
      : 'Eine neue Version ($minVersion) ist verfügbar. Wir empfehlen ein Update.';
}
