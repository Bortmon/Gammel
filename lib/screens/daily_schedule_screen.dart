// lib/screens/daily_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// BELANGRIJK: Zorg dat flutter_localizations is toegevoegd aan pubspec.yaml
// en geconfigureerd in je MaterialApp voor Nederlandse datumnotatie!
// Zie: https://docs.flutter.dev/ui/accessibility-and-localization/internationalization

// --- DATA MODEL VOOR EEN DAGELIJKSE DIENST ENTRY (UITGEBREID & GECORRIGEERD) ---
class DailyShiftEntry {
  final int id;
  final String employeeId; // Nodig voor koppeling
  final String employeeFullName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Duration breakDuration;
  final Duration totalDuration;
  final String departmentName; // Afdeling van *deze* dienst
  final String hourCodeName;
  final bool isPresence;
  final String? functionCode;
  // --- Extra velden voor details dialog ---
  final String? employeeTypeAbbr;
  final double? workingHours; // Contracturen (in minuten)
  final double? dailyHours;   // Gemiddelde daguren (in minuten)
  final List<int> allowedDepartmentIds; // IDs van afdelingen waar men mag werken

  DailyShiftEntry({
    required this.id,
    required this.employeeId,
    required this.employeeFullName,
    required this.startTime,
    required this.endTime,
    required this.breakDuration,
    required this.totalDuration,
    required this.departmentName,
    required this.hourCodeName,
    required this.isPresence,
    this.functionCode,
    this.employeeTypeAbbr,
    this.workingHours,
    this.dailyHours,
    required this.allowedDepartmentIds,
  });

  // --- Static Helper Functies ---
  static TimeOfDay _minutesToTimeOfDay(int m) => TimeOfDay(hour: m ~/ 60, minute: m % 60);
  static String formatTime(TimeOfDay time) => "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  static String formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes";
  }

  static int? _parseInt(dynamic v){if(v==null)return null;if(v is int)return v;if(v is String)return int.tryParse(v);if(v is num)return v.toInt();print("P Int Err:${v.runtimeType}");return null;}
  static double? _parseDouble(dynamic v){if(v==null)return null;if(v is double)return v;if(v is int)return v.toDouble();if(v is String)return double.tryParse(v);if(v is num)return v.toDouble();print("P Double Err:${v.runtimeType}");return null;}
  static bool _parseBool(dynamic v) { if (v == null) return false; if (v is bool) return v; if (v is String) return v.toLowerCase() == 'true' || v == '1'; if (v is num) return v != 0; return false; }
  static num? _parseNum(dynamic v){ if(v==null)return null; if(v is num)return v; if(v is String)return num.tryParse(v); print("P Num Err:${v.runtimeType}"); return null; }

  // --- Getters ---
  String get formattedWorkingHours {
    if (workingHours == null || workingHours! <= 0) return "N/B";
    double hoursPerWeek = workingHours! / 60.0;
    return "${hoursPerWeek.toStringAsFixed(1)} uur/week";
  }
  String get timeRangeDisplay => '${formatTime(startTime)} - ${formatTime(endTime)}';
  String get breakTimeDisplay => formatDuration(breakDuration);
  String get totalTimeDisplay => formatDuration(totalDuration);

  // --- fromJson Factory ---
  static DailyShiftEntry? fromJson(
      Map<String, dynamic> entryData,
      String empId,
      Map<String, dynamic> empDetails,
      Map<String, dynamic>? contractDetails,
      Map<String, dynamic> allDepartments,
      Map<String, dynamic> allHourCodes,
      List<int> presenceCodeIds
    ) {
    try {
      final int? entryId = _parseInt(entryData['id']);
      final int? sM = _parseInt(entryData['startTime']);
      final int? eM = _parseInt(entryData['endTime']);
      final int? dId = _parseInt(entryData['departmentId']);
      final int? cId = _parseInt(entryData['hourCodeId']);
      final num? bN = _parseNum(entryData['breakTime']);
      final num? tN = _parseNum(entryData['totalTime']);
      final bool isPres = _parseBool(entryData['isPresence']) || (cId != null && presenceCodeIds.contains(cId));

      if (entryId == null || sM == null || eM == null || dId == null || cId == null) {
        print("DailyShiftEntry parse fail (basic): $entryData");
        return null;
      }

      final TimeOfDay sT = _minutesToTimeOfDay(sM);
      final TimeOfDay eT = _minutesToTimeOfDay(eM);
      final Duration bD = Duration(minutes: bN?.toInt() ?? 0);
      final Duration tD = Duration(minutes: tN?.toInt() ?? 0);
      final String depN = allDepartments[dId.toString()]?['name'] ?? 'Afd $dId?';
      final String codeN = allHourCodes[cId.toString()]?['name'] ?? 'Type $cId?';

      final String employeeName = empDetails['text'] ?? 'Onbekende Medewerker ($empId)';
      final String? funcCode = empDetails['functionCode'];
      final String? empTypeAbbr = empDetails['employeeTypeAbbr'];
      final double? workHours = _parseDouble(contractDetails?['workingHours']);
      final double? dayHours = _parseDouble(contractDetails?['dailyHours']);
      final List<int> allowedDepts = (contractDetails?['employeeDepartments'] as List<dynamic>? ?? [])
          .map((id) => _parseInt(id))
          .where((id) => id != null)
          .cast<int>()
          .toList();

      return DailyShiftEntry(
        id: entryId,
        employeeId: empId,
        employeeFullName: employeeName,
        startTime: sT,
        endTime: eT,
        breakDuration: bD,
        totalDuration: tD,
        departmentName: depN,
        hourCodeName: codeN,
        isPresence: isPres,
        functionCode: funcCode,
        employeeTypeAbbr: empTypeAbbr,
        workingHours: workHours,
        dailyHours: dayHours,
        allowedDepartmentIds: allowedDepts,
      );
    } catch (e, s) {
      print("DailyShiftEntry Err: $e\n$s\n$entryData");
      return null;
    }
  }
}
// ----------------------------------------------------

