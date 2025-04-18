// lib/screens/schedule_screen.dart

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:convert';
import 'package:intl/intl.dart';

import '../models/login_result.dart'; // Importeer models
import '../models/work_shift.dart';

class ScheduleScreen extends StatefulWidget {
  final String? authToken;
  final bool isLoggedIn; // Kan nuttig blijven voor initiële UI state
  final String? employeeId;
  final String? nodeId;
  final Future<LoginResult> Function(BuildContext context) loginCallback;
  final Future<void> Function() logoutCallback;

  const ScheduleScreen({
    super.key,
    required this.authToken,
    required this.isLoggedIn,
    required this.employeeId,
    required this.nodeId,
    required this.loginCallback,
    required this.logoutCallback,
  });

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  List<WorkShift> _shifts = [];
  bool _isLoading = false;
  String? _error;
  int _currentYear = DateTime.now().year;
  int _currentWeek = _isoWeekNumber(DateTime.now());
  String? _localAuthToken;
  String? _localEmployeeId;
  String? _localNodeId;
  Duration _totalWeekDuration = Duration.zero;
  Duration _totalBreakDuration = Duration.zero;

  final String _apiBaseUrl = 'https://server.manus.plus/intergamma/api/node/';
  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'; // Ingekort

  @override
  void initState() {
    super.initState();
    // Initialiseer lokale state met widget props
    _localAuthToken = widget.authToken;
    _localEmployeeId = widget.employeeId;
    _localNodeId = widget.nodeId;
    // Fetch data alleen als alles direct aanwezig is
    if (_localAuthToken != null && _localEmployeeId != null && _localNodeId != null) {
      _fetchSchedule();
    }
  }

  // --- Helper functies ---
  static int _isoWeekNumber(DateTime date) {
    int dayOfYear = int.parse(DateFormat("D", "en_US").format(date));
    int woy = ((dayOfYear - date.weekday + 10) / 7).floor();
    if (woy < 1) {
      woy = _isoWeekNumber(DateTime(date.year - 1, 12, 31));
    } else if (woy == 53 && DateTime(date.year, 1, 1).weekday != DateTime.thursday && DateTime(date.year, 12, 31).weekday != DateTime.thursday) {
      woy = 1;
    }
    return woy;
  }
  // ----------------------

  Future<void> _promptLoginAndFetch() async {
    if (_isLoading || !mounted) return;
    setState(() { _isLoading = true; _error = null; });
    final LoginResult res = await widget.loginCallback(context);
    if (!mounted) return;
    if (res.success && res.employeeId != null && res.nodeId != null && res.authToken != null) {
      print("[Schedule] Login OK. Storing locally & Fetching...");
      setState(() {
        _localAuthToken = res.authToken;
        _localEmployeeId = res.employeeId;
        _localNodeId = res.nodeId;
        _isLoading = true; // Houdt loading voor fetch
        _error = null;
      });
      await _fetchSchedule(); // Roep standaard fetch aan, die gebruikt nu lokale state
    } else {
      print("[Schedule] Login Fail/Cancel: ${res.errorMessage}");
      setState(() { _error = res.errorMessage ?? "Login mislukt."; _isLoading = false; });
    }
  }

  String _buildScheduleUrl(String nId, String eId, int yr, int wk) =>
      '$_apiBaseUrl$nId/employee/$eId/schedule/$yr/$wk/fromData';

  void _calculateWeeklyTotals() {
    Duration weekTotal = Duration.zero;
    Duration breakTotal = Duration.zero;
    for (var shift in _shifts) {
      weekTotal += shift.totalDuration;
      breakTotal += shift.breakDuration;
    }
    if (mounted && (_totalWeekDuration != weekTotal || _totalBreakDuration != breakTotal)) {
      setState(() {
        _totalWeekDuration = weekTotal;
        _totalBreakDuration = breakTotal;
      });
    }
  }

  Future<void> _fetchSchedule() async {
    if (_localEmployeeId == null || _localNodeId == null || _localAuthToken == null) {
      print("[API] Fetch abort: Local auth missing.");
      if (mounted && _error == null) { setState(() { _error = "Auth data?"; _isLoading = false; }); }
      else if (mounted) { setState(() { _isLoading = false; }); }
      return;
    }
    // Verwijder if (_isLoading) return; check
    setState(() { _isLoading = true; _error = null; _shifts = []; _totalWeekDuration = Duration.zero; _totalBreakDuration = Duration.zero; });
    final url = _buildScheduleUrl(_localNodeId!, _localEmployeeId!, _currentYear, _currentWeek);
    print("[API] Fetching: $url");
    await _executeFetch(url, _localAuthToken!);
  }

