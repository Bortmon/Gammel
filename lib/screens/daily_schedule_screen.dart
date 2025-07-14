import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

import '../widgets/custom_bottom_nav_bar.dart';
import 'scanner_screen.dart';

class DailyShiftEntry
{
  final int id;
  final String employeeId;
  final String employeeFullName;
  final TimeOfDay startTime;
  final TimeOfDay endTime;
  final Duration breakDuration;
  final Duration totalDuration;
  final String departmentName;
  final String hourCodeName;
  final bool isPresence;
  final String? functionCode;
  final String? employeeTypeAbbr;
  final double? workingHours;
  final double? dailyHours;
  final List<int> allowedDepartmentIds;

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

  static TimeOfDay _minutesToTimeOfDay(int m) 
  {
    return TimeOfDay(hour: m ~/ 60, minute: m % 60);
  }

  static String formatTime(TimeOfDay time) 
  {
    return "${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}";
  }

  static String formatDuration(Duration duration)
  {
    String twoDigits(int n) 
    {
      return n.toString().padLeft(2, "0");
    }
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60).abs());
    return "${twoDigits(duration.inHours)}:$twoDigitMinutes";
  }

  static int? _parseInt(dynamic v)
  {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v);
    if (v is num) return v.toInt();
    return null;
  }

  static double? _parseDouble(dynamic v)
  {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    if (v is String) return double.tryParse(v);
    if (v is num) return v.toDouble();
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
    return null;
  }

  String get formattedWorkingHours
  {
    if (workingHours == null || workingHours! <= 0) return "N/B";
    double hoursPerWeek = workingHours! / 60.0;
    return "${hoursPerWeek.toStringAsFixed(1)} uur/week";
  }

  String get timeRangeDisplay 
  {
    return '${formatTime(startTime)} - ${formatTime(endTime)}';
  }

  String get breakTimeDisplay 
  {
    return formatDuration(breakDuration);
  }

  String get totalTimeDisplay 
  {
    return formatDuration(totalDuration);
  }

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
      final bool isPres = _parseBool(entryData['isPresence']) || (cId != null && presenceCodeIds.contains(cId));

      if (entryId == null || sM == null || eM == null || dId == null || cId == null)
      {
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
    }
    catch (e, s)
    {
      return null;
    }
  }
}

class DailyScheduleScreen extends StatefulWidget 
{
  final String authToken;
  final String nodeId;
  final DateTime selectedDate;

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

class _DailyScheduleScreenState extends State<DailyScheduleScreen> with TickerProviderStateMixin 
{
  bool _isLoading = true;
  String? _error;
  List<dynamic> _displayItems = [];
  Map<String, dynamic> _departmentsFromApi = {};
  Map<String, dynamic> _hourCodes = {};
  List<int> _presenceCodeIds = [];
  late DateTime _currentDate;

  List<String> _availableDepartmentFilters = ["All"];
  String _selectedDepartmentFilter = "All";

