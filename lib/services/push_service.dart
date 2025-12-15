import 'dart:io';

import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

// Cambia la URL a la de tu API
const String baseUrlApi = "https://apifraccionamiento.onrender.com";

// Canal para Android (id = "avisos")
const AndroidNotificationChannel avisosChannel = AndroidNotificationChannel(
  'avisos', // ID debe coincidir con channel_id del backend
  'Avisos',
  description: 'Notificaciones de avisos del fraccionamiento',
  importance: Importance.high,
);

// Plugin global de notificaciones locales
final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

class PushService {
  static bool _initialized = false;
  static final Dio _dio = Dio(
    BaseOptions(
      baseUrl: baseUrlApi,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
    ),
  );

  /// Llamar UNA sola vez (internamente lo controlamos con _initialized)
  static Future<void> initFirebaseAndNotifications() async {
    if (_initialized) return;

    await Firebase.initializeApp();

    // Inicializar notificaciones locales
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initSettings =
        InitializationSettings(android: androidSettings);

    await flutterLocalNotificationsPlugin.initialize(initSettings);

    // Crear canal "avisos" en Android
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(avisosChannel);

    // Permisos en iOS (por si lo usas después)
    if (Platform.isIOS) {
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
    }

    // Listener cuando app está en foreground
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              avisosChannel.id,
              avisosChannel.name,
              channelDescription: avisosChannel.description,
              importance: Importance.high,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    _initialized = true;
    print("✅ PushService: Firebase + notificaciones inicializadas");
  }

  /// Obtiene el token de FCM actual
  static Future<String?> getFcmToken() async {
    final token = await FirebaseMessaging.instance.getToken();
    print("🔥 FCM TOKEN: $token");
    return token;
  }

  /// Registra el dispositivo en tu backend
  static Future<void> registrarDispositivo({
    required int idPersona,
    required String plataforma, // "android" / "ios"
  }) async {
    final token = await getFcmToken();
    if (token == null) {
      print("⚠️ No se pudo obtener token FCM");
      return;
    }

    try {
      final resp = await _dio.post(
        '/dispositivo',
        data: {
          'id_persona': idPersona,
          'plataforma': plataforma,
          'push_token': token,
        },
      );
      print("✅ Dispositivo registrado: ${resp.data}");
    } catch (e) {
      print("❌ Error registrando dispositivo: $e");
    }
  }

  /// Helper para usar justo después del login
  static Future<void> initForPersona({required int idPersona}) async {
    // 1) Asegura Firebase + notificaciones
    await initFirebaseAndNotifications();

    // 2) Determinar plataforma
    String plataforma;
    if (Platform.isAndroid) {
      plataforma = "android";
    } else if (Platform.isIOS) {
      plataforma = "ios";
    } else {
      plataforma = "otro";
    }

    // 3) Registrar en backend
    await registrarDispositivo(
      idPersona: idPersona,
      plataforma: plataforma,
    );
  }
}
