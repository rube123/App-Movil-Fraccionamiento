import 'package:flutter/material.dart';
import 'package:dio/dio.dart' as dio;
import 'package:fraccionamiento/colors.dart';
import 'package:fraccionamiento/inicio_screen.dart';
import 'package:fraccionamiento/services/push_service.dart';
import 'package:fraccionamiento/session.dart';
import 'package:fraccionamiento/controllers/auth_controller.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  static const String baseUrl = "https://apifraccionamiento.onrender.com";
  //static const String baseUrl = "https://apifracc-1.onrender.com";
  //static const String baseUrl = "http://192.168.100.132:3002";

  final _correoController = TextEditingController();
  final _contrasenaController = TextEditingController();

  bool _cargando = false;
  String? _error;

  late final dio.Dio _dio = dio.Dio(
    dio.BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {'Content-Type': 'application/json'},
      responseType: dio.ResponseType.json,
      validateStatus: (s) => s != null && s >= 200 && s < 500,
    ),
  );

  int _asInt(dynamic v, {int fallback = 0}) {
    if (v == null) return fallback;
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v.trim()) ?? fallback;
    return fallback;
  }

  List<String> _asStringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const [];
  }

  String _serverMsg(dio.Response res) {
    final d = res.data;
    if (d == null) return "";
    if (d is String) return d;
    if (d is Map && d["error"] != null) return d["error"].toString();
    return d.toString();
  }

  /// Procesa la respuesta del backend (/login o /login/google)
  Future<void> _procesarLoginResponse(dio.Response res) async {
    if (res.statusCode != 200) {
      final msg = _serverMsg(res);
      setState(() {
        _error = (res.statusCode == 401)
            ? "Credenciales incorrectas o usuario no encontrado."
            : "Error del servidor (HTTP ${res.statusCode}). ${msg.isNotEmpty ? msg : ""}"
                  .trim();
      });
      return;
    }

    if (res.data is! Map) {
      setState(
        () => _error = "Respuesta inválida del servidor (no es JSON objeto).",
      );
      return;
    }

    final data = Map<String, dynamic>.from(res.data as Map);

    final roles = _asStringList(data["roles"]);
    final idPersona = _asInt(data["id_persona"]);
    final idUsuario = _asInt(data["id_usuario"]);

    if (idPersona <= 0 || idUsuario <= 0) {
      setState(() {
        _error =
            "Login OK pero IDs inválidos (id_persona=$idPersona, id_usuario=$idUsuario).\n"
            "Revisa tu endpoint /login para que regrese enteros correctos.";
      });
      return;
    }

    // Guardar sesión local
    await Session.save(idPersona: idPersona, idUsuario: idUsuario);

    // Init push (Firebase + registro de token en backend),
    // pero sin romper el login si falla
    try {
      await PushService.initForPersona(idPersona: idPersona);
    } catch (e) {
      debugPrint("PushService.initForPersona falló pero sigo login: $e");
    }

    final tipoUsuario = roles.contains("admin")
        ? "admin"
        : (roles.contains("mesa_directiva") ? "mesa_directiva" : "residente");

    if (!mounted) return;

    debugPrint(
      "Login OK -> idPersona=$idPersona, idUsuario=$idUsuario, roles=$roles",
    );

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InicioScreen(
          roles: roles,
          idPersona: idPersona,
          idUsuario: idUsuario,
          tipoUsuario: tipoUsuario,
        ),
      ),
    );
  }

  /// Login normal con correo/contraseña → POST /login
  Future<void> _login() async {
    final correo = _correoController.text.trim();
    final contrasena = _contrasenaController.text;

    if (correo.isEmpty || contrasena.isEmpty) {
      setState(() => _error = "Ingresa correo y contraseña.");
      return;
    }

    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final res = await _dio.post(
        "/login",
        data: {"correo": correo, "contrasena": contrasena},
      );

      await _procesarLoginResponse(res);
    } on dio.DioException catch (e) {
      debugPrint(
        "DioException: type=${e.type}, message=${e.message}, error=${e.error}",
      );
      final status = e.response?.statusCode;
      final body = e.response?.data?.toString();

      setState(() {
        _error = status == 401
            ? "Credenciales incorrectas o usuario no encontrado."
            : "Error de conexión/servidor. ${status != null ? "HTTP $status" : ""} ${body ?? ""}"
                  .trim();
      });
    } catch (e) {
      setState(() => _error = "Error inesperado: $e");
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  /// Login con Google usando tu endpoint `/login/google`
  Future<void> _loginConGoogle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      await AuthController.to.loginWithGoogle();
      if (!AuthController.to.isLoggedIn) {
        setState(() {
          _error = "No se pudo iniciar sesión con Google.";
        });
        return;
      }

      final googleUser = AuthController.to.user.value;
      final correo = googleUser.email.trim();

      if (correo.isEmpty) {
        setState(() {
          _error =
              "Tu cuenta de Google no tiene un correo visible. No se puede continuar.";
        });
        await AuthController.to.logout();
        return;
      }

      final res = await _dio.post("/login/google", data: {"correo": correo});

      if (res.statusCode == 401 || res.statusCode == 404) {
        await AuthController.to.logout();
        setState(() {
          _error =
              "Tu correo $correo no está registrado en el fraccionamiento.\n"
              "Contacta a la administración o mesa directiva para que te den de alta.";
        });
        return;
      }

      await _procesarLoginResponse(res);
    } on dio.DioException catch (e) {
      final status = e.response?.statusCode;
      final body = e.response?.data?.toString();
      setState(() {
        _error =
            "Error al validar tu cuenta de Google en el servidor.\n"
            "${status != null ? "HTTP $status\n" : ""}"
            "${body ?? e.message ?? e.toString()}";
      });
    } catch (e) {
      setState(() {
        _error = "Error inesperado en Google Sign-In: $e";
      });
    } finally {
      if (mounted) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  void dispose() {
    _correoController.dispose();
    _contrasenaController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.home, color: AppColors.celesteNegro, size: 60),
              const SizedBox(height: 10),
              Text(
                "Bienvenido",
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.celesteNegro,
                ),
              ),
              const SizedBox(height: 40),
              TextField(
                controller: _correoController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: "Correo",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: _contrasenaController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: "Contraseña",
                  labelStyle: const TextStyle(color: AppColors.celesteVivo),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              if (_error != null)
                Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 25),
              ElevatedButton(
                onPressed: _cargando ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.celesteNegro,
                  minimumSize: const Size(double.infinity, 50),
                ),
                child: _cargando
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        "Iniciar Sesión",
                        style: TextStyle(color: Colors.white),
                      ),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: _cargando ? null : _loginConGoogle,
                icon: Image.asset("assets/google.png", height: 24),
                label: const Text(
                  "Iniciar sesión con Google",
                  style: TextStyle(color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  side: const BorderSide(color: Colors.black12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