  final Set<String> _managementFunctionCodes = {'BM', 'ABM'};
  final Map<String, String> _employeeClusterMapping = 
  {
    "Bakker, Jaimy": "Management", "Kliek, Twan": "Management",
    "Fiechter, Gertjan": "Voorcluster", "Bakker, Mandy": "Voorcluster",
    "Kamps, Karin": "Voorcluster", "Post-Portegies, Manon": "Voorcluster",
    "Navrozoglou, Loukas": "Voorcluster", "Posch, Swen": "Voorcluster",
    "Hoogenboom, Thijs": "Voorcluster", "Sikman, Maxim": "Kassa/Balie",
    "Keijzer, Riley": "Kassa/Balie", "Diercks-van Bruggen, Pauline": "Kassa/Balie",
    "Koning, Bo": "Kassa/Balie", "Saat, Lidia": "Kassa/Balie",
    "Weide, Eric, van der": "Kassa/Balie", "Johanns, Ingeborg": "Kassa/Balie",
    "Raja, Nima": "Kassa/Balie", "Kruiper, Julie": "Kassa/Balie",
    "Nouland, Sofie, van den": "Kassa/Balie", "Nijland -  Kahmann, Sandra": "Kassa/Balie",
    "Wubbels -  Grimbergen, Eefje": "Kassa/Balie", "Adema, Jasper": "Achtercluster",
    "Oomkens, Laurens": "Achtercluster", "Zwart, Ricardo": "Achtercluster",
    "Witteveen, Stijn": "Achtercluster", "Akkerman, Bart": "Achtercluster",
    "Petter, Mike": "Achtercluster", "Blansch, Rene, Le": "Achtercluster",
    "Huijboom, Matteo": "Achtercluster",
  };
  final List<String> _clusterOrder = 
  [
    "Management", "Voorcluster", "Kassa/Balie",
    "Achtercluster", "Overige Medewerkers"
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

  @override
  void dispose() 
  {
    super.dispose();
  }

  String _buildDailyScheduleUrl(String nodeId, DateTime date) 
  {
    final formattedDate = DateFormat('yyyy-MM-dd').format(date);
    return '$_apiBaseUrl$nodeId/schedule/$formattedDate?departmentId=-1&scheduledOnly=false';
  }

  Future<void> _fetchDailySchedule() async 
  {
    if (!mounted) return;
    setState(() 
    {
      _isLoading = true;
      _error = null;
      if (_selectedDepartmentFilter == "All") 
      {
         _displayItems = [];
      }
    });

    final url = _buildDailyScheduleUrl(widget.nodeId, _currentDate);
    try 
    {
      final response = await http.get( Uri.parse(url),
        headers: {
          'Authorization': 'Bearer ${widget.authToken}', 'User-Agent': _userAgent,
          'Accept': 'application/json', 'X-Application-Type': 'employee',
          'Origin': 'https://ess.manus.plus', 'Referer': 'https://ess.manus.plus/',
        },
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) 
      {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        if (data is Map<String, dynamic>) 
        {
          _parseAndGroupDailyData(data);
        } 
        else 
        {
          setState(() { _error = "Ongeldige data ontvangen van server."; _displayItems = []; });
        }
      } 
      else 
      {
         String errorMsg = "Fout bij ophalen (${response.statusCode})";
         try { final b = jsonDecode(response.body); errorMsg = b['message'] ?? errorMsg; } catch (e) {}
         if (response.statusCode == 401 || response.statusCode == 403) errorMsg = "Sessie verlopen. Log opnieuw in.";
         else if (response.statusCode == 404) errorMsg = "Rooster niet gevonden voor deze dag (404).";
         else if (response.statusCode == 500) errorMsg = "Serverfout (500).";
         setState(() { _error = errorMsg; _displayItems = []; });
      }
    } 
    catch (e) 
    {
      if (mounted) setState(() { _error = 'Netwerkfout: $e'; _displayItems = []; });
    } 
    finally 
    {
      if (mounted) setState(() { _isLoading = false; });
    }
  }

  void _parseAndGroupDailyData(Map<String, dynamic> data) 
  {
    final Map<String, dynamic> scheduleMap = data['schedule'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> employeesMap = data['employees'] as Map<String, dynamic>? ?? {};
    final Map<String, dynamic> contractsMap = data['employeesContract'] as Map<String, dynamic>? ?? {};
    _departmentsFromApi = data['departments'] as Map<String, dynamic>? ?? {};
    _hourCodes = data['hourCodes'] as Map<String, dynamic>? ?? {};
    _presenceCodeIds = (data['presenceCodes'] as List<dynamic>? ?? [])
        .map((code) => DailyShiftEntry._parseInt(code)).where((id) => id != null).cast<int>().toList();

    final Set<String> uniqueDepartmentNamesInSchedule = {"All"};
    final Map<String, List<DailyShiftEntry>> groupedEntries = {};
    _clusterOrder.forEach((cn) => groupedEntries[cn] = []);
    groupedEntries.putIfAbsent("Overige Medewerkers", () => []);
    int totalPresenceEntries = 0;

    employeesMap.forEach((employeeId, employeeData) 
    {
      if (employeeData is! Map<String, dynamic>) return;
      final scheduleInfo = scheduleMap[employeeId] as Map<String, dynamic>?;
      final contractInfo = contractsMap[employeeId] as Map<String, dynamic>?;
      if (scheduleInfo == null) return;
      final List<dynamic>? entries = scheduleInfo['entries'] as List<dynamic>?;
      if (entries == null || entries.isEmpty) return;

      for (var entryItem in entries) 
      {
         if (entryItem is! Map<String, dynamic>) continue;
         final dailyEntry = DailyShiftEntry.fromJson(entryItem, employeeId, employeeData, contractInfo, _departmentsFromApi, _hourCodes, _presenceCodeIds);
         if (dailyEntry == null || !dailyEntry.isPresence) continue;
         
         uniqueDepartmentNamesInSchedule.add(dailyEntry.departmentName);
         if (_selectedDepartmentFilter != "All" && dailyEntry.departmentName != _selectedDepartmentFilter) continue;
         
         totalPresenceEntries++;
         String clusterName = "Overige Medewerkers"; 
         if (dailyEntry.functionCode != null && _managementFunctionCodes.contains(dailyEntry.functionCode)) clusterName = "Management";
         else if (_employeeClusterMapping.containsKey(dailyEntry.employeeFullName)) clusterName = _employeeClusterMapping[dailyEntry.employeeFullName]!;
         groupedEntries.putIfAbsent(clusterName, () => []).add(dailyEntry);
      }
    });
    
    List<String> sortedDepartments = uniqueDepartmentNamesInSchedule.where((name) => name != "All").toList()..sort();
    _availableDepartmentFilters = ["All"] + sortedDepartments;

    final sortLogic = (DailyShiftEntry a, DailyShiftEntry b) 
    {
      int startComp = (a.startTime.hour * 60 + a.startTime.minute).compareTo(b.startTime.hour * 60 + b.startTime.minute);
      if (startComp != 0) return startComp;
      return a.employeeFullName.compareTo(b.employeeFullName);
    };
    groupedEntries.values.forEach((list) => list.sort(sortLogic));

    final List<dynamic> newDisplayItems = [];
    _clusterOrder.forEach((cn) 
    {
       final entries = groupedEntries[cn];
       if (entries != null && entries.isNotEmpty) { newDisplayItems.add(cn); newDisplayItems.addAll(entries); }
    });
    groupedEntries.forEach((cn, entries) 
    {
       if (!_clusterOrder.contains(cn) && entries.isNotEmpty) { newDisplayItems.add(cn); newDisplayItems.addAll(entries); }
    });
    
    if(mounted)
    {
      setState(() 
      {
        _displayItems = newDisplayItems;
        if (totalPresenceEntries == 0 && _error == null) 
        {
          _error = 'Geen collega\'s gevonden${_selectedDepartmentFilter != "All" ? " op afd. $_selectedDepartmentFilter" : " voor deze dag"}.';
        } 
        else if (totalPresenceEntries > 0 && _error != null && _error!.contains('Geen collega\'s gevonden')) 
        {
          _error = null;
        }
      });
    }
  }

  void _goToPreviousDay() 
  {
    setState(() { _currentDate = _currentDate.subtract(const Duration(days: 1)); _selectedDepartmentFilter = "All"; });
    _fetchDailySchedule();
  }

  void _goToNextDay() 
  {
    setState(() { _currentDate = _currentDate.add(const Duration(days: 1)); _selectedDepartmentFilter = "All"; });
    _fetchDailySchedule();
  }

  Future<void> _selectDate(BuildContext context) async 
  {
    final DateTime? pickedDate = await showDatePicker(
      context: context, initialDate: _currentDate,
      firstDate: DateTime(_currentDate.year - 2), lastDate: DateTime(_currentDate.year + 2),
      locale: const Locale('nl', 'NL'),
    );
    if (pickedDate != null && pickedDate != _currentDate) 
    {
      setState(() { _currentDate = pickedDate; _selectedDepartmentFilter = "All"; });
      _fetchDailySchedule();
    }
  }

  void _showEmployeeDetailsDialog(BuildContext context, DailyShiftEntry entry) 
  {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final allowedDepartmentNames = entry.allowedDepartmentIds
        .map((id) => _departmentsFromApi[id.toString()]?['name'] as String?)
        .where((name) => name != null && name.isNotEmpty).toList()..sort();

    showDialog( context: context, builder: (BuildContext context) 
    {
        return AlertDialog(
          backgroundColor: colorScheme.surfaceContainerHigh,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
          title: Text(entry.employeeFullName, style: textTheme.titleLarge?.copyWith(color: colorScheme.onSurface)),
          content: SingleChildScrollView( child: ListBody( children: <Widget>[
                _buildDetailRow(Icons.badge_outlined, "Functiecode:", entry.functionCode ?? "N/B"),
                _buildDetailRow(Icons.person_outline, "Type:", entry.employeeTypeAbbr ?? "N/B"),
                _buildDetailRow(Icons.timer_outlined, "Contract:", entry.formattedWorkingHours),
                if (entry.dailyHours != null && entry.dailyHours! > 0)
                   _buildDetailRow(Icons.hourglass_bottom_outlined, "Gem. daguren:", "${(entry.dailyHours! / 60.0).toStringAsFixed(1)} uur"),
                const SizedBox(height: 10),
                if (allowedDepartmentNames.isNotEmpty)
                  Padding( padding: const EdgeInsets.only(bottom: 4.0), child: Row( children: [
                        Icon(Icons.business_outlined, size: 18, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Text('Mag werken op:', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
                      ],),),
                if (allowedDepartmentNames.isNotEmpty)
                   Padding( padding: const EdgeInsets.only(left: 30.0), child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: allowedDepartmentNames.map((name) => Text('- $name', style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),)).toList(),),),
              ],),),
          actions: <Widget>[ TextButton(child: Text('Sluiten', style: TextStyle(color: colorScheme.primary)), onPressed: () => Navigator.of(context).pop(),),],
        );
    });
  }

  Widget _buildDetailRow(IconData icon, String label, String value) 
  {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Padding( padding: const EdgeInsets.symmetric(vertical: 4.0), child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 18, color: colorScheme.primary),
          const SizedBox(width: 12),
          Text('$label ', style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurfaceVariant)),
          Expanded(child: Text(value, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant), softWrap: true,)),],),);
  }

  Widget _buildDayNavigator(BuildContext context) 
  {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    final formattedDisplayDate = DateFormat('EEEE, MMMM d, yyyy', 'nl_NL').format(_currentDate);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 10.0),
      color: colorScheme.surface, 
      child: Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          IconButton( icon: Icon(Icons.chevron_left, color: colorScheme.onSurfaceVariant, size: 28), tooltip: 'Vorige dag', onPressed: _isLoading ? null : _goToPreviousDay,),
          InkWell( onTap: _isLoading ? null : () => _selectDate(context), borderRadius: BorderRadius.circular(8.0),
             child: Padding( padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), child: Row( mainAxisSize: MainAxisSize.min, children: [
                 Icon(Icons.calendar_today_outlined, size: 20, color: colorScheme.primary),
                 const SizedBox(width: 10),
                 Text( formattedDisplayDate, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w500, color: colorScheme.onSurface, fontSize: 15),),],),),),
          IconButton( icon: Icon(Icons.chevron_right, color: colorScheme.onSurfaceVariant, size: 28), tooltip: 'Volgende dag', onPressed: _isLoading ? null : _goToNextDay,),],),);
  }

  Widget _buildDepartmentFilterTabs(BuildContext context) 
  {
    final ColorScheme clr = Theme.of(context).colorScheme;
    final TextTheme txt = Theme.of(context).textTheme;

    if (_availableDepartmentFilters.length <= 1 && _availableDepartmentFilters.contains("All")) 
    {
      return const SizedBox(height: 12); 
    }

    return Container(
      height: 52, 
      color: clr.surface, 
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12.0),
        itemCount: _availableDepartmentFilters.length,
        itemBuilder: (context, index) 
        {
          final departmentName = _availableDepartmentFilters[index];
          final bool isSelected = departmentName == _selectedDepartmentFilter;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0),
            child: FilterChip(
              label: Text(departmentName),
              selected: isSelected,
              onSelected: (bool sel) 
              {
                if (sel) { setState(() { _selectedDepartmentFilter = departmentName; }); _fetchDailySchedule(); }
              },
              backgroundColor: isSelected ? clr.primary : clr.surfaceContainerHighest,
              selectedColor: clr.primary,
              labelStyle: txt.bodySmall?.copyWith(
                color: isSelected ? clr.onPrimary : clr.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              checkmarkColor: isSelected ? clr.onPrimary : Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20.0),
                side: BorderSide( color: isSelected ? clr.primary : clr.outline.withAlpha(80), width: 1.0 )
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 6.0),
              showCheckmark: isSelected,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          );
        },
      ),
    );
  }

  void _onBottomNavTabSelected(BottomNavTab tab) 
  {
    switch (tab) 
    {
      case BottomNavTab.agenda: break; 
      case BottomNavTab.home: Navigator.popUntil(context, (route) => route.isFirst); break;
      case BottomNavTab.scanner:
         Navigator.push(context, MaterialPageRoute(builder: (context) => const ScannerScreen())).then((scanResult) 
         {
            if (scanResult != null && scanResult is String && scanResult.isNotEmpty && mounted) 
            {
                Navigator.popUntil(context, (route) 
                {
                  if (route.isFirst) { (route.settings.arguments as Map<String, dynamic>?)?['onScanResult']?.call(scanResult); }
                  return route.isFirst; 
                }); 
            }
         }); 
        break;
    }
  }

  @override
  Widget build(BuildContext context) 
  {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.background,
      appBar: AppBar(
        title: const Text('Rooster'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0.5,
        actions: [
           IconButton( icon: const Icon(Icons.refresh_rounded), tooltip: 'Verversen', onPressed: _isLoading ? null : _fetchDailySchedule,),
        ],
      ),
      body: Column( 
        children: [
           _buildDayNavigator(context),
           _buildDepartmentFilterTabs(context),
           Expanded( child: Container( color: colorScheme.background, child: _buildListArea(context, textTheme, colorScheme),)),
        ],
      ),
      bottomNavigationBar: CustomBottomNavBar( currentTab: BottomNavTab.agenda, onTabSelected: _onBottomNavTabSelected,),
    );
  }

 Widget _buildListArea(BuildContext context, TextTheme textTheme, ColorScheme colorScheme) 
 {
    if (_isLoading && _displayItems.isEmpty) 
    {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) 
    {
      return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.error_outline, color: colorScheme.error, size: 48),
              const SizedBox(height: 16),
              Text( _error!, style: TextStyle(color: colorScheme.error, fontSize: 16), textAlign: TextAlign.center,),
              const SizedBox(height: 20),
              ElevatedButton.icon( icon: const Icon(Icons.refresh), label: const Text('Opnieuw Proberen'), onPressed: _isLoading ? null : _fetchDailySchedule,),
            ],
          ),
        ),
      );
    }
    if (_displayItems.isEmpty && !_isLoading) 
    {
       String message = 'Geen collega\'s gevonden${_selectedDepartmentFilter != "All" ? " op afd. $_selectedDepartmentFilter" : " voor deze dag"}.';
       return Center( child: Padding( padding: const EdgeInsets.all(20.0), child: Column( mainAxisAlignment: MainAxisAlignment.center, children: [
                 const Icon(Icons.calendar_month_outlined, size: 48, color: Colors.grey),
                 const SizedBox(height: 16),
                 Text( message, textAlign: TextAlign.center, style: textTheme.bodyMedium?.copyWith(color: colorScheme.onSurfaceVariant),),
               ],
             ),
           ),
        );
    }

    return RefreshIndicator(
       onRefresh: _fetchDailySchedule,
       child: ListView.builder(
         padding: const EdgeInsets.fromLTRB(16.0, 10.0, 16.0, 16.0),
         itemCount: _displayItems.length,
         itemBuilder: (context, index) 
         {
           final item = _displayItems[index];
           if (item is String) 
           {
             return Padding(
               padding: EdgeInsets.only( top: index == 0 ? 8.0 : 20.0, bottom: 8.0, left: 2.0, ),
               child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                   Text( item, style: textTheme.titleSmall?.copyWith( color: colorScheme.primary, fontWeight: FontWeight.bold, fontSize: 14),),
                   Container( margin: const EdgeInsets.only(top: 4.0), height: 1.5, width: 60, color: colorScheme.primary.withAlpha(120),)
                 ],
               )
             );
           }
           else if (item is DailyShiftEntry) 
           {
             final entry = item;
             return Container(
               margin: const EdgeInsets.symmetric(vertical: 4.0),
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  borderRadius: BorderRadius.circular(8.0),
                ),
               child: InkWell(
                 onTap: () => _showEmployeeDetailsDialog(context, entry),
                 borderRadius: BorderRadius.circular(8.0),
                 child: Row( 
                   children: [
                     SizedBox( 
                       width: 55, 
                       child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                           Text(DailyShiftEntry.formatTime(entry.startTime), style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onSurface, fontSize: 16)),
                           Text(DailyShiftEntry.formatTime(entry.endTime), style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withAlpha(200), fontSize: 13)),
                         ],
                       ),
                     ),
                     const SizedBox(width: 16),
                     Expanded( 
                       child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                           Text(entry.employeeFullName, style: textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600, color: colorScheme.onSurface, fontSize: 15)),
                           const SizedBox(height: 2),
                           Text(entry.departmentName, style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withAlpha(200), fontSize: 13)),
                         ],
                       ),
                     ),
                     const SizedBox(width: 12),
                     Column( crossAxisAlignment: CrossAxisAlignment.end, mainAxisAlignment: MainAxisAlignment.center, children: [
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                           decoration: BoxDecoration( color: colorScheme.primary.withAlpha(200), borderRadius: BorderRadius.circular(6),),
                           child: Text( entry.totalTimeDisplay, style: textTheme.labelMedium?.copyWith(fontWeight: FontWeight.bold, color: colorScheme.onPrimary, fontSize: 13),),
                         ),
                         if (entry.breakDuration > Duration.zero)
                           Padding( padding: const EdgeInsets.only(top: 4.0),
                             child: Text('P: ${entry.breakTimeDisplay}', style: textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant.withAlpha(180), fontSize: 11.5)),
                           ),
                       ],
                     ),
                   ],
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