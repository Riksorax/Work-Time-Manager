import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

/// Erzeugt einen SHA-256-Hash einer PIN mit Salt, damit die PIN nicht im
/// Klartext in SharedPreferences liegt (siehe #223).
///
/// Reine Funktion ohne Seiteneffekte - der Salt wird separat generiert und
/// gespeichert (siehe [generateSalt]).
String hashPin(String pin, String salt) {
  final bytes = utf8.encode('$salt:$pin');
  return sha256.convert(bytes).toString();
}

/// Generiert einen kryptographisch zufälligen Salt für [hashPin].
String generateSalt() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  return base64Url.encode(bytes);
}

/// Alphabet der Wiederherstellungscodes (32 Zeichen, ohne I/O/0/1, damit sich
/// der Code gut abschreiben lässt). 256 % 32 == 0, daher kein Modulo-Bias.
const _recoveryAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Erzeugt einen 16-stelligen Wiederherstellungscode (80 Bit) für die
/// App-Sperre (siehe #288). [random] ist nur für Tests injizierbar.
String generateRecoveryCode({Random? random}) {
  final rnd = random ?? Random.secure();
  return List.generate(16,
          (_) => _recoveryAlphabet[rnd.nextInt(256) % _recoveryAlphabet.length],
          growable: false)
      .join();
}

/// Formatiert einen normalisierten Code als `XXXX-XXXX-XXXX-XXXX`.
String formatRecoveryCode(String code) {
  final parts = <String>[];
  for (var i = 0; i < code.length; i += 4) {
    parts.add(code.substring(i, min(i + 4, code.length)));
  }
  return parts.join('-');
}

/// Normalisiert eine Benutzereingabe: Großbuchstaben, ohne `-` und Leerzeichen.
String normalizeRecoveryCode(String input) =>
    input.replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
