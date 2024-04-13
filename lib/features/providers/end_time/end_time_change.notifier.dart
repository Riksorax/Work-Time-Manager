import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'end_time_change.notifier.g.dart';

@riverpod
class EndTimeChangeNotifier extends _$EndTimeChangeNotifier {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setStartTimeChange(DateTime endTime){
    state = endTime;
  }
}