import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';

import 'data/attachment_storage.dart';
import 'data/db_opener.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home_shell.dart';
import 'services/auth_service.dart';
import 'services/data_store.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Intl.defaultLocale = 'tr_TR';
  await initializeDateFormatting('tr_TR');
  final db = await openAppDatabase();
  final files = await openAttachmentStorage();
  final auth = AuthService(db, files: files);
  await auth.restoreSession();
  runApp(TenAntsApp(db: db, auth: auth, files: files));
}

class TenAntsApp extends StatelessWidget {
  const TenAntsApp({super.key, required this.db, required this.auth, this.files});
  final Database db;
  final AuthService auth;
  final AttachmentStorage? files;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: auth),
        ChangeNotifierProvider(create: (_) => DataStore(db, auth, files: files)),
      ],
      child: MaterialApp(
        title: '10ants',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light),
        darkTheme: buildTheme(Brightness.dark),
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AuthGate(),
      ),
    );
  }
}

/// Oturum durumuna göre giriş ekranını veya ana ekranı gösterir.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final loggedIn = context.select<AuthService, bool>((a) => a.isLoggedIn);
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: loggedIn ? const HomeShell(key: ValueKey('home')) : const LoginScreen(key: ValueKey('login')),
    );
  }
}
