import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers/providers.dart';
import '../../core/providers/subscription_provider.dart';
import '../../domain/entities/work_profile_entity.dart';
import '../../domain/utils/assistant_query.dart';
import '../../domain/utils/leave_balance_utils.dart';
import '../../l10n/app_localizations.dart';
import '../screens/login_page.dart';
import '../view_models/dashboard_view_model.dart';
import '../view_models/leave_balance_view_model.dart';
import 'common/paywall_launcher.dart';
import 'common/sheet_insets.dart';

/// Route des offenen Antwort-Sheets (höchstens eins zur Zeit).
Route<void>? _openRoute;

/// Zeigt die Antwort auf eine Sprachabfrage (#287) als Bottom Sheet. Ein
/// bereits offenes Antwort-Sheet wird vorher geschlossen.
Future<void> showAssistantQuerySheet(
    BuildContext context, AssistantQuery query) {
  dismissAssistantQuerySheet();
  // Wie `showModalBottomSheet`, aber mit Zugriff auf die Route (zum
  // Schließen von außen).
  final navigator = Navigator.of(context);
  final localizations = MaterialLocalizations.of(context);
  final route = ModalBottomSheetRoute<void>(
    builder: (_) => AssistantQuerySheet(query: query),
    capturedThemes:
        InheritedTheme.capture(from: context, to: navigator.context),
    isScrollControlled: true,
    useSafeArea: true,
    barrierLabel: localizations.scrimLabel,
    barrierOnTapHint:
        localizations.scrimOnTapHint(localizations.bottomSheetLabel),
    modalBarrierColor: Theme.of(context).bottomSheetTheme.modalBarrierColor,
  );
  _openRoute = route;
  return navigator.push(route).whenComplete(() {
    if (identical(_openRoute, route)) _openRoute = null;
  });
}

/// Schließt ein offenes Antwort-Sheet (z. B. bevor `main.dart` für eine
/// weitere Aktion von außen das Dashboard neu öffnet; sonst ersetzte
/// `pushReplacement` das Sheet statt des HomeScreens). Sonst ein No-op.
void dismissAssistantQuerySheet() {
  final route = _openRoute;
  _openRoute = null;
  if (route == null || !route.isActive) return;
  route.navigator?.removeRoute(route);
}

/// Formatiert die Gesamt-Überstunden wie das Dashboard (`+HH:MM`/`-HH:MM`,
/// vgl. `TotalOvertimeDisplay` und `DashboardScreen._formatOvertime`).
String formatOvertimeLikeDashboard(Duration overtime) {
  final isNegative = overtime.isNegative;
  final abs = overtime.abs();
  String twoDigits(int n) => n.toString().padLeft(2, '0');
  final hours = twoDigits(abs.inHours);
  final minutes = twoDigits(abs.inMinutes.remainder(60));
  return '${isNegative ? '-' : '+'}$hours:$minutes';
}

/// Antwort auf eine Sprachabfrage des Assistant (#287).
///
/// Zeigt nur vorhandene Werte an und verändert keine Daten:
/// - Überstunden: `DashboardState.totalOvertime` (gespeicherter Saldo plus
///   heutiger Tag), derselbe Wert wie im Dashboard.
/// - Resturlaub: verbleibende Tage und Anspruch aus
///   [leaveBalanceViewModelProvider] (laufendes Jahr).
///
/// Reihenfolge der Zustände: nicht angemeldet -> Hinweis auf Anmeldung;
/// ohne Premium -> Hinweis mit Paywall; sonst Laden/Fehler/Wert. Ist nicht das
/// Standard-Profil aktiv, nennt die Ansicht den Profilnamen. Der Inhalt ist
/// für TalkBack eine Live-Region (wird beim Erscheinen und bei Änderung
/// vorgelesen).
class AssistantQuerySheet extends ConsumerWidget {
  const AssistantQuerySheet({super.key, required this.query});

  final AssistantQuery query;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final user = ref.watch(authStateProvider).asData?.value;

    final title = switch (query) {
      AssistantQuery.overtime => l10n.overtimeTotalLabel,
      AssistantQuery.leave => l10n.remainingVacationTitle,
    };

