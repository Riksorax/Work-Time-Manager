import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/auth_view_model.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/common/error_display.dart';
import 'dashboard_page.dart';
import 'login_page.dart';

class AuthGate extends ConsumerWidget {
  const AuthGate({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      data: (user) {
        if (user != null) {
          return const DashboardPage();
        } else {
          return const LoginPage();
        }
      },
      loading: () => const Scaffold(body: LoadingIndicator()),
      error: (err, stack) =>
          Scaffold(body: ErrorDisplay(error: err.toString())),
    );
  }
}
