/// Dauer einer Pause im Dashboard (#504).
library;

import '../entities/break_entity.dart';

/// Dauer von [b]: abgeschlossen Ende minus Start, laufend bis [now]; nie negativ.
Duration breakDuration(BreakEntity b, DateTime now) {
  final d = (b.end ?? now).difference(b.start);
  return d.isNegative ? Duration.zero : d;
}
