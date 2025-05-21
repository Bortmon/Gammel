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

  static const Color roosterZeerDonkerGrijs = Color.fromARGB(255, 23, 22, 22);
  static const Color roosterDonkerGrijsBlok = Color.fromARGB(255, 38, 37, 37);
  static const Color roosterBlauwAccent = Color.fromARGB(255, 0, 132, 255);   
  static const Color roosterTekstPrimair = Color(0xFFEAEFF3);  
  static const Color roosterTekstSubtiel = Color.fromARGB(255, 255, 255, 255);  
  static const Color roosterGroenTijd = Color(0xFF2ECC71);    
  static const Color roosterErrorColor = Color(0xFFE53E3E);    
  static const Color roosterOnErrorColor = Colors.white;
  static const Color roosterOutline = Color.fromARGB(255, 28, 26, 26);      


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

  @override
  Widget build(BuildContext context)
  {
     ColorScheme darkAppColorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: roosterBlauwAccent,
      onPrimary: Colors.white, 
      secondary: const Color.fromARGB(255, 0, 226, 94),
      onSecondary: Colors.white, 
      error: roosterErrorColor,
      onError: roosterOnErrorColor,
      background: roosterZeerDonkerGrijs,
      onBackground: roosterTekstPrimair,
      surface: roosterDonkerGrijsBlok, 
      onSurface: roosterTekstPrimair,
      surfaceVariant: Color.lerp(roosterDonkerGrijsBlok, Colors.black, 0.2)!,
      onSurfaceVariant: roosterTekstSubtiel,
      outline: roosterOutline,
      outlineVariant: Color.lerp(roosterOutline, roosterZeerDonkerGrijs, 0.3)!,
      shadow: Colors.black.withAlpha(30),
      surfaceTint: Colors.transparent,
      inverseSurface: roosterTekstPrimair,
      onInverseSurface: roosterZeerDonkerGrijs,
      primaryContainer: roosterBlauwAccent.withAlpha(40),
      onPrimaryContainer: roosterBlauwAccent,
      secondaryContainer: roosterGroenTijd.withAlpha(40),
      onSecondaryContainer: roosterGroenTijd,
      tertiaryContainer: Colors.grey.shade800,
      onTertiaryContainer: Colors.grey.shade400,
      errorContainer: roosterErrorColor.withAlpha(40),
      onErrorContainer: roosterErrorColor,
      surfaceContainerLowest: Color.lerp(const Color.fromARGB(255, 26, 25, 25), roosterDonkerGrijsBlok, 0.3)!,
      surfaceContainerLow: roosterDonkerGrijsBlok, 
      surfaceContainer: Color.lerp(roosterDonkerGrijsBlok, roosterTekstPrimair, 0.04)!,
      surfaceContainerHigh: Color.lerp(roosterDonkerGrijsBlok, roosterTekstPrimair, 0.07)!,
      surfaceContainerHighest: Color.lerp(roosterDonkerGrijsBlok, roosterTekstPrimair, 0.10)!,

     );

     final ThemeData gammelDarkTheme = ThemeData(
        useMaterial3: true,
        fontFamily: 'Inter',
        colorScheme: darkAppColorScheme,
        scaffoldBackgroundColor: darkAppColorScheme.background,
        appBarTheme: AppBarTheme(
          backgroundColor: darkAppColorScheme.surface,
          elevation: 0, 
          titleTextStyle: TextStyle(
            color: darkAppColorScheme.onSurface,
            fontSize: 20,
            fontWeight: FontWeight.w500,
            fontFamily: 'Inter',
          ),
          iconTheme: IconThemeData(color: darkAppColorScheme.onSurfaceVariant),
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
          fillColor: darkAppColorScheme.surfaceContainerLowest,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: darkAppColorScheme.outline.withAlpha(100), width: 0.8),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.0),
            borderSide: BorderSide(color: darkAppColorScheme.primary, width: 1.5),
          ),
          labelStyle: TextStyle(color: darkAppColorScheme.onSurfaceVariant, fontFamily: 'Inter'),
          hintStyle: TextStyle(color: darkAppColorScheme.onSurfaceVariant.withAlpha(180), fontFamily: 'Inter'),
          prefixIconColor: darkAppColorScheme.onSurfaceVariant,
        ),
        cardTheme: CardTheme(
          elevation: 0,
          color: darkAppColorScheme.surface, 
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0),
          ),
          margin: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0),
        ),
        textTheme: TextTheme(
          headlineSmall: TextStyle(fontFamily: 'Inter', color: roosterTekstPrimair, fontWeight: FontWeight.w600, fontSize: 18),
          titleLarge: TextStyle(fontFamily: 'Inter', color: roosterTekstPrimair, fontWeight: FontWeight.bold, fontSize: 17), 
          titleMedium: TextStyle(fontFamily: 'Inter', color: roosterTekstPrimair, fontWeight: FontWeight.w500, fontSize: 15), 
          titleSmall: TextStyle(fontFamily: 'Inter', color: roosterBlauwAccent, fontWeight: FontWeight.w600, fontSize: 14), 
          bodyLarge: TextStyle(fontFamily: 'Inter', color: roosterTekstPrimair, fontSize: 16, height: 1.5),
          bodyMedium: TextStyle(fontFamily: 'Inter', color: roosterTekstSubtiel, fontSize: 14, height: 1.4), 
          bodySmall: TextStyle(fontFamily: 'Inter', color: roosterTekstSubtiel.withAlpha(220), fontSize: 12, height: 1.3), 
          labelLarge: TextStyle(fontFamily: 'Inter', color: darkAppColorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 16),
          labelMedium: TextStyle(fontFamily: 'Inter', color: darkAppColorScheme.onSecondary, fontWeight: FontWeight.bold, fontSize: 13), 
          labelSmall: TextStyle(fontFamily: 'Inter', color: darkAppColorScheme.onPrimary, fontWeight: FontWeight.bold, fontSize: 11),
        ),
        iconTheme: IconThemeData(
          color: roosterTekstSubtiel,
        ),
        dividerTheme: DividerThemeData(
          color: roosterOutline.withAlpha(80),
          thickness: 1,
        ),
        chipTheme: ChipThemeData( 
          backgroundColor: darkAppColorScheme.surfaceContainerHighest,
          disabledColor: Colors.grey.shade800,
          selectedColor: darkAppColorScheme.primary,
          checkmarkColor: darkAppColorScheme.onPrimary,
          labelStyle: TextStyle(fontFamily: 'Inter', color: roosterTekstSubtiel, fontSize: 13, fontWeight: FontWeight.w500),
          secondaryLabelStyle: TextStyle(fontFamily: 'Inter', color: darkAppColorScheme.onPrimary, fontWeight: FontWeight.w600, fontSize: 13),
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8.0), 
            side: BorderSide.none
          ),
        ),
        extensions: <ThemeExtension<dynamic>>[
          const MyThemeColors(
            moneyColor: roosterGroenTijd,
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