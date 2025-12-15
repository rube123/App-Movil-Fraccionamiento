import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:fraccionamiento/colors.dart';
import 'package:fraccionamiento/controllers/auth_controller.dart';

class ProfileScreen extends StatefulWidget {
  final int idPersona; // 👈 ESTE es el importante para el perfil
  final int idUsuario; // lo dejo por si lo necesitas después

  const ProfileScreen({
    super.key,
    required this.idPersona,
    required this.idUsuario,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const String baseUrl = "https://apifraccionamiento.onrender.com";
  late final Dio dio;

  bool cargando = true;
  String? error;

  String? nombreBackend;
  String? correoBackend;
  String? numeroCasaBackend;

  @override
  void initState() {
    super.initState();
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
      ),
    );
    _cargarPerfil();
  }

  Future<void> _cargarPerfil() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      // 👈 USAR idPersona, NO idUsuario
      final res = await dio.get('/persona/${widget.idPersona}');

      if (res.statusCode != 200) {
        setState(() {
          cargando = false;
          error = "Error al cargar perfil (HTTP ${res.statusCode}).";
        });
        return;
      }

      final data = Map<String, dynamic>.from(res.data as Map);

      setState(() {
        nombreBackend = data["nombre"] as String?;
        correoBackend = data["correo"] as String?;
        numeroCasaBackend = data["numero_casa"]?.toString();
        cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = "Error al cargar perfil: $e";
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthController.to;

    return Scaffold(
      backgroundColor: AppColors.celesteClaro,
      appBar: AppBar(
        backgroundColor: AppColors.celesteNegro,
        title: const Text('Perfil'),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Obx(() {
        final user = auth.user.value;

        // Avatar: foto de Google o avatar por defecto
        final ImageProvider avatarImage = user.photoUrl.isNotEmpty
            ? NetworkImage(user.photoUrl)
            : const AssetImage('assets/avatar_default.png');

        // Datos mostrados (BACKEND manda):
        final String displayName = nombreBackend ?? user.name;
        final String displayEmail = correoBackend ?? user.email;

        final String displayCasa = (numeroCasaBackend == null ||
                numeroCasaBackend!.isEmpty)
            ? "Sin número asignado"
            : numeroCasaBackend!;

        if (cargando) {
          return const Center(child: CircularProgressIndicator());
        }

        if (error != null) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    error!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: _cargarPerfil,
                    child: const Text("Reintentar"),
                  ),
                ],
              ),
            ),
          );
        }

        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),

              // ===== AVATAR + ICONO DE EDITAR =====
              Center(
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 110,
                      height: 110,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: CircleAvatar(
                        radius: 45,
                        backgroundImage: avatarImage,
                      ),
                    ),
                    Positioned(
                      bottom: 0,
                      right: -2,
                      child: Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          color: AppColors.celesteNegro,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.edit,
                          size: 18,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // ===== NOMBRE (desde backend) =====
              Center(
                child: Text(
                  displayName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 28),

              // ===== CARD: CORREO =====
              _InfoCard(
                icon: Icons.email_outlined,
                title: 'Correo electrónico',
                value: displayEmail,
              ),
              const SizedBox(height: 12),

              // ===== CARD: NÚMERO DE CASA =====
              _InfoCard(
                icon: Icons.home_outlined,
                title: 'Número de casa',
                value: displayCasa,
              ),

              const SizedBox(height: 40),

              // ===== BOTÓN CERRAR SESIÓN =====
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => auth.logout(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.celesteNegro,
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Cerrar sesión',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

// ===== TARJETA REUTILIZABLE =====
class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.celesteClaro,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.celesteNegro,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right,
            size: 20,
            color: Colors.grey,
          ),
        ],
      ),
    );
  }
}
