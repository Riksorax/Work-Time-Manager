// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'edit_work_entry_view_model.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(EditWorkEntryViewModel)
const editWorkEntryViewModelProvider = EditWorkEntryViewModelFamily._();

final class EditWorkEntryViewModelProvider
    extends $NotifierProvider<EditWorkEntryViewModel, EditWorkEntryState> {
  const EditWorkEntryViewModelProvider._(
      {required EditWorkEntryViewModelFamily super.from,
      required WorkEntryEntity super.argument})
      : super(
          retry: null,
          name: r'editWorkEntryViewModelProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$editWorkEntryViewModelHash();

  @override
  String toString() {
    return r'editWorkEntryViewModelProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  EditWorkEntryViewModel create() => EditWorkEntryViewModel();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EditWorkEntryState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EditWorkEntryState>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is EditWorkEntryViewModelProvider &&
        other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$editWorkEntryViewModelHash() =>
    r'90500f2efe699f69994080682ea6ac33a70e0def';

final class EditWorkEntryViewModelFamily extends $Family
    with
        $ClassFamilyOverride<EditWorkEntryViewModel, EditWorkEntryState,
            EditWorkEntryState, EditWorkEntryState, WorkEntryEntity> {
  const EditWorkEntryViewModelFamily._()
      : super(
          retry: null,
          name: r'editWorkEntryViewModelProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  EditWorkEntryViewModelProvider call(
    WorkEntryEntity entry,
  ) =>
      EditWorkEntryViewModelProvider._(argument: entry, from: this);

  @override
  String toString() => r'editWorkEntryViewModelProvider';
}

abstract class _$EditWorkEntryViewModel extends $Notifier<EditWorkEntryState> {
  late final _$args = ref.$arg as WorkEntryEntity;
  WorkEntryEntity get entry => _$args;

  EditWorkEntryState build(
    WorkEntryEntity entry,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<EditWorkEntryState, EditWorkEntryState>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<EditWorkEntryState, EditWorkEntryState>,
        EditWorkEntryState,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
