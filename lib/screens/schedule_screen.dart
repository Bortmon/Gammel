// lib/screens/schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/login_result.dart';
import '../models/work_shift.dart';

class ScheduleScreen extends StatefulWidget {
  final String? authToken;
  final bool isLoggedIn;
  final String? employeeId;
  final String? nodeId;
  final String? userName; // <-- Nieuwe parameter
  final Future<LoginResult> Function(BuildContext context) loginCallback;
  final Future<void> Function() logoutCallback;

  const ScheduleScreen({
    super.key,
    required this.authToken,
    required this.isLoggedIn,
    required this.employeeId,
    required this.nodeId,
    required this.userName, // <-- Vereist maken
    required this.loginCallback,
    required this.logoutCallback,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<WorkShift> _shifts = [];
  bool _isLoading = false;
  bool _isCheckingFuture = false;
  String? _error;
  int _currentYear = DateTime.now().year;
  int _currentWeek = _isoWeekNumber(DateTime.now());
  String? _localAuthToken;
  String? _localEmployeeId;
  String? _localNodeId;
  String? _localUserName; // <-- Lokale state voor naam
  Duration _totalWeekDuration = Duration.zero;
  Duration _totalBreakDuration = Duration.zero;

  final String _apiBaseUrl = 'https://server.manus.plus/intergamma/api/node/';
  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';
  final int _numberOfFutureWeeksToCheck = 4;

  @override
  void initState() {
    super.initState();
    // Initialiseer lokale state met widget props
    _localAuthToken = widget.authToken;
    _localEmployeeId = widget.employeeId;
    _localNodeId = widget.nodeId;
    _localUserName = widget.userName; // <-- Initialiseer lokale naam

    if (_localAuthToken != null && _localEmployeeId != null && _localNodeId != null) {
      _fetchSchedule();
      _checkFutureWeeks();
    }
  }

  static int _isoWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D", "en_US").format(date));
    int woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) { woy = _isoWeekNumber(DateTime(date.year - 1, 12, 31)); }
    else if (woy == 53 && DateTime(date.year, 1, 1).weekday != DateTime.thursday && DateTime(date.year, 12, 31).weekday != DateTime.thursday) { woy = 1; }
    return woy;
  }

  Future<void> _promptLoginAndFetch() async {
    if (_isLoading || !mounted) return;
    setState(() { _isLoading = true; _error = null; });
    final LoginResult res = await widget.loginCallback(context);
    if (!mounted) return;
    if (res.success && res.employeeId != null && res.nodeId != null && res.authToken != null) {
      print("[Schedule] Login OK. Storing locally & Fetching...");
      // Update lokale state (naam wordt in MyApp al geupdate en doorgegeven bij volgende build)
      setState(() {
        _localAuthToken = res.authToken;
        _localEmployeeId = res.employeeId;
        _localNodeId = res.nodeId;
        // Wacht met _localUserName updaten tot de widget herbouwd is met nieuwe props
        _isLoading = true;
        _error = null;
      });
      // Wacht kort op potentiële state update in parent voordat fetch start
      await Future.delayed(Duration(milliseconds: 50));
      if(mounted) {
         _localUserName = widget.userName; // Update lokale naam met mogelijk nieuwe prop
         await _fetchSchedule();
         _checkFutureWeeks();
      }
    } else {
      print("[Schedule] Login Fail/Cancel: ${res.errorMessage}");
      setState(() { _error = res.errorMessage ?? "Login mislukt."; _isLoading = false; });
    }
  }

  String _buildScheduleUrl(String nId, String eId, int yr, int wk) =>
      '$_apiBaseUrl$nId/employee/$eId/schedule/$yr/$wk/fromData';

  void _calculateWeeklyTotals() {
    Duration weekTotal = Duration.zero; Duration breakTotal = Duration.zero;
    for (var shift in _shifts) { if (!shift.isDeleted) { weekTotal += shift.totalDuration; breakTotal += shift.breakDuration; } }
    if (mounted && (_totalWeekDuration != weekTotal || _totalBreakDuration != breakTotal)) { setState(() { _totalWeekDuration = weekTotal; _totalBreakDuration = breakTotal; }); }
  }

