import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../view_models/auth_view_model.dart';
import '../view_models/dashboard_view_model.dart';
import '../widgets/common/error_display.dart';
import '../widgets/common/loading_indicator.dart';
import '../widgets/dashboard/timer_card.dart';

class DashboardPage extends ConsumerWidget {
  const DashboardPage({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dashboardState = ref.watch(dashboardViewModelProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Heutiger Arbeitstag'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => ref.read(signOutProvider)(),
          ),
        ],
      ),
      body: dashboardState.when(
        data: (workEntry) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Hier werden die spezialisierten Widgets verwendet
                TimerCard(workEntry: workEntry),
                const SizedBox(height: 16),
                // BreaksCard(workEntry: workEntry),
                // TimeSummaryCard(workEntry: workEntry),
              ],
            ),
          );
        },
        loading: () => const LoadingIndicator(),
        error: (err, stack) => ErrorDisplay(
          error: err.toString(),
          onRetry: () => ref.invalidate(dashboardViewModelProvider),
        ),
      ),
    );
  }
}
