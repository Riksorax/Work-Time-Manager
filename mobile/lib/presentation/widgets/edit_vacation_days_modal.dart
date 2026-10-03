import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/utils/leave_balance_utils.dart';
import '../../l10n/app_localizations.dart';
import '../view_models/settings_view_model.dart';

void showEditVacationDaysModal(BuildContext context, int currentDays) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: EditVacationDaysModal(currentDays: currentDays),
    ),
  );
}

/// Bottom-Sheet zum Bearbeiten des Jahres-Urlaubsanspruchs (siehe #278).
class EditVacationDaysModal extends ConsumerStatefulWidget {
  final int currentDays;

  const EditVacationDaysModal({super.key, required this.currentDays});

  @override
  ConsumerState<EditVacationDaysModal> createState() =>
      _EditVacationDaysModalState();
}

class _EditVacationDaysModalState extends ConsumerState<EditVacationDaysModal> {
  late final TextEditingController _controller;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.currentDays.toString());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int? _parse(String? value) {
    final text = value?.trim() ?? '';
    final number = int.tryParse(text);
    if (number == null || number < 0 || number > maxVacationDaysPerYear) {
      return null;
    }
    return number;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final days = _parse(_controller.text);
    if (days == null) return;
    await ref
        .read(settingsViewModelProvider.notifier)
        .updateVacationDaysPerYear(days);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.editVacationEntitlementTitle,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _controller,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: l10n.vacationEntitlementFieldLabel,
                helperText: l10n.vacationEntitlementHint,
                helperMaxLines: 2,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => _parse(value) == null
                  ? l10n.vacationEntitlementInvalid
                  : null,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.cancel),
                ),
                const SizedBox(width: 8),
                ElevatedButton(
                  onPressed: _save,
                  child: Text(l10n.save),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
