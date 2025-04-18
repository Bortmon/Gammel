// lib/models/work_shift.dart

import 'package:flutter/material.dart'; // Nodig voor TimeOfDay
import 'package:intl/intl.dart';      // Nodig voor DateFormat

class WorkShift {
  final DateTime date;
  final String dayName;
  final String departmentName;
  final String nodeName;
  final String hourCodeName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Duration breakDuration;
  final Duration totalDuration; // Duur zoals geretourneerd door API

  WorkShift({
    required this.date,
    required this.dayName,
    required this.departmentName,
    required this.nodeName,
    required this.hourCodeName,
    required this.startTime,
    required this.endTime,
    required this.breakDuration,
    required this.totalDuration,
  });

  static int? _parseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is String) return int.tryParse(value);
    if (value is num) return value.toInt();
    print("[WorkShift Parser] Unexpected type for int parsing: ${value.runtimeType}");
    return null;
  }

  static num? _parseNum(dynamic value) {
    if (value == null) return null;
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    print("[WorkShift Parser] Unexpected type for num parsing: ${value.runtimeType}");
    return null;
  }

  static WorkShift? fromJson(
    Map<String, dynamic> entryJson,
    DateTime date,
    Map<String, dynamic> nodesMap,
    Map<String, dynamic> departmentsMap,
    Map<String, dynamic> hourCodesMap,
  ) {
    try {
      final int? startTimeMinutes = _parseInt(entryJson['startTime']);
      final int? endTimeMinutes = _parseInt(entryJson['endTime']);
      final int? departmentId = _parseInt(entryJson['departmentId']);
      final String? nodeId = entryJson['nodeId'] as String?;
      final int? hourCodeId = _parseInt(entryJson['hourCodeId']);
      final num? breakTimeNum = _parseNum(entryJson['breakTime']);
      final num? totalTimeNum = _parseNum(entryJson['totalTime']);

      if (startTimeMinutes == null || endTimeMinutes == null || departmentId == null || nodeId == null || hourCodeId == null) {
        print("[WorkShift Parser] Failed to parse essential fields. Entry: $entryJson");
        return null;
      }

      final String dayName = _getDayName(date.weekday);
      final TimeOfDay startTime = _minutesToTimeOfDay(startTimeMinutes);
      final TimeOfDay endTime = _minutesToTimeOfDay(endTimeMinutes);
      final Duration breakDuration = Duration(minutes: breakTimeNum?.toInt() ?? 0);
      final Duration totalDuration = Duration(minutes: totalTimeNum?.toInt() ?? 0);

      final String departmentName = departmentsMap[departmentId.toString()]?['name'] ?? 'Afd. $departmentId?';
      final String nodeName = nodesMap[nodeId]?['name'] ?? 'Locatie $nodeId?';
      final String hourCodeName = hourCodesMap[hourCodeId.toString()]?['name'] ?? 'Type $hourCodeId?';

      return WorkShift(
        date: date,
        dayName: dayName,
        departmentName: departmentName,
        nodeName: nodeName,
        hourCodeName: hourCodeName,
        startTime: startTime,
        endTime: endTime,
        breakDuration: breakDuration,
        totalDuration: totalDuration,
      );
    } catch (e, s) {
      print("[WorkShift Parser] Unexpected Error: $e\nStack: $s\nEntry: $entryJson");
      return null;
    }
  }

  static TimeOfDay _minutesToTimeOfDay(int minutes) {
    final int hours = minutes ~/ 60;
    final int minute = minutes % 60;
    return TimeOfDay(hour: hours, minute: minute);
  }

  static String _getDayName(int weekday) {
    const days = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
    if (weekday >= 1 && weekday <= 7) {
      return days[weekday - 1];
    }
    return '?';
  }

  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes";
  }

  String _formatTime(TimeOfDay time) =>
      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";

  String get timeRangeDisplay => '${_formatTime(startTime)} - ${_formatTime(endTime)}';
  String get breakTimeDisplay => WorkShift.formatDuration(breakDuration);
  String get totalTimeDisplay => WorkShift.formatDuration(totalDuration);
  String get formattedDateShort => DateFormat('d MMM', 'nl_NL').format(date);
}