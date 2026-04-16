import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart'; // Für kIsWeb

// Provider für den aktuellen CustomerInfo (Abo-Status)
final customerInfoProvider = StreamProvider<CustomerInfo>((ref) {
  // Im Web gibt es aktuell kein RevenueCat, daher geben wir einen leeren Stream zurück 
  if (kIsWeb) {
    return const Stream.empty();
  }
  
  // Wir bauen einen eigenen Stream aus dem Listener
  return Stream<CustomerInfo>.multi((controller) {
    // Initialer Abruf (optional, aber gut für sofortigen Status)
    Purchases.getCustomerInfo().then((info) {
      if (!controller.isClosed) controller.add(info);
    }).catchError((e) {
      // Fehler beim initialen Laden ignorieren oder loggen
    });

    // Listener hinzufügen
    final listener = (CustomerInfo info) {
       if (!controller.isClosed) controller.add(info);
    };
    
    Purchases.addCustomerInfoUpdateListener(listener);

    // Aufräumen (Listener entfernen)
    controller.onCancel = () {
      Purchases.removeCustomerInfoUpdateListener(listener);
    };
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
      final info = await Purchases.getCustomerInfo();
      // Der Stream wird automatisch aktualisiert, aber ein explizites Fetch schadet oft nicht beim Start
    } catch (e) {
      debugPrint("Fehler beim Laden der CustomerInfo: $e");
    }
  }
}
