import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fraccionamiento/colors.dart';

class AvisosScreen extends StatefulWidget {
  final List<String> roles;
  final int idPersona;
  final int idUsuario;

  const AvisosScreen({
    super.key,
    required this.roles,
    required this.idPersona,
    required this.idUsuario,
  });

  @override
  State<AvisosScreen> createState() => _AvisosScreenState();
}

class _AvisosScreenState extends State<AvisosScreen> {
  final Dio dio =
      Dio(BaseOptions(baseUrl: 'https://apifraccionamiento.onrender.com'));
  // final Dio dio = Dio(BaseOptions(baseUrl: 'https://apifracc-1.onrender.com'));

  bool get puedeEnviar =>
      widget.roles.contains('admin') || widget.roles.contains('mesa_directiva');

  List avisos = [];
  List<Map<String, dynamic>> personas = [];
  List<int> seleccionados = [];

  bool cargando = true;
  String? error;

  // form
  bool aTodos = true;
  final tituloCtrl = TextEditingController();
  final mensajeCtrl = TextEditingController();
  String filtro = '';

  @override
  void initState() {
    super.initState();
    cargarAvisos();
    if (puedeEnviar) cargarPersonas();
  }

  @override
  void dispose() {
    tituloCtrl.dispose();
    mensajeCtrl.dispose();
    super.dispose();
  }

  Future<void> cargarPersonas() async {
    try {
      final res = await dio.get('/personas');
      setState(() {
        personas = (res.data as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      // Si falla, no tronamos la pantalla, solo mostramos error en consola
      debugPrint('Error cargando personas: $e');
    }
  }

  Future<void> cargarAvisos() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      // Trae avisos para esta persona (con campo leido si tu API lo manda)
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
      debugPrint("❌ Error marcando leído: $e");
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

    // ✅ al cerrar el dialog lo marcamos leído si aún no lo estaba
    if (!yaLeido) {
      await _marcarAvisoLeido(idAviso);
      await cargarAvisos(); // refresca lista para que cambie icono/estilo
    }
  }

  Future<void> enviarAviso() async {
    if (tituloCtrl.text.isEmpty || mensajeCtrl.text.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Título y mensaje son obligatorios')),
      );
      return;
    }

    try {
      await dio.post(
        '/avisos',
        data: {
          "id_usuario_emisor": widget.idUsuario,
          "titulo": tituloCtrl.text,
          "mensaje": mensajeCtrl.text,
          "a_todos": aTodos,
          "destinatarios": aTodos ? null : seleccionados,
        },
      );

      tituloCtrl.clear();
      mensajeCtrl.clear();
      seleccionados.clear();
      aTodos = true;

      await cargarAvisos();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aviso enviado')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al enviar aviso: $e')),
      );
    }
  }

  void abrirNuevoAviso() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final listaFiltrada = personas.where((p) {
              final nombre =
                  '${p["nombre"]} ${p["primer_apellido"]}'.toLowerCase();
              return nombre.contains(filtro.toLowerCase());
            }).toList();

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
              ),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Nuevo aviso",
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: tituloCtrl,
                      decoration: InputDecoration(
                        labelText: "Título",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    TextField(
                      controller: mensajeCtrl,
                      minLines: 3,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: "Mensaje",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    SwitchListTile(
                      title: const Text("Enviar a todos"),
                      value: aTodos,
                      onChanged: (v) => setModalState(() {
                        aTodos = v;
                        if (aTodos) seleccionados.clear();
                      }),
                    ),

                    if (!aTodos) ...[
                      TextField(
                        decoration: InputDecoration(
                          hintText: "Buscar persona...",
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: Colors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onChanged: (v) => setModalState(() => filtro = v),
                      ),
                      const SizedBox(height: 8),

                      ...listaFiltrada.map((p) {
                        final id = p["id_persona"] as int;
                        final nombre =
                            '${p["nombre"]} ${p["primer_apellido"]}';
                        final seleccionado = seleccionados.contains(id);

                        return CheckboxListTile(
                          value: seleccionado,
                          title: Text(nombre),
                          subtitle: Text(
                            p["no_residencia"] != null
                                ? "Casa ${p["no_residencia"]}"
                                : "Sin residencia asignada",
                          ),
                          activeColor: AppColors.celesteNegro,
                          checkColor: Colors.white,
                          side: const BorderSide(
                            color: AppColors.celesteNegro,
                            width: 1.5,
                          ),
                          selected: seleccionado,
                          selectedTileColor:
                              AppColors.celesteClaro.withOpacity(0.3),
                          onChanged: (v) {
                            setModalState(() {
                              if (v == true) {
                                if (!seleccionados.contains(id)) {
                                  seleccionados.add(id);
                                }
                              } else {
                                seleccionados.remove(id);
                              }
                            });
                          },
                        );
                      }),
                    ],

                    const SizedBox(height: 10),
                    ElevatedButton.icon(
                      onPressed: () async {
                        await enviarAviso();
                        // 🔹 Aquí SÓLO cerramos el bottom sheet.
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                      icon: const Icon(Icons.send, color: Colors.white),
                      label: const Text(
                        "Enviar aviso",
                        style: TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.celesteNegro,
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.celesteClaro,
      appBar: AppBar(
        backgroundColor: AppColors.celesteNegro,
        title: const Text("Avisos", style: TextStyle(color: Colors.white)),
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
                            leading: Icon(
                              leido
                                  ? Icons.notifications_none
                                  : Icons.notifications_active,
                              color: leido
                                  ? Colors.grey
                                  : AppColors.celesteNegro,
                            ),
                            title: Text(
                              a["titulo"] ?? "",
                              style: TextStyle(
                                fontWeight: leido
                                    ? FontWeight.normal
                                    : FontWeight.bold,
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
      floatingActionButton: puedeEnviar
          ? FloatingActionButton.extended(
              onPressed: abrirNuevoAviso,
              backgroundColor: AppColors.celesteNegro,
              icon: const Icon(Icons.add, color: Colors.white),
              label: const Text(
                "Nuevo aviso",
                style: TextStyle(color: Colors.white),
              ),
            )
          : null,
    );
  }
}
