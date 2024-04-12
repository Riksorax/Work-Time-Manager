import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'start_time_change.notifier.g.dart';

@riverpod
class StartTimeChangeNotifier extends _$StartTimeChangeNotifier {
  @override
  DateTime build() {
    return DateTime.now();
  }

  void setStartTimeChange(DateTime startTime){
    state = startTime;
  }
}