  List<WorkShift> _parseShiftsFromData(dynamic scheduleData, Map<String, dynamic> nodes, Map<String, dynamic> depts, Map<String, dynamic> codes) {
      final List<WorkShift> parsedList = []; final days = scheduleData['schedule'] as List<dynamic>?;
      if (days != null) { for (var day in days) { if (day is Map<String, dynamic>) { final String? ds = day['date'] as String?; DateTime? pDate = ds != null ? DateTime.tryParse(ds) : null; final List<dynamic>? entries = day['entries'] as List<dynamic>?; if(pDate != null && entries != null) { for (var entry in entries) { if (entry is Map<String, dynamic>) { final shift = WorkShift.fromJson(entry, pDate, nodes, depts, codes); if (shift != null) parsedList.add(shift); } } } else if (pDate == null) { print("[Parse] Skip day, date err: ${day['date']}");} } } }
      return parsedList;
  }

  (List<WorkShift>, bool) _compareAndMergeSchedules(List<WorkShift> oldShifts, List<WorkShift> newShifts) {
    final List<WorkShift> mergedList = []; final Map<String, WorkShift> oldShiftMap = { for (var s in oldShifts) s.uniqueIdentifier : s }; bool changesFound = false;
    for (var newShift in newShifts) { final oldShift = oldShiftMap[newShift.uniqueIdentifier]; if (oldShift != null) { if (newShift.hasChangedComparedTo(oldShift)) { print("[Compare] Shift changed: ${newShift.uniqueIdentifier}"); mergedList.add(newShift.copyWithChangeInfo(changeType: ShiftChangeType.modified, previousShift: oldShift)); changesFound = true; } else { mergedList.add(newShift); } oldShiftMap.remove(newShift.uniqueIdentifier); } else { print("[Compare] Shift added: ${newShift.uniqueIdentifier}"); mergedList.add(newShift.copyWithChangeInfo(changeType: ShiftChangeType.added)); changesFound = true; } }
    if (oldShiftMap.isNotEmpty) { print("[Compare] Shifts deleted: ${oldShiftMap.keys}"); changesFound = true; mergedList.addAll(oldShiftMap.values.map((s) => s.copyWithChangeInfo(changeType: ShiftChangeType.deleted))); }
    mergedList.sort((a, b) { int d=a.date.compareTo(b.date); if(d!=0)return d; int h=a.startTime.hour.compareTo(b.startTime.hour); if(h!=0)return h; return a.startTime.minute.compareTo(b.startTime.minute);});
    return (mergedList, changesFound);
  }

  void _showChangeNotification(String message) {
     if (!mounted) return;
     ScaffoldMessenger.of(context).hideCurrentSnackBar();
     ScaffoldMessenger.of(context).showSnackBar(
        SnackBar( content: Text(message), backgroundColor: Colors.orange[800], duration: const Duration(seconds: 5), action: SnackBarAction( label: 'OK', textColor: Colors.white, onPressed: () => ScaffoldMessenger.of(context).hideCurrentSnackBar(),),),
     );
  }

  Future<void> _checkFutureWeeks() async {
    if (_localEmployeeId == null || _localNodeId == null || _localAuthToken == null || _isCheckingFuture) return;
    setState(() { _isCheckingFuture = true; }); print("[Schedule Check] Starting check for future weeks...");
    List<Future<bool>> futureChecks = []; DateTime firstDayOfCurrentWeek = DateTime.utc(_currentYear).add(Duration(days: (_currentWeek - 1) * 7)); firstDayOfCurrentWeek = firstDayOfCurrentWeek.subtract(Duration(days: firstDayOfCurrentWeek.weekday - 1));
    for (int i = 1; i <= _numberOfFutureWeeksToCheck; i++) {
      DateTime firstDayOfFutureWeek = firstDayOfCurrentWeek.add(Duration(days: i * 7)); int futureWeek = _isoWeekNumber(firstDayOfFutureWeek); int futureYear = firstDayOfFutureWeek.year; String url = _buildScheduleUrl(_localNodeId!, _localEmployeeId!, futureYear, futureWeek);
      futureChecks.add( _executeFetch(url, _localAuthToken!, updateUiShifts: false, showNotificationOnChanges: false).then((changesFound) => changesFound ?? false).catchError((e){ print("[Schedule Check] Error in _executeFetch for $futureYear/$futureWeek: $e"); return false; }) );
    }
    try { final List<bool> results = await Future.wait(futureChecks); if (mounted && results.any((changed) => changed)) { print("[Schedule Check] Changes detected in future weeks."); _showChangeNotification('Wijzigingen gevonden in toekomstige weken!'); } else { print("[Schedule Check] No changes detected in future weeks."); } }
    catch (e) { print("[Schedule Check] Error during Future.wait: $e"); }
    finally { if (mounted) { setState(() { _isCheckingFuture = false; }); } }
  }

