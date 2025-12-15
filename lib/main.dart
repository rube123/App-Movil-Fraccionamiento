import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:fraccionamiento/colors.dart';
import 'package:fraccionamiento/login_screen.dart';
import 'package:fraccionamiento/mesa_directiva_screen.dart';
import 'package:fraccionamiento/onboarding_screen.dart';
import 'package:fraccionamiento/registro_screen.dart';
import 'package:fraccionamiento/avisos_screen.dart';
import 'package:fraccionamiento/pagos_screen.dart';
import 'package:fraccionamiento/area_comun_screen.dart';
import 'package:fraccionamiento/services/push_service.dart';
import 'package:fraccionamiento/session.dart';
import 'package:fraccionamiento/inicio_screen.dart';
import 'package:fraccionamiento/controllers/auth_controller.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 🔹 Firebase (usa tus opciones si tienes firebase_options.dart)
  await Firebase.initializeApp();

  // 🔹 Notificaciones (canal, permisos, listeners)
  await PushService.initFirebaseAndNotifications();

  // 🔹 Stripe
  Stripe.publishableKey =
      "pk_test_51SWmkKFFf8vKAWyUeuIU57DSP0L1T57zoMJyEqcYGYIAen012W9p2OmtuxTn6nHMMm7NhBEXb5cesoIEFDbLTrqq00HpqwEdxW";
  await Stripe.instance.applySettings();

  // 🔹 AuthController global
  Get.put(AuthController(), permanent: true);

  runApp(const MiApp());
}

class MiApp extends StatelessWidget {
  const MiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Residentes App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: AppColors.celesteNegro,
        scaffoldBackgroundColor: AppColors.celesteClaro,
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.amarillo,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      ),

      // Ya no usamos initialRoute, decidimos aquí
      home: const AuthWrapper(),

      routes: {
        '/login': (_) => const LoginScreen(),
        '/registro': (_) => const RegistroScreen(),
        '/mesa_directiva': (_) => const MesaDirectivaScreen(),
      },
      onGenerateRoute: (settings) {
        final args = (settings.arguments as Map<String, dynamic>?) ?? {};

        if (settings.name == '/avisos') {
          final roles = (args['roles'] as List<dynamic>? ?? []).cast<String>();
          final idPersona = args['idPersona'] as int? ?? 0;
          final idUsuario = args['idUsuario'] as int? ?? 0;

          return MaterialPageRoute(
            builder: (_) => AvisosScreen(
              roles: roles,
              idPersona: idPersona,
              idUsuario: idUsuario,
            ),
          );
        }

        if (settings.name == '/pagos') {
          final idPersona = args['idPersona'] as int? ?? 0;
          final idUsuario = args['idUsuario'] as int? ?? 0;

          return MaterialPageRoute(
            builder: (_) => PagosScreen(
              idPersona: idPersona,
              idUsuario: idUsuario,
              roles: const [],
            ),
          );
        }

        if (settings.name == '/area_comun') {
          final idPersona = args['idPersona'] as int? ?? 0;
          final idUsuario = args['idUsuario'] as int? ?? 0;

          return MaterialPageRoute(
            builder: (_) =>
                AreaComunScreen(idPersona: idPersona, idUsuario: idUsuario),
          );
        }

        return null;
      },
    );
  }
}

// Pequeño modelo interno para decidir a dónde ir
class _StartInfo {
  final bool loggedIn;
  final int idPersona;
  final int idUsuario;
  final List<String> roles;
  final String tipoUsuario;

  const _StartInfo({
    required this.loggedIn,
    required this.idPersona,
    required this.idUsuario,
    required this.roles,
    required this.tipoUsuario,
  });
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  Future<_StartInfo> _load() async {
    final sp = await SharedPreferences.getInstance();

    // 0) Onboarding
    final onboardingDone = sp.getBool("onboarding_done") ?? false;

    if (!onboardingDone) {
      return const _StartInfo(
        loggedIn: false,
        idPersona: 0,
        idUsuario: 0,
        roles: [],
        tipoUsuario: "onboarding",
      );
    }

    // 1) Sesión local
    final savedIdPersona = await Session.idPersona();
    final savedIdUsuario = await Session.idUsuario();

    if (savedIdPersona > 0 && savedIdUsuario > 0) {
      return _StartInfo(
        loggedIn: true,
        idPersona: savedIdPersona,
        idUsuario: savedIdUsuario,
        roles: const ['residente'],
        tipoUsuario: 'backend',
      );
    }

    // 2) Usuario Firebase (Google)
    final fbUser = FirebaseAuth.instance.currentUser;
    if (fbUser != null) {
      AuthController.to.setFromFirebase(fbUser);

      return const _StartInfo(
        loggedIn: true,
        idPersona: 0,
        idUsuario: 0,
        roles: ['residente'],
        tipoUsuario: 'google',
      );
    }

    // 3) Nadie logueado
    return const _StartInfo(
      loggedIn: false,
      idPersona: 0,
      idUsuario: 0,
      roles: [],
      tipoUsuario: "",
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_StartInfo>(
      future: _load(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final info = snapshot.data!;

        if (info.tipoUsuario == "onboarding") {
          return const OnboardingScreen();
        }

        if (!info.loggedIn) {
          return const LoginScreen();
        }

        return InicioScreen(
          roles: info.roles,
          idPersona: info.idPersona,
          idUsuario: info.idUsuario,
          tipoUsuario: info.tipoUsuario,
        );
      },
    );
  }
}