    final Widget body;
    if (user == null) {
      body = _hint(
        context,
        text: l10n.assistantQueryLoginHint,
        buttonLabel: l10n.loginButton,
        icon: Icons.login,
        onPressed: () {
          final navigator = Navigator.of(context);
          navigator.pop();
          navigator.push(MaterialPageRoute(
              builder: (_) => const LoginPage(returnToIndex: 0)));
        },
      );
    } else if (!ref.watch(isPremiumProvider)) {
      body = _hint(
        context,
        text: l10n.assistantQueryPremiumHint,
        buttonLabel: l10n.unlockPremiumButton,
        icon: Icons.workspace_premium,
        // Auf Web gibt es keinen Kauf; der Assistant ist ohnehin nur Android.
        onPressed: kIsWeb ? null : () => showPaywall(context),
      );
    } else {
      body = switch (query) {
        AssistantQuery.overtime => const _OvertimeAnswer(),
        AssistantQuery.leave => const _LeaveAnswer(),
      };
    }

    final profileName = user == null ? null : _activeProfileName(ref);

    return Padding(
      padding: EdgeInsets.only(bottom: bottomSheetBottomInset(context)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        child: Semantics(
          container: true,
          liveRegion: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: theme.textTheme.titleLarge),
              if (profileName != null) ...[
                const SizedBox(height: 4),
                Text(
                  l10n.assistantQueryProfileLabel(profileName),
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ],
              const SizedBox(height: 16),
              body,
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child:
                      Text(MaterialLocalizations.of(context).closeButtonLabel),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Name des aktiven Profils, wenn es nicht das Standard-Profil ist. Solange
  /// die Profil-Liste lädt oder fehlschlägt, entfällt die Zeile.
  String? _activeProfileName(WidgetRef ref) {
    final activeId = ref.watch(activeWorkProfileIdProvider);
    if (activeId == null || activeId == WorkProfileEntity.defaultProfileId) {
      return null;
    }
    final profiles = ref.watch(workProfilesProvider).asData?.value;
    if (profiles == null) return null;
    for (final p in profiles) {
      if (p.id == activeId) return p.name;
    }
    return null;
  }

  Widget _hint(
    BuildContext context, {
    required String text,
    required String buttonLabel,
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(text, style: Theme.of(context).textTheme.bodyLarge),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: onPressed,
            icon: Icon(icon),
            label: Text(buttonLabel),
          ),
        ),
      ],
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(8),
          child: CircularProgressIndicator(),
        ),
      );
}

class _OvertimeAnswer extends ConsumerWidget {
  const _OvertimeAnswer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(dashboardViewModelProvider);
    final overtime = state.totalOvertime;
    if (overtime == null) {
      if (state.isLoading) return const _Loading();
      // Laden gescheitert: das Dashboard-ViewModel hat den Fehler bereits
      // geloggt (einen eigenen Ladepfad gibt es hier nicht).
      return Text(l10n.assistantQueryOvertimeError,
          style: theme.textTheme.bodyLarge
              ?.copyWith(color: theme.colorScheme.error));
    }
    return Text(
      formatOvertimeLikeDashboard(overtime),
      style: theme.textTheme.displaySmall?.copyWith(
        // Farben wie im Dashboard.
        color: overtime.isNegative ? Colors.red : Colors.green,
      ),
    );
  }
}

class _LeaveAnswer extends ConsumerWidget {
  const _LeaveAnswer();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final state = ref.watch(leaveBalanceViewModelProvider);
    final LeaveBalance? balance = state.balance;
    if (state.hasError && balance == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.leaveLoadError,
              style: theme.textTheme.bodyLarge
                  ?.copyWith(color: theme.colorScheme.error)),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () =>
                ref.read(leaveBalanceViewModelProvider.notifier).reload(),
            child: Text(l10n.leaveRetry),
          ),
        ],
      );
    }
    if (balance == null) return const _Loading();

    final over = balance.remaining < 0;
    final String headline;
    if (balance.entitlement <= 0 && balance.taken == 0) {
      headline = l10n.vacationEntitlementZero;
    } else if (over) {
      headline = l10n.vacationOverEntitlement(-balance.remaining);
    } else {
      headline =
          l10n.remainingVacationOf(balance.remaining, balance.entitlement);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          headline,
          style: theme.textTheme.headlineSmall
              ?.copyWith(color: over ? theme.colorScheme.error : null),
        ),
        const SizedBox(height: 4),
        Text(l10n.assistantQueryLeaveYear(balance.year),
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
