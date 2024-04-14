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

String _$saveStartTimeManualSharedPrefsHash() =>
    r'bf0cfdc95efbc651ea4dff8bd16317f722ae9fb0';

/// See also [saveStartTimeManualSharedPrefs].
@ProviderFor(saveStartTimeManualSharedPrefs)
const saveStartTimeManualSharedPrefsProvider =
    SaveStartTimeManualSharedPrefsFamily();

/// See also [saveStartTimeManualSharedPrefs].
class SaveStartTimeManualSharedPrefsFamily extends Family<AsyncValue<bool>> {
  /// See also [saveStartTimeManualSharedPrefs].
  const SaveStartTimeManualSharedPrefsFamily();

  /// See also [saveStartTimeManualSharedPrefs].
  SaveStartTimeManualSharedPrefsProvider call(
    String startTime,
    String timeManual,
  ) {
    return SaveStartTimeManualSharedPrefsProvider(
      startTime,
      timeManual,
    );
  }

  @override
  SaveStartTimeManualSharedPrefsProvider getProviderOverride(
    covariant SaveStartTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.startTime,
      provider.timeManual,
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
  String? get name => r'saveStartTimeManualSharedPrefsProvider';
}

/// See also [saveStartTimeManualSharedPrefs].
class SaveStartTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<bool> {
  /// See also [saveStartTimeManualSharedPrefs].
  SaveStartTimeManualSharedPrefsProvider(
    String startTime,
    String timeManual,
  ) : this._internal(
          (ref) => saveStartTimeManualSharedPrefs(
            ref as SaveStartTimeManualSharedPrefsRef,
            startTime,
            timeManual,
          ),
          from: saveStartTimeManualSharedPrefsProvider,
          name: r'saveStartTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveStartTimeManualSharedPrefsHash,
          dependencies: SaveStartTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              SaveStartTimeManualSharedPrefsFamily._allTransitiveDependencies,
          startTime: startTime,
          timeManual: timeManual,
        );

  SaveStartTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.startTime,
    required this.timeManual,
  }) : super.internal();

  final String startTime;
  final String timeManual;

  @override
  Override overrideWith(
    FutureOr<bool> Function(SaveStartTimeManualSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SaveStartTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as SaveStartTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        startTime: startTime,
        timeManual: timeManual,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _SaveStartTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveStartTimeManualSharedPrefsProvider &&
        other.startTime == startTime &&
        other.timeManual == timeManual;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, startTime.hashCode);
    hash = _SystemHash.combine(hash, timeManual.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveStartTimeManualSharedPrefsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `startTime` of this provider.
  String get startTime;

  /// The parameter `timeManual` of this provider.
  String get timeManual;
}

class _SaveStartTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with SaveStartTimeManualSharedPrefsRef {
  _SaveStartTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get startTime =>
      (origin as SaveStartTimeManualSharedPrefsProvider).startTime;
  @override
  String get timeManual =>
      (origin as SaveStartTimeManualSharedPrefsProvider).timeManual;
}

String _$getStartTimeManualSharedPrefsHash() =>
    r'bed446ddc11b162f05fb92da11817b60ce8bd921';

/// See also [getStartTimeManualSharedPrefs].
@ProviderFor(getStartTimeManualSharedPrefs)
const getStartTimeManualSharedPrefsProvider =
    GetStartTimeManualSharedPrefsFamily();

/// See also [getStartTimeManualSharedPrefs].
class GetStartTimeManualSharedPrefsFamily extends Family<AsyncValue<String?>> {
  /// See also [getStartTimeManualSharedPrefs].
  const GetStartTimeManualSharedPrefsFamily();

  /// See also [getStartTimeManualSharedPrefs].
  GetStartTimeManualSharedPrefsProvider call(
    String startTime,
  ) {
    return GetStartTimeManualSharedPrefsProvider(
      startTime,
    );
  }

  @override
  GetStartTimeManualSharedPrefsProvider getProviderOverride(
    covariant GetStartTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.startTime,
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
  String? get name => r'getStartTimeManualSharedPrefsProvider';
}

/// See also [getStartTimeManualSharedPrefs].
class GetStartTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<String?> {
  /// See also [getStartTimeManualSharedPrefs].
  GetStartTimeManualSharedPrefsProvider(
    String startTime,
  ) : this._internal(
          (ref) => getStartTimeManualSharedPrefs(
            ref as GetStartTimeManualSharedPrefsRef,
            startTime,
          ),
          from: getStartTimeManualSharedPrefsProvider,
          name: r'getStartTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getStartTimeManualSharedPrefsHash,
          dependencies: GetStartTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              GetStartTimeManualSharedPrefsFamily._allTransitiveDependencies,
          startTime: startTime,
        );

  GetStartTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.startTime,
  }) : super.internal();

  final String startTime;

  @override
  Override overrideWith(
    FutureOr<String?> Function(GetStartTimeManualSharedPrefsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetStartTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as GetStartTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        startTime: startTime,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _GetStartTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetStartTimeManualSharedPrefsProvider &&
        other.startTime == startTime;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, startTime.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GetStartTimeManualSharedPrefsRef
    on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `startTime` of this provider.
  String get startTime;
}

class _GetStartTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with GetStartTimeManualSharedPrefsRef {
  _GetStartTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get startTime =>
      (origin as GetStartTimeManualSharedPrefsProvider).startTime;
}

String _$saveBreakTimeManualSharedPrefsHash() =>
    r'01122f767c7ca0de8eb401f6333ecc502ef9c9ab';

/// See also [saveBreakTimeManualSharedPrefs].
@ProviderFor(saveBreakTimeManualSharedPrefs)
const saveBreakTimeManualSharedPrefsProvider =
    SaveBreakTimeManualSharedPrefsFamily();

/// See also [saveBreakTimeManualSharedPrefs].
class SaveBreakTimeManualSharedPrefsFamily extends Family<AsyncValue<bool>> {
  /// See also [saveBreakTimeManualSharedPrefs].
  const SaveBreakTimeManualSharedPrefsFamily();

  /// See also [saveBreakTimeManualSharedPrefs].
  SaveBreakTimeManualSharedPrefsProvider call(
    String breakTime,
    String timeManual,
  ) {
    return SaveBreakTimeManualSharedPrefsProvider(
      breakTime,
      timeManual,
    );
  }

  @override
  SaveBreakTimeManualSharedPrefsProvider getProviderOverride(
    covariant SaveBreakTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.breakTime,
      provider.timeManual,
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
  String? get name => r'saveBreakTimeManualSharedPrefsProvider';
}

/// See also [saveBreakTimeManualSharedPrefs].
class SaveBreakTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<bool> {
  /// See also [saveBreakTimeManualSharedPrefs].
  SaveBreakTimeManualSharedPrefsProvider(
    String breakTime,
    String timeManual,
  ) : this._internal(
          (ref) => saveBreakTimeManualSharedPrefs(
            ref as SaveBreakTimeManualSharedPrefsRef,
            breakTime,
            timeManual,
          ),
          from: saveBreakTimeManualSharedPrefsProvider,
          name: r'saveBreakTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveBreakTimeManualSharedPrefsHash,
          dependencies: SaveBreakTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              SaveBreakTimeManualSharedPrefsFamily._allTransitiveDependencies,
          breakTime: breakTime,
          timeManual: timeManual,
        );

  SaveBreakTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.breakTime,
    required this.timeManual,
  }) : super.internal();

  final String breakTime;
  final String timeManual;

  @override
  Override overrideWith(
    FutureOr<bool> Function(SaveBreakTimeManualSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SaveBreakTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as SaveBreakTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        breakTime: breakTime,
        timeManual: timeManual,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _SaveBreakTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveBreakTimeManualSharedPrefsProvider &&
        other.breakTime == breakTime &&
        other.timeManual == timeManual;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, breakTime.hashCode);
    hash = _SystemHash.combine(hash, timeManual.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveBreakTimeManualSharedPrefsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `breakTime` of this provider.
  String get breakTime;

  /// The parameter `timeManual` of this provider.
  String get timeManual;
}

class _SaveBreakTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with SaveBreakTimeManualSharedPrefsRef {
  _SaveBreakTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get breakTime =>
      (origin as SaveBreakTimeManualSharedPrefsProvider).breakTime;
  @override
  String get timeManual =>
      (origin as SaveBreakTimeManualSharedPrefsProvider).timeManual;
}

String _$getBreakTimeManualSharedPrefsHash() =>
    r'8999b4ab4ae7492fc7f3939c8d68f578fbdbeb56';

/// See also [getBreakTimeManualSharedPrefs].
@ProviderFor(getBreakTimeManualSharedPrefs)
const getBreakTimeManualSharedPrefsProvider =
    GetBreakTimeManualSharedPrefsFamily();

/// See also [getBreakTimeManualSharedPrefs].
class GetBreakTimeManualSharedPrefsFamily extends Family<AsyncValue<String?>> {
  /// See also [getBreakTimeManualSharedPrefs].
  const GetBreakTimeManualSharedPrefsFamily();

  /// See also [getBreakTimeManualSharedPrefs].
  GetBreakTimeManualSharedPrefsProvider call(
    String breakTime,
  ) {
    return GetBreakTimeManualSharedPrefsProvider(
      breakTime,
    );
  }

  @override
  GetBreakTimeManualSharedPrefsProvider getProviderOverride(
    covariant GetBreakTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.breakTime,
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
  String? get name => r'getBreakTimeManualSharedPrefsProvider';
}

/// See also [getBreakTimeManualSharedPrefs].
class GetBreakTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<String?> {
  /// See also [getBreakTimeManualSharedPrefs].
  GetBreakTimeManualSharedPrefsProvider(
    String breakTime,
  ) : this._internal(
          (ref) => getBreakTimeManualSharedPrefs(
            ref as GetBreakTimeManualSharedPrefsRef,
            breakTime,
          ),
          from: getBreakTimeManualSharedPrefsProvider,
          name: r'getBreakTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getBreakTimeManualSharedPrefsHash,
          dependencies: GetBreakTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              GetBreakTimeManualSharedPrefsFamily._allTransitiveDependencies,
          breakTime: breakTime,
        );

  GetBreakTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.breakTime,
  }) : super.internal();

  final String breakTime;

  @override
  Override overrideWith(
    FutureOr<String?> Function(GetBreakTimeManualSharedPrefsRef provider)
        create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetBreakTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as GetBreakTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        breakTime: breakTime,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _GetBreakTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetBreakTimeManualSharedPrefsProvider &&
        other.breakTime == breakTime;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, breakTime.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GetBreakTimeManualSharedPrefsRef
    on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `breakTime` of this provider.
  String get breakTime;
}

class _GetBreakTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with GetBreakTimeManualSharedPrefsRef {
  _GetBreakTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get breakTime =>
      (origin as GetBreakTimeManualSharedPrefsProvider).breakTime;
}

String _$saveWorkTimeManualSharedPrefsHash() =>
    r'7654e5db9d18c532b03fd2de2a363056d8101914';

/// See also [saveWorkTimeManualSharedPrefs].
@ProviderFor(saveWorkTimeManualSharedPrefs)
const saveWorkTimeManualSharedPrefsProvider =
    SaveWorkTimeManualSharedPrefsFamily();

/// See also [saveWorkTimeManualSharedPrefs].
class SaveWorkTimeManualSharedPrefsFamily extends Family<AsyncValue<bool>> {
  /// See also [saveWorkTimeManualSharedPrefs].
  const SaveWorkTimeManualSharedPrefsFamily();

  /// See also [saveWorkTimeManualSharedPrefs].
  SaveWorkTimeManualSharedPrefsProvider call(
    String workTime,
    String timeManual,
  ) {
    return SaveWorkTimeManualSharedPrefsProvider(
      workTime,
      timeManual,
    );
  }

  @override
  SaveWorkTimeManualSharedPrefsProvider getProviderOverride(
    covariant SaveWorkTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.workTime,
      provider.timeManual,
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
  String? get name => r'saveWorkTimeManualSharedPrefsProvider';
}

/// See also [saveWorkTimeManualSharedPrefs].
class SaveWorkTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<bool> {
  /// See also [saveWorkTimeManualSharedPrefs].
  SaveWorkTimeManualSharedPrefsProvider(
    String workTime,
    String timeManual,
  ) : this._internal(
          (ref) => saveWorkTimeManualSharedPrefs(
            ref as SaveWorkTimeManualSharedPrefsRef,
            workTime,
            timeManual,
          ),
          from: saveWorkTimeManualSharedPrefsProvider,
          name: r'saveWorkTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveWorkTimeManualSharedPrefsHash,
          dependencies: SaveWorkTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              SaveWorkTimeManualSharedPrefsFamily._allTransitiveDependencies,
          workTime: workTime,
          timeManual: timeManual,
        );

  SaveWorkTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.workTime,
    required this.timeManual,
  }) : super.internal();

  final String workTime;
  final String timeManual;

  @override
  Override overrideWith(
    FutureOr<bool> Function(SaveWorkTimeManualSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SaveWorkTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as SaveWorkTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        workTime: workTime,
        timeManual: timeManual,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _SaveWorkTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveWorkTimeManualSharedPrefsProvider &&
        other.workTime == workTime &&
        other.timeManual == timeManual;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, workTime.hashCode);
    hash = _SystemHash.combine(hash, timeManual.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveWorkTimeManualSharedPrefsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `workTime` of this provider.
  String get workTime;

  /// The parameter `timeManual` of this provider.
  String get timeManual;
}

class _SaveWorkTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with SaveWorkTimeManualSharedPrefsRef {
  _SaveWorkTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get workTime =>
      (origin as SaveWorkTimeManualSharedPrefsProvider).workTime;
  @override
  String get timeManual =>
      (origin as SaveWorkTimeManualSharedPrefsProvider).timeManual;
}

String _$getWorkTimeManualSharedPrefsHash() =>
    r'19734aff3d6a5abdfa28fbcda7fe9061f749e0dc';

/// See also [getWorkTimeManualSharedPrefs].
@ProviderFor(getWorkTimeManualSharedPrefs)
const getWorkTimeManualSharedPrefsProvider =
    GetWorkTimeManualSharedPrefsFamily();

/// See also [getWorkTimeManualSharedPrefs].
class GetWorkTimeManualSharedPrefsFamily extends Family<AsyncValue<String?>> {
  /// See also [getWorkTimeManualSharedPrefs].
  const GetWorkTimeManualSharedPrefsFamily();

  /// See also [getWorkTimeManualSharedPrefs].
  GetWorkTimeManualSharedPrefsProvider call(
    String workTime,
  ) {
    return GetWorkTimeManualSharedPrefsProvider(
      workTime,
    );
  }

  @override
  GetWorkTimeManualSharedPrefsProvider getProviderOverride(
    covariant GetWorkTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.workTime,
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
  String? get name => r'getWorkTimeManualSharedPrefsProvider';
}

/// See also [getWorkTimeManualSharedPrefs].
class GetWorkTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<String?> {
  /// See also [getWorkTimeManualSharedPrefs].
  GetWorkTimeManualSharedPrefsProvider(
    String workTime,
  ) : this._internal(
          (ref) => getWorkTimeManualSharedPrefs(
            ref as GetWorkTimeManualSharedPrefsRef,
            workTime,
          ),
          from: getWorkTimeManualSharedPrefsProvider,
          name: r'getWorkTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getWorkTimeManualSharedPrefsHash,
          dependencies: GetWorkTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              GetWorkTimeManualSharedPrefsFamily._allTransitiveDependencies,
          workTime: workTime,
        );

  GetWorkTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.workTime,
  }) : super.internal();

  final String workTime;

  @override
  Override overrideWith(
    FutureOr<String?> Function(GetWorkTimeManualSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetWorkTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as GetWorkTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        workTime: workTime,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _GetWorkTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetWorkTimeManualSharedPrefsProvider &&
        other.workTime == workTime;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, workTime.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GetWorkTimeManualSharedPrefsRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `workTime` of this provider.
  String get workTime;
}

class _GetWorkTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with GetWorkTimeManualSharedPrefsRef {
  _GetWorkTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get workTime =>
      (origin as GetWorkTimeManualSharedPrefsProvider).workTime;
}

String _$saveEndTimeManualSharedPrefsHash() =>
    r'2ab282643fc00d9c2f494302074fcf035b8c1376';

/// See also [saveEndTimeManualSharedPrefs].
@ProviderFor(saveEndTimeManualSharedPrefs)
const saveEndTimeManualSharedPrefsProvider =
    SaveEndTimeManualSharedPrefsFamily();

/// See also [saveEndTimeManualSharedPrefs].
class SaveEndTimeManualSharedPrefsFamily extends Family<AsyncValue<bool>> {
  /// See also [saveEndTimeManualSharedPrefs].
  const SaveEndTimeManualSharedPrefsFamily();

  /// See also [saveEndTimeManualSharedPrefs].
  SaveEndTimeManualSharedPrefsProvider call(
    String endTime,
    String timeManual,
  ) {
    return SaveEndTimeManualSharedPrefsProvider(
      endTime,
      timeManual,
    );
  }

  @override
  SaveEndTimeManualSharedPrefsProvider getProviderOverride(
    covariant SaveEndTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.endTime,
      provider.timeManual,
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
  String? get name => r'saveEndTimeManualSharedPrefsProvider';
}

/// See also [saveEndTimeManualSharedPrefs].
class SaveEndTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<bool> {
  /// See also [saveEndTimeManualSharedPrefs].
  SaveEndTimeManualSharedPrefsProvider(
    String endTime,
    String timeManual,
  ) : this._internal(
          (ref) => saveEndTimeManualSharedPrefs(
            ref as SaveEndTimeManualSharedPrefsRef,
            endTime,
            timeManual,
          ),
          from: saveEndTimeManualSharedPrefsProvider,
          name: r'saveEndTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$saveEndTimeManualSharedPrefsHash,
          dependencies: SaveEndTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              SaveEndTimeManualSharedPrefsFamily._allTransitiveDependencies,
          endTime: endTime,
          timeManual: timeManual,
        );

  SaveEndTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.endTime,
    required this.timeManual,
  }) : super.internal();

  final String endTime;
  final String timeManual;

  @override
  Override overrideWith(
    FutureOr<bool> Function(SaveEndTimeManualSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: SaveEndTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as SaveEndTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        endTime: endTime,
        timeManual: timeManual,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<bool> createElement() {
    return _SaveEndTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is SaveEndTimeManualSharedPrefsProvider &&
        other.endTime == endTime &&
        other.timeManual == timeManual;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, endTime.hashCode);
    hash = _SystemHash.combine(hash, timeManual.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin SaveEndTimeManualSharedPrefsRef on AutoDisposeFutureProviderRef<bool> {
  /// The parameter `endTime` of this provider.
  String get endTime;

  /// The parameter `timeManual` of this provider.
  String get timeManual;
}

class _SaveEndTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<bool>
    with SaveEndTimeManualSharedPrefsRef {
  _SaveEndTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get endTime =>
      (origin as SaveEndTimeManualSharedPrefsProvider).endTime;
  @override
  String get timeManual =>
      (origin as SaveEndTimeManualSharedPrefsProvider).timeManual;
}

String _$getEndTimeManualSharedPrefsHash() =>
    r'c77ba01e86da4ca8f0d1ef490b817c884dddb570';

/// See also [getEndTimeManualSharedPrefs].
@ProviderFor(getEndTimeManualSharedPrefs)
const getEndTimeManualSharedPrefsProvider = GetEndTimeManualSharedPrefsFamily();

/// See also [getEndTimeManualSharedPrefs].
class GetEndTimeManualSharedPrefsFamily extends Family<AsyncValue<String?>> {
  /// See also [getEndTimeManualSharedPrefs].
  const GetEndTimeManualSharedPrefsFamily();

  /// See also [getEndTimeManualSharedPrefs].
  GetEndTimeManualSharedPrefsProvider call(
    String endTime,
  ) {
    return GetEndTimeManualSharedPrefsProvider(
      endTime,
    );
  }

  @override
  GetEndTimeManualSharedPrefsProvider getProviderOverride(
    covariant GetEndTimeManualSharedPrefsProvider provider,
  ) {
    return call(
      provider.endTime,
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
  String? get name => r'getEndTimeManualSharedPrefsProvider';
}

/// See also [getEndTimeManualSharedPrefs].
class GetEndTimeManualSharedPrefsProvider
    extends AutoDisposeFutureProvider<String?> {
  /// See also [getEndTimeManualSharedPrefs].
  GetEndTimeManualSharedPrefsProvider(
    String endTime,
  ) : this._internal(
          (ref) => getEndTimeManualSharedPrefs(
            ref as GetEndTimeManualSharedPrefsRef,
            endTime,
          ),
          from: getEndTimeManualSharedPrefsProvider,
          name: r'getEndTimeManualSharedPrefsProvider',
          debugGetCreateSourceHash:
              const bool.fromEnvironment('dart.vm.product')
                  ? null
                  : _$getEndTimeManualSharedPrefsHash,
          dependencies: GetEndTimeManualSharedPrefsFamily._dependencies,
          allTransitiveDependencies:
              GetEndTimeManualSharedPrefsFamily._allTransitiveDependencies,
          endTime: endTime,
        );

  GetEndTimeManualSharedPrefsProvider._internal(
    super._createNotifier, {
    required super.name,
    required super.dependencies,
    required super.allTransitiveDependencies,
    required super.debugGetCreateSourceHash,
    required super.from,
    required this.endTime,
  }) : super.internal();

  final String endTime;

  @override
  Override overrideWith(
    FutureOr<String?> Function(GetEndTimeManualSharedPrefsRef provider) create,
  ) {
    return ProviderOverride(
      origin: this,
      override: GetEndTimeManualSharedPrefsProvider._internal(
        (ref) => create(ref as GetEndTimeManualSharedPrefsRef),
        from: from,
        name: null,
        dependencies: null,
        allTransitiveDependencies: null,
        debugGetCreateSourceHash: null,
        endTime: endTime,
      ),
    );
  }

  @override
  AutoDisposeFutureProviderElement<String?> createElement() {
    return _GetEndTimeManualSharedPrefsProviderElement(this);
  }

  @override
  bool operator ==(Object other) {
    return other is GetEndTimeManualSharedPrefsProvider &&
        other.endTime == endTime;
  }

  @override
  int get hashCode {
    var hash = _SystemHash.combine(0, runtimeType.hashCode);
    hash = _SystemHash.combine(hash, endTime.hashCode);

    return _SystemHash.finish(hash);
  }
}

mixin GetEndTimeManualSharedPrefsRef on AutoDisposeFutureProviderRef<String?> {
  /// The parameter `endTime` of this provider.
  String get endTime;
}

class _GetEndTimeManualSharedPrefsProviderElement
    extends AutoDisposeFutureProviderElement<String?>
    with GetEndTimeManualSharedPrefsRef {
  _GetEndTimeManualSharedPrefsProviderElement(super.provider);

  @override
  String get endTime => (origin as GetEndTimeManualSharedPrefsProvider).endTime;
}
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member
