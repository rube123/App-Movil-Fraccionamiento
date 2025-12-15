import 'package:flutter/material.dart';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';

class TutorialService {
  late TutorialCoachMark tutorial;

  List<TargetFocus> createTargets({
    GlobalKey? botonReservas,
    GlobalKey? botonAvisos,
    GlobalKey? botonPagos,
    GlobalKey? botonPerfil,
    bool mostrarReservas = false,
    bool mostrarAvisos = false,
    bool mostrarPagos = false,
    bool mostrarPerfil = false,
  }) {
    final targets = <TargetFocus>[];

    if (mostrarReservas && botonReservas != null) {
      targets.add(
        TargetFocus(
          identify: "reservas",
          keyTarget: botonReservas,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _texto(
                "Áreas comunes",
                "Desde aquí puedes reservar áreas como salón de fiestas, alberca o multicancha.",
              ),
            ),
          ],
        ),
      );
    }

    if (mostrarPagos && botonPagos != null) {
      targets.add(
        TargetFocus(
          identify: "pagos",
          keyTarget: botonPagos,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _texto(
                "Pagos",
                "Consulta tus pagos pendientes, tu historial y genera comprobantes.",
              ),
            ),
          ],
        ),
      );
    }

    if (mostrarAvisos && botonAvisos != null) {
      targets.add(
        TargetFocus(
          identify: "avisos",
          keyTarget: botonAvisos,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.top,
              child: _texto(
                "Avisos",
                "Aquí verás los avisos importantes que envía la administración o mesa directiva.",
              ),
            ),
          ],
        ),
      );
    }

    if (mostrarPerfil && botonPerfil != null) {
      targets.add(
        TargetFocus(
          identify: "perfil",
          keyTarget: botonPerfil,
          shape: ShapeLightFocus.Circle,
          contents: [
            TargetContent(
              align: ContentAlign.bottom,
              child: _texto(
                "Tu perfil",
                "Toca tu foto para ver tus datos y cerrar sesión cuando lo necesites.",
              ),
            ),
          ],
        ),
      );
    }

    return targets;
  }

  Widget _texto(String titulo, String desc) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          titulo,
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          desc,
          style: const TextStyle(fontSize: 17, color: Colors.white),
        ),
      ],
    );
  }

  Future<void> start({
    required BuildContext context,
    required List<TargetFocus> targets,
  }) async {
    tutorial = TutorialCoachMark(
      targets: targets,
      colorShadow: Colors.black.withOpacity(0.8),
      textSkip: "Saltar",
      paddingFocus: 10,
      opacityShadow: 0.9,
      alignSkip: Alignment.topLeft,
      onFinish: () => debugPrint("Tutorial finalizado"),
      onSkip: () {
        debugPrint("Tutorial saltado");
        return true; // Importante
      },
    );

    await Future.delayed(const Duration(milliseconds: 300));
    tutorial.show(context: context);
  }
}
