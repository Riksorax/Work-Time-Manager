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
