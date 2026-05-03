import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_work_time/presentation/screens/reports_page.dart';
import 'package:flutter_work_time/presentation/screens/settings_page.dart';

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
    setState(() {
      _selectedIndex = index;
    });
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
