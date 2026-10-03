import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clock_provider.g.dart';

/// Liefert die aktuelle Gerätezeit (lokal). Tests überschreiben den Provider
/// mit einer festen oder veränderbaren Uhr (siehe #279).
@riverpod
DateTime Function() clock(Ref ref) => DateTime.now;
