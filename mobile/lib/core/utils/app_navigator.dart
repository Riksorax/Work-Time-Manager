import 'package:flutter/widgets.dart';

/// Globaler Navigator-Key (Navigation aus Benachrichtigungen). Nicht für
/// Dialoge der App-Sperre: sie hat einen eigenen Navigator (siehe #450).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
