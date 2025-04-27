// lib/screens/daily_schedule_screen.dart
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

// Model voor een dagelijkse dienst entry
class DailyShiftEntry
{
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
  // Extra velden voor details dialog
  final String? employeeTypeAbbr;
  final double? workingHours; // Contracturen (in minuten)
  final double? dailyHours;   // Gemiddelde daguren (in minuten)
  final List<int> allowedDepartmentIds; // IDs van afdelingen waar men mag werken

  DailyShiftEntry(
  {
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
  static String formatDuration(Duration duration)
  {
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes";
  }

  // Veilige parse functies
  static int? _parseInt(dynamic v)
  {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is num) return v.toInt();
    print("Parse Int Error: Unexpected type ${v.runtimeType} for value $v");
    return null;
  }
  static double? _parseDouble(dynamic v)
  {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    if (v is num) return v.toDouble();
    print("Parse Double Error: Unexpected type ${v.runtimeType} for value $v");
    return null;
  }
  static bool _parseBool(dynamic v)
  {
    if (v == null) return false;
    if (v is bool) return v;
    if (v is String) return v.toLowerCase() == 'true' || v == '1';
    if (v is num) return v != 0;
    return false;
  }
  static num? _parseNum(dynamic v)
  {
    if (v == null) return null;
    if (v is num) return v;
    if (v is String) return num.tryParse(v);
    print("Parse Num Error: Unexpected type ${v.runtimeType} for value $v");
    return null;
  }

  // --- Getters ---
  String get formattedWorkingHours
  {
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
    )
  {
    try
    {
      final int? entryId = _parseInt(entryData['id']);
      final int? sM = _parseInt(entryData['startTime']);
      final int? eM = _parseInt(entryData['endTime']);
      final int? dId = _parseInt(entryData['departmentId']);
      final int? cId = _parseInt(entryData['hourCodeId']);
      final num? bN = _parseNum(entryData['breakTime']);
      final num? tN = _parseNum(entryData['totalTime']);
      // Aanwezigheid bepalen: via expliciet veld OF via aanwezigheidscode ID
      final bool isPres = _parseBool(entryData['isPresence']) || (cId != null && presenceCodeIds.contains(cId));

      if (entryId == null || sM == null || eM == null || dId == null || cId == null)
      {
        print("DailyShiftEntry parse fail (basic fields missing/invalid): $entryData");
        return null;
      }

      final TimeOfDay sT = _minutesToTimeOfDay(sM);
      final TimeOfDay eT = _minutesToTimeOfDay(eM);
      final Duration bD = Duration(minutes: bN?.toInt() ?? 0);
      final Duration tD = Duration(minutes: tN?.toInt() ?? 0);
      final String depN = allDepartments[dId.toString()]?['name'] ?? 'Afd $dId?';
      final String codeN = allHourCodes[cId.toString()]?['name'] ?? 'Type $cId?';

      // Employee details ophalen
      final String employeeName = empDetails['text'] ?? 'Onbekende Medewerker ($empId)';
      final String? funcCode = empDetails['functionCode'];
      final String? empTypeAbbr = empDetails['employeeTypeAbbr'];

      // Contract details ophalen (kunnen null zijn)
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
    }
    catch (e, s)
    {
      print("DailyShiftEntry JSON parsing error: $e\nStacktrace: $s\nEntry data: $entryData");
      return null;
    }
  }
}

class DailyScheduleScreen extends StatefulWidget
{
  final String authToken;
  final String nodeId;
  final DateTime selectedDate; // Startdatum

  const DailyScheduleScreen(
  {
    super.key,
    required this.authToken,
    required this.nodeId,
    required this.selectedDate,
  });

  @override
  State<DailyScheduleScreen> createState() => _DailyScheduleScreenState();
}

class _DailyScheduleScreenState extends State<DailyScheduleScreen>
{
  bool _isLoading = true;
  String? _error;
  List<dynamic> _displayItems = []; // Kan Strings (headers) of DailyShiftEntry bevatten
  Map<String, dynamic> _departments = {};
  Map<String, dynamic> _hourCodes = {};
  List<int> _presenceCodeIds = [];
  late DateTime _currentDate;

  // Functiecodes die als 'Management' worden beschouwd
  final Set<String> _managementFunctionCodes = {'BM', 'ABM'};

