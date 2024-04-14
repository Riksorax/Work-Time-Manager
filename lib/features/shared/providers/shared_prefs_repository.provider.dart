import 'package:flutter/material.dart';
import 'package:flutter_work_time/features/shared/data/repositories/shared_prefs_repositories.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'shared_prefs_repository.provider.g.dart';

@riverpod
Future<bool> saveThemeModeSharedPrefs(
        SaveThemeModeSharedPrefsRef ref, String themeMode, ThemeMode mode) =>
    SharedPrefsRepositories().setString(themeMode, mode.name);

@riverpod
Future<String?> getThemeModeSharedPrefs(
        GetThemeModeSharedPrefsRef ref, String themeMode) =>
    SharedPrefsRepositories().getString(themeMode);

@riverpod
Future<bool> saveStartTimeManualSharedPrefs(
    SaveStartTimeManualSharedPrefsRef ref,
    String startTime,
    String timeManual) async {
  return await SharedPrefsRepositories().setString(startTime, timeManual);
}

@riverpod
Future<String?> getStartTimeManualSharedPrefs(
    GetStartTimeManualSharedPrefsRef ref, String startTime) async {
  return await SharedPrefsRepositories().getString(startTime);
}

@riverpod
Future<bool> saveBreakTimeManualSharedPrefs(
    SaveBreakTimeManualSharedPrefsRef ref,
    String breakTime,
    String timeManual) async {
  return await SharedPrefsRepositories().setString(breakTime, timeManual);
}

@riverpod
Future<String?> getBreakTimeManualSharedPrefs(
    GetBreakTimeManualSharedPrefsRef ref, String breakTime) async {
  return await SharedPrefsRepositories().getString(breakTime);
}

@riverpod
Future<bool> saveWorkTimeManualSharedPrefs(SaveWorkTimeManualSharedPrefsRef ref,
    String workTime, String timeManual) async {
  return await SharedPrefsRepositories().setString(workTime, timeManual);
}

@riverpod
Future<String?> getWorkTimeManualSharedPrefs(
    GetWorkTimeManualSharedPrefsRef ref, String workTime) async {
  return await SharedPrefsRepositories().getString(workTime);
}

@riverpod
Future<bool> saveEndTimeManualSharedPrefs(SaveEndTimeManualSharedPrefsRef ref,
    String endTime, String timeManual) async {
  return await SharedPrefsRepositories().setString(endTime, timeManual);
}

@riverpod
Future<String?> getEndTimeManualSharedPrefs(
    GetEndTimeManualSharedPrefsRef ref, String endTime) async {
  return await SharedPrefsRepositories().getString(endTime);
}