  Future<void> _executeFetch(String url, String token) async {
    try {
      final response = await http.get(Uri.parse(url), headers: {'Authorization': 'Bearer $token', 'User-Agent': _userAgent, 'Accept': 'application/json', 'X-Application-Type': 'employee', 'Origin': 'https://ess.manus.plus', 'Referer': 'https://ess.manus.plus/'});
      print("[API] Status: ${response.statusCode}");
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(response.body);
        if (data is Map<String, dynamic>) {
          final nodes = data['nodes'] as Map<String, dynamic>? ?? {};
          final depts = data['departments'] as Map<String, dynamic>? ?? {};
          final codes = data['hourCodes'] as Map<String, dynamic>? ?? {};
          final days = data['schedule'] as List<dynamic>?;
          if (days != null) {
            final List<WorkShift> tempShifts = [];
            for (var day in days) {
              if (day is Map<String, dynamic>) {
                final String? ds = day['date'] as String?;
                DateTime? pDate = ds != null ? DateTime.tryParse(ds) : null;
                final List<dynamic>? entries = day['entries'] as List<dynamic>?;
                if (pDate != null && entries != null) {
                  for (var entry in entries) {
                    if (entry is Map<String, dynamic>) {
                      final shift = WorkShift.fromJson(entry, pDate, nodes, depts, codes);
                      if (shift != null) tempShifts.add(shift);
                    }
                  }
                } else if (pDate == null) { print("[Parse] Skip day, date err: ${day['date']}"); }
              }
            }
            tempShifts.sort((a, b) { int d = a.date.compareTo(b.date); if (d != 0) return d; int h = a.startTime.hour.compareTo(b.startTime.hour); if (h != 0) return h; return a.startTime.minute.compareTo(b.startTime.minute); });
            setState(() { _shifts = tempShifts; _error = null; });
            _calculateWeeklyTotals();
          } else { setState(() { _error = "Data err: 'schedule' list?"; }); }
        } else { setState(() { _error = "Data err: not map."; }); }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        setState(() { _error = "Sessie verlopen."; _localAuthToken = null; _localEmployeeId = null; _localNodeId = null; });
        await widget.logoutCallback();
      } else if (response.statusCode == 404) { setState(() { _error = "Rooster niet gevonden (404)."; });
      } else if (response.statusCode == 500) { setState(() { _error = "Nog niet ingepland? (500)"; });
      } else { String msg = "Fout (${response.statusCode})"; try { final b = jsonDecode(response.body); msg = b['message'] ?? msg; } catch (e) {} setState(() { _error = msg; }); }
    } catch (e, s) { print('[API] Err: $e\n$s'); if (mounted) { setState(() { _error = (e is FormatException) ? 'Data verwerk err.' : 'Netwerkfout: $e'; }); } }
    finally { if (mounted) { setState(() { _isLoading = false; }); } }
  }

  void _goToPreviousWeek() { DateTime d=DateTime.utc(_currentYear).add(Duration(days:(_currentWeek-1)*7)); d=d.subtract(Duration(days:d.weekday-1)); DateTime p=d.subtract(const Duration(days:7)); setState((){_currentYear=p.year;_currentWeek=_isoWeekNumber(p);}); _fetchSchedule(); }
  void _goToNextWeek() { DateTime d=DateTime.utc(_currentYear).add(Duration(days:(_currentWeek-1)*7)); d=d.subtract(Duration(days:d.weekday-1)); DateTime n=d.add(const Duration(days:7)); setState((){_currentYear=n.year;_currentWeek=_isoWeekNumber(n);}); _fetchSchedule(); }

  Widget _buildWeekNavigator(BuildContext context) {
    final bool canNav = !_isLoading && (_localAuthToken != null);
    final txt = Theme.of(context).textTheme;
    final clr = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Material(
        color: clr.surfaceContainer,
        elevation: 1,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(icon: const Icon(Icons.chevron_left), tooltip: 'Vorige', onPressed: canNav ? _goToPreviousWeek : null, color: canNav ? clr.onSurface : Colors.grey,),
                GestureDetector(onTap: () { print("Week tap"); }, child: Text('Wk $_currentWeek - $_currentYear', style: txt.titleMedium?.copyWith(fontWeight: FontWeight.bold),)),
                IconButton(icon: const Icon(Icons.chevron_right), tooltip: 'Volgende', onPressed: canNav ? _goToNextWeek : null, color: canNav ? clr.onSurface : Colors.grey,),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsDisplay(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    String formattedTotal = WorkShift.formatDuration(_totalWeekDuration);
    String formattedBreak = WorkShift.formatDuration(_totalBreakDuration);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
      child: Card(
        elevation: 2,
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Totaal: ', style: textTheme.titleMedium,),
              Text(formattedTotal, style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary,),),
              if (_totalBreakDuration > Duration.zero)
                Padding(padding: const EdgeInsets.only(left: 8.0), child: Text('(Pauze: $formattedBreak)', style: textTheme.bodyMedium?.copyWith(color: textTheme.bodySmall?.color,),),),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mijn Rooster'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), tooltip: 'Verversen', onPressed: (_isLoading || _localAuthToken == null) ? null : _fetchSchedule,),
          if (_localAuthToken != null)
            IconButton(icon: const Icon(Icons.logout), tooltip: 'Uitloggen', onPressed: () async { await widget.logoutCallback(); if (mounted) { setState(() { _shifts = []; _error = "Uitgelogd."; _isLoading = false; _localAuthToken = null; _localEmployeeId = null; _localNodeId = null; }); } },),
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
    if (_error != null && _shifts.isEmpty) {
      bool isLoginIssue = _localAuthToken == null || (_error!.contains("inloggen") || _error!.contains("ingelogd") || _error!.contains("Sessie verlopen") || _error!.contains("Authenticatiegegevens") || _error!.contains("Token niet beschikbaar"));
      return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(isLoginIssue ? Icons.lock_person_outlined : Icons.error_outline, color: colorScheme.error, size: 48),
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: colorScheme.error, fontSize: 16), textAlign: TextAlign.center,),
            const SizedBox(height: 20),
            if (isLoginIssue)
              ElevatedButton.icon(icon: const Icon(Icons.login), label: const Text('Inloggen'), onPressed: _isLoading ? null : _promptLoginAndFetch,)
            else if (_localAuthToken != null)
              ElevatedButton.icon(style: ElevatedButton.styleFrom(foregroundColor: colorScheme.onError, backgroundColor: colorScheme.error,).copyWith(overlayColor: WidgetStateProperty.resolveWith<Color?>((s) { if (s.contains(WidgetState.hovered)) return Colors.white.withAlpha(20); if (s.contains(WidgetState.pressed)) return Colors.white.withAlpha(30); return null; })), icon: const Icon(Icons.refresh), label: const Text('Opnieuw Proberen'), onPressed: _isLoading ? null : _fetchSchedule,),
          ],),),);
    }
    if (_localAuthToken == null && _shifts.isEmpty && _error == null) {
      return Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            const Icon(Icons.lock_outline, size: 48, color: Colors.grey), const SizedBox(height: 16),
            const Text('Log in om je rooster te bekijken.', textAlign: TextAlign.center, style: TextStyle(fontSize: 16),), const SizedBox(height: 20),
            ElevatedButton.icon(icon: const Icon(Icons.login), label: const Text('Inloggen'), onPressed: _isLoading ? null : _promptLoginAndFetch,),
          ],),),);
    }

    // Hoofdweergave: Lijst + Totalen (of lege staat)
    return Column(
      children: [
        Expanded(
          child: RefreshIndicator(
            onRefresh: _fetchSchedule,
            child: (_shifts.isEmpty && !_isLoading)
                ? Center(child: Padding(padding: const EdgeInsets.all(20.0), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey), const SizedBox(height: 16),
                      Text('Geen roostergegevens gevonden voor week $_currentWeek.', textAlign: TextAlign.center, style: textTheme.bodyMedium,),
                    ],),),)
                : ListView.builder(
                    padding: const EdgeInsets.only(left: 8.0, right: 8.0, bottom: 8.0),
                    itemCount: _shifts.length,
                    itemBuilder: (context, index) {
                      final shift = _shifts[index];
                      final bool showDateHeader = index == 0 || _shifts[index - 1].date.day != shift.date.day || _shifts[index - 1].date.month != shift.date.month || _shifts[index - 1].date.year != shift.date.year;
                      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          if (showDateHeader) Padding(padding: EdgeInsets.only(top: (index == 0 ? 8.0 : 16.0), bottom: 8.0, left: 4.0), child: Text('${shift.dayName} ${shift.formattedDateShort}', style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.primary),),),
                          Card(margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0), child: ListTile(contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0), leading: Column(mainAxisAlignment: MainAxisAlignment.center, children: [ Text(shift.timeRangeDisplay.split(' - ')[0], style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)), Text(shift.timeRangeDisplay.split(' - ')[1], style: textTheme.bodyMedium), ],), title: Text(shift.departmentName, style: textTheme.titleMedium?.copyWith(fontSize: 15),), subtitle: Padding(padding: const EdgeInsets.only(top: 4.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Text(shift.nodeName), Text('Type: ${shift.hourCodeName}'), if (shift.breakDuration > Duration.zero) Text('Pauze: ${shift.breakTimeDisplay}'), ],),), trailing: Text(shift.totalTimeDisplay, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.secondary),), dense: true,),),
                        ],);
                    },),
          ),
        ),
        // Toon totalen alleen als er shifts zijn en niet (meer) aan het laden
        if (!_isLoading && _shifts.isNotEmpty)
          _buildTotalsDisplay(context, textTheme, colorScheme),
        // Toon kleine indicator onderaan tijdens het laden van nieuwe week data
        if (_isLoading && _shifts.isNotEmpty)
          const Padding(padding: EdgeInsets.symmetric(vertical: 8.0), child: LinearProgressIndicator()),
      ],
    );
  }
} // <<< EINDE ScheduleScreenState