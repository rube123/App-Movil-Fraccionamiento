import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:fraccionamiento/colors.dart';

class MantenimientoPagoScreen extends StatefulWidget {
  final Dio dio;
  final int idPersona;
  final int idUsuario;

  const MantenimientoPagoScreen({
    super.key,
    required this.dio,
    required this.idPersona,
    required this.idUsuario,
  });

  @override
  State<MantenimientoPagoScreen> createState() => _MantenimientoPagoScreenState();
}

class _MantenimientoPagoScreenState extends State<MantenimientoPagoScreen> {
  final _formKey = GlobalKey<FormState>();

  final montoCtrl = TextEditingController(text: "500.00");
  final conceptoCtrl = TextEditingController(text: "Mantenimiento");

  String cuentaDestino = "Cuenta mantenimiento";
  bool pagando = false;

  static const int _idTipoCuotaMantenimiento = 1; 
  static const int _cveTipoPagoStripe = 2; 

  @override
  void dispose() {
    montoCtrl.dispose();
    conceptoCtrl.dispose();
    super.dispose();
  }

  int _noTransaccionI32Safe() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }

  Future<Map<String, dynamic>> _crearIntentMantenimiento({
    required int montoCentavos,
    required String concepto,
    required String cuentaDestino,
  }) async {
    final int noTransaccion = _noTransaccionI32Safe();
    debugPrint("idPersona=${widget.idPersona}, idUsuario=${widget.idUsuario}");

    final res = await widget.dio.post(
      "/pagos/crear_intent",
      data: {
        "no_transaccion": noTransaccion,
        "id_persona": widget.idPersona,
        "id_usuario": widget.idUsuario,
        "id_tipo_cuota": _idTipoCuotaMantenimiento,
        "cve_tipo_pago": _cveTipoPagoStripe,
        "descripcion": "$concepto | $cuentaDestino",
        "monto_centavos": montoCentavos,
        "moneda": "mxn",
      },
    );

    return (res.data as Map).cast<String, dynamic>();
  }

  Future<void> _pagar() async {
    if (!_formKey.currentState!.validate()) return;

    final monto = double.parse(montoCtrl.text.trim().replaceAll(",", "."));
    final montoCentavos = (monto * 100).round();
    final concepto = conceptoCtrl.text.trim().isEmpty ? "Mantenimiento" : conceptoCtrl.text.trim();

    setState(() => pagando = true);

    try {
      final intent = await _crearIntentMantenimiento(
        montoCentavos: montoCentavos,
        concepto: concepto,
        cuentaDestino: cuentaDestino,
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
      debugPrint("idPersona=${widget.idPersona}, idUsuario=${widget.idUsuario}");

      await widget.dio.post(
        "/pagos/confirmar",
        data: {"payment_intent_id": paymentIntentId},
      );

      if (!mounted) return;
      setState(() => pagando = false);

      await showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Depósito realizado"),
          content: Text(
            "Pago registrado.\n"
            "Cuenta: $cuentaDestino\n"
            "Concepto: $concepto\n"
            "Monto: \$${monto.toStringAsFixed(2)}",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } on StripeException catch (e) {
      if (!mounted) return;
      setState(() => pagando = false);
      _mostrarError("Pago cancelado o fallido: ${e.error.localizedMessage ?? ""}");
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => pagando = false);
      _mostrarError("No se pudo realizar el pago.\nHTTP ${e.response?.statusCode}\n${e.response?.data ?? e.message}");
    } catch (e) {
      if (!mounted) return;
      setState(() => pagando = false);
      _mostrarError("No se pudo realizar el pago.\n$e");
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.celesteNegro,
        title: const Text("Mantenimiento", style: TextStyle(color: Colors.white),),
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(blurRadius: 3, color: Colors.black12)],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Depósito a cuenta (simulado)",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: cuentaDestino,
                      items: const [
                        DropdownMenuItem(value: "Cuenta mantenimiento", child: Text("Cuenta mantenimiento")),
                        DropdownMenuItem(value: "Cuenta principal", child: Text("Cuenta principal")),
                      ],
                      onChanged: (v) => setState(() => cuentaDestino = v ?? "Cuenta mantenimiento"),
                      decoration: const InputDecoration(
                        labelText: "Cuenta destino",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: montoCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: "Monto (MXN)",
                        hintText: "Ej: 500.00",
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final s = (v ?? "").trim().replaceAll(",", ".");
                        final m = double.tryParse(s);
                        if (m == null || m <= 0) return "Monto inválido";
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: conceptoCtrl,
                      decoration: const InputDecoration(
                        labelText: "Concepto",
                        hintText: "Ej: Mantenimiento Noviembre",
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.celesteNegro,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: pagando ? null : _pagar,
                        icon: pagando
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.credit_card, color: Colors.white,),
                        label: Text(pagando ? "Procesando..." : "Seleccionar tarjeta y pagar", style: TextStyle(color: Colors.white),),
                      ),
                    ),
                    
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