class DailyScheduleScreen extends StatefulWidget {
  final String authToken;
  final String nodeId;
  final DateTime selectedDate; // Startdatum

  const DailyScheduleScreen({
    super.key,
    required this.authToken,
    required this.nodeId,
    required this.selectedDate,
  });

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _displayItems = [];
  Map<String, dynamic> _departments = {};
  Map<String, dynamic> _hourCodes = {};
  List<int> _presenceCodeIds = [];
  late DateTime _currentDate;

  // --- CONFIGURATIE: Functiecodes voor Management ---
  final Set<String> _managementFunctionCodes = {'BM', 'ABM'};

  // --- *** BIJGEWERKT: Hardcoded mapping van naam naar cluster *** ---
  final Map<String, String> _employeeClusterMapping = {
    // Management
    "Bakker, Jaimy": "Management",
    "Kliek, Twan": "Management",

    // Voorcluster
    "Fiechter, Gertjan": "Voorcluster",
    "Bakker, Mandy": "Voorcluster",
    "Kamps, Karin": "Voorcluster",
    "Post-Portegies, Manon": "Voorcluster",
    "Navrozoglou, Loukas": "Voorcluster",
    "Posch, Swen": "Voorcluster",
    "Hoogenboom, Thijs": "Voorcluster",

    // Kassa/Balie
    "Sikman, Maxim": "Kassa/Balie",
    "Keijzer, Riley": "Kassa/Balie",
    "Diercks-van Bruggen, Pauline": "Kassa/Balie",
    "Koning, Bo": "Kassa/Balie",
    "Saat, Lidia": "Kassa/Balie",
    "Weide, Eric, van der": "Kassa/Balie", // Check naam format!
    "Johanns, Ingeborg": "Kassa/Balie",
    "Raja, Nima": "Kassa/Balie",
    "Kruiper, Julie": "Kassa/Balie",
    "Nouland, Sofie, van den": "Kassa/Balie", // Check naam format!
    "Nijland -  Kahmann, Sandra": "Kassa/Balie", // Check naam format!
    "Wubbels -  Grimbergen, Eefje": "Kassa/Balie", // Check naam format!

    // Achtercluster
    "Adema, Jasper": "Achtercluster",
    "Oomkens, Laurens": "Achtercluster",
    "Zwart, Ricardo": "Achtercluster",
    "Witteveen, Stijn": "Achtercluster",
    "Akkerman, Bart": "Achtercluster",
    "Petter, Mike": "Achtercluster",
    "Blansch, Rene, Le": "Achtercluster", // Check naam format!
    "Huijboom, Matteo": "Achtercluster",


  };
  // --- *** BIJGEWERKT: Gewenste volgorde van de clusters *** ---
  final List<String> _clusterOrder = [
    "Management",
    "Voorcluster",
    "Kassa/Balie",
    "Achtercluster",
    "Overige Medewerkers" // 'Overige' als laatste
  ];
  // -----------------------------------------------------------

