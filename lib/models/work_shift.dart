// lib/models/work_shift.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ShiftChangeType
{
  none,
  modified,
  added,
  deleted
}

class WorkShift
{
  final int id;
  final DateTime date;
  final String dayName;
  final String departmentName;
  final String nodeName;
  final String hourCodeName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Duration breakDuration;
  final Duration totalDuration;

  // Velden voor het bijhouden van wijzigingen
  final ShiftChangeType changeType;
  final TimeOfDay? previousStartTime;
  final TimeOfDay? previousEndTime;
  final Duration? previousBreakDuration;
  final Duration? previousTotalDuration;
  final String? previousDepartmentName;

  WorkShift(
  {
    required this.id,
    required this.date,
    required this.dayName,
    required this.departmentName,
    required this.nodeName,
    required this.hourCodeName,
    required this.startTime,
    required this.endTime,
    required this.breakDuration,
    required this.totalDuration,
    this.changeType = ShiftChangeType.none,
    this.previousStartTime,
    this.previousEndTime,
    this.previousBreakDuration,
    this.previousTotalDuration,
    this.previousDepartmentName,
  });

  bool get isAdded => changeType == ShiftChangeType.added;
  bool get isModified => changeType == ShiftChangeType.modified;
  bool get isDeleted => changeType == ShiftChangeType.deleted;

  // Helper om veilig een integer te parsen uit diverse types.
  static int? _parseInt(dynamic v)
  {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is num) return v.toInt();
    print("Parse Int Error: Unexpected type ${v.runtimeType} for value $v");
    return null;
  }

  // Helper om veilig een nummer (num) te parsen uit diverse types.
  static num? _parseNum(dynamic v)
  {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    print("Parse Num Error: Unexpected type ${v.runtimeType} for value $v");
    return null;
  }

  // Factory constructor om een WorkShift te maken van JSON data.
  static WorkShift? fromJson(Map<String, dynamic> entry, DateTime date, Map<String, dynamic> nodes, Map<String, dynamic> depts, Map<String, dynamic> codes)
  {
    try
    {
      final int? entryId = _parseInt(entry['id']);
      final int? startMinutes = _parseInt(entry['startTime']);
      final int? endMinutes = _parseInt(entry['endTime']);
      final int? departmentId = _parseInt(entry['departmentId']);
      final String? nodeId = entry['nodeId'] as String?;
      final int? hourCodeId = _parseInt(entry['hourCodeId']);
      final num? breakNum = _parseNum(entry['breakTime']);
      final num? totalNum = _parseNum(entry['totalTime']);

      // Controleer of alle vereiste velden correct geparsed zijn
      if (entryId == null || startMinutes == null || endMinutes == null || departmentId == null || nodeId == null || hourCodeId == null)
      {
        print("WorkShift parse failed due to missing or invalid required fields: $entry");
        return null;
      }

      final String dayName = _getDayName(date.weekday);
      final TimeOfDay startTime = _minutesToTimeOfDay(startMinutes);
      final TimeOfDay endTime = _minutesToTimeOfDay(endMinutes);
      final Duration breakDuration = Duration(minutes: breakNum?.toInt() ?? 0);
      final Duration totalDuration = Duration(minutes: totalNum?.toInt() ?? 0);

      // Zoek namen op in de meegegeven maps, met fallbacks
      final String departmentName = depts[departmentId.toString()]?['name'] ?? 'Afd $departmentId?';
      final String nodeName = nodes[nodeId]?['name'] ?? 'Loc $nodeId?';
      final String hourCodeName = codes[hourCodeId.toString()]?['name'] ?? 'Type $hourCodeId?';

      return WorkShift(
        id: entryId,
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
    }
    catch (e, s)
    {
      print("WorkShift JSON parsing error: $e\nStacktrace: $s\nEntry data: $entry");
      return null;
    }
  }

  // Converteert minuten sinds middernacht naar TimeOfDay.
  static TimeOfDay _minutesToTimeOfDay(int minutes)
  {
    return TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
  }

  // Geeft de Nederlandse afkorting voor de dag van de week (1=Ma, 7=Zo).
  static String _getDayName(int weekday)
  {
    const days = ['Ma', 'Di', 'Wo', 'Do', 'Vr', 'Za', 'Zo'];
    if (weekday >= 1 && weekday <= 7)
    {
      return days[weekday - 1];
    }
    return '?'; // Fallback voor ongeldige weekday
  }

  // Formatteert een Duration naar HH:MM formaat.
  static String formatDuration(Duration duration)
  {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    // Gebruik abs() voor negatieve duraties indien nodig, hoewel hier onwaarschijnlijk.
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
    String twoDigitHours = twoDigits(duration.inHours.abs());
    return "$twoDigitHours:$twoDigitMinutes";
  }

  // Formatteert een TimeOfDay naar HH:MM formaat.
  static String formatTime(TimeOfDay time)
  {
    final String hour = time.hour.toString().padLeft(2, '0');
    final String minute = time.minute.toString().padLeft(2, '0');
    return "$hour:$minute";
  }

  // Getters die de static formatters gebruiken voor weergave.
  String get timeRangeDisplay => '${WorkShift.formatTime(startTime)} - ${WorkShift.formatTime(endTime)}';
  String get breakTimeDisplay => WorkShift.formatDuration(breakDuration);
  String get totalTimeDisplay => WorkShift.formatDuration(totalDuration);
  String get formattedDateShort => DateFormat('d MMM', 'nl_NL').format(date);

  // Maakt een kopie van deze shift met toegevoegde wijzigingsinformatie.
  WorkShift copyWithChangeInfo(
  {
    required ShiftChangeType changeType,
    WorkShift? previousShift,
  })
  {
    return WorkShift(
      id: id,
      date: date,
      dayName: dayName,
      departmentName: departmentName,
      nodeName: nodeName,
      hourCodeName: hourCodeName,
      startTime: startTime,
      endTime: endTime,
      breakDuration: breakDuration,
      totalDuration: totalDuration,
      changeType: changeType,
      previousStartTime: previousShift?.startTime,
      previousEndTime: previousShift?.endTime,
      previousBreakDuration: previousShift?.breakDuration,
      previousTotalDuration: previousShift?.totalDuration,
      previousDepartmentName: previousShift?.departmentName,
    );
  }

  // Geeft een unieke identifier voor deze shift instantie (gebaseerd op ID).
  String get uniqueIdentifier => id.toString();

  // Controleert of belangrijke velden zijn gewijzigd vergeleken met een andere shift.
  bool hasChangedComparedTo(WorkShift other)
  {
    return startTime != other.startTime ||
           endTime != other.endTime ||
           breakDuration != other.breakDuration ||
           totalDuration != other.totalDuration ||
           departmentName != other.departmentName ||
           hourCodeName != other.hourCodeName ||
           nodeName != other.nodeName;
  }
}