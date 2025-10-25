import 'package:flutter/material.dart';

/// Dialog zum Anzeigen der Datenschutzerklärung
class PrivacyPolicyDialog extends StatelessWidget {
  const PrivacyPolicyDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          AppBar(
            title: const Text('Datenschutzerklärung'),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSection(
                    'Einleitung',
                    'Wir nehmen den Schutz Ihrer persönlichen Daten ernst. Diese Datenschutzerklärung informiert Sie über die Verarbeitung personenbezogener Daten bei der Nutzung unserer Work Time Manager App.',
                  ),
                  _buildSection(
                    'Verantwortlicher',
                    'Verantwortlich für die Datenverarbeitung ist:\n\n[Ihr Name/Ihre Firma]\n[Adresse]\n[E-Mail]\n[Telefonnummer]',
                  ),
                  _buildSection(
                    'Welche Daten werden erhoben?',
                    'Bei der Nutzung der App werden folgende Daten verarbeitet:\n\n'
                    '• Arbeitszeiteinträge (Datum, Uhrzeit, Dauer)\n'
                    '• Überstundensaldo\n'
                    '• Persönliche Einstellungen (Soll-Arbeitszeit, Arbeitstage)\n'
                    '• Bei Anmeldung: Google-Kontoinformationen (Name, E-Mail, Profilbild)',
                  ),
                  _buildSection(
                    'Wie werden die Daten verwendet?',
                    'Die erhobenen Daten werden ausschließlich für folgende Zwecke verwendet:\n\n'
                    '• Erfassung und Verwaltung Ihrer Arbeitszeiten\n'
                    '• Berechnung von Überstunden und Berichten\n'
                    '• Synchronisierung Ihrer Daten über mehrere Geräte (bei Anmeldung)',
                  ),
                  _buildSection(
                    'Speicherung der Daten',
                    'Lokale Speicherung: Ohne Anmeldung werden alle Daten lokal auf Ihrem Gerät gespeichert.\n\n'
                    'Cloud-Speicherung: Bei Anmeldung mit Google werden Ihre Daten in Firebase (Google Cloud Platform) gespeichert. Die Datenübertragung erfolgt verschlüsselt.',
                  ),
                  _buildSection(
                    'Weitergabe von Daten',
                    'Ihre Daten werden nicht an Dritte weitergegeben, verkauft oder vermietet. Eine Weitergabe erfolgt nur:\n\n'
                    '• Bei gesetzlicher Verpflichtung\n'
                    '• Mit Ihrer ausdrücklichen Einwilligung',
                  ),
                  _buildSection(
                    'Ihre Rechte',
                    'Sie haben folgende Rechte bezüglich Ihrer Daten:\n\n'
                    '• Auskunft über gespeicherte Daten\n'
                    '• Berichtigung unrichtiger Daten\n'
                    '• Löschung Ihrer Daten\n'
                    '• Einschränkung der Verarbeitung\n'
                    '• Datenübertragbarkeit\n'
                    '• Widerspruch gegen die Verarbeitung',
                  ),
                  _buildSection(
                    'Account-Löschung',
                    'Sie können Ihren Account und alle zugehörigen Daten jederzeit in den Einstellungen der App löschen. Diese Aktion ist unwiderruflich.',
                  ),
                  _buildSection(
                    'Änderungen der Datenschutzerklärung',
                    'Wir behalten uns vor, diese Datenschutzerklärung anzupassen, um sie an geänderte Rechtslage oder bei Änderungen der App anzupassen.',
                  ),
                  _buildSection(
                    'Kontakt',
                    'Bei Fragen zum Datenschutz kontaktieren Sie uns bitte unter:\n\n[Ihre E-Mail-Adresse]',
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Stand: ${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          content,
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
      ],
    );
  }

  /// Zeigt den Datenschutz-Dialog an
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const PrivacyPolicyDialog(),
    );
  }
}
