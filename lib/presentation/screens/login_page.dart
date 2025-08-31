import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../view_models/auth_view_model.dart';
import 'home_screen.dart';

class LoginPage extends ConsumerWidget {
  final bool returnToReports;
  const LoginPage({this.returnToReports = false, Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Anmelden'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.login), // Hier könnte ein Google-Icon stehen
              label: const Text('Mit Google anmelden'),
              onPressed: () async {
                // Rufe den Use Case über den Provider auf.
                await ref.read(signInWithGoogleProvider)();

                if (context.mounted) {
                  // Nach erfolgreicher Anmeldung zur Startseite oder Berichtsseite navigieren
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (context) => const HomeScreen(initialIndex: 1)),
                  );
                }
              },
            ),
            TextButton(
              child: const Text('Überspringen'),
              onPressed: () {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (context) => HomeScreen(
                    initialIndex: returnToReports ? 1 : 0,
                  )),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}