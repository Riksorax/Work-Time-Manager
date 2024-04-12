// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'shared_prefs_repository.provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$saveThemeModeSharedPrefsHash() =>
    r'8616ed6bdde1a9a36b0362a26858f0d586ffee0a';

/// Copied from Dart SDK
class _SystemHash {
  _SystemHash._();

  static int combine(int hash, int value) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + value);
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x0007ffff & hash) << 10));
    return hash ^ (hash >> 6);
  }

  static int finish(int hash) {
    // ignore: parameter_assignments
    hash = 0x1fffffff & (hash + ((0x03ffffff & hash) << 3));
    // ignore: parameter_assignments
    hash = hash ^ (hash >> 11);
    return 0x1fffffff & (hash + ((0x00003fff & hash) << 15));
  }
}

/// See also [saveThemeModeSharedPrefs].
@ProviderFor(saveThemeModeSharedPrefs)
const saveThemeModeSharedPrefsProvider = SaveThemeModeSharedPrefsFamily();

/// See also [saveThemeModeSharedPrefs].
class SaveThemeModeSharedPrefsFamily extends Family<AsyncValue<bool>> {
  /// See also [saveThemeModeSharedPrefs].
  const SaveThemeModeSharedPrefsFamily();

  /// See also [saveThemeModeSharedPrefs].
  SaveThemeModeSharedPrefsProvider call(
    String themeMode,
    ThemeMode mode,
  ) {
    return SaveThemeModeSharedPrefsProvider(
      themeMode,
      mode,
    );
  }

  @override
  SaveThemeModeSharedPrefsProvider getProviderOverride(
    covariant SaveThemeModeSharedPrefsProvider provider,
  ) {
    return call(
      provider.themeMode,
      provider.mode,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'saveThemeModeSharedPrefsProvider';
}

/// See also [saveThemeModeSharedPrefs].
class SaveThemeModeSharedPrefsProvider extends AutoDisposeFutureProvider<bool> {
  /// See also [saveThemeModeSharedPrefs].
  SaveThemeModeSharedPrefsProvider(
    String themeMode,
    ThemeMode mode,
  ) : this._internal(
          (ref) => saveThemeModeSharedPrefs(
            ref as SaveThemeModeSharedPrefsRef,
            themeMode,
            mode,
          ),
          from: saveThemeModeSharedPrefsProvider,
          name: r'saveThemeModeSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveThemeModeSharedPrefsHash,
          dependencies: SaveThemeModeSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              SaveThemeModeSharedPrefsFamily._allTransitiveDependencies,
          themeMode: themeMode,
          mode: mode,
        );

  SaveThemeModeSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.themeMode,
    required this.mode,
  }) : super.internal();

  final String themeMode;
  final ThemeMode mode;

  @override
  Override overrideWith(
    FutureOr<bool> Function(SaveThemeModeSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SaveThemeModeSharedPrefsProvider._internal(
        (ref) => create(ref as SaveThemeModeSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        themeMode: themeMode,
        mode: mode,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _SaveThemeModeSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveThemeModeSharedPrefsProvider &&
        other.themeMode == themeMode &&
        other.mode == mode;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, themeMode.hashCode);
    hash = _SystemHash.combine(hash, mode.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveThemeModeSharedPrefsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `themeMode` of this provider.
  String get themeMode;

  /// The parameter `mode` of this provider.
  ThemeMode get mode;
}

class _SaveThemeModeSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with SaveThemeModeSharedPrefsRef {
  _SaveThemeModeSharedPrefsProviderElement(super.provider);

  @override
  String get themeMode =>
      (origin as SaveThemeModeSharedPrefsProvider).themeMode;
  @override
  ThemeMode get mode => (origin as SaveThemeModeSharedPrefsProvider).mode;
}

String _$getThemeModeSharedPrefsHash() =>
    r'ff1f8b00c1e62732126bc0b48e2d1253b5845747';

/// See also [getThemeModeSharedPrefs].
@ProviderFor(getThemeModeSharedPrefs)
const getThemeModeSharedPrefsProvider = GetThemeModeSharedPrefsFamily();

/// See also [getThemeModeSharedPrefs].
class GetThemeModeSharedPrefsFamily extends Family<AsyncValue<String?>> {
  /// See also [getThemeModeSharedPrefs].
  const GetThemeModeSharedPrefsFamily();

  /// See also [getThemeModeSharedPrefs].
  GetThemeModeSharedPrefsProvider call(
    String themeMode,
  ) {
    return GetThemeModeSharedPrefsProvider(
      themeMode,
    );
  }

  @override
  GetThemeModeSharedPrefsProvider getProviderOverride(
    covariant GetThemeModeSharedPrefsProvider provider,
  ) {
    return call(
      provider.themeMode,
    );
  }

  static const Iterable<ProviderOrFamily>? _dependencies = null;

  @override
  Iterable<ProviderOrFamily>? get dependencies => _dependencies;

  static const Iterable<ProviderOrFamily>? _allTransitiveDependencies = null;

  @override
  Iterable<ProviderOrFamily>? get allTransitiveDependencies =>
      _allTransitiveDependencies;

  @override
  String? get name => r'getThemeModeSharedPrefsProvider';
}

/// See also [getThemeModeSharedPrefs].
class GetThemeModeSharedPrefsProvider
    extends AutoDisposeFutureProvider<String?> {
  /// See also [getThemeModeSharedPrefs].
  GetThemeModeSharedPrefsProvider(
    String themeMode,
  ) : this._internal(
          (ref) => getThemeModeSharedPrefs(
            ref as GetThemeModeSharedPrefsRef,
            themeMode,
          ),
          from: getThemeModeSharedPrefsProvider,
          name: r'getThemeModeSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getThemeModeSharedPrefsHash,
          dependencies: GetThemeModeSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              GetThemeModeSharedPrefsFamily._allTransitiveDependencies,
          themeMode: themeMode,
        );

  GetThemeModeSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.themeMode,
  }) : super.internal();

  final String themeMode;

  @override
  Override overrideWith(
    FutureOr<String?> Function(GetThemeModeSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetThemeModeSharedPrefsProvider._internal(
        (ref) => create(ref as GetThemeModeSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        themeMode: themeMode,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _GetThemeModeSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetThemeModeSharedPrefsProvider &&
        other.themeMode == themeMode;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, themeMode.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GetThemeModeSharedPrefsRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `themeMode` of this provider.
  String get themeMode;
}

class _GetThemeModeSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with GetThemeModeSharedPrefsRef {
  _GetThemeModeSharedPrefsProviderElement(super.provider);

  @override
  String get themeMode => (origin as GetThemeModeSharedPrefsProvider).themeMode;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
