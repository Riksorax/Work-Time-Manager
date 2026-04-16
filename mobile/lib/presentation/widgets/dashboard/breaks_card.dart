import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
import '../../../domain/services/break_calculator_service.dart';
import '../../view_models/dashboard_view_model.dart';

/// Eine Karte zur Anzeige und Verwaltung von Pausen.
class BreaksCard extends ConsumerWidget {
  final WorkEntryEntity workEntry;

  const BreaksCard({
    super.key,
    required this.workEntry,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeFormat = DateFormat('HH:mm');
    final BreakEntity? activeBreak = workEntry.breaks.firstWhereOrNull(
          (b) => b.end == null,
    );

    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Pausen',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            // Zeige eine Nachricht an, wenn keine Pausen erfasst wurden.
            if (workEntry.breaks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: Text(
                    'Keine Pausen erfasst',
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                ),
              ),
            // Liste alle erfassten Pausen auf.
            ...workEntry.breaks.map(
                  (b) => ListTile(
                dense: true,
                leading: Icon(
                  b.end == null ? Icons.timer_outlined : Icons.check_circle_outline,
                  color: Theme.of(context).primaryColor,
                ),
                title: Text(b.name),
                trailing: Text(
                  '${timeFormat.format(b.start)} - ${b.end != null ? timeFormat.format(b.end!) : '...'}',
                ),
              ),
            ),
            // Warnung bei unzureichenden Pausen (Arbeitszeitgesetz)
            _buildBreakComplianceWarning(context),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(
                activeBreak != null ? Icons.stop_circle_outlined : Icons.play_circle_outlined,
              ),
              label: Text(
                activeBreak != null ? 'Pause beenden' : 'Pause starten',
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.secondary,
                foregroundColor: Theme.of(context).colorScheme.onSecondary,
              ),
              // Der Button ist nur aktiv, wenn die Arbeit läuft.
              onPressed: workEntry.workStart == null || workEntry.workEnd != null
                  ? null // Deaktiviere Button, wenn Arbeit nicht läuft
                  : () {
                // ====== HIER IST DIE ÄNDERUNG ======
                // Rufe die neue ViewModel-Methode auf, die wir erstellt haben.
                ref.read(dashboardViewModelProvider.notifier).startOrStopBreak();
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Zeigt eine Warnung an, wenn die Pausen nicht den Anforderungen
  /// des Arbeitszeitgesetzes entsprechen.
  Widget _buildBreakComplianceWarning(BuildContext context) {
    // Nur prüfen, wenn Arbeit gestartet wurde
    if (workEntry.workStart == null) {
      return const SizedBox.shrink();
    }

    final compliance = BreakCalculatorService.validateBreakCompliance(workEntry);

    // Keine Warnung nötig, wenn Pausen ausreichend sind oder keine Pause erforderlich ist
    if (compliance.isCompliant || compliance.requiredBreakTime == Duration.zero) {
      return const SizedBox.shrink();
    }

    final missingMinutes = compliance.missingBreakTime.inMinutes;
    final requiredMinutes = compliance.requiredBreakTime.inMinutes;

    return Padding(
      padding: const EdgeInsets.only(top: 12.0),
      child: Container(
        padding: const EdgeInsets.all(12.0),
        decoration: BoxDecoration(
          color: Colors.orange.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.shade200),
        ),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Hinweis: Laut Arbeitszeitgesetz sind bei dieser Arbeitszeit mind. $requiredMinutes Min. Pause vorgeschrieben. Es fehlen noch $missingMinutes Min.',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.orange.shade900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}