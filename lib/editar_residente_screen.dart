import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fraccionamiento/colors.dart';
import 'package:fraccionamiento/models/api_fracc_dao.dart';

class EditarResidenteScreen extends StatefulWidget {
  final Residente residente;

  const EditarResidenteScreen({super.key, required this.residente});

  @override
  State<EditarResidenteScreen> createState() => _EditarResidenteScreenState();
}

class _EditarResidenteScreenState extends State<EditarResidenteScreen> {
  //  final Dio dio = Dio(BaseOptions(baseUrl: 'https://apifraccionamiento.onrender.com'),
  //);

  final Dio dio = Dio(BaseOptions(baseUrl: 'https://apifracc-1.onrender.com'));
  final _formKey = GlobalKey<FormState>();

  late TextEditingController nombreCtrl;
  late TextEditingController apellido1Ctrl;
  late TextEditingController apellido2Ctrl;
  late TextEditingController correoCtrl;
  late TextEditingController telefonoCtrl;
  late TextEditingController numeroCasaCtrl;

  @override
  void initState() {
    super.initState();
    nombreCtrl = TextEditingController(text: widget.residente.nombre);
    apellido1Ctrl = TextEditingController(
      text: widget.residente.primerApellido,
    );
    apellido2Ctrl = TextEditingController(
      text: widget.residente.segundoApellido ?? '',
    );
    correoCtrl = TextEditingController(text: widget.residente.correo ?? '');
    telefonoCtrl = TextEditingController(text: widget.residente.telefono ?? '');
    numeroCasaCtrl = TextEditingController(
      text: widget.residente.numeroResidencia?.toString() ?? '',
    );
  }

  Future<void> actualizarResidente() async {
    if (!_formKey.currentState!.validate()) return;

    try {
      await dio.put(
        '/persona/${widget.residente.idResidente}',
        data: {
          "nombre": nombreCtrl.text,
          "primer_apellido": apellido1Ctrl.text,
          "segundo_apellido": apellido2Ctrl.text.isEmpty
              ? null
              : apellido2Ctrl.text,
          "correo": correoCtrl.text.isEmpty ? null : correoCtrl.text,
          "telefono": telefonoCtrl.text.isEmpty ? null : telefonoCtrl.text,
          "no_residencia": int.tryParse(numeroCasaCtrl.text),
        },
      );

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Persona actualizada correctamente')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al actualizar persona: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.celesteClaro,
      appBar: AppBar(
        backgroundColor: AppColors.celesteVivo,
        title: const Text('Editar Residente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              campoTexto('Nombre', nombreCtrl),
              campoTexto('Primer apellido', apellido1Ctrl),
              campoTexto('Segundo apellido', apellido2Ctrl),
              campoTexto(
                'Correo electrónico',
                correoCtrl,
                tipo: TextInputType.emailAddress,
              ),
              campoTexto('Teléfono', telefonoCtrl, tipo: TextInputType.phone),
              campoTexto(
                'Número de casa',
                numeroCasaCtrl,
                tipo: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar cambios'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.celesteVivo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: actualizarResidente,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget campoTexto(
    String label,
    TextEditingController controller, {
    TextInputType tipo = TextInputType.text,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: TextFormField(
        controller: controller,
        keyboardType: tipo,
        decoration: InputDecoration(
          labelText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        validator: (value) =>
            value == null || value.isEmpty ? 'Campo obligatorio' : null,
      ),
    );
  }
}
