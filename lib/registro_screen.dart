import 'package:flutter/material.dart';
import 'package:fraccionamiento/colors.dart';

class RegistroScreen extends StatelessWidget {
  const RegistroScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.celesteNegro,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(25),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 60),
            const Text(
              'Registro de Residente',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 20),
            _campo('Nombre(s)'),
            _campo('Apellidos'),
            _campo('Correo Electrónico'),
            _campo('Número de Teléfono'),
            _campo('Número de Residencia'),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: () {},
              icon: const Icon(
                Icons.attach_file,
                color: AppColors.celesteNegro,
              ),
              label: const Text(
                'Adjuntar Comprobante de Identidad',
                style: TextStyle(color: AppColors.celesteNegro),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () =>
                  Navigator.pushReplacementNamed(context, '/inicio'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.amarillo,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text(
                'Enviar Solicitud',
                style: TextStyle(
                  color: Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'Su cuenta se activará tras la validación de la Mesa Directiva.',
              style: TextStyle(color: Colors.white, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  Widget _campo(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        decoration: InputDecoration(
          hintText: label,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}
