/// Art eines Standard-Pausennamens, wie ihn die App (Mobile, Web, Backend)
/// beim Anlegen einer Pause als Datenwert speichert (siehe #346).
enum DefaultBreakNameKind { plain, numbered, automatic, lunch, short }

class DefaultBreakName {
  final DefaultBreakNameKind kind;

  /// Laufende Nummer, nur bei [DefaultBreakNameKind.numbered].
  final int? number;

  const DefaultBreakName(this.kind, [this.number]);
}

final _numberedBreakName = RegExp(r'^Pause #?(\d+)$');

/// Erkennt die gespeicherten deutschen Standardnamen. Frei vergebene Namen
/// liefern `null` und müssen unverändert angezeigt werden.
///
/// Die Namen bleiben bewusst als Datenwert deutsch gespeichert, damit bestehende
/// Einträge und die anderen Plattformen kompatibel bleiben; übersetzt wird erst
/// bei der Anzeige.
DefaultBreakName? parseDefaultBreakName(String name) {
  switch (name) {
    case 'Pause':
      return const DefaultBreakName(DefaultBreakNameKind.plain);
    case 'Automatische Pause':
      return const DefaultBreakName(DefaultBreakNameKind.automatic);
    case 'Mittagspause':
      return const DefaultBreakName(DefaultBreakNameKind.lunch);
    case 'Kurzpause':
      return const DefaultBreakName(DefaultBreakNameKind.short);
  }
  final match = _numberedBreakName.firstMatch(name);
  if (match != null) {
    return DefaultBreakName(
        DefaultBreakNameKind.numbered, int.parse(match.group(1)!));
  }
  return null;
}
