// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'clock_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Liefert die aktuelle Gerätezeit (lokal). Tests überschreiben den Provider
/// mit einer festen oder veränderbaren Uhr (siehe #279).

@ProviderFor(clock)
const clockProvider = ClockProvider._();

/// Liefert die aktuelle Gerätezeit (lokal). Tests überschreiben den Provider
/// mit einer festen oder veränderbaren Uhr (siehe #279).

final class ClockProvider extends $FunctionalProvider<
    DateTime Function(),
    DateTime Function(),
    DateTime Function()> with $Provider<DateTime Function()> {
  /// Liefert die aktuelle Gerätezeit (lokal). Tests überschreiben den Provider
  /// mit einer festen oder veränderbaren Uhr (siehe #279).
  const ClockProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'clockProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$clockHash();

  @$internal
  @override
  $ProviderElement<DateTime Function()> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  DateTime Function() create(Ref ref) {
    return clock(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(DateTime Function() value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<DateTime Function()>(value),
    );
  }
}

String _$clockHash() => r'3b571c5a0c08b7391c0eed04391003191bab6ccf';
