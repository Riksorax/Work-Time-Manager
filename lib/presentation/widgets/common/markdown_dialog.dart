import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:url_launcher/url_launcher.dart';

/// Ein wiederverwendbarer Dialog, der Markdown-Content aus Assets lädt und anzeigt.
class MarkdownDialog extends StatelessWidget {
  final String title;
  final String assetPath;

  const MarkdownDialog({
    super.key,
    required this.title,
    required this.assetPath,
  });

  static Future<void> show(BuildContext context, {required String title, required String assetPath}) {
    return showDialog(
      context: context,
      builder: (context) => MarkdownDialog(title: title, assetPath: assetPath),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 800),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: FutureBuilder<String>(
                future: rootBundle.loadString(assetPath),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  
                  if (snapshot.hasError) {
                    return Center(
                      child: Text(
                        'Fehler beim Laden: ${snapshot.error}',
                        style: const TextStyle(color: Colors.red),
                      ),
                    );
                  }

                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return const Center(child: Text('Kein Inhalt gefunden.'));
                  }

                  return Markdown(
                    data: snapshot.data!,
                    styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                      p: Theme.of(context).textTheme.bodyMedium?.copyWith(height: 1.5),
                      h1: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                        height: 2.0,
                      ),
                      h2: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                        height: 2.0,
                        decoration: TextDecoration.underline,
                        decorationColor: Theme.of(context).dividerColor,
                      ),
                      blockSpacing: 16.0,
                    ),
                    onTapLink: (text, href, title) async {
                      if (href != null) {
                        final uri = Uri.parse(href);
                        if (await canLaunchUrl(uri)) {
                          await launchUrl(uri, mode: LaunchMode.externalApplication);
                        }
                      }
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Schließen'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
