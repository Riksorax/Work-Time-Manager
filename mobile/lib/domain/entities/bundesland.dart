/// Die 16 deutschen Bundesländer, für die gesetzliche Feiertage im
/// Kalender berechnet werden können (siehe #222).
enum Bundesland {
  badenWuerttemberg,
  bayern,
  berlin,
  brandenburg,
  bremen,
  hamburg,
  hessen,
  mecklenburgVorpommern,
  niedersachsen,
  nordrheinWestfalen,
  rheinlandPfalz,
  saarland,
  sachsen,
  sachsenAnhalt,
  schleswigHolstein,
  thueringen,
}

/// Menschenlesbare Anzeige-Namen für die Bundesland-Auswahl in den
/// Einstellungen.
extension BundeslandDisplayName on Bundesland {
  String get displayName {
    switch (this) {
      case Bundesland.badenWuerttemberg:
        return 'Baden-Württemberg';
      case Bundesland.bayern:
        return 'Bayern';
      case Bundesland.berlin:
        return 'Berlin';
      case Bundesland.brandenburg:
        return 'Brandenburg';
      case Bundesland.bremen:
        return 'Bremen';
      case Bundesland.hamburg:
        return 'Hamburg';
      case Bundesland.hessen:
        return 'Hessen';
      case Bundesland.mecklenburgVorpommern:
        return 'Mecklenburg-Vorpommern';
      case Bundesland.niedersachsen:
        return 'Niedersachsen';
      case Bundesland.nordrheinWestfalen:
        return 'Nordrhein-Westfalen';
      case Bundesland.rheinlandPfalz:
        return 'Rheinland-Pfalz';
      case Bundesland.saarland:
        return 'Saarland';
      case Bundesland.sachsen:
        return 'Sachsen';
      case Bundesland.sachsenAnhalt:
        return 'Sachsen-Anhalt';
      case Bundesland.schleswigHolstein:
        return 'Schleswig-Holstein';
      case Bundesland.thueringen:
        return 'Thüringen';
    }
  }
}

/// Wandelt den in SharedPreferences gespeicherten Enum-Namen zurück in ein
/// [Bundesland]. Gibt `null` zurück, wenn kein gültiger Wert vorliegt
/// (z. B. wenn der Nutzer noch keins ausgewählt hat).
Bundesland? bundeslandFromName(String? name) {
  if (name == null) return null;
  for (final b in Bundesland.values) {
    if (b.name == name) return b;
  }
  return null;
}
