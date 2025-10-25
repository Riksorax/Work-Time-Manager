import 'package:flutter/material.dart';

/// Dialog zum Anzeigen der Allgemeinen Geschäftsbedingungen (AGB)
class TermsOfServiceDialog extends StatelessWidget {
  const TermsOfServiceDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          AppBar(
            title: const Text('Allgemeine Geschäftsbedingungen'),
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
                    '1. Geltungsbereich',
                    'Diese Allgemeinen Geschäftsbedingungen (AGB) gelten für die Nutzung der Work Time Manager App. '
                    'Mit der Nutzung der App akzeptieren Sie diese Bedingungen in vollem Umfang.',
                  ),
                  _buildSection(
                    '2. Leistungsumfang',
                    'Work Time Manager ist eine App zur Erfassung und Verwaltung von Arbeitszeiten. Die App bietet:\n\n'
                    '• Erfassung von Arbeitsbeginn und -ende\n'
                    '• Berechnung von Arbeitszeiten und Überstunden\n'
                    '• Verwaltung von Pausen\n'
                    '• Lokale oder Cloud-basierte Datenspeicherung\n'
                    '• Synchronisierung über mehrere Geräte (bei Anmeldung)',
                  ),
                  _buildSection(
                    '3. Nutzungsvoraussetzungen',
                    'Die Nutzung der App setzt voraus:\n\n'
                    '• Ein kompatibles Endgerät (Smartphone, Tablet)\n'
                    '• Für Cloud-Funktionen: Internetverbindung und Google-Konto\n'
                    '• Akzeptanz dieser AGB und der Datenschutzerklärung\n'
                    '• Sie müssen mindestens 16 Jahre alt sein',
                  ),
                  _buildSection(
                    '4. Nutzungsrechte',
                    'Die App wird Ihnen zur persönlichen, nicht-kommerziellen Nutzung zur Verfügung gestellt. '
                    'Sie erhalten ein einfaches, nicht übertragbares Nutzungsrecht. Folgende Handlungen sind untersagt:\n\n'
                    '• Reverse Engineering, Dekompilierung oder Disassemblierung\n'
                    '• Entfernung von Urheberrechtsvermerken\n'
                    '• Kommerzielle Weitergabe oder Vermietung\n'
                    '• Nutzung für rechtswidrige Zwecke',
                  ),
                  _buildSection(
                    '5. Registrierung und Account',
                    'Für die Cloud-Synchronisation ist eine Anmeldung mit einem Google-Konto erforderlich. '
                    'Sie sind verpflichtet:\n\n'
                    '• Wahrheitsgemäße Angaben zu machen\n'
                    '• Ihre Zugangsdaten geheim zu halten\n'
                    '• Uns unverzüglich über unbefugte Zugriffe zu informieren\n\n'
                    'Sie können Ihren Account jederzeit in den Einstellungen löschen.',
                  ),
                  _buildSection(
                    '6. Verfügbarkeit',
                    'Wir bemühen uns um eine hohe Verfügbarkeit der App und der Cloud-Services. '
                    'Es besteht jedoch kein Anspruch auf ununterbrochene Verfügbarkeit. '
                    'Wartungsarbeiten können zu vorübergehenden Einschränkungen führen.',
                  ),
                  _buildSection(
                    '7. Haftung',
                    'Die Nutzung der App erfolgt auf eigene Gefahr. Wir haften nur:\n\n'
                    '• Bei Vorsatz und grober Fahrlässigkeit\n'
                    '• Bei Verletzung wesentlicher Vertragspflichten\n'
                    '• Bei Schäden aus der Verletzung des Lebens, des Körpers oder der Gesundheit\n'
                    '• Im Rahmen einer übernommenen Garantie\n\n'
                    'Bei leichter Fahrlässigkeit ist die Haftung auf den vertragstypischen, vorhersehbaren Schaden begrenzt.',
                  ),
                  _buildSection(
                    '8. Datensicherung',
                    'Sie sind selbst für die Sicherung Ihrer Daten verantwortlich. Bei lokaler Speicherung empfehlen wir '
                    'regelmäßige Backups. Bei Cloud-Speicherung werden Ihre Daten automatisch gesichert, jedoch übernehmen '
                    'wir keine Garantie für die jederzeitige Wiederherstellbarkeit.',
                  ),
                  _buildSection(
                    '9. Änderungen der AGB',
                    'Wir behalten uns vor, diese AGB jederzeit zu ändern. Änderungen werden in der App bekannt gegeben. '
                    'Bei wesentlichen Änderungen werden Sie per E-Mail oder In-App-Benachrichtigung informiert. '
                    'Die weitere Nutzung nach Änderung gilt als Zustimmung.',
                  ),
                  _buildSection(
                    '10. Kündigung',
                    'Sie können die Nutzung der App jederzeit einstellen. Ihren Account können Sie in den Einstellungen '
                    'löschen. Wir behalten uns vor, Accounts bei Verstößen gegen diese AGB zu sperren oder zu löschen.',
                  ),
                  _buildSection(
                    '11. Schlussbestimmungen',
                    'Es gilt das Recht der Bundesrepublik Deutschland unter Ausschluss des UN-Kaufrechts. '
                    'Sollten einzelne Bestimmungen dieser AGB unwirksam sein, bleibt die Wirksamkeit der übrigen Bestimmungen unberührt.',
                  ),
                  _buildSection(
                    'Kontakt',
                    'Bei Fragen zu diesen AGB kontaktieren Sie uns bitte unter:\n\n[Ihre E-Mail-Adresse]',
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

  /// Zeigt den AGB-Dialog an
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const TermsOfServiceDialog(),
    );
  }
}
