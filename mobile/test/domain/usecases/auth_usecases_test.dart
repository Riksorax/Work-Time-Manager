import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:flutter_work_time/domain/repositories/auth_repository.dart';
import 'package:flutter_work_time/domain/usecases/delete_account.dart';
import 'package:flutter_work_time/domain/usecases/reauthenticate.dart';
import 'package:flutter_work_time/domain/usecases/sign_in_with_google.dart';
import 'package:flutter_work_time/domain/usecases/sign_out.dart';

import 'auth_usecases_test.mocks.dart';

@GenerateMocks([AuthRepository])
void main() {
  late MockAuthRepository mockAuthRepository;
  late SignInWithGoogle signInWithGoogle;
  late SignOut signOut;
  late DeleteAccount deleteAccount;
  late Reauthenticate reauthenticate;

  setUp(() {
    mockAuthRepository = MockAuthRepository();
    signInWithGoogle = SignInWithGoogle(mockAuthRepository);
    signOut = SignOut(mockAuthRepository);
    deleteAccount = DeleteAccount(mockAuthRepository);
    reauthenticate = Reauthenticate(mockAuthRepository);
  });

  group('AuthUseCases', () {
    test('SignInWithGoogle should call repository', () async {
      when(mockAuthRepository.signInWithGoogle()).thenAnswer((_) async {});

      await signInWithGoogle();

      verify(mockAuthRepository.signInWithGoogle()).called(1);
    });

    test('SignOut should call repository', () async {
      when(mockAuthRepository.signOut()).thenAnswer((_) async {});

      await signOut();

      verify(mockAuthRepository.signOut()).called(1);
    });

    test('DeleteAccount should call repository', () async {
      when(mockAuthRepository.deleteAccount()).thenAnswer((_) async {});

      await deleteAccount();

      verify(mockAuthRepository.deleteAccount()).called(1);
    });

    test('Reauthenticate reicht true/false des Repositories durch', () async {
      when(mockAuthRepository.reauthenticate()).thenAnswer((_) async => true);
      expect(await reauthenticate(), isTrue);
      when(mockAuthRepository.reauthenticate()).thenAnswer((_) async => false);
      expect(await reauthenticate(), isFalse);
      verify(mockAuthRepository.reauthenticate()).called(2);
    });
  });
}