  final String _apiBaseUrl = 'https://server.manus.plus/intergamma/api/node/';
  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _currentDate = widget.selectedDate;
    _fetchDailySchedule();
  }

  String _buildDailyScheduleUrl(String nodeId, DateTime date) {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    return '$_apiBaseUrl$nodeId/schedule/$formattedDate?departmentId=-1&scheduledOnly=false';
  }

  Future<void> _fetchDailySchedule() async {
    print("[FETCH START] Fetching for $_currentDate");
    if (!mounted) { print("[FETCH ABORT] Not mounted"); return; }
    setState(() {
      _isLoading = true;
      _error = null;
      if (_displayItems.isEmpty) { _displayItems = []; }
    });

    final url = _buildDailyScheduleUrl(widget.nodeId, _currentDate);
    print("[API Daily] Fetching: $url");

    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}',
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'X-Application-Type': 'employee',
          'Origin': 'https://ess.manus.plus',
          'Referer': 'https://ess.manus.plus/',
        },
      );

      print("[API Daily] Status: ${response.statusCode}");
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) {
           print("[FETCH PARSE START] Parsing data for $_currentDate");
          _parseAndGroupDailyData(data);
           print("[FETCH PARSE END] Finished parsing for $_currentDate");
        } else {
          setState(() { _error = "Ongeldige data ontvangen van server."; _displayItems = []; });
        }
      } else {
         String errorMsg = "Fout bij ophalen (${response.statusCode})";
         try { final b = jsonDecode(response.body); errorMsg = b['message'] ?? errorMsg; } catch (e) {}
         if (response.statusCode == 401 || response.statusCode == 403) { errorMsg = "Sessie verlopen. Ga terug en log opnieuw in."; }
         else if (response.statusCode == 404) { errorMsg = "Rooster niet gevonden voor deze dag (404)."; }
         else if (response.statusCode == 500) { errorMsg = "Serverfout (500)."; }
        setState(() { _error = errorMsg; _displayItems = []; });
      }
    } catch (e, s) {
      print('[API Daily] Error: $e\n$s');
      if (mounted) {
        setState(() { _error = 'Netwerkfout of dataverwerkingsfout: $e'; _displayItems = []; });
      }
    } finally {
      if (mounted) {
         print("[FETCH SETSTATE START] Updating UI for $_currentDate");
        setState(() { _isLoading = false; });
         print("[FETCH SETSTATE END] UI update finished for $_currentDate");
      } else {
         print("[FETCH FINALLY] Not mounted, skipping setState");
      }
    }
     print("[FETCH END] Finished fetching for $_currentDate");
  }

  // --- Parse en groepeer op basis van functie EN naam ---
  void _parseAndGroupDailyData(Map<String, dynamic> data) {
     print("[PARSE START] Starting _parseAndGroupDailyData");
    final Map<String, dynamic> scheduleMap = data['schedule'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> employeesMap = data['employees'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> contractsMap = data['employeesContract'] as Map<String, dynamic>? ?? {};
    _departments = data['departments'] as Map<String, dynamic>? ?? {};
    _hourCodes = data['hourCodes'] as Map<String, dynamic>? ?? {};
    _presenceCodeIds = (data['presenceCodes'] as List<dynamic>? ?? [])
        .map((code) => DailyShiftEntry._parseInt(code))
        .where((id) => id != null)
        .cast<int>()
        .toList();

    final Map<String, List<DailyShiftEntry>> groupedEntries = {};
    for (var clusterName in _clusterOrder) {
      groupedEntries[clusterName] = [];
    }
    groupedEntries.putIfAbsent("Overige Medewerkers", () => []);

    int totalPresenceEntries = 0;

    employeesMap.forEach((employeeId, employeeData) {
      if (employeeData is! Map<String, dynamic>) {
         print("Skipping employeeId $employeeId: employeeData is not a Map.");
         return;
      }

      final scheduleInfo = scheduleMap[employeeId] as Map<String, dynamic>?;
      final contractInfo = contractsMap[employeeId] as Map<String, dynamic>?;

      if (scheduleInfo != null) {
        final List<dynamic>? entries = scheduleInfo['entries'] as List<dynamic>?;

        if (entries != null && entries.isNotEmpty) {
          for (var entryItem in entries) {
             if (entryItem is Map<String, dynamic>) {
                final entryData = entryItem;

                final dailyEntry = DailyShiftEntry.fromJson(
                    entryData, employeeId, employeeData, contractInfo, _departments, _hourCodes, _presenceCodeIds);

                if (dailyEntry != null && dailyEntry.isPresence) {
                  totalPresenceEntries++;
                  String clusterName = "Overige Medewerkers"; // Default

                  if (dailyEntry.functionCode != null && _managementFunctionCodes.contains(dailyEntry.functionCode)) {
                    clusterName = "Management";
                  }
                  else if (_employeeClusterMapping.containsKey(dailyEntry.employeeFullName)) {
                    clusterName = _employeeClusterMapping[dailyEntry.employeeFullName]!;
                  }

                  groupedEntries.putIfAbsent(clusterName, () {
                     print("Warning: Cluster '$clusterName' from mapping was not pre-initialized in _clusterOrder. Adding dynamically.");
                     return [];
                  }).add(dailyEntry);

                } else if (dailyEntry == null) {
                   print("Failed to parse entry for employee $employeeId: $entryData");
                }
             } else {
                print("Skipping entry for employee $employeeId: entry item is not a Map.");
             }
          }
        }
      }
    });

    final sortLogic = (DailyShiftEntry a, DailyShiftEntry b) {
      int startComp = (a.startTime.hour * 60 + a.startTime.minute).compareTo(b.startTime.hour * 60 + b.startTime.minute);
      if (startComp != 0) return startComp;
      return a.employeeFullName.compareTo(b.employeeFullName);
    };
    groupedEntries.values.forEach((list) => list.sort(sortLogic));

    final List<dynamic> newDisplayItems = [];
    for (var clusterName in _clusterOrder) {
       final entriesForCluster = groupedEntries[clusterName];
       if (entriesForCluster != null && entriesForCluster.isNotEmpty) {
          newDisplayItems.add(clusterName);
          newDisplayItems.addAll(entriesForCluster);
       }
    }
    groupedEntries.forEach((clusterName, entries) {
       if (!_clusterOrder.contains(clusterName) && entries.isNotEmpty) {
          print("Adding dynamically found cluster '$clusterName' to the end of the list.");
          newDisplayItems.add(clusterName);
          newDisplayItems.addAll(entries);
       }
    });

    _displayItems = newDisplayItems;
    if (totalPresenceEntries == 0 && _error == null) {
       _error = 'Geen werkende collega\'s gevonden voor deze dag.';
    } else if (totalPresenceEntries > 0) {
       if (_error == 'Geen werkende collega\'s gevonden voor deze dag.') {
          _error = null;
       }
    }
     print("[PARSE END] Finished _parseAndGroupDailyData. Display items count: ${_displayItems.length}");
  }
  // -----------------------------------------------------------------

  void _goToPreviousDay() {
    setState(() { _currentDate = _currentDate.subtract(const Duration(days: 1)); });
    _fetchDailySchedule();
  }

  void _goToNextDay() {
    setState(() { _currentDate = _currentDate.add(const Duration(days: 1)); });
    _fetchDailySchedule();
  }

  Future<void> _selectDate(BuildContext context) async {
     print("Attempting to show DatePicker...");
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(_currentDate.year - 2),
      lastDate: DateTime(_currentDate.year + 2),
      locale: const Locale('nl', 'NL'), // Zorg voor flutter_localizations setup!
    );
     print("DatePicker closed. Picked: $pickedDate");

    if (pickedDate != null && pickedDate != _currentDate) {
       print("New date selected: $pickedDate. Updating state...");
      setState(() {
        _currentDate = pickedDate;
      });
       print("State updated. Fetching schedule...");
      _fetchDailySchedule();
    } else {
        print("Date selection cancelled or same date picked.");
    }
  }

  void _showEmployeeDetailsDialog(BuildContext context, DailyShiftEntry entry) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    final allowedDepartmentNames = entry.allowedDepartmentIds
        .map((id) => _departments[id.toString()]?['name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .toList();
    allowedDepartmentNames.sort();

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(entry.employeeFullName),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                _buildDetailRow(Icons.badge_outlined, "Functiecode:", entry.functionCode ?? "N/B"),
                _buildDetailRow(Icons.person_outline, "Type:", entry.employeeTypeAbbr ?? "N/B"),
                _buildDetailRow(Icons.timer_outlined, "Contract:", entry.formattedWorkingHours),
                if (entry.dailyHours != null && entry.dailyHours! > 0)
                   _buildDetailRow(Icons.hourglass_bottom_outlined, "Gem. daguren:", "${(entry.dailyHours! / 60.0).toStringAsFixed(1)} uur"),
                const SizedBox(height: 10),
                if (allowedDepartmentNames.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children: [
                        Icon(Icons.business_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Mag werken op:', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (allowedDepartmentNames.isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.only(left: 30.0),
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: allowedDepartmentNames.map((name) => Text(
                         '- $name',
                         style: textTheme.bodyMedium,
                       )).toList(),
                     ),
                   ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Sluiten'),
              onPressed: () { Navigator.of(context).pop(); },
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          backgroundColor: colorScheme.surfaceContainerHigh,
        );
      },
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text('$label ', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
              softWrap: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDayNavigator(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDisplayDate = DateFormat('EEE d MMM yyyy', 'nl_NL').format(_currentDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
      child: Material(
        color: colorScheme.surfaceContainer,
        elevation: 1,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Vorige dag',
                onPressed: _isLoading ? null : _goToPreviousDay,
                color: _isLoading ? Colors.grey : colorScheme.onSurface,
              ),
              InkWell(
                 onTap: _isLoading ? null : () => _selectDate(context),
                 child: Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children: [
                       Icon(Icons.calendar_today_outlined, size: 20, color: colorScheme.primary),
                       const SizedBox(width: 8),
                       Text(
                         formattedDisplayDate,
                         style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                       ),
                     ],
                   ),
                 ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right),
                tooltip: 'Volgende dag',
                onPressed: _isLoading ? null : _goToNextDay,
                color: _isLoading ? Colors.grey : colorScheme.onSurface,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String formattedAppBarDate = DateFormat('EEEE d MMMM yyyy', 'nl_NL').format(_currentDate);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Rooster $formattedAppBarDate'),
        actions: [
           IconButton(
             icon: const Icon(Icons.refresh),
             tooltip: 'Verversen',
             onPressed: _isLoading ? null : _fetchDailySchedule,
           ),
        ],
      ),
      body: Column(
         children: [
           _buildDayNavigator(context),
           Expanded(
             child: _buildListArea(context, textTheme, colorScheme),
           ),
         ],
      ),
    );
  }

 Widget _buildListArea(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) {
    if (_isLoading && _displayItems.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text(
                _error!,
                style: TextStyle(color: colorScheme.error, fontSize: 16),
                textAlign: TextAlign.center,
              ),
               const SizedBox(height: 20),
               ElevatedButton.icon(
                 icon: const Icon(Icons.refresh),
                 label: const Text('Opnieuw Proberen'),
                 onPressed: _isLoading ? null : _fetchDailySchedule,
               ),
            ],
          ),
        ),
      );
    }

    if (_displayItems.isEmpty && !_isLoading) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                 const Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey),
                 const SizedBox(height: 16),
                 Text(
                   'Geen werkende collega\'s gevonden voor deze dag.',
                   textAlign: TextAlign.center,
                   style: textTheme.bodyMedium,
                 ),
              ],
           ),
         ),
       );
    }

    return RefreshIndicator(
       onRefresh: _fetchDailySchedule,
       child: ListView.builder(
         padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
         itemCount: _displayItems.length,
         itemBuilder: (context, index) {
           final item = _displayItems[index];

           // --- Render Header ---
           if (item is String) {
             return Padding(
               padding: EdgeInsets.only(
                 top: index == 0 ? 0 : 16.0,
                 bottom: 8.0,
                 left: 8.0,
               ),
               child: Text(
                 item, // Cluster naam
                 style: textTheme.titleMedium?.copyWith(
                   fontWeight: FontWeight.bold,
                   color: colorScheme.primary,
                 ),
               ),
             );
           }
           // --- Render Entry ---
           else if (item is DailyShiftEntry) {
             final entry = item;

             Widget leadingWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text( DailyShiftEntry.formatTime(entry.startTime), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 15), ),
                  Text( DailyShiftEntry.formatTime(entry.endTime), style: textTheme.bodyMedium?.copyWith(fontSize: 13), ),
                ],
             );

             Widget trailingWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text( entry.totalTimeDisplay, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.secondary), ),
                  if (entry.breakDuration > Duration.zero)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text( 'P: ${entry.breakTimeDisplay}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant), ),
                    ),
                ],
             );

             return InkWell(
               onTap: () => _showEmployeeDetailsDialog(context, entry),
               borderRadius: BorderRadius.circular(12.0),
               child: Card(
                 margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                 clipBehavior: Clip.antiAlias,
                 child: ListTile(
                   contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                   leading: leadingWidget,
                   title: Text( entry.employeeFullName, style: textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w500), ),
                   subtitle: Padding(
                     padding: const EdgeInsets.only(top: 4.0),
                     child: Text( entry.departmentName, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), maxLines: 1, overflow: TextOverflow.ellipsis, ),
                   ),
                   trailing: trailingWidget,
                   dense: true,
                 ),
               ),
             );
           }
           return const SizedBox.shrink();
         },
       ),
    );
  }
}