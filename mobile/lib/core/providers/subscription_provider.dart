import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_work_time/core/providers/providers.dart';

bool _hasActivePremium(CustomerInfo info) {
  return info.entitlements.all['work_time_manager_premium']?.isActive ??
         info.entitlements.all['work_time_manager_premiun']?.isActive ??
         info.entitlements.all['premium']?.isActive ??
         info.entitlements.all['Premium']?.isActive ??
         false;
}

// Provider für den aktuellen CustomerInfo (Abo-Status)
final customerInfoProvider = StreamProvider<CustomerInfo>((ref) {
  if (kIsWeb) return const Stream.empty();

  return Stream<CustomerInfo>.multi((controller) {
    void syncToFirestore(CustomerInfo info) {
      final uid = ref.read(firebaseAuthProvider).currentUser?.uid;
      if (uid == null) return;
      ref
          .read(firestoreDataSourceProvider)
          .setUserProfile(uid, {'isPremium': _hasActivePremium(info)})
          .catchError((e) => debugPrint('[Premium] Firestore-Sync fehlgeschlagen: $e'));
    }

    Purchases.getCustomerInfo().then((info) {
      if (!controller.isClosed) {
        controller.add(info);
        syncToFirestore(info);
      }
    }).catchError((_) {});

    void listener(CustomerInfo info) {
      if (!controller.isClosed) {
        controller.add(info);
        syncToFirestore(info);
      }
    }

    Purchases.addCustomerInfoUpdateListener(listener);
    controller.onCancel = () => Purchases.removeCustomerInfoUpdateListener(listener);
  });
});

// Provider, der direkt true/false zurückgibt, ob der Nutzer Premium hat
final isPremiumProvider = Provider<bool>((ref) {
  final customerInfoAsync = ref.watch(customerInfoProvider);

  return customerInfoAsync.when(
    data: (customerInfo) {
      // Prüfe auf verschiedene Schreibweisen der Entitlement ID
      final hasPremium = customerInfo.entitlements.all['work_time_manager_premium']?.isActive ?? 
                         customerInfo.entitlements.all['work_time_manager_premiun']?.isActive ?? // Falls Tippfehler
                         customerInfo.entitlements.all['premium']?.isActive ?? 
                         customerInfo.entitlements.all['Premium']?.isActive ?? 
                         false;
                         
      return hasPremium;
    },
    error: (_, __) => false, // Bei Fehler kein Premium
    loading: () => false,    // Beim Laden noch kein Premium
  );
});

// Hilfsfunktion zum Initialisieren (kann beim App-Start aufgerufen werden)
Future<void> refreshCustomerInfo(WidgetRef ref) async {
  if (!kIsWeb) {
    try {
      await Purchases.getCustomerInfo();
    } catch (e) {
      debugPrint("Fehler beim Laden der CustomerInfo: $e");
    }
  }
}

/// Liefert das aktive Premium-[EntitlementInfo] (falls vorhanden), um z.B.
/// Ablaufdatum und Verlängerungsstatus in den Einstellungen anzuzeigen
/// (siehe #220).
EntitlementInfo? activeEntitlement(CustomerInfo info) {
  const ids = [
    'work_time_manager_premium',
    'work_time_manager_premiun', // Falls Tippfehler
    'premium',
    'Premium',
  ];
  for (final id in ids) {
    final entitlement = info.entitlements.all[id];
    if (entitlement?.isActive ?? false) return entitlement;
  }
  return null;
}

// Provider für das aktive Premium-Entitlement (Laufzeit, Verlängerungsstatus)
final activeEntitlementProvider = Provider<EntitlementInfo?>((ref) {
  final customerInfoAsync = ref.watch(customerInfoProvider);
  return customerInfoAsync.when(
    data: activeEntitlement,
    error: (_, __) => null,
    loading: () => null,
  );
});

/// Ruft den store-eigenen Link zur Abo-Verwaltung ab (Kündigung/Verlängerung
/// direkt im App Store bzw. Play Store). Gibt `null` zurück, wenn kein Link
/// verfügbar ist (z.B. Web oder Fehler) - siehe #220.
///
/// `purchases_flutter` bietet dafür keine eigene statische Methode - der
/// Link steckt direkt als Feld in [CustomerInfo.managementURL].
Future<String?> getSubscriptionManagementUrl() async {
  if (kIsWeb) return null;
  try {
    final info = await Purchases.getCustomerInfo();
    return info.managementURL;
  } catch (e) {
    debugPrint('[Premium] managementURL nicht verfügbar: $e');
    return null;
  }
}
