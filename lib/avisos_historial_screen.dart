import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fraccionamiento/colors.dart';

class AvisosHistorialScreen extends StatefulWidget {
  final int idPersona;
  const AvisosHistorialScreen({super.key, required this.idPersona});

  @override
  State<AvisosHistorialScreen> createState() => _AvisosHistorialScreenState();
}

class _AvisosHistorialScreenState extends State<AvisosHistorialScreen> {
  static const String BASE_URL = "https://apifraccionamiento.onrender.com";
  //static const String BASE_URL = "https://apifracc-1.onrender.com";
  final Dio dio = Dio(BaseOptions(baseUrl: BASE_URL));

  bool cargando = true;
  String? error;
  List avisos = [];

  @override
  void initState() {
    super.initState();
    cargarAvisos();
  }

  Future<void> cargarAvisos() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      final res = await dio.get('/avisos/persona/${widget.idPersona}');
      avisos = res.data as List;
      setState(() => cargando = false);
    } catch (e) {
      setState(() {
        cargando = false;
        error = "Error al cargar avisos: $e";
      });
    }
  }

  Future<void> _marcarAvisoLeido(int idAviso) async {
    try {
      await dio.post(
        '/avisos/leer',
        data: {
          "id_persona": widget.idPersona,
          "ids_avisos": [idAviso],
        },
      );
    } catch (e) {
      print("❌ Error marcando leído: $e");
    }
  }

  Future<void> _mostrarDetalleAviso(Map<String, dynamic> aviso) async {
    final int idAviso = aviso["id_aviso"] as int;
    final bool yaLeido = (aviso["leido"] == true);

    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(aviso["titulo"] ?? "Aviso"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(aviso["mensaje"] ?? ""),
            const SizedBox(height: 12),
            Text(
              "Enviado por: ${aviso["nombre_emisor"] ?? ""}",
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
            if (aviso["creado_en"] != null)
              Text(
                "Fecha: ${aviso["creado_en"]}",
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );

    if (!yaLeido) {
      await _marcarAvisoLeido(idAviso);
      await cargarAvisos();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.celesteClaro,
      appBar: AppBar(
        backgroundColor: AppColors.celesteNegro,
        title: const Text("Avisos"),
        foregroundColor: Colors.white,
      ),
      body: cargando
          ? const Center(child: CircularProgressIndicator())
          : error != null
          ? Center(child: Text(error!))
          : avisos.isEmpty
          ? const Center(child: Text("No hay avisos aún."))
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: avisos.length,
              itemBuilder: (_, i) {
                final a = avisos[i] as Map<String, dynamic>;
                final bool leido = a["leido"] == true;

                return Card(
                  child: ListTile(
                    onTap: () => _mostrarDetalleAviso(a),
                    leading: leido
                        ? const Icon(Icons.mark_email_read)
                        : const Icon(
                            Icons.mark_email_unread,
                            color: Colors.blue,
                          ),
                    title: Text(
                      a["titulo"] ?? "",
                      style: TextStyle(
                        fontWeight: leido ? FontWeight.normal : FontWeight.bold,
                      ),
                    ),
                    subtitle: Text(a["mensaje"] ?? ""),
                    trailing: Text(
                      a["nombre_emisor"] ?? "",
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                );
              },
            ),
    );
  }
}
