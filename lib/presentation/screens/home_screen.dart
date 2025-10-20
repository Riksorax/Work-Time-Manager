import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';
import 'package:flutter_work_time/presentation/screens/login_page.dart';
import 'package:flutter_work_time/presentation/view_models/auth_view_model.dart';

import '../../core/providers/providers.dart';
import '../widgets/update_required_dialog.dart';
import 'dashboard_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  final int initialIndex;
  const HomeScreen({this.initialIndex = 0, super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  late int _selectedIndex;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.initialIndex;

    // Version-Check beim Start der App
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkForUpdate();
    });
  }

  Future<void> _checkForUpdate() async {
    final versionService = ref.read(versionServiceProvider);
    if (mounted) {
      await UpdateRequiredDialog.checkAndShow(context, versionService);
    }
  }

  static const List<Widget> _widgetOptions = <Widget>[
    DashboardScreen(),
    ReportsPage(),
    SettingsPage(),
  ];

  void _onItemTapped(int index) {
    // Wenn Reports ausgewählt wird (Index 1) und der Benutzer nicht eingeloggt ist
    if (index == 1) {
      final authState = ref.read(authStateProvider);

      // Debug: Zeige Auth-State
      authState.when(
        data: (user) => print('[HomeScreen] Auth State: ${user != null ? 'Eingeloggt als ${user.email}' : 'NICHT eingeloggt'}'),
        loading: () => print('[HomeScreen] Auth State: Loading...'),
        error: (err, stack) => print('[HomeScreen] Auth State: Error - $err'),
      );

      // Prüfe ob der User nicht eingeloggt ist
      // AsyncValue.data mit value == null bedeutet: User ist NICHT eingeloggt
      // AsyncValue.loading oder error bedeutet: Noch am Laden, nicht blockieren
      final isNotLoggedIn = authState.maybeWhen(
        data: (user) => user == null,
        orElse: () => false, // Wenn loading/error, nicht blockieren
      );

      if (isNotLoggedIn) {
        print('[HomeScreen] Blockiere Zugriff auf Berichte - User nicht eingeloggt');
        // Zeige Login-Seite mit Hinweis
        _showLoginRequiredDialog();
        return;
      }

      print('[HomeScreen] Erlaube Zugriff auf Berichte');
    }

    setState(() {
      _selectedIndex = index;
    });
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anmeldung erforderlich'),
        content: const Text('Berichte sind nur für angemeldete Benutzer verfügbar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Abbrechen'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute(builder: (context) => const LoginPage(returnToReports: true)),
              );
            },
            child: const Text('Anmelden'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _widgetOptions.elementAt(_selectedIndex),
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart),
            label: 'Berichte',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Einstellungen',
          ),
        ],
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        type: BottomNavigationBarType.fixed,
      ),
    );
  }
}
