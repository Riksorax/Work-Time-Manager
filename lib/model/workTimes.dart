import 'package:flutter/material.dart';

class WorkTimes {
  TimeOfDay defaultWorkTime;
  TimeOfDay defaultWorkTimeBreak;

  WorkTimes(
      {
        required this.defaultWorkTime,
        required this.defaultWorkTimeBreak,
      }
  );
}