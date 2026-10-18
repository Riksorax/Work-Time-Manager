import 'package:flutter/widgets.dart';

/// Unterer Abstand, den der Inhalt eines Bottom-Sheets freihalten muss (#468).
///
/// Die App läuft Edge-to-Edge (`SystemUiMode.edgeToEdge`): Sheets reichen bis
/// an den Bildschirmrand und liegen sonst unter der Navigationsleiste. Mit
/// sichtbarer Tastatur gilt deren Höhe; die Navigationsleiste liegt dann
/// hinter der Tastatur und darf nicht zusätzlich addiert werden. Deshalb das
/// Maximum aus `viewInsets.bottom` (Tastatur) und `viewPadding.bottom`
/// (Navigationsleiste), keine Summe.
///
/// `useSafeArea` des Sheets genügt nicht: es berücksichtigt nur oben/seitlich
/// zuverlässig und kennt die Tastatur nicht.
double bottomSheetBottomInset(BuildContext context) {
  final media = MediaQuery.of(context);
  final keyboard = media.viewInsets.bottom;
  final navigationBar = media.viewPadding.bottom;
  return keyboard > navigationBar ? keyboard : navigationBar;
}
