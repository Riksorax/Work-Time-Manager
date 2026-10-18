import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_work_time/core/services/app_lock_store.dart';

import '../../support/fake_app_lock_backend.dart';

void main() {
  late FakeAppLockBackend backend;
  late AppLockStore store;

  setUp(() {
    backend = FakeAppLockBackend();
    store = AppLockStore(backend);
  });

  test('liest synchron direkt nach dem Schreibaufruf (Cache zuerst)', () async {
    final hold = Completer<void>();
    backend.holdWrites = hold;

    final future = store.setInt('k', 7);
    expect(store.getInt('k'), 7, reason: 'Cache vor Abschluss des Backends');
    expect(backend.data, isEmpty);

    hold.complete();
    await future;
    expect(backend.data['k'], '7');
  });

  test('Typen: bool, int, String werden als String abgelegt', () async {
    await store.setBool('b', true);
    await store.setInt('i', 42);
    await store.setString('s', 'a:b');
    expect(backend.data, {'b': 'true', 'i': '42', 's': 'a:b'});
    expect(store.getBool('b'), isTrue);
    expect(store.getInt('i'), 42);
    expect(store.getString('s'), 'a:b');
  });

  test('fehlende Werte liefern null', () {
    expect(store.getBool('x'), isNull);
    expect(store.getInt('x'), isNull);
    expect(store.getString('x'), isNull);
  });

  test('kaputte Zahlen und Bools liefern null statt zu werfen', () {
    final s = AppLockStore(FakeAppLockBackend(),
        initial: {'i': 'abc', 'b': 'vielleicht'});
    expect(s.getInt('i'), isNull);
    expect(s.getBool('b'), isNull);
  });

  test('remove löscht Cache sofort und im Backend', () async {
    await store.setString('s', 'v');
    final future = store.remove('s');
    expect(store.getString('s'), isNull);
    await future;
    expect(backend.data, isEmpty);
    expect(backend.log.last, 'delete:s');
  });

  test('Schreibfehler ohne Rollback: Cache behält den neuen Wert', () async {
    backend.failAllWrites = true;
    await expectLater(store.setInt('k', 1), throwsStateError);
    expect(store.getInt('k'), 1);
  });

  test('Schreibfehler mit Rollback stellt den alten Wert wieder her', () async {
    await store.setString('k', 'alt');
    backend.failAllWrites = true;
    await expectLater(
        store.setString('k', 'neu', rollbackOnError: true), throwsStateError);
    expect(store.getString('k'), 'alt');
  });

  test('Rollback eines neuen Schlüssels entfernt ihn wieder', () async {
    backend.failAllWrites = true;
    await expectLater(
        store.setBool('k', true, rollbackOnError: true), throwsStateError);
    expect(store.getBool('k'), isNull);
  });

  test('Rollback beim Entfernen stellt den Wert wieder her', () async {
    await store.setString('k', 'wert');
    backend.failDeleteKeys.add('k');
    await expectLater(
        store.remove('k', rollbackOnError: true), throwsStateError);
    expect(store.getString('k'), 'wert');
  });

  test('Rollback überschreibt keinen zwischenzeitlich neueren Wert', () async {
    await store.setString('k', 'alt');
    final hold = Completer<void>();
    backend.holdWrites = hold;
    backend.failAllWrites = true;
    final first = store.setString('k', 'a', rollbackOnError: true);
    final firstExpectation = expectLater(first, throwsStateError);
    // zweiter Schreiber setzt den Cache neu, bevor der erste scheitert
    final second = store.setString('k', 'b').then((_) {}, onError: (_) {});
    hold.complete();
    await firstExpectation;
    await second;
    expect(store.getString('k'), 'b');
  });

  test('inMemory startet leer bzw. mit Startwerten', () async {
    expect(AppLockStore.inMemory().getString('x'), isNull);
    final s = AppLockStore.inMemory({'x': 'y'});
    expect(s.getString('x'), 'y');
    await s.setString('x', 'z');
    expect(s.getString('x'), 'z');
  });
}