  // Handmatige mapping van medewerker naam naar cluster
  // TODO: Overweeg dit extern te configureren of via API te verkrijgen indien mogelijk
  final Map<String, String> _employeeClusterMapping =
  {
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
    "Weide, Eric, van der": "Kassa/Balie",
    "Johanns, Ingeborg": "Kassa/Balie",
    "Raja, Nima": "Kassa/Balie",
    "Kruiper, Julie": "Kassa/Balie",
    "Nouland, Sofie, van den": "Kassa/Balie",
    "Nijland -  Kahmann, Sandra": "Kassa/Balie",
    "Wubbels -  Grimbergen, Eefje": "Kassa/Balie",

    // Achtercluster
    "Adema, Jasper": "Achtercluster",
    "Oomkens, Laurens": "Achtercluster",
    "Zwart, Ricardo": "Achtercluster",
    "Witteveen, Stijn": "Achtercluster",
    "Akkerman, Bart": "Achtercluster",
    "Petter, Mike": "Achtercluster",
    "Blansch, Rene, Le": "Achtercluster",
    "Huijboom, Matteo": "Achtercluster",
  };

  // Gewenste volgorde van de clusters in de UI
  final List<String> _clusterOrder =
  [
    "Management",
    "Voorcluster",
    "Kassa/Balie",
    "Achtercluster",
    "Overige Medewerkers" // Fallback cluster
  ];

  final String _apiBaseUrl = 'https://server.manus.plus/intergamma/api/node/';
  final String _userAgent = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  @override
  void initState()
  {
    super.initState();
    _currentDate = widget.selectedDate;
    _fetchDailySchedule();
  }

  String _buildDailyScheduleUrl(String nodeId, DateTime date)
  {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    // Haalt schedule op voor specifieke node en datum. departmentId=-1 voor alle afdelingen.
    // scheduledOnly=false om ook niet-geplande (maar wel aanwezige) entries te zien.
    return '$_apiBaseUrl$nodeId/schedule/$formattedDate?departmentId=-1&scheduledOnly=false';
  }

  Future<void> _fetchDailySchedule() async
  {
    print("[API Daily] Fetching schedule for $_currentDate");
    if (!mounted) return;

    setState(()
    {
      _isLoading = true;
      _error = null;
      // Behoud oude items tijdens laden voor betere UX, tenzij er nog geen zijn.
      if (_displayItems.isEmpty)
      {
        _displayItems = [];
      }
    });

    final url = _buildDailyScheduleUrl(widget.nodeId, _currentDate);

    try
    {
      final response = await http.get(
        Uri.parse(url),
        headers:
        {
          'Authorization': 'Bearer ${widget.authToken}',
          'User-Agent': _userAgent,
          'Accept': 'application/json',
          'X-Application-Type': 'employee', // Belangrijk voor deze API endpoint
          'Origin': 'https://ess.manus.plus',
          'Referer': 'https://ess.manus.plus/',
        },
      );

      print("[API Daily] Status: ${response.statusCode} for $_currentDate");
      if (!mounted) return;

      if (response.statusCode >= 200 && response.statusCode < 300)
      {
        // Gebruik utf8.decode om eventuele encoding issues te voorkomen
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>)
        {
           print("[API Daily] Parsing data for $_currentDate");
          _parseAndGroupDailyData(data);
           print("[API Daily] Finished parsing for $_currentDate");
        }
        else
        {
          setState(()
          {
            _error = "Ongeldige data ontvangen van server.";
            _displayItems = []; // Leegmaken bij ongeldige data
          });
        }
      }
      else
      {
         // Probeer een specifiekere foutmelding te geven
         String errorMsg = "Fout bij ophalen (${response.statusCode})";
         try
         {
           final b = jsonDecode(response.body);
           errorMsg = b['message'] ?? errorMsg;
         }
         catch (e)
         {
           // Body was geen JSON of bevatte geen message
         }

         if (response.statusCode == 401 || response.statusCode == 403)
         {
           errorMsg = "Sessie verlopen of geen toegang. Ga terug en log opnieuw in.";
         }
         else if (response.statusCode == 404)
         {
           errorMsg = "Rooster niet gevonden voor deze dag (404).";
         }
         else if (response.statusCode == 500)
         {
           errorMsg = "Interne serverfout (500). Probeer het later opnieuw.";
         }
         setState(()
         {
           _error = errorMsg;
           _displayItems = []; // Leegmaken bij fout
         });
      }
    }
    catch (e, s)
    {
      print('[API Daily] Network/Parsing Error: $e\n$s');
      if (mounted)
      {
        setState(()
        {
          _error = 'Netwerkfout of dataverwerkingsfout: $e';
          _displayItems = []; // Leegmaken bij fout
        });
      }
    }
    finally
    {
      if (mounted)
      {
        setState(()
        {
          _isLoading = false;
        });
         print("[API Daily] UI update finished for $_currentDate");
      }
    }
  }

