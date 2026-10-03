import 'package:equatable/equatable.dart';

import '../../domain/utils/leave_balance_utils.dart';

/// Zustand der Resturlaub-Anzeige (siehe #278).
///
/// [balance] bleibt während eines Neuladens als Vorwert erhalten, damit die
/// Karte nicht flackert. [hasError] ist nur gesetzt, wenn das letzte Laden
/// fehlgeschlagen ist - es wird nie still ein 0/30-Wert angezeigt.
class LeaveBalanceState extends Equatable {
  final bool isLoading;
  final bool hasError;
  final LeaveBalance? balance;

  const LeaveBalanceState({
    this.isLoading = false,
    this.hasError = false,
    this.balance,
  });

  @override
  List<Object?> get props => [
        isLoading,
        hasError,
        balance?.year,
        balance?.entitlement,
        balance?.taken,
        balance?.remaining,
        balance?.sickDays,
      ];
}
