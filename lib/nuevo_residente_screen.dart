import 'package:flutter/material.dart';
import 'package:dio/dio.dart';
import 'package:fraccionamiento/colors.dart';

class NuevoResidenteScreen extends StatefulWidget {
  const NuevoResidenteScreen({super.key});

  @override
  State<NuevoResidenteScreen> createState() => _NuevoResidenteScreenState();
}

class _NuevoResidenteScreenState extends State<NuevoResidenteScreen> {
  //final Dio dio =Dio(BaseOptions(baseUrl: 'https://apifraccionamiento.onrender.com'));
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://apifracc-1.onrender.com'));

  final _formKey = GlobalKey<FormState>();

  final TextEditingController nombreCtrl = TextEditingController();
  final TextEditingController apellido1Ctrl = TextEditingController();
  final TextEditingController apellido2Ctrl = TextEditingController();
  final TextEditingController correoCtrl = TextEditingController();
  final TextEditingController telefonoCtrl = TextEditingController();
  final TextEditingController numeroCasaCtrl = TextEditingController();

  Future<void> insertarResidente() async {
    if (!_formKey.currentState!.validate()) return;

    final numeroCasa = int.tryParse(numeroCasaCtrl.text.trim());
    if (numeroCasa == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Número de casa inválido')));
      return;
    }

    try {
      final res = await dio.post(
        '/persona',
        data: {
          "nombre": nombreCtrl.text.trim(),
          "primer_apellido": apellido1Ctrl.text.trim(),
          "segundo_apellido": apellido2Ctrl.text.trim().isEmpty
              ? null
              : apellido2Ctrl.text.trim(),
          // correo obligatorio (el backend lo requiere para crear usuario)
          "correo": correoCtrl.text.trim(),
          // teléfono opcional
          "telefono": telefonoCtrl.text.trim().isEmpty
              ? null
              : telefonoCtrl.text.trim(),
          "no_residencia": numeroCasa,
        },
      );

      final data = res.data is Map ? res.data as Map : <String, dynamic>{};
      final correoLogin = (data['correo_login'] ?? correoCtrl.text.trim())
          .toString();
      final passDefault = (data['contrasena_default'] ?? '123456').toString();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Residente creado.\nUsuario: $correoLogin\nContraseña: $passDefault',
          ),
          duration: const Duration(seconds: 4),
        ),
      );

      Navigator.pop(context, true);
    } on DioException catch (e) {
      final msg = e.response?.data?.toString() ?? e.message ?? e.toString();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al agregar residente: $msg')),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error inesperado: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.celesteClaro,
      appBar: AppBar(
        backgroundColor: AppColors.celesteVivo,
        title: const Text('Nuevo Residente'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              campoTexto('Nombre', nombreCtrl),
              campoTexto('Primer apellido', apellido1Ctrl),
              campoTexto('Segundo apellido', apellido2Ctrl, obligatorio: false),
              campoTexto(
                'Correo electrónico',
                correoCtrl,
                tipo: TextInputType.emailAddress,
              ),
              campoTexto(
                'Teléfono',
                telefonoCtrl,
                tipo: TextInputType.phone,
                obligatorio: false,
              ),
              campoTexto(
                'Número de casa',
                numeroCasaCtrl,
                tipo: TextInputType.number,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                icon: const Icon(Icons.save),
                label: const Text('Guardar residente'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.celesteVivo,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: insertarResidente,
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
    bool obligatorio = true,
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
        validator: (value) {
          if (!obligatorio) return null;
          if (value == null || value.trim().isEmpty) {
            return 'Campo obligatorio';
          }
          return null;
        },
      ),
    );
  }
}
