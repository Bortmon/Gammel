// lib/models/work_shift.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum ShiftChangeType { none, modified, added, deleted }

class WorkShift {
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

  final ShiftChangeType changeType;
  final TimeOfDay? previousStartTime;
  final TimeOfDay? previousEndTime;
  final Duration? previousBreakDuration;
  final Duration? previousTotalDuration;
  final String? previousDepartmentName;

  WorkShift({
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

  static int? _parseInt(dynamic v){if(v==null)return null;if(v is int)return v;if(v is String)return int.tryParse(v);if(v is num)return v.toInt();print("P Int Err:${v.runtimeType}");return null;}
  static num? _parseNum(dynamic v){if(v==null)return null;if(v is num)return v;if(v is String)return num.tryParse(v);print("P Num Err:${v.runtimeType}");return null;}

  static WorkShift? fromJson(Map<String,dynamic> entry, DateTime date, Map<String,dynamic> nodes, Map<String,dynamic> depts, Map<String,dynamic> codes) {
    try {
      final int? entryId=_parseInt(entry['id']);final int? sM=_parseInt(entry['startTime']); final int? eM=_parseInt(entry['endTime']); final int? dId=_parseInt(entry['departmentId']); final String? nId=entry['nodeId'] as String?; final int? cId=_parseInt(entry['hourCodeId']); final num? bN=_parseNum(entry['breakTime']); final num? tN=_parseNum(entry['totalTime']);
      if(entryId==null||sM==null||eM==null||dId==null||nId==null||cId==null){print("WorkShift parse fail: $entry"); return null;}
      final String dN=_getDayName(date.weekday); final TimeOfDay sT=_minutesToTimeOfDay(sM); final TimeOfDay eT=_minutesToTimeOfDay(eM); final Duration bD=Duration(minutes:bN?.toInt()??0); final Duration tD=Duration(minutes:tN?.toInt()??0);
      final String depN=depts[dId.toString()]?['name']??'Afd $dId?'; final String nodeN=nodes[nId]?['name']??'Loc $nId?'; final String codeN=codes[cId.toString()]?['name']??'Type $cId?';
      return WorkShift(id:entryId, date:date, dayName:dN, departmentName:depN, nodeName:nodeN, hourCodeName:codeN, startTime:sT, endTime:eT, breakDuration:bD, totalDuration:tD);
    } catch (e,s) { print("WorkShift Err: $e\n$s\n$entry"); return null; }
  }

  static TimeOfDay _minutesToTimeOfDay(int m) => TimeOfDay(hour: m~/60, minute: m%60);
  static String _getDayName(int wd) => (wd>=1&&wd<=7)?['Ma','Di','Wo','Do','Vr','Za','Zo'][wd-1]:'?';

  // --- Maak formatters static en public ---
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes";
  }
  static String formatTime(TimeOfDay time) =>
      "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  // ----------------------------------------

  // Gebruik de static formatters in getters
  String get timeRangeDisplay => '${WorkShift.formatTime(startTime)} - ${WorkShift.formatTime(endTime)}';
  String get breakTimeDisplay => WorkShift.formatDuration(breakDuration);
  String get totalTimeDisplay => WorkShift.formatDuration(totalDuration);
  String get formattedDateShort => DateFormat('d MMM', 'nl_NL').format(date);

  WorkShift copyWithChangeInfo({ required ShiftChangeType changeType, WorkShift? previousShift, }) {
    return WorkShift( id: id, date: date, dayName: dayName, departmentName: departmentName, nodeName: nodeName, hourCodeName: hourCodeName, startTime: startTime, endTime: endTime, breakDuration: breakDuration, totalDuration: totalDuration, changeType: changeType, previousStartTime: previousShift?.startTime, previousEndTime: previousShift?.endTime, previousBreakDuration: previousShift?.breakDuration, previousTotalDuration: previousShift?.totalDuration, previousDepartmentName: previousShift?.departmentName, );
  }

  String get uniqueIdentifier => id.toString();

  bool hasChangedComparedTo(WorkShift other) { return startTime != other.startTime || endTime != other.endTime || breakDuration != other.breakDuration || totalDuration != other.totalDuration || departmentName != other.departmentName || hourCodeName != other.hourCodeName || nodeName != other.nodeName; }
}