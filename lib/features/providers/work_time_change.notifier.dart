import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'work_time_change.notifier.g.dart';

@riverpod
class WorkTimeChangeNotifier extends _$WorkTimeChangeNotifier {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setStartTimeChange(DateTime workTime){
    state = workTime;
  }
}