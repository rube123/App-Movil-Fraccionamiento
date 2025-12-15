import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:fraccionamiento/colors.dart';
import 'package:fraccionamiento/mantenimiento_pagos_screen.dart';

class PagosScreen extends StatefulWidget {
  final int idPersona;
  final int idUsuario;
  final List<String> roles;
  final bool embedded;

  const PagosScreen({
    super.key,
    required this.idPersona,
    required this.idUsuario,
    required this.roles,
    this.embedded = false,
  });

  @override
  State<PagosScreen> createState() => _PagosScreenState();
}

class _PagosScreenState extends State<PagosScreen> {
  static const String baseUrl = "https://apifraccionamiento.onrender.com";
  //static const String baseUrl = "http://192.168.100.132:3002";
  //static const String baseUrl = "https://apifracc-1.onrender.com";

  late final Dio dio;

  bool viendoPendientes = true;
  bool cargando = true;
  String? error;
  List<dynamic> pagos = [];

  int _idPersona = 0;
  int _idUsuario = 0;

  static const int _cveTipoPagoStripe = 2;
  static const int _idTipoCuotaDefault = 1;

  late final bool isAdmin;
  late final bool isMesa;
  late final bool isResidente;

  @override
  void initState() {
    super.initState();
    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
      ),
    );

    dio.interceptors.add(
      LogInterceptor(
        request: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );

    isAdmin = widget.roles.contains('admin');
    isMesa = widget.roles.contains('mesa_directiva');
    isResidente = widget.roles.contains('residente');

    _initIdsAndLoad();
  }

  Future<void> _initIdsAndLoad() async {
    // Usa directamente los valores que vienen del constructor
    _idPersona = widget.idPersona;
    _idUsuario = widget.idUsuario;

    debugPrint("PagosScreen IDs -> persona=$_idPersona usuario=$_idUsuario");

    if (_idPersona <= 0 || _idUsuario <= 0) {
      setState(() {
        cargando = false;
        error =
            "Sesión inválida. Vuelve a iniciar sesión.\n(idPersona=$_idPersona, idUsuario=$_idUsuario)";
      });
      return;
    }

    await cargarPagos();
  }

  String _dioMsg(Response res) {
    final status = res.statusCode;
    final data = res.data;
    return "HTTP $status\n${data ?? ""}";
  }

  Future<void> cargarPagos() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      String endpoint;

      if (viendoPendientes) {
        // Pendientes siempre por persona (admin/mesa/residente)
        endpoint = '/pagos/pendientes/${_idPersona.toString()}';
      } else {
        // Historial dependiendo del rol
        if (isAdmin) {
          // 🔹 Admin: todos los pagos
          endpoint = '/pagos/historial_todos';
        } else if (isMesa) {
          // 🔹 Mesa directiva: solo mantenimiento de todos los residentes
          endpoint = '/pagos/historial_mantenimiento';
        } else {
          // 🔹 Residente: solo su historial personal
          endpoint = '/pagos/historial/${_idPersona.toString()}';
        }
      }

      debugPrint('GET $endpoint');

      final res = await dio.get(endpoint);

      if (res.statusCode != 200) {
        setState(() {
          cargando = false;
          error = "Error al cargar pagos:\n${_dioMsg(res)}";
        });
        return;
      }

      pagos = (res.data as List);

      if (!mounted) return;
      setState(() => cargando = false);
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error =
            "Error al cargar pagos:\nHTTP ${e.response?.statusCode}\n${e.response?.data ?? e.message}";
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        cargando = false;
        error = "Error al cargar pagos: $e";
      });
    }
  }

  Future<Map<String, dynamic>> crearIntentStripe({
    required int noTransaccion,
    required int montoCentavos,
    required int idTipoCuota,
    required int cveTipoPago,
    required String descripcion,
  }) async {
    final res = await dio.post(
      "/pagos/crear_intent",
      data: {
        "no_transaccion": noTransaccion,
        "id_persona": _idPersona,
        "id_usuario": _idUsuario,
        "id_tipo_cuota": idTipoCuota,
        "cve_tipo_pago": cveTipoPago,
        "descripcion": descripcion,
        "monto_centavos": montoCentavos,
        "moneda": "mxn",
      },
    );

    if (res.statusCode != 200) {
      throw Exception("crear_intent falló:\n${_dioMsg(res)}");
    }

    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> pagarAhora(dynamic pago) async {
    try {
      final int noTransaccion = (pago["no_transaccion"] as num).toInt();
      final double total = double.parse(pago["total"].toString());
      final int montoCentavos = (total * 100).round();

      final int idTipoCuota = (pago["id_tipo_cuota"] is num)
          ? (pago["id_tipo_cuota"] as num).toInt()
          : _idTipoCuotaDefault;

      final String descripcion = "Pago #$noTransaccion";

      final intent = await crearIntentStripe(
        noTransaccion: noTransaccion,
        montoCentavos: montoCentavos,
        idTipoCuota: idTipoCuota,
        cveTipoPago: _cveTipoPagoStripe,
        descripcion: descripcion,
      );

      final clientSecret = intent["client_secret"] as String;
      final paymentIntentId = intent["payment_intent_id"] as String;

      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: "Fraccionamiento",
        ),
      );

      await Stripe.instance.presentPaymentSheet();

      final confirmRes = await dio.post(
        "/pagos/confirmar",
        data: {"payment_intent_id": paymentIntentId},
      );

      if (confirmRes.statusCode != 200) {
        throw Exception("confirmar falló:\n${_dioMsg(confirmRes)}");
      }

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Pago registrado"),
          content: const Text("Pago confirmado y guardado en el servidor."),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      await cargarPagos();
    } on StripeException catch (e) {
      if (!mounted) return;
      _mostrarError(
        "Pago cancelado o fallido: ${e.error.localizedMessage ?? ""}",
      );
    } catch (e) {
      if (!mounted) return;
      _mostrarError("No se pudo realizar la transacción.\n$e");
    }
  }

  void _mostrarError(String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Pago fallido"),
        content: Text(msg),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar"),
          ),
        ],
      ),
    );
  }

  Future<void> _irAMantenimiento() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MantenimientoPagoScreen(
          dio: dio,
          idPersona: _idPersona,
          idUsuario: _idUsuario,
        ),
      ),
    );

    if (ok == true) {
      await cargarPagos();
    }
  }

  /// 🔹 Contenido reutilizable (para modo embebido o con Scaffold)
  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          // Filtros
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _filtro(
                'Pendientes',
                viendoPendientes,
                onTap: () {
                  if (!viendoPendientes) {
                    setState(() => viendoPendientes = true);
                    cargarPagos();
                  }
                },
              ),
              _filtro(
                'Historial de Pagos',
                !viendoPendientes,
                onTap: () {
                  if (viendoPendientes) {
                    setState(() => viendoPendientes = false);
                    cargarPagos();
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 25),

          const Text(
            'Gráfico de Pagos',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 20),
          const Icon(Icons.pie_chart, color: AppColors.celesteNegro, size: 100),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _boton('Exportar PDF', AppColors.celesteNegro, () {}),
              _boton('Exportar Excel', AppColors.celesteVivo, () {}),
            ],
          ),

          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: _boton('Pagar', AppColors.celesteNegro, _irAMantenimiento),
          ),

          const SizedBox(height: 20),

          // Lista de pagos
          Expanded(
            child: cargando
                ? const Center(child: CircularProgressIndicator())
                : error != null
                ? Center(child: Text(error!, textAlign: TextAlign.center))
                : pagos.isEmpty
                ? Center(
                    child: Text(
                      viendoPendientes
                          ? "No tienes pagos pendientes."
                          : "No hay historial de pagos.",
                    ),
                  )
                : ListView.builder(
                    itemCount: pagos.length,
                    itemBuilder: (_, i) {
                      final p = pagos[i];
                      final idRecibo = p["no_transaccion"].toString();
                      final monto =
                          "\$${double.parse(p["total"].toString()).toStringAsFixed(2)}";
                      final estado = (p["estado"] ?? "")
                          .toString()
                          .toUpperCase();

                      return _recibo(
                        idRecibo,
                        monto,
                        estado,
                        onAction: () {
                          if (estado == "PENDIENTE") pagarAhora(p);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();

    // 👇 Si viene embebido (desde InicioScreen) no mostramos Scaffold ni AppBar
    if (widget.embedded) {
      return content;
    }

    // 👇 Si viene por ruta normal, se comporta como antes
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.celesteNegro,
        title: const Text(
          'Administración de Pagos',
          style: TextStyle(color: Colors.white),
        ),
        foregroundColor: Colors.white,
      ),
      body: content,
    );
  }

  Widget _filtro(String texto, bool activo, {required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: activo ? AppColors.amarillo : Colors.grey[300],
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          texto,
          style: TextStyle(color: activo ? Colors.black : Colors.grey[700]),
        ),
      ),
    );
  }

  Widget _boton(String texto, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(backgroundColor: color),
      child: Text(texto, style: const TextStyle(color: Colors.white)),
    );
  }

  Widget _recibo(
    String id,
    String monto,
    String estado, {
    required VoidCallback onAction,
  }) {
    final bool pagado = estado == 'PAGADO';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black12)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recibo #$id',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text('Monto: $monto'),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: pagado ? Colors.green : AppColors.amarillo,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  estado,
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TextButton(
                onPressed: onAction,
                child: Text(pagado ? 'Ver Comprobante' : 'Pagar ahora'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
