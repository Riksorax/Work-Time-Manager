import 'package:flutter/widgets.dart';

/// Globaler Navigator-Key (Navigation aus Benachrichtigungen, Dialoge aus dem
/// App-Sperre-Screen, der oberhalb des Navigators liegt - siehe #288).
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
