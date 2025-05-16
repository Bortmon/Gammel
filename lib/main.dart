import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:convert';

import 'package:flutter_localizations/flutter_localizations.dart';

import 'models/login_result.dart';
import 'screens/home_page.dart';

Future<void> main() async
{
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'nl_NL';
  await initializeDateFormatting(Intl.defaultLocale, null);
  runApp(const MyApp());
}

@immutable
class MyThemeColors extends ThemeExtension<MyThemeColors>
{
  const MyThemeColors({
    required this.moneyColor,
  });

  final Color? moneyColor;

  @override
  MyThemeColors copyWith({Color? moneyColor})
  {
    return MyThemeColors(
      moneyColor: moneyColor ?? this.moneyColor,
    );
  }

  @override
  MyThemeColors lerp(ThemeExtension<MyThemeColors>? other, double t)
  {
    if (other is! MyThemeColors)
    {
      return this;
    }
    return MyThemeColors(
      moneyColor: Color.lerp(moneyColor, other.moneyColor, t),
    );
  }

  static MyThemeColors? of(BuildContext context)
  {
    return Theme.of(context).extension<MyThemeColors>();
  }
}

class MyApp extends StatefulWidget
{
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp>
{
  // ThemeMode is niet meer nodig als we maar één thema hebben
  // ThemeMode _themeMode = ThemeMode.dark;

  final _storage = const FlutterSecureStorage();
  String? _authToken;
  String? _employeeId;
  String? _nodeId;
  String? _userName;
  bool _isLoggedIn = false;
  bool _isLoggingIn = false;
  String? _loginError;
  final String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36';

  static const Color wcTrackerPrimaryAccentColor = Color(0xFF4A90E2);
  static const Color wcTrackerScaffoldBackgroundColor = Color(0xFF212121);
  static const Color wcTrackerCardBackgroundColor = Color(0xFF2C2C2C);
  static const Color wcTrackerMainTextColor = Colors.white; // Of Color(0xFFF5F5F5) voor net-niet-wit
  static const Color wcTrackerSecondaryTextColor = Color(0xFFE0E0E0);
  static const Color wcTrackerMoneyDisplayColor = Color(0xFF34C759);

  @override
  void initState()
  {
    super.initState();
    _loadAuthToken();
  }

  Future<void> _loadAuthToken() async
  {
    try
    {
      String? token = await _storage.read(key: 'authToken');
      String? storedEmployeeId = await _storage.read(key: 'employeeId');
      String? storedNodeId = await _storage.read(key: 'nodeId');
      String? storedUserName = await _storage.read(key: 'userName');

      if (mounted)
      {
        if (token != null && token.isNotEmpty && storedEmployeeId != null && storedNodeId != null)
        {
           setState(()
           {
            _authToken = token;
            _employeeId = storedEmployeeId;
            _nodeId = storedNodeId;
            _isLoggedIn = true;
            _userName = storedUserName;
          });
          await _fetchUserProfile();
        }
        else
        {
           setState(()
           {
             _isLoggedIn = false;
           });
           if (token != null || storedEmployeeId != null || storedNodeId != null || storedUserName != null)
           {
             _logout();
           }
        }
      }
    }
    catch (e)
    {
      if (mounted)
      {
        setState(()
        {
          _isLoggedIn = false;
        });
      }
    }
  }

   Future<void> _fetchUserProfile() async
   {
     if (_authToken == null || !mounted) return;
     const profileUrl = 'https://server.manus.plus/intergamma/api/user/own';
     try
     {
        final response = await http.get(
          Uri.parse(profileUrl),
          headers:
          {
            'Authorization': 'Bearer $_authToken',
            'User-Agent': _userAgent,
            'Accept': 'application/json',
          },
        );
        if (response.statusCode >= 200 && response.statusCode < 300 && mounted)
        {
           final data = jsonDecode(response.body);
           final String? fetchedName = data['name'];
           if (fetchedName != null && fetchedName.isNotEmpty)
           {
             if (fetchedName != _userName)
             {
               await _storage.write(key: 'userName', value: fetchedName);
               setState(()
               {
                 _userName = fetchedName;
               });
             }
           }
           else
           {
             if (_userName != null)
             {
               await _storage.delete(key: 'userName');
               setState(() => _userName = null);
             }
           }
        }
     }
     catch (e)
     {
       // no-op
     }
   }

  Future<void> _logout() async
  {
    try
    {
      await _storage.deleteAll();
      if (mounted)
      {
        setState(()
        {
          _authToken = null;
          _employeeId = null;
          _nodeId = null;
          _userName = null;
          _isLoggedIn = false;
          _loginError = null;
        });
      }
    }
    catch (e)
    {
      // no-op
    }
  }

  Future<LoginResult> _showLoginDialog(BuildContext context) async
  {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();
    String? dialogError;
    LoginResult loginResult = LoginResult(success: false, errorMessage: "Dialog gesloten");

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext)
      {
        return StatefulBuilder(builder: (context, setDialogState)
        {
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
                      decoration: const InputDecoration(
                        labelText: 'Gebruikersnaam',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      validator: (v) => (v?.isEmpty ?? true) ? 'Voer naam in' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: passwordController,
                      style: Theme.of(context).textTheme.bodyMedium,
                      decoration: const InputDecoration(
                        labelText: 'Wachtwoord',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      obscureText: true,
                      validator: (v) => (v?.isEmpty ?? true) ? 'Voer ww in' : null,
                    ),
                    const SizedBox(height: 8),
                    if (dialogError != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12.0),
                        child: Text(
                          dialogError!,
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            actions: <Widget>[
              TextButton(
                child: const Text('Annuleren'),
                onPressed: ()
                {
                  loginResult = LoginResult(success: false, errorMessage: "Geannuleerd");
                  Navigator.of(dialogContext).pop();
                },
              ),
              TextButton(
                child: _isLoggingIn
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Inloggen'),
                onPressed: _isLoggingIn
                    ? null
                    : () async
                    {
                        setDialogState(() => dialogError = null);
                        if (formKey.currentState!.validate())
                        {
                          bool ok = await _handleLogin(usernameController.text, passwordController.text);
                          if (!dialogContext.mounted) return;
                          if (ok)
                          {
                            loginResult = LoginResult(
                              success: true,
                              employeeId: _employeeId,
                              nodeId: _nodeId,
                              authToken: _authToken
                            );
                            Navigator.of(dialogContext).pop();
                          }
                          else
                          {
                            loginResult = LoginResult(success: false, errorMessage: _loginError ?? "Fout");
                            setDialogState(() => dialogError = loginResult.errorMessage);
                          }
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

  Future<bool> _handleLogin(String username, String password) async
  {
    if (_isLoggingIn) return false;
    setState(()
    {
      _isLoggingIn = true;
      _loginError = null;
    });

    const url = 'https://server.manus.plus/intergamma/app/token';
    final data =
    {
      'client_id': 'employee',
      'grant_type': 'password',
      'username': username,
      'password': password
    };
    bool success = false;

    try
    {
      final response = await http.post(
        Uri.parse(url),
        headers:
        {
          'User-Agent': _userAgent,
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': '*/*',
          'Origin': 'https://ess.manus.plus',
          'Referer': 'https://ess.manus.plus/',
          'X-Application-Type': 'employee'
        },
        body: data
      );
      if (!mounted) return false;

      if (response.statusCode >= 200 && response.statusCode < 300)
      {
        String? token;
        String? eId;
        String? nId;
        try
        {
          final body = jsonDecode(response.body);
          token = body['access_token'];
          if (token != null && token.isNotEmpty)
          {
            try
            {
              Map<String, dynamic> jwt = JwtDecoder.decode(token);
              eId = jwt['EmployeeId'] as String?;
              nId = jwt['NodeId'] as String?;
              if (eId == null || nId == null)
              {
                _loginError = "Login succesvol, maar IDs niet gevonden in token.";
                token = null;
              }
            }
            catch (e)
            {
              _loginError = "Login succesvol, maar token kon niet worden gelezen.";
              token = null;
            }
          }
          else
          {
            _loginError = "Login succesvol, maar geen token ontvangen.";
          }
        }
        catch (e)
        {
          _loginError = "Login succesvol, maar antwoord kon niet worden verwerkt.";
        }

        if (token != null && eId != null && nId != null)
        {
           await _storage.write(key: 'authToken', value: token);
           await _storage.write(key: 'employeeId', value: eId);
           await _storage.write(key: 'nodeId', value: nId);

           setState(()
           {
             _authToken = token;
             _employeeId = eId;
             _nodeId = nId;
             _isLoggedIn = true;
             _loginError = null;
             _userName = null;
           });
           await _fetchUserProfile();
           success = true;
        }
      }
      else
      {
        String msg = "Login Fout (${response.statusCode})";
        try
        {
          final b = jsonDecode(response.body);
          msg = b['message'] ?? b['error_description'] ?? b['error'] ?? msg;
        }
        catch (e)
        {
            //no-op
        }
        _loginError = msg;
      }
    }
    catch (e)
    {
      _loginError = 'Netwerkfout bij inloggen: $e';
    }
    finally
    {
      if (mounted)
      {
        setState(()
        {
          _isLoggingIn = false;
        });
      }
    }
    return success;
  }

  // Verwijder changeThemeMode en toggleThemeMode als je geen thema-wisselaar meer nodig hebt
  // void changeThemeMode(ThemeMode m)
  // {
  //   setState(()
  //   {
  //     _themeMode = m;
  //   });
  // }

  // void toggleThemeMode()
  // {
  //   final newMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
  //   changeThemeMode(newMode);
  // }

  @override
  Widget build(BuildContext context)
  {
     ColorScheme darkAppColorScheme = ColorScheme.fromSeed(
      seedColor: wcTrackerPrimaryAccentColor,
      brightness: Brightness.dark,
      background: wcTrackerScaffoldBackgroundColor,
      surface: wcTrackerCardBackgroundColor,
      onBackground: wcTrackerMainTextColor,
      onSurface: wcTrackerMainTextColor,
      primary: wcTrackerPrimaryAccentColor,
      onPrimary: Colors.white,
      secondary: wcTrackerMoneyDisplayColor,
      onSecondary: Colors.white,
      error: Colors.redAccent.shade100,
      onError: Colors.black,
     ).copyWith(
        surfaceContainerLow: wcTrackerCardBackgroundColor, // Zekerstellen dat secties deze kleur krijgen
        // Je kunt hier nog andere surfaceContainer varianten expliciet zetten als fromSeed ze niet naar wens maakt
        // surfaceContainer: Color.lerp(wcTrackerCardBackgroundColor, wcTrackerMainTextColor, 0.05)!,
        // surfaceContainerHigh: Color.lerp(wcTrackerCardBackgroundColor, wcTrackerMainTextColor, 0.1)!,
     );

     final ThemeData gammelDarkTheme = ThemeData(
        useMaterial3: true, // Blijf Material 3 gebruiken
        fontFamily: 'Inter',
        colorScheme: darkAppColorScheme,
        scaffoldBackgroundColor: darkAppColorScheme.background,

        appBarTheme: AppBarTheme(
          backgroundColor: darkAppColorScheme.surface,
          elevation: 0,
          titleTextStyle: TextStyle(
            color: darkAppColorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.bold,
            fontFamily: 'Inter',
          ),
          iconTheme: IconThemeData(color: darkAppColorScheme.primary),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: darkAppColorScheme.primary,
            foregroundColor: darkAppColorScheme.onPrimary,
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Inter'),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            elevation: 1,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: OutlinedButton.styleFrom(
                foregroundColor: darkAppColorScheme.primary,
                side: BorderSide(color: darkAppColorScheme.primary.withAlpha(150)),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, fontFamily: 'Inter'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10.0),
                ),
            ),
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(
            foregroundColor: darkAppColorScheme.primary,
            textStyle: const TextStyle(fontWeight: FontWeight.w600, fontFamily: 'Inter', fontSize: 14),
          )
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Color.lerp(darkAppColorScheme.background, darkAppColorScheme.surface, 0.3),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: darkAppColorScheme.surface.withAlpha(128), width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: darkAppColorScheme.primary, width: 1.5),
          ),
          labelStyle: TextStyle(color: wcTrackerSecondaryTextColor.withAlpha(200), fontFamily: 'Inter'),
          hintStyle: TextStyle(color: wcTrackerSecondaryTextColor.withAlpha(150), fontFamily: 'Inter'),
          prefixIconColor: darkAppColorScheme.primary.withAlpha(220),
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: darkAppColorScheme.surface, // Gebruik surface, wat wcTrackerCardBackgroundColor is
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 8.0),
        ),
        textTheme: TextTheme(
          displayLarge: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.bold, fontSize: 32),
          displayMedium: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.bold, fontSize: 28),
          displaySmall: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.bold, fontSize: 24),
          headlineLarge: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.bold, fontSize: 22),
          headlineMedium: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.bold, fontSize: 20),
          headlineSmall: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.w600, fontSize: 18),
          titleLarge: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.w600, fontSize: 16),
          titleMedium: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontWeight: FontWeight.w500, fontSize: 14),
          titleSmall: TextStyle(fontFamily: 'Inter', color: wcTrackerSecondaryTextColor, fontWeight: FontWeight.w500, fontSize: 12),
          bodyLarge: TextStyle(fontFamily: 'Inter', color: wcTrackerMainTextColor, fontSize: 16, height: 1.5),
          bodyMedium: TextStyle(fontFamily: 'Inter', color: wcTrackerSecondaryTextColor, fontSize: 14, height: 1.4),
          bodySmall: TextStyle(fontFamily: 'Inter', color: wcTrackerSecondaryTextColor.withAlpha(200), fontSize: 12, height: 1.3),
          labelLarge: TextStyle(fontFamily: 'Inter', color: darkAppColorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        iconTheme: IconThemeData(
          color: wcTrackerSecondaryTextColor.withAlpha(220),
        ),
        dividerTheme: DividerThemeData(
          color: wcTrackerMainTextColor.withAlpha(50),
          thickness: 0.5,
        ),
        extensions: <ThemeExtension<dynamic>>[
          const MyThemeColors(
            moneyColor: wcTrackerMoneyDisplayColor,
          ),
        ],
     );

     return MaterialApp(
       title: 'Gammel',
       theme: gammelDarkTheme, 
       localizationsDelegates: const [
         GlobalMaterialLocalizations.delegate,
         GlobalWidgetsLocalizations.delegate,
         GlobalCupertinoLocalizations.delegate,
       ],
       supportedLocales: const [
         Locale('nl', 'NL'),
         Locale('en', ''),
       ],
       home: HomePage( 
         isLoggedIn: _isLoggedIn,
         authToken: _authToken,
         employeeId: _employeeId,
         nodeId: _nodeId,
         userName: _userName,
         loginCallback: _showLoginDialog,
         logoutCallback: _logout,
       ),
       debugShowCheckedModeBanner: false,
     );
  }
}