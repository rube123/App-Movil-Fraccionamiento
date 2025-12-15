import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fraccionamiento/colors.dart';
import 'package:fraccionamiento/login_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _pagina = 0;

  final List<_OnboardPage> pages = const [
    _OnboardPage(
      titulo: "Bienvenido",
      descripcion: "Tu fraccionamiento ahora está al alcance de tu mano.",
      icono: Icons.home,
    ),
    _OnboardPage(
      titulo: "Avisos y Reservas",
      descripcion: "Recibe avisos y administra tus áreas comunes fácilmente.",
      icono: Icons.notifications_active,
    ),
    _OnboardPage(
      titulo: "Pagos Simples",
      descripcion: "Realiza tus pagos de mantenimiento de forma segura.",
      icono: Icons.credit_card,
    ),
  ];

  Future<void> _finish() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setBool("onboarding_done", true);
    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.celesteClaro,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _controller,
                onPageChanged: (i) => setState(() => _pagina = i),
                itemCount: pages.length,
                itemBuilder: (_, i) => pages[i],
              ),
            ),

            // Indicadores
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                pages.length,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 250),
                  margin: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 20,
                  ),
                  width: _pagina == i ? 22 : 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: _pagina == i
                        ? AppColors.celesteNegro
                        : Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.celesteNegro,
                  minimumSize: const Size(double.infinity, 50),
                ),
                onPressed: () {
                  if (_pagina == pages.length - 1) {
                    _finish();
                  } else {
                    _controller.nextPage(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeInOut,
                    );
                  }
                },
                child: Text(
                  _pagina == pages.length - 1 ? "Comenzar" : "Siguiente",
                  style: const TextStyle(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardPage extends StatelessWidget {
  final String titulo;
  final String descripcion;
  final IconData icono;

  const _OnboardPage({
    required this.titulo,
    required this.descripcion,
    required this.icono,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(30),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icono, size: 120, color: AppColors.celesteNegro),
          const SizedBox(height: 40),
          Text(
            titulo,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: AppColors.celesteNegro,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          Text(
            descripcion,
            style: const TextStyle(fontSize: 18, color: Colors.black87),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
