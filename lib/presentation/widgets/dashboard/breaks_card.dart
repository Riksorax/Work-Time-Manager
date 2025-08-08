import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../domain/entities/break_entity.dart';
import '../../../domain/entities/work_entry_entity.dart';
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
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: Icon(
                activeBreak != null ? Icons.start_outlined : Icons.stop_circle_outlined,
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
                ref.read(dashboardViewModelProvider.notifier).toggleBreak();
              },
            ),
          ],
        ),
      ),
    );
  }
}