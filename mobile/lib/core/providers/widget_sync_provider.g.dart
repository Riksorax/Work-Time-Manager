// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'widget_sync_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Haelt das Android-Status-Widget (#276) aktuell: schreibt bei jeder
/// relevanten Aenderung des Dashboard-Zustands einen [TimerSnapshot] in das
/// Gateway. Das Widget wird nur von hier aktualisiert (kein Backend-Poll).
///
/// - Der Ladezustand wird nie geschrieben.
/// - Es wird nur geschrieben, wenn sich der Snapshot aendert (Status, Start,
///   Pausenstart, Netto-Minute, Tag, Sperre), nicht jede Sekunde.
/// - Logout/Nutzerwechsel und Profilwechsel leeren den Snapshot sofort; der
///   neue Ladelauf des Dashboards schreibt danach den neuen Stand.
/// - Vor dem ersten Auth-Wert wird nichts geschrieben (die Repositories fallen
///   davor auf den lokalen Speicher zurueck); mit dem Wert wird neu gepusht.
/// - Ist die App-Sperre aktiviert (PIN eingerichtet und aktiv, nicht nur
///   gerade gesperrt), werden nie Zeiten geschrieben: nur Status und
///   `locked: true`. So bleiben auch bei beendetem Dart-Prozess keine Zeiten
///   im Klartext im Widget. Die Konfiguration wird bei jedem Push gelesen;
///   Aenderungen greifen spaetestens beim naechsten Push (z. B. Wechsel in den
///   Hintergrund, der die Sperre setzt).

@ProviderFor(widgetSync)
const widgetSyncProvider = WidgetSyncProvider._();

/// Haelt das Android-Status-Widget (#276) aktuell: schreibt bei jeder
/// relevanten Aenderung des Dashboard-Zustands einen [TimerSnapshot] in das
/// Gateway. Das Widget wird nur von hier aktualisiert (kein Backend-Poll).
///
/// - Der Ladezustand wird nie geschrieben.
/// - Es wird nur geschrieben, wenn sich der Snapshot aendert (Status, Start,
///   Pausenstart, Netto-Minute, Tag, Sperre), nicht jede Sekunde.
/// - Logout/Nutzerwechsel und Profilwechsel leeren den Snapshot sofort; der
///   neue Ladelauf des Dashboards schreibt danach den neuen Stand.
/// - Vor dem ersten Auth-Wert wird nichts geschrieben (die Repositories fallen
///   davor auf den lokalen Speicher zurueck); mit dem Wert wird neu gepusht.
/// - Ist die App-Sperre aktiviert (PIN eingerichtet und aktiv, nicht nur
///   gerade gesperrt), werden nie Zeiten geschrieben: nur Status und
///   `locked: true`. So bleiben auch bei beendetem Dart-Prozess keine Zeiten
///   im Klartext im Widget. Die Konfiguration wird bei jedem Push gelesen;
///   Aenderungen greifen spaetestens beim naechsten Push (z. B. Wechsel in den
///   Hintergrund, der die Sperre setzt).

final class WidgetSyncProvider extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Haelt das Android-Status-Widget (#276) aktuell: schreibt bei jeder
  /// relevanten Aenderung des Dashboard-Zustands einen [TimerSnapshot] in das
  /// Gateway. Das Widget wird nur von hier aktualisiert (kein Backend-Poll).
  ///
  /// - Der Ladezustand wird nie geschrieben.
  /// - Es wird nur geschrieben, wenn sich der Snapshot aendert (Status, Start,
  ///   Pausenstart, Netto-Minute, Tag, Sperre), nicht jede Sekunde.
  /// - Logout/Nutzerwechsel und Profilwechsel leeren den Snapshot sofort; der
  ///   neue Ladelauf des Dashboards schreibt danach den neuen Stand.
  /// - Vor dem ersten Auth-Wert wird nichts geschrieben (die Repositories fallen
  ///   davor auf den lokalen Speicher zurueck); mit dem Wert wird neu gepusht.
  /// - Ist die App-Sperre aktiviert (PIN eingerichtet und aktiv, nicht nur
  ///   gerade gesperrt), werden nie Zeiten geschrieben: nur Status und
  ///   `locked: true`. So bleiben auch bei beendetem Dart-Prozess keine Zeiten
  ///   im Klartext im Widget. Die Konfiguration wird bei jedem Push gelesen;
  ///   Aenderungen greifen spaetestens beim naechsten Push (z. B. Wechsel in den
  ///   Hintergrund, der die Sperre setzt).
  const WidgetSyncProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'widgetSyncProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$widgetSyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return widgetSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$widgetSyncHash() => r'5bbf8bdd5b41ccdedd94cb11cc7c236997d05987';
