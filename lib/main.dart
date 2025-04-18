// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert';

// Importeer de schermen en modellen
import 'models/login_result.dart';
import 'screens/home_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'nl_NL';
  await initializeDateFormatting(Intl.defaultLocale, null);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});
  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  ThemeMode _themeMode = ThemeMode.system;
  final _storage = const FlutterSecureStorage();
  String? _authToken;
  String? _employeeId;
  String? _nodeId;
  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  String? _loginError;
  final String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  @override
  void initState() {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async {
    try {
      String? token = await _storage.read(key: 'authToken');
      String? storedEmployeeId = await _storage.read(key: 'employeeId');
      String? storedNodeId = await _storage.read(key: 'nodeId');
      if (mounted) {
        setState(() {
          if (token != null && token.isNotEmpty && storedEmployeeId != null && storedNodeId != null) {
            _authToken = token;
            _employeeId = storedEmployeeId;
            _nodeId = storedNodeId;
            _isLoggedIn = true;
            print("[Auth] Loaded OK.");
          } else {
            _isLoggedIn = false;
            print("[Auth] Not found/incomplete.");
            if (token != null || storedEmployeeId != null || storedNodeId != null) {
              _logout();
            }
          }
        });
      }
    } catch (e) {
      print("[Auth] Load Err: $e");
      if (mounted) {
        setState(() { _isLoggedIn = false; });
      }
    }
  }

  Future<void> _logout() async {
    try {
      await _storage.deleteAll();
      if (mounted) {
        setState(() {
          _authToken = null;
          _employeeId = null;
          _nodeId = null;
          _isLoggedIn = false;
          _loginError = null;
        });
        print("[Auth] Logged out.");
      }
    } catch (e) {
      print("[Auth] Logout Err: $e");
    }
  }

  Future<LoginResult> _showLoginDialog(BuildContext context) async {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? dialogError;
    LoginResult loginResult = LoginResult(success: false, errorMessage: "Dialog gesloten");

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Inloggen Manus'),
            content: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: ListBody(
                  children: <Widget>[
                    TextFormField(
                      controller: usernameController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration( labelText: 'Gebruikersnaam', border: OutlineInputBorder(), isDense: true,),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Voer naam in' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration( labelText: 'Wachtwoord', border: OutlineInputBorder(), isDense: true, ),
                      obscureText: true,
                      validator: (v) => (v?.isEmpty ?? true) ? 'Voer ww in' : null,
                    ),
                    const SizedBox(height: 8),
                    if (dialogError != null) Padding( padding: const EdgeInsets.only(top: 12.0), child: Text(dialogError!, style: TextStyle(color: Theme.of(context).colorScheme.error)),),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: <Widget>[
              TextButton( child: const Text('Annuleren'), onPressed: () { loginResult = LoginResult(success: false, errorMessage: "Geannuleerd"); Navigator.of(dialogContext).pop(); },),
              TextButton( child: _isLoggingIn ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Inloggen'),
                onPressed: _isLoggingIn ? null : () async {
                    setDialogState(() => dialogError = null);
                    if (formKey.currentState!.validate()) {
                      bool ok = await _handleLogin(usernameController.text, passwordController.text);
                      if (!dialogContext.mounted) return;
                      if (ok) { loginResult = LoginResult(success: true, employeeId: _employeeId, nodeId: _nodeId, authToken: _authToken); Navigator.of(dialogContext).pop(); }
                      else { loginResult = LoginResult(success: false, errorMessage: _loginError ?? "Fout"); setDialogState(() => dialogError = loginResult.errorMessage); }
                    }
                  },
              ),
            ],
          );
        });
      },
    );
    return loginResult;
  }

  Future<bool> _handleLogin(String username, String password) async {
    if (_isLoggingIn) return false;
    setState(() { _isLoggingIn = true; _loginError = null; });
    const url = 'https://server.manus.plus/intergamma/app/token';
    final data = {'client_id': 'employee', 'grant_type': 'password', 'username': username, 'password': password};
    bool success = false;
    print("[Auth] Login...");
    try {
      final response = await http.post(Uri.parse(url), headers: {'User-Agent': _userAgent, 'Content-Type': 'application/x-www-form-urlencoded', 'Accept': '*/*', 'Origin': 'https://ess.manus.plus', 'Referer': 'https://ess.manus.plus/', 'X-Application-Type': 'employee'}, body: data);
      print("[Auth] Status: ${response.statusCode}");
      if (!mounted) return false;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        String? token; String? eId; String? nId;
        try {
          final body = jsonDecode(response.body);
          token = body['access_token'];
          if (token != null && token.isNotEmpty) {
            try { Map<String, dynamic> jwt = JwtDecoder.decode(token); eId = jwt['EmployeeId'] as String?; nId = jwt['NodeId'] as String?; if (eId == null || nId == null) { print("[Auth] IDs missing in JWT."); _loginError = "Login OK, IDs?"; token = null; } else { print("[Auth] IDs OK."); } }
            catch (e) { print("[Auth] JWT Decode Err: $e"); _loginError = "Login OK, token err."; token = null; }
          } else { print("[Auth] Token missing."); _loginError = "Login OK, token?"; }
        } catch (e) { print("[Auth] JSON Parse Err: $e"); _loginError = "Login OK, data err."; }
        if (token != null && eId != null && nId != null) {
           print("[Auth] All OK."); await _storage.write(key: 'authToken', value: token); await _storage.write(key: 'employeeId', value: eId); await _storage.write(key: 'nodeId', value: nId); setState(() { _authToken = token; _employeeId = eId; _nodeId = nId; _isLoggedIn = true; _loginError = null; }); success = true;
        }
      } else { String msg = "Login Err (${response.statusCode})"; try { final b = jsonDecode(response.body); msg = b['message'] ?? b['error_description'] ?? b['error'] ?? msg; } catch (e) { print("Err parsing login err response: $e"); } _loginError = msg; }
    } catch (e) { print('[Auth] Request Err: $e'); _loginError = 'Netwerkfout: $e'; }
    finally { if (mounted) { setState(() { _isLoggingIn = false; }); } }
    return success;
  }

  void changeThemeMode(ThemeMode m) { setState(() { _themeMode = m; }); }
  void toggleThemeMode() { final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light; changeThemeMode(newMode); }

  @override
  Widget build(BuildContext context) {
     final baseLight=ThemeData.light(useMaterial3:true);final baseDark=ThemeData.dark(useMaterial3:true);
     final lightCS=ColorScheme.fromSeed(seedColor:Colors.orange,brightness:Brightness.light);
     final darkCS=ColorScheme.fromSeed(seedColor:const Color(0xFF75a7ff),brightness:Brightness.dark,surface:const Color(0xFF2A2A2A),primary:const Color(0xFF75a7ff),onPrimary:Colors.black,secondary:const Color(0xFFb8c7ff),onSecondary:Colors.black,surfaceVariant:const Color(0xFF3A3A3A),error:Colors.redAccent[100],surfaceContainer:const Color(0xFF303030),surfaceContainerHighest:const Color(0xFF3A3A3A));
     final lightTheme=baseLight.copyWith(colorScheme:lightCS,appBarTheme:AppBarTheme(backgroundColor:lightCS.primary,foregroundColor:lightCS.onPrimary,elevation:2,iconTheme:IconThemeData(color:lightCS.onPrimary),actionsIconTheme:IconThemeData(color:lightCS.onPrimary)),cardTheme:CardTheme(elevation:1,margin:const EdgeInsets.symmetric(vertical:6.0,horizontal:0),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8.0)),color:lightCS.surface,surfaceTintColor:Colors.transparent),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.grey[100],contentPadding:const EdgeInsets.symmetric(vertical:12.0,horizontal:16.0),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8.0),borderSide:BorderSide.none),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8.0),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8.0),borderSide:BorderSide(color:lightCS.primary,width:1.5)),labelStyle:TextStyle(color:Colors.grey[600]),prefixIconColor:Colors.grey[600],suffixIconColor:Colors.grey[600]),textTheme:baseLight.textTheme.copyWith(bodySmall:baseLight.textTheme.bodySmall?.copyWith(color:Colors.grey[700])).apply(displayColor:Colors.black87,bodyColor:Colors.black87));
     final darkTheme=baseDark.copyWith(colorScheme:darkCS,scaffoldBackgroundColor:darkCS.surface,appBarTheme:AppBarTheme(backgroundColor:const Color(0xFF2B3035),foregroundColor:darkCS.onSurface,elevation:1,iconTheme:IconThemeData(color:darkCS.onSurface),actionsIconTheme:IconThemeData(color:darkCS.onSurface)),cardTheme:CardTheme(elevation:1,margin:const EdgeInsets.symmetric(vertical:6.0,horizontal:0),shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(8.0)),color:darkCS.surfaceContainer,surfaceTintColor:Colors.transparent),inputDecorationTheme:InputDecorationTheme(filled:true,fillColor:Colors.grey[850],contentPadding:const EdgeInsets.symmetric(vertical:12.0,horizontal:16.0),border:OutlineInputBorder(borderRadius:BorderRadius.circular(8.0),borderSide:BorderSide.none),enabledBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8.0),borderSide:BorderSide.none),focusedBorder:OutlineInputBorder(borderRadius:BorderRadius.circular(8.0),borderSide:BorderSide(color:darkCS.primary,width:1.5)),labelStyle:TextStyle(color:Colors.grey[400]),prefixIconColor:Colors.grey[400],suffixIconColor:Colors.grey[400]),textTheme:baseDark.textTheme.apply(bodyColor:Colors.grey[300],displayColor:Colors.white).copyWith(bodySmall:baseDark.textTheme.bodySmall?.copyWith(color:Colors.grey[500])),iconButtonTheme:IconButtonThemeData(style:IconButton.styleFrom(foregroundColor:darkCS.onSurface)),iconTheme:IconThemeData(color:darkCS.onSurface.withAlpha((255*0.8).round())),dividerTheme:DividerThemeData(color:Colors.grey[700],thickness:0.5));
     return MaterialApp(title:'Gammel',theme:lightTheme,darkTheme:darkTheme,themeMode:_themeMode,home:HomePage(currentThemeMode:_themeMode,onThemeModeChanged:toggleThemeMode,isLoggedIn:_isLoggedIn,authToken:_authToken,employeeId:_employeeId,nodeId:_nodeId,loginCallback:_showLoginDialog,logoutCallback:_logout,),debugShowCheckedModeBanner:false);
  }
}