import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/network_error.dart';
import '../../l10n/app_localizations.dart';
import '../utils/user_error_message.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common/load_failure_notice.dart';
import '../widgets/common/loading_indicator.dart';
import 'home_screen.dart';
import 'login_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Fehler des Anmeldestatus ins Log, ohne Ausnahmetext (#582).
    ref.listen(authStateProvider, (previous, next) {
      if (next is AsyncError && previous is! AsyncError) {
        logUserFacingError('[AuthGate] Anmeldestatus nicht ermittelt',
            next.error!, next.stackTrace);
      }
    });
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user != null) {
          return const HomeScreen();
        } else {
          return const LoginPage();
        }
      },
      loading: () => const Scaffold(body: LoadingIndicator()),
      // Verständlicher Hinweis statt des Ausnahmetexts (#582). „Erneut
      // versuchen“ fragt den Anmeldestatus neu ab, die Anmeldung bleibt
      // so nie dauerhaft blockiert.
      error: (err, stack) => Scaffold(
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: LoadFailureNotice(
                message: AppLocalizations.of(context).authStateLoadFailed,
                offline: isTransientNetworkError(err),
                onRetry: () => ref.invalidate(authStateProvider),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
