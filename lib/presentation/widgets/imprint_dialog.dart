import 'package:flutter/material.dart';

/// Dialog zum Anzeigen des Impressums
class ImprintDialog extends StatelessWidget {
  const ImprintDialog({super.key});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Column(
        children: [
          AppBar(
            title: const Text('Impressum'),
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
                    'Angaben gemäß § 5 TMG',
                    '[Ihr Name / Firmenname]\n'
                    '[Straße und Hausnummer]\n'
                    '[PLZ Ort]\n'
                    '[Land]',
                  ),
                  _buildSection(
                    'Kontakt',
                    'Telefon: [Ihre Telefonnummer]\n'
                    'E-Mail: [Ihre E-Mail-Adresse]',
                  ),
                  _buildSection(
                    'Verantwortlich für den Inhalt',
                    'Verantwortlich für den Inhalt nach § 55 Abs. 2 RStV:\n\n'
                    '[Ihr Name]\n'
                    '[Straße und Hausnummer]\n'
                    '[PLZ Ort]',
                  ),
                  _buildSection(
                    'EU-Streitschlichtung',
                    'Die Europäische Kommission stellt eine Plattform zur Online-Streitbeilegung (OS) bereit: '
                    'https://ec.europa.eu/consumers/odr\n\n'
                    'Unsere E-Mail-Adresse finden Sie oben im Impressum.',
                  ),
                  _buildSection(
                    'Verbraucherstreitbeilegung / Universalschlichtungsstelle',
                    'Wir sind nicht bereit oder verpflichtet, an Streitbeilegungsverfahren vor einer '
                    'Verbraucherschlichtungsstelle teilzunehmen.',
                  ),
                  _buildSection(
                    'Haftung für Inhalte',
                    'Als Diensteanbieter sind wir gemäß § 7 Abs.1 TMG für eigene Inhalte auf diesen Seiten '
                    'nach den allgemeinen Gesetzen verantwortlich. Nach §§ 8 bis 10 TMG sind wir als Diensteanbieter '
                    'jedoch nicht verpflichtet, übermittelte oder gespeicherte fremde Informationen zu überwachen oder '
                    'nach Umständen zu forschen, die auf eine rechtswidrige Tätigkeit hinweisen.\n\n'
                    'Verpflichtungen zur Entfernung oder Sperrung der Nutzung von Informationen nach den allgemeinen '
                    'Gesetzen bleiben hiervon unberührt. Eine diesbezügliche Haftung ist jedoch erst ab dem Zeitpunkt '
                    'der Kenntnis einer konkreten Rechtsverletzung möglich. Bei Bekanntwerden von entsprechenden '
                    'Rechtsverletzungen werden wir diese Inhalte umgehend entfernen.',
                  ),
                  _buildSection(
                    'Haftung für Links',
                    'Unser Angebot enthält Links zu externen Websites Dritter, auf deren Inhalte wir keinen Einfluss haben. '
                    'Deshalb können wir für diese fremden Inhalte auch keine Gewähr übernehmen. Für die Inhalte der '
                    'verlinkten Seiten ist stets der jeweilige Anbieter oder Betreiber der Seiten verantwortlich. Die '
                    'verlinkten Seiten wurden zum Zeitpunkt der Verlinkung auf mögliche Rechtsverstöße überprüft. '
                    'Rechtswidrige Inhalte waren zum Zeitpunkt der Verlinkung nicht erkennbar.\n\n'
                    'Eine permanente inhaltliche Kontrolle der verlinkten Seiten ist jedoch ohne konkrete Anhaltspunkte '
                    'einer Rechtsverletzung nicht zumutbar. Bei Bekanntwerden von Rechtsverletzungen werden wir derartige '
                    'Links umgehend entfernen.',
                  ),
                  _buildSection(
                    'Urheberrecht',
                    'Die durch die Seitenbetreiber erstellten Inhalte und Werke auf diesen Seiten unterliegen dem '
                    'deutschen Urheberrecht. Die Vervielfältigung, Bearbeitung, Verbreitung und jede Art der Verwertung '
                    'außerhalb der Grenzen des Urheberrechtes bedürfen der schriftlichen Zustimmung des jeweiligen Autors '
                    'bzw. Erstellers. Downloads und Kopien dieser Seite sind nur für den privaten, nicht kommerziellen '
                    'Gebrauch gestattet.\n\n'
                    'Soweit die Inhalte auf dieser Seite nicht vom Betreiber erstellt wurden, werden die Urheberrechte '
                    'Dritter beachtet. Insbesondere werden Inhalte Dritter als solche gekennzeichnet. Sollten Sie trotzdem '
                    'auf eine Urheberrechtsverletzung aufmerksam werden, bitten wir um einen entsprechenden Hinweis. Bei '
                    'Bekanntwerden von Rechtsverletzungen werden wir derartige Inhalte umgehend entfernen.',
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 8),
                  Text(
                    'Quelle: erstellt mit dem Impressum-Generator von eRecht24.',
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      fontSize: 12,
                      color: Colors.grey,
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

  /// Zeigt den Impressums-Dialog an
  static void show(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => const ImprintDialog(),
    );
  }
}