  Future<void> _fetchSchedule() async {
    if (_localEmployeeId == null || _localNodeId == null || _localAuthToken == null) { print("[API] Fetch abort: Local auth missing."); if(mounted && _error == null){setState((){_error = "Auth data?"; _isLoading = false;});} else if (mounted) {setState((){_isLoading = false;});} return; }
    setState(() { _isLoading = true; _error = null; _shifts = []; _totalWeekDuration = Duration.zero; _totalBreakDuration = Duration.zero; });
    final url = _buildScheduleUrl(_localNodeId!, _localEmployeeId!, _currentYear, _currentWeek); print("[API] Fetching current week: $url");
    await _executeFetch(url, _localAuthToken!, updateUiShifts: true, showNotificationOnChanges: true);
  }

  Future<bool?> _executeFetch(String url, String token, {bool updateUiShifts = true, bool showNotificationOnChanges = false}) async {
    String storageKey = 'schedule_json_${_localEmployeeId}_${url.split('/schedule/')[1].replaceAll('/fromData', '').replaceAll('/', '_')}';
    SharedPreferences? prefs;
    bool changesFoundThisWeek = false;

    try {
      prefs = await SharedPreferences.getInstance();
      final String? previousJson = prefs.getString(storageKey);

      final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token', 'User-Agent': _userAgent, 'Accept': 'application/json', 'X-Application-Type': 'employee', 'Origin': 'https://ess.manus.plus', 'Referer': 'https://ess.manus.plus/'});
      print("[API] Status for $url: ${response.statusCode}");
      if (!mounted) return null;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final String currentJson = response.body;
        final data = jsonDecode(currentJson);
        if (data is Map<String, dynamic>) {
          final nodes = data['nodes'] as Map<String, dynamic>? ?? {};
          final depts = data['departments'] as Map<String, dynamic>? ?? {};
          final codes = data['hourCodes'] as Map<String, dynamic>? ?? {};

          final List<WorkShift> newShiftsParsed = _parseShiftsFromData(data, nodes, depts, codes);
          List<WorkShift> finalShiftsToProcess = newShiftsParsed;
          String jsonToSave = currentJson; // Standaard opslaan

          // Vergelijk alleen als er oude data is
          if (previousJson != null && previousJson.isNotEmpty) {
             try {
                final oldData = jsonDecode(previousJson);
                final List<WorkShift> oldShiftsParsed = _parseShiftsFromData(oldData, nodes, depts, codes);
                final (mergedList, changes) = _compareAndMergeSchedules(oldShiftsParsed, newShiftsParsed);
                finalShiftsToProcess = mergedList;
                changesFoundThisWeek = changes;
             } catch(e) { print("Err parsing/comparing old JSON for $storageKey: $e"); /* Fallback */ }
              // Sla altijd de *nieuwe* (originele) JSON op
              jsonToSave = currentJson;
          }

          // Update UI en totalen alleen als gevraagd
          if (updateUiShifts && mounted) {
             setState(() { _shifts = finalShiftsToProcess; _error = null; });
             _calculateWeeklyTotals();
             if(showNotificationOnChanges && changesFoundThisWeek) {
                _showChangeNotification("Wijzigingen in week $_currentWeek gevonden!");
             }
          }
          await prefs.setString(storageKey, jsonToSave);

        } else { if (updateUiShifts && mounted) setState(() { _error = "Data err: not map."; }); }
      } else { // Handle HTTP errors
         if (updateUiShifts && mounted) {
            if (response.statusCode == 401 || response.statusCode == 403) { setState(() { _error = "Sessie verlopen."; _localAuthToken = null; _localEmployeeId = null; _localNodeId = null; }); await widget.logoutCallback(); }
            else if (response.statusCode == 404) { setState(() { _error = "Rooster niet gevonden (404)."; _shifts=[]; _calculateWeeklyTotals();}); }
            else if (response.statusCode == 500) { setState(() { _error = "Nog niet ingepland? (500)"; _shifts=[]; _calculateWeeklyTotals();}); }
            else { String msg = "Fout (${response.statusCode})"; try { final b = jsonDecode(response.body); msg = b['message'] ?? msg; } catch (e) {} setState(() { _error = msg; }); }
         }
         changesFoundThisWeek = false;
      }
      return changesFoundThisWeek;
    } catch (e, s) { print('[API] Err for $url: $e\n$s'); if (updateUiShifts && mounted) { setState(() { _error = (e is FormatException) ? 'Data verwerk err.' : 'Netwerkfout: $e'; }); } return false; }
    finally { if (updateUiShifts && mounted) { setState(() { _isLoading = false; }); } }
  }

  void _goToPreviousWeek() { DateTime d=DateTime.utc(_currentYear).add(Duration(days:(_currentWeek-1)*7)); d=d.subtract(Duration(days:d.weekday-1)); DateTime p=d.subtract(const Duration(days:7)); setState((){_currentYear=p.year;_currentWeek=_isoWeekNumber(p);}); _fetchSchedule(); }
  void _goToNextWeek() { DateTime d=DateTime.utc(_currentYear).add(Duration(days:(_currentWeek-1)*7)); d=d.subtract(Duration(days:d.weekday-1)); DateTime n=d.add(const Duration(days:7)); setState((){_currentYear=n.year;_currentWeek=_isoWeekNumber(n);}); _fetchSchedule(); }

  Widget _buildWeekNavigator(BuildContext context) { final bool canNav=!_isLoading&&!_isCheckingFuture&&(_localAuthToken!=null); final txt=Theme.of(context).textTheme; final clr=Theme.of(context).colorScheme; return Padding( padding: const EdgeInsets.symmetric(vertical:8.0, horizontal:8.0), child: Material( color:clr.surfaceContainer, elevation:1, borderRadius:BorderRadius.circular(8), child: InkWell( borderRadius:BorderRadius.circular(8), onTap:null, child: Padding( padding:const EdgeInsets.symmetric(horizontal:8.0), child: Row( mainAxisAlignment:MainAxisAlignment.spaceBetween, children: [ IconButton(icon:const Icon(Icons.chevron_left), tooltip:'Vorige', onPressed:canNav?_goToPreviousWeek:null, color:canNav?clr.onSurface:Colors.grey,), GestureDetector(onTap:(){print("Week tap");}, child:Text('Wk $_currentWeek - $_currentYear', style:txt.titleMedium?.copyWith(fontWeight:FontWeight.bold),)), IconButton(icon:const Icon(Icons.chevron_right), tooltip:'Volgende', onPressed:canNav?_goToNextWeek:null, color:canNav?clr.onSurface:Colors.grey,), ], ),),),),); }

  Widget _buildTotalsDisplay(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) { String formattedTotal = WorkShift.formatDuration(_totalWeekDuration); String formattedBreak = WorkShift.formatDuration(_totalBreakDuration); return Padding( padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0), child: Card( elevation: 2, margin: EdgeInsets.zero, child: Padding( padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0), child: Row( mainAxisAlignment: MainAxisAlignment.center, children: [ Text( 'Totaal: ', style: textTheme.titleMedium, ), Text( formattedTotal, style: textTheme.titleMedium?.copyWith( fontWeight: FontWeight.bold, color: colorScheme.primary,), ), if (_totalBreakDuration > Duration.zero) Padding( padding: const EdgeInsets.only(left: 8.0), child: Text( '(Pauze: $formattedBreak)', style: textTheme.bodyMedium?.copyWith( color: textTheme.bodySmall?.color,), ), ), ], ), ), ), ); }

  @override Widget build(BuildContext context) {
    // Probeer de naam te formatteren (Achternaam, Voornaam -> Voornaam Achternaam)
    String displayTitle = 'Rooster'; // Fallback
    if (_localUserName != null && _localUserName!.contains(',')) {
       final parts = _localUserName!.split(',');
       if (parts.length >= 2) {
          displayTitle = 'Rooster ${parts[1].trim()} ${parts[0].trim()}';
       } else {
          displayTitle = 'Rooster ${_localUserName!}'; // Gebruik ongewijzigd als geen komma
       }
    } else if (_localUserName != null) {
        displayTitle = 'Rooster ${_localUserName!}'; // Gebruik als geen komma
    }


    return Scaffold(
      appBar: AppBar(
        // --- Titel Aangepast ---
        title: Text(displayTitle),
        // ---------------------
        actions: [
          if (_isCheckingFuture) const Padding(padding: EdgeInsets.only(right: 8.0), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))),
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Verversen', onPressed: (_isLoading || _isCheckingFuture || _localAuthToken == null) ? null : _fetchSchedule,),
          if (_localAuthToken != null) IconButton(icon: const Icon(Icons.logout), tooltip: 'Uitloggen', onPressed: () async { await widget.logoutCallback(); if (mounted) { setState(() { _shifts = []; _error = "Uitgelogd."; _isLoading = false; _localAuthToken = null; _localEmployeeId = null; _localNodeId = null; _localUserName = null; /* Reset naam ook */ }); } },),
        ],
      ),
      body: Column(
        children: [
          _buildWeekNavigator(context),
          Expanded(child: _buildBody(context, Theme.of(context).textTheme, Theme.of(context).colorScheme),),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    if (_isLoading && _shifts.isEmpty) { return const Center(child: CircularProgressIndicator()); }
    if (_error != null && _shifts.isEmpty) { bool isLoginIssue = _localAuthToken == null || (_error!.contains("inloggen") || _error!.contains("ingelogd") || _error!.contains("Sessie verlopen") || _error!.contains("Authenticatiegegevens") || _error!.contains("Token niet beschikbaar"));
      return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ Icon( isLoginIssue ? Icons.lock_person_outlined : Icons.error_outline, color: colorScheme.error, size: 48 ), const SizedBox(height: 16), Text( _error!, style: TextStyle(color: colorScheme.error, fontSize: 16), textAlign: TextAlign.center,), const SizedBox(height: 20), if (isLoginIssue) ElevatedButton.icon( icon: const Icon(Icons.login), label: const Text('Inloggen'), onPressed: _isLoading ? null : _promptLoginAndFetch, ) else if (_localAuthToken != null) ElevatedButton.icon( style: ElevatedButton.styleFrom(foregroundColor: colorScheme.onError, backgroundColor: colorScheme.error,).copyWith(overlayColor: WidgetStateProperty.resolveWith<Color?>((s){if(s.contains(WidgetState.hovered))return Colors.white.withAlpha(20);if(s.contains(WidgetState.pressed))return Colors.white.withAlpha(30);return null;})), icon: const Icon(Icons.refresh), label: const Text('Opnieuw Proberen'), onPressed: _isLoading ? null : _fetchSchedule, ), ], ), ), );
    }
    if (_localAuthToken == null && _shifts.isEmpty && _error == null) { return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ const Icon(Icons.lock_outline, size: 48, color: Colors.grey), const SizedBox(height: 16), const Text('Log in om je rooster te bekijken.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),), const SizedBox(height: 20), ElevatedButton.icon( icon: const Icon(Icons.login), label: const Text('Inloggen'), onPressed: _isLoading ? null : _promptLoginAndFetch, ), ], ), ), ); }

    // Hoofdweergave: Lijst + Totalen (of lege staat)
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchSchedule,
            child: (_shifts.isEmpty && !_isLoading)
                ? Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [ const Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey), const SizedBox(height: 16), Text('Geen roostergegevens gevonden voor week $_currentWeek.', textAlign: TextAlign.center, style: textTheme.bodyMedium,), ], ) ), )
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                    itemCount: _shifts.length,
                    itemBuilder: (context, index) {
                      final shift = _shifts[index];
                      final bool showDateHeader = index == 0 || _shifts[index - 1].date.day != shift.date.day || _shifts[index-1].date.month != shift.date.month || _shifts[index-1].date.year != shift.date.year ;

                      Color? tileColor; IconData? leadingIcon; Color? leadingIconColor;
                      TextDecoration? itemDecoration = TextDecoration.none;
                      Color? itemColor;
                      Color? subtitleColor = textTheme.bodyMedium?.color;
                      Color? trailingColor = colorScheme.secondary;

                      switch (shift.changeType) {
                        case ShiftChangeType.added: tileColor = Colors.green.withAlpha((255*0.1).round()); leadingIcon = Icons.add_circle_outline; leadingIconColor = Colors.green; break;
                        case ShiftChangeType.modified: tileColor = Colors.orange.withAlpha((255*0.1).round()); leadingIcon = Icons.edit_outlined; leadingIconColor = Colors.orange[800]; break;
                        case ShiftChangeType.deleted: tileColor = Colors.grey.withAlpha((255*0.1).round()); leadingIcon = Icons.delete_outline; leadingIconColor = Colors.grey[600]; itemDecoration = TextDecoration.lineThrough; itemColor = Colors.grey[600]; subtitleColor = Colors.grey[600]; trailingColor = Colors.grey[600]; break;
                        case ShiftChangeType.none: break;
                      }

                      Widget buildTimeWidget(TimeOfDay currentTime, TimeOfDay? previousTime, TextStyle? baseStyle, TextStyle? oldStyle) {
                          List<InlineSpan> spans = [];
                          if (shift.isModified && previousTime != null && previousTime != currentTime) { spans.add(TextSpan( text: WorkShift.formatTime(previousTime), style: oldStyle, )); spans.add(const TextSpan(text: ' ')); }
                          spans.add(TextSpan( text: WorkShift.formatTime(currentTime), style: baseStyle?.copyWith(decoration: itemDecoration, color: itemColor), ));
                          return RichText( text: TextSpan(children: spans), textAlign: TextAlign.end, );
                      }

                      Widget leadingWidget = Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          buildTimeWidget(shift.startTime, shift.previousStartTime, textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 15), textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: Colors.grey[600])),
                          buildTimeWidget(shift.endTime, shift.previousEndTime, textTheme.bodyMedium?.copyWith(fontSize: 13), textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: Colors.grey[600])),
                      ], );

                     Widget trailingWidget = Column( mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
                          if (shift.isModified && shift.previousTotalDuration != null && shift.previousTotalDuration != shift.totalDuration) Text( WorkShift.formatDuration(shift.previousTotalDuration!), style: textTheme.bodySmall?.copyWith(decoration: TextDecoration.lineThrough, color: Colors.grey[600])),
                          Text( shift.totalTimeDisplay, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: trailingColor, decoration: itemDecoration),),
                      ], );

                      return Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (showDateHeader) Padding( padding: EdgeInsets.only(top: (index == 0 ? 8.0 : 16.0), bottom: 8.0, left: 4.0), child: Text( '${shift.dayName} ${shift.formattedDateShort}', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary), ), ),
                          Card( color: tileColor, margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), child: ListTile( contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                              leading: leadingWidget,
                              title: Text(shift.departmentName, style: textTheme.titleMedium?.copyWith(fontSize: 15, decoration: itemDecoration, color: itemColor)),
                              subtitle: Padding( padding: const EdgeInsets.only(top: 4.0), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  if (leadingIcon != null) Padding( padding: const EdgeInsets.only(bottom: 3.0), child: Icon(leadingIcon, color: leadingIconColor, size: 16), ),
                                  if (shift.isModified) ...[
                                     if(shift.previousBreakDuration != null && shift.previousBreakDuration != shift.breakDuration) Text('Pauze was: ${WorkShift.formatDuration(shift.previousBreakDuration!)}', style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                                     if (shift.previousDepartmentName != null && shift.previousDepartmentName != shift.departmentName) Text('Afd. was: ${shift.previousDepartmentName!}', style: textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                                     const SizedBox(height: 4),
                                  ],
                                  Text(shift.nodeName, style: textTheme.bodyMedium?.copyWith(decoration: itemDecoration, color: subtitleColor)),
                                  Text('Type: ${shift.hourCodeName}', style: textTheme.bodyMedium?.copyWith(decoration: itemDecoration, color: subtitleColor)),
                                  if (shift.breakDuration > Duration.zero && !shift.isDeleted) Text('Pauze: ${shift.breakTimeDisplay}', style: textTheme.bodyMedium?.copyWith(decoration: itemDecoration, color: subtitleColor)),
                                ],),
                              ),
                              trailing: trailingWidget,
                              dense: true,
                            ),
                          ),
                        ],);
                    },
                  ),
          ),
        ),
        if (!_isLoading && _shifts.isNotEmpty) _buildTotalsDisplay(context, textTheme, colorScheme),
        if (_isLoading && _shifts.isNotEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator()),
      ],
    );
   }

} // <<< EINDE ScheduleScreenState