  // Verwerkt de ontvangen data en groepeert medewerkers per cluster
  void _parseAndGroupDailyData(Map<String, dynamic> data)
  {
     print("[PARSE] Starting data parsing and grouping...");
    // Haal de benodigde data secties op, met null checks
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

    // Initialiseer de map voor gegroepeerde entries gebaseerd op de gewenste volgorde
    final Map<String, List<DailyShiftEntry>> groupedEntries = {};
    for (var clusterName in _clusterOrder)
    {
      groupedEntries[clusterName] = [];
    }
    // Zorg dat de fallback cluster altijd bestaat
    groupedEntries.putIfAbsent("Overige Medewerkers", () => []);

    int totalPresenceEntries = 0;

    // Itereer over alle medewerkers in de response
    employeesMap.forEach((employeeId, employeeData)
    {
      if (employeeData is! Map<String, dynamic>)
      {
         print("[PARSE] Skipping employeeId $employeeId: employeeData is not a Map.");
         return; // Ga naar de volgende medewerker
      }

      final scheduleInfo = scheduleMap[employeeId] as Map<String, dynamic>?;
      final contractInfo = contractsMap[employeeId] as Map<String, dynamic>?;

      // Controleer of er rooster entries zijn voor deze medewerker
      if (scheduleInfo != null)
      {
        final List<dynamic>? entries = scheduleInfo['entries'] as List<dynamic>?;

        if (entries != null && entries.isNotEmpty)
        {
          // Verwerk elke rooster entry voor de medewerker
          for (var entryItem in entries)
          {
             if (entryItem is Map<String, dynamic>)
             {
                final entryData = entryItem;

                // Probeer de entry te parsen naar een DailyShiftEntry object
                final dailyEntry = DailyShiftEntry.fromJson(
                    entryData, employeeId, employeeData, contractInfo, _departments, _hourCodes, _presenceCodeIds);

                // Voeg alleen toe als het een geldige entry is EN als het een aanwezigheidsdienst is
                if (dailyEntry != null && dailyEntry.isPresence)
                {
                  totalPresenceEntries++;
                  String clusterName = "Overige Medewerkers"; // Default cluster

                  // Bepaal cluster: eerst op functiecode (management), dan op naam mapping
                  if (dailyEntry.functionCode != null && _managementFunctionCodes.contains(dailyEntry.functionCode))
                  {
                    clusterName = "Management";
                  }
                  else if (_employeeClusterMapping.containsKey(dailyEntry.employeeFullName))
                  {
                    clusterName = _employeeClusterMapping[dailyEntry.employeeFullName]!;
                  }

                  // Voeg toe aan de juiste cluster (maak aan indien niet in _clusterOrder)
                  groupedEntries.putIfAbsent(clusterName, ()
                  {
                     print("[PARSE] Warning: Cluster '$clusterName' from mapping/function was not pre-initialized in _clusterOrder. Adding dynamically.");
                     return [];
                  }).add(dailyEntry);

                }
                else if (dailyEntry == null)
                {
                   print("[PARSE] Failed to parse entry for employee $employeeId: $entryData");
                }
                // else: entry is not a presence entry, skip
             }
             else
             {
                print("[PARSE] Skipping entry for employee $employeeId: entry item is not a Map.");
             }
          }
        }
      }
    });

    // Sorteer de entries binnen elke cluster op starttijd, dan op naam
    final sortLogic = (DailyShiftEntry a, DailyShiftEntry b)
    {
      int startComp = (a.startTime.hour * 60 + a.startTime.minute).compareTo(b.startTime.hour * 60 + b.startTime.minute);
      if (startComp != 0) return startComp;
      return a.employeeFullName.compareTo(b.employeeFullName);
    };
    groupedEntries.values.forEach((list) => list.sort(sortLogic));

    // Bouw de uiteindelijke lijst voor de UI (_displayItems) op
    final List<dynamic> newDisplayItems = [];
    // Voeg eerst clusters toe in de gedefinieerde volgorde
    for (var clusterName in _clusterOrder)
    {
       final entriesForCluster = groupedEntries[clusterName];
       if (entriesForCluster != null && entriesForCluster.isNotEmpty)
       {
          newDisplayItems.add(clusterName); // Voeg header toe
          newDisplayItems.addAll(entriesForCluster); // Voeg entries toe
       }
    }
    // Voeg eventuele overige (dynamisch gevonden) clusters toe aan het einde
    groupedEntries.forEach((clusterName, entries)
    {
       if (!_clusterOrder.contains(clusterName) && entries.isNotEmpty)
       {
          print("[PARSE] Adding dynamically found cluster '$clusterName' to the end of the display list.");
          newDisplayItems.add(clusterName);
          newDisplayItems.addAll(entries);
       }
    });

    // Update de state met de nieuwe lijst
    _displayItems = newDisplayItems;

    // Update de error state als er geen entries zijn gevonden
    if (totalPresenceEntries == 0 && _error == null)
    {
       _error = 'Geen werkende collega\'s gevonden voor deze dag.';
    }
    else if (totalPresenceEntries > 0)
    {
       // Verwijder de 'geen collega's' error als er nu wel collega's zijn (bv. na refresh)
       if (_error == 'Geen werkende collega\'s gevonden voor deze dag.')
       {
          _error = null;
       }
    }
     print("[PARSE] Finished parsing and grouping. Display items count: ${_displayItems.length}");
  }

