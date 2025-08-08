import 'package:equatable/equatable.dart';

/// Repräsentiert einen Benutzer in der Domain-Schicht.
///
/// Diese Entität ist eine vereinfachte, von der Datenquelle unabhängige
/// Darstellung eines Benutzers. Sie enthält nur die für die App-Logik
/// wirklich notwendigen Informationen.
class UserEntity extends Equatable {
  /// Die eindeutige ID des Benutzers (z.B. von Firebase Auth).
  final String id;

  /// Die E-Mail-Adresse des Benutzers. Kann null sein.
  final String? email;

  /// Der Anzeigename des Benutzers. Kann null sein.
  final String? displayName;

  const UserEntity({
    required this.id,
    this.email,
    this.displayName,
  });

  @override
  List<Object?> get props => [id, email, displayName];
}