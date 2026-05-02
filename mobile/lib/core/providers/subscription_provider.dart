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