  void _goToPreviousDay()
  {
    setState(()
    {
      _currentDate = _currentDate.subtract(const Duration(days: 1));
    });
    _fetchDailySchedule();
  }

  void _goToNextDay()
  {
    setState(()
    {
      _currentDate = _currentDate.add(const Duration(days: 1));
    });
    _fetchDailySchedule();
  }

  Future<void> _selectDate(BuildContext context) async
  {
     print("Opening DatePicker...");
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _currentDate,
      firstDate: DateTime(_currentDate.year - 2), // Sta 2 jaar terug toe
      lastDate: DateTime(_currentDate.year + 2),  // Sta 2 jaar vooruit toe
      locale: const Locale('nl', 'NL'), // Zorg voor flutter_localizations setup in main.dart!
    );
     print("DatePicker closed. Picked date: $pickedDate");

    if (pickedDate != null && pickedDate != _currentDate)
    {
       print("New date selected: $pickedDate. Updating state and fetching schedule...");
      setState(()
      {
        _currentDate = pickedDate;
      });
      _fetchDailySchedule();
    }
    else
    {
        print("Date selection cancelled or same date picked.");
    }
  }

  void _showEmployeeDetailsDialog(BuildContext context, DailyShiftEntry entry)
  {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    // Zoek de namen van toegestane afdelingen op
    final allowedDepartmentNames = entry.allowedDepartmentIds
        .map((id) => _departments[id.toString()]?['name'] as String?)
        .where((name) => name != null && name.isNotEmpty)
        .toList();
    allowedDepartmentNames.sort(); // Sorteer alfabetisch

    showDialog(
      context: context,
      builder: (BuildContext context)
      {
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
                // Toon toegestane afdelingen alleen als ze er zijn
                if (allowedDepartmentNames.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4.0),
                    child: Row(
                      children:
                      [
                        Icon(Icons.business_outlined, size: 18, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Mag werken op:', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                if (allowedDepartmentNames.isNotEmpty)
                   Padding(
                     padding: const EdgeInsets.only(left: 30.0), // Inspringen voor lijst
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
              onPressed: ()
              {
                Navigator.of(context).pop();
              },
            ),
          ],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          backgroundColor: colorScheme.surfaceContainerHigh, // Iets lichtere achtergrond voor dialog
        );
      },
    );
  }

  // Helper widget voor een detail rij in de dialog
  Widget _buildDetailRow(IconData icon, String label, String value)
  {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
        [
          Icon(icon, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          Text('$label ', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold)),
          Expanded(
            child: Text(
              value,
              style: textTheme.bodyMedium,
              softWrap: true, // Zorgt voor tekst-terugloop indien nodig
            ),
          ),
        ],
      ),
    );
  }

  // Bouwt de navigatiebalk voor dagen
  Widget _buildDayNavigator(BuildContext context)
  {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    // Formatteer de datum voor weergave (bv. "Ma 1 Jan 2024")
    final formattedDisplayDate = DateFormat('EEE d MMM yyyy', 'nl_NL').format(_currentDate);

    return Padding(
      padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 0),
      child: Material(
        color: colorScheme.surfaceContainer, // Gebruik themakleur
        elevation: 1,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:
            [
              IconButton(
                icon: const Icon(Icons.chevron_left),
                tooltip: 'Vorige dag',
                // Disable knop tijdens laden
                onPressed: _isLoading ? null : _goToPreviousDay,
                color: _isLoading ? Colors.grey : colorScheme.onSurface,
              ),
              // Maak de datum klikbaar om de date picker te openen
              InkWell(
                 onTap: _isLoading ? null : () => _selectDate(context),
                 child: Padding(
                   padding: const EdgeInsets.symmetric(vertical: 8.0),
                   child: Row(
                     mainAxisSize: MainAxisSize.min,
                     children:
                     [
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
                // Disable knop tijdens laden
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
  Widget build(BuildContext context)
  {
    // Formatteer datum voor de AppBar titel (bv. "Maandag 1 januari 2024")
    final String formattedAppBarDate = DateFormat('EEEE d MMMM yyyy', 'nl_NL').format(_currentDate);
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text('Rooster $formattedAppBarDate'),
        actions:
        [
           IconButton(
             icon: const Icon(Icons.refresh),
             tooltip: 'Verversen',
             // Disable knop tijdens laden
             onPressed: _isLoading ? null : _fetchDailySchedule,
           ),
        ],
      ),
      body: Column(
         children:
         [
           _buildDayNavigator(context), // De dag navigatie bovenaan
           Expanded(
             // Het gebied waar de lijst of de lader/error wordt getoond
             child: _buildListArea(context, textTheme, colorScheme),
           ),
         ],
      ),
    );
  }

 // Bouwt het hoofdgedeelte van de body: lijst, lader of foutmelding
 Widget _buildListArea(BuildContext context, TextTheme textTheme, ColorScheme colorScheme)
 {
    // Toon lader alleen als we laden EN er nog geen items zijn
    if (_isLoading && _displayItems.isEmpty)
    {
      return const Center(child: CircularProgressIndicator());
    }

    // Toon foutmelding als die er is
    if (_error != null)
    {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:
            [
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

    // Toon melding als er geen items zijn (en niet aan het laden of error)
    if (_displayItems.isEmpty && !_isLoading)
    {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children:
              [
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

    // Toon de lijst met items (headers en entries)
    return RefreshIndicator(
       onRefresh: _fetchDailySchedule, // Pull-to-refresh functionaliteit
       child: ListView.builder(
         padding: const EdgeInsets.fromLTRB(8.0, 8.0, 8.0, 8.0),
         itemCount: _displayItems.length,
         itemBuilder: (context, index)
         {
           final item = _displayItems[index];

           // Render Cluster Header (als item een String is)
           if (item is String)
           {
             return Padding(
               padding: EdgeInsets.only(
                 top: index == 0 ? 0 : 16.0, // Extra ruimte boven headers, behalve de eerste
                 bottom: 8.0,
                 left: 8.0, // Kleine indent voor header
               ),
               child: Text(
                 item, // Cluster naam
                 style: textTheme.titleMedium?.copyWith(
                   fontWeight: FontWeight.bold,
                   color: colorScheme.primary, // Gebruik primaire kleur voor headers
                 ),
               ),
             );
           }
           // Render Rooster Entry (als item een DailyShiftEntry is)
           else if (item is DailyShiftEntry)
           {
             final entry = item;

             // Widget voor de start- en eindtijd (links)
             Widget leadingWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children:
                [
                  Text( DailyShiftEntry.formatTime(entry.startTime), style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 15), ),
                  Text( DailyShiftEntry.formatTime(entry.endTime), style: textTheme.bodyMedium?.copyWith(fontSize: 13), ),
                ],
             );

             // Widget voor de totale tijd en pauze (rechts)
             Widget trailingWidget = Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children:
                [
                  Text( entry.totalTimeDisplay, style: textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.secondary), ), // Gebruik secundaire kleur
                  // Toon pauze alleen als deze groter is dan 0
                  if (entry.breakDuration > Duration.zero)
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Text( 'P: ${entry.breakTimeDisplay}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant), ), // Subtiele kleur voor pauze
                    ),
                ],
             );

             // Maak de hele kaart klikbaar voor details
             return InkWell(
               onTap: () => _showEmployeeDetailsDialog(context, entry),
               borderRadius: BorderRadius.circular(12.0), // Match Card shape
               child: Card(
                 margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
                 clipBehavior: Clip.antiAlias, // Voorkomt dat inhoud buiten de ronding valt
                 child: ListTile(
                   contentPadding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
                   leading: leadingWidget,
                   title: Text( entry.employeeFullName, style: textTheme.titleMedium?.copyWith(fontSize: 15, fontWeight: FontWeight.w500), ),
                   subtitle: Padding(
                     padding: const EdgeInsets.only(top: 4.0),
                     child: Text(
                       entry.departmentName, // Toon afdeling als subtitel
                       style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),
                       maxLines: 1,
                       overflow: TextOverflow.ellipsis, // Voorkom te lange afdelingsnamen
                     ),
                   ),
                   trailing: trailingWidget,
                   dense: true, // Maakt de ListTile iets compacter
                 ),
               ),
             );
           }
           // Fallback voor onverwachte item types (zou niet moeten gebeuren)
           return const SizedBox.shrink();
         },
       ),
    );
  }
}