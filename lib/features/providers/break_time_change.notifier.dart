import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'break_time_change.notifier.g.dart';

@riverpod
class BreakTimeChangeNotifier extends _$BreakTimeChangeNotifier {
  @override
  DateTime build() {
    return DateTime.now().add(const Duration(hours: 00 ,minutes: 30));
  }

  void setStartTimeChange(DateTime breakTime){
    state = breakTime;
  }
}