/**
 * Typisierte Rejection einer Dashboard-Schreibaktion mit Saldo-Block, deren Eintrag- oder Saldo-Write gescheitert ist
 * (#426). Die Anzeige ist dann bereits auf den Vorzustand zurückgenommen (bei Saldo-Fehler auch der Eintrag
 * best-effort kompensiert). `cause` ist der ursprüngliche Fehler bzw. ein `PromiseTimeoutError` und geht vom
 * `DashboardComponent` an den globalen `ErrorHandler`; die Meldung selbst nennt bewusst keine Eintragswerte.
 * Pure TypeScript, ohne Angular.
 */
export class DashboardSaveError extends Error {
  constructor(cause: unknown) {
    super('Dashboard-Aktion konnte nicht gespeichert werden', { cause });
    this.name = 'DashboardSaveError';
  }
}
