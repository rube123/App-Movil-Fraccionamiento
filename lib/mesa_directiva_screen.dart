import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fraccionamiento/colors.dart';

class MesaDirectivaScreen extends StatefulWidget {
  final bool embedded;

  const MesaDirectivaScreen({super.key, this.embedded = false});

  @override
  State<MesaDirectivaScreen> createState() => _MesaDirectivaScreenState();
}

class _MesaDirectivaScreenState extends State<MesaDirectivaScreen> {
  final Dio dio = Dio(
    BaseOptions(baseUrl: 'https://apifraccionamiento.onrender.com'),
  );

  bool cargando = true;
  List<dynamic> miembros = [];
  String? error;

  @override
  void initState() {
    super.initState();
    _cargarMiembros();
  }

  Future<void> _cargarMiembros() async {
    try {
      final res = await dio.get('/mesa_directiva/miembros');
      setState(() {
        miembros = res.data as List<dynamic>;
        cargando = false;
      });
    } catch (e) {
      setState(() {
        error = 'Error al cargar mesa directiva: $e';
        cargando = false;
      });
    }
  }

  Widget _buildBody() {
    if (cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Text(error!, style: const TextStyle(color: Colors.red)),
      );
    }

    if (miembros.isEmpty) {
      return const Center(
        child: Text('No hay miembros de la mesa directiva registrados'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: miembros.length,
      itemBuilder: (context, index) {
        final m = miembros[index] as Map<String, dynamic>;
        final nombre = '${m["nombre"]} ${m["primer_apellido"] ?? ""}';
        final rol = m["rol"] ?? 'Miembro';
        final casa = m["no_residencia"]?.toString() ?? '-';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: ListTile(
            leading: const CircleAvatar(
              backgroundImage: AssetImage('assets/avatar_default.png'),
            ),
            title: Text(nombre),
            subtitle: Text('$rol · Casa $casa'),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = _buildBody();

    if (widget.embedded) {
      // Dentro del PageView
      return body;
    }

    // Pantalla normal
    return Scaffold(
      backgroundColor: AppColors.celesteClaro,
      appBar: AppBar(
        backgroundColor: AppColors.celesteNegro,
        title: const Text('Mesa Directiva',
            style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
      ),
      body: body,
    );
  }
}

