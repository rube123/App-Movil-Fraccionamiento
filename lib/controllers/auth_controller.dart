import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:fraccionamiento/models/user_model.dart';
import 'package:fraccionamiento/services/google_auth_service.dart';

class AuthController extends GetxController {
  static AuthController get to => Get.find<AuthController>();

  final googleService = GoogleAuthService();

  /// Estado del usuario actual
  Rx<UserModel> user = UserModel.empty().obs;

  bool get isLoggedIn => user.value.uid.isNotEmpty;

  @override
  void onInit() {
    super.onInit();

    // Escucha global del estado de FirebaseAuth
    FirebaseAuth.instance.authStateChanges().listen((firebaseUser) {
      if (firebaseUser == null) {
        user.value = UserModel.empty();
      } else {
        setFromFirebase(firebaseUser);
      }
    });
  }

  /// Llena tu UserModel desde Firebase
  void setFromFirebase(User firebaseUser) {
    user.value = UserModel(
      uid: firebaseUser.uid,
      name: firebaseUser.displayName ?? "",
      email: firebaseUser.email ?? "",
      photoUrl: firebaseUser.photoURL ?? "",
    );
  }

  /// Login con Google SOLO en Firebase.
  ///
  /// No muestra SnackBars (para evitar el error de overlay null),
  /// solo actualiza `user` e imprime errores en consola.
  Future<void> loginWithGoogle() async {
    try {
      final credential = await googleService.signInWithGoogle();
      if (credential == null) {
        // Usuario canceló la ventana de Google
        await FirebaseAuth.instance.signOut();
        user.value = UserModel.empty();
        return;
      }

      final firebaseUser = credential.user;
      if (firebaseUser == null) {
        await FirebaseAuth.instance.signOut();
        user.value = UserModel.empty();
        return;
      }

      // Login Firebase OK
      setFromFirebase(firebaseUser);
    } catch (e, st) {
      debugPrint("Error en loginWithGoogle: $e\n$st");
      await FirebaseAuth.instance.signOut();
      user.value = UserModel.empty();
    }
  }

  /// Cerrar sesión total (Google + Firebase) y limpiar modelo
  Future<void> logout() async {
    await googleService.signOut();
    await FirebaseAuth.instance.signOut();
    user.value = UserModel.empty();
  }
}
