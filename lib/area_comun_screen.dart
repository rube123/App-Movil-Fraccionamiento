import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:fraccionamiento/colors.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

class AreaComunScreen extends StatefulWidget {
  final int idPersona;
  final int idUsuario;
  final bool embedded;

  const AreaComunScreen({
    super.key,
    required this.idPersona,
    required this.idUsuario,
    this.embedded = false,
  });

  @override
  State<AreaComunScreen> createState() => _AreaComunScreenState();
}

class _AreaComunScreenState extends State<AreaComunScreen>
    with SingleTickerProviderStateMixin {
  static const String baseUrl = "https://apifraccionamiento.onrender.com";
  //static const String baseUrl = "http://192.168.100.132:3002";
  //static const String baseUrl = "https://apifracc-1.onrender.com";

  late final Dio dio;
  late final TabController _tab;

  @override
  void initState() {
    super.initState();

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        contentType: Headers.jsonContentType,
        responseType: ResponseType.json,
        validateStatus: (s) => s != null && s >= 200 && s < 500,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    // 🔹 Ahora el Tab 2 será el historial GLOBAL con persona que reservó
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // 🔹 Cuerpo principal (TabBar + TabBarView)
    final tabBar = TabBar(
      controller: _tab,
      tabs: const [
        Tab(icon: Icon(Icons.add_box_outlined, color: Colors.white)),
        Tab(icon: Icon(Icons.history, color: Colors.white)),
      ],
    );

    final tabViews = TabBarView(
      controller: _tab,
      children: [
        _NuevaReservaTab(
          dio: dio,
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
          onReservaCreada: () => _tab.animateTo(1),
        ),
        _HistorialReservasTab(dio: dio),
      ],
    );

    // 🔹 Mensaje de error por IDs inválidos
    final invalidIdsBody = Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          "IDs inválidos. Regresa y vuelve a iniciar sesión.",
          textAlign: TextAlign.center,
        ),
      ),
    );

    if (widget.idPersona <= 0 || widget.idUsuario <= 0) {
      if (widget.embedded) {
        return invalidIdsBody;
      }
      return Scaffold(
        appBar: AppBar(
          backgroundColor: AppColors.celesteNegro,
          title: const Text(
            "Área Común",
            style: TextStyle(color: Colors.white),
          ),
        ),
        body: invalidIdsBody,
      );
    }

    // 👇 MODO EMBEBIDO (desde InicioScreen, sin Scaffold)
    if (widget.embedded) {
      return Column(
        children: [
          // TabBar con fondo de color para que se vea como barra
          Material(
            color: AppColors.celesteNegro,
            child: SafeArea(
              bottom: false,
              child: tabBar,
            ),
          ),
          Expanded(child: tabViews),
        ],
      );
    }

    // 👇 MODO NORMAL (como estaba: con Scaffold + AppBar + tabs)
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.celesteNegro,
        title: const Text("Área Común", style: TextStyle(color: Colors.white)),
        foregroundColor: Colors.white,
        bottom: tabBar,
      ),
      body: tabViews,
    );
  }
}

// =======================
// TAB: NUEVA RESERVA + CALENDAR
// =======================
class _NuevaReservaTab extends StatefulWidget {
  final Dio dio;
  final int idPersona;
  final int idUsuario;
  final VoidCallback onReservaCreada;

  const _NuevaReservaTab({
    required this.dio,
    required this.idPersona,
    required this.idUsuario,
    required this.onReservaCreada,
  });

  @override
  State<_NuevaReservaTab> createState() => _NuevaReservaTabState();
}

class _NuevaReservaTabState extends State<_NuevaReservaTab> {
  bool cargandoAreas = true;
  String? errorAreas;
  List<dynamic> areas = [];

  dynamic areaSel;

  // Calendar state
  DateTime _focusedDay = DateTime.now();
  DateTime? fechaSel;

  // Fechas ocupadas (por día)
  final Set<DateTime> _ocupadas = {};

  bool cargandoFechas = false;
  String? errorFechas;

  TimeOfDay? horaIni;
  TimeOfDay? horaFin;

  bool consultando = false;
  bool? disponible;
  String? mensajeDisp;

  String _fmtFecha(DateTime d) => DateFormat("yyyy-MM-dd").format(d);
  String _fmtMonth(DateTime d) => DateFormat("yyyy-MM").format(d);

  String _fmtTime(TimeOfDay t) =>
      "${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}";

  DateTime _onlyDate(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  void initState() {
    super.initState();
    _cargarAreas();
  }

  Future<void> _cargarAreas() async {
    setState(() {
      cargandoAreas = true;
      errorAreas = null;
    });

    try {
      final res = await widget.dio.get("/areas");

      if (res.statusCode != 200) {
        setState(() {
          errorAreas =
              "Error al cargar áreas. HTTP ${res.statusCode}\n${res.data}";
          cargandoAreas = false;
        });
        return;
      }

      setState(() {
        areas = (res.data as List);
        cargandoAreas = false;
      });
    } catch (e) {
      setState(() {
        errorAreas = "Error al cargar áreas: $e";
        cargandoAreas = false;
      });
    }
  }

  Future<void> _cargarFechasOcupadas({
    required int cveArea,
    required DateTime month,
  }) async {
    setState(() {
      cargandoFechas = true;
      errorFechas = null;
    });

    try {
      final res = await widget.dio.get(
        "/areas/$cveArea/fechas_ocupadas",
        queryParameters: {"month": _fmtMonth(month)},
      );

      if (res.statusCode != 200) {
        setState(() {
          errorFechas =
              "Error cargando calendario. HTTP ${res.statusCode}\n${res.data}";
          cargandoFechas = false;
        });
        return;
      }

      final data = (res.data is Map)
          ? Map<String, dynamic>.from(res.data as Map)
          : <String, dynamic>{};

      final list = (data["fechas"] is List)
          ? (data["fechas"] as List)
          : <dynamic>[];

      _ocupadas.clear();
      for (final f in list) {
        final parsed = DateTime.tryParse(f.toString());
        if (parsed != null) _ocupadas.add(_onlyDate(parsed));
      }

      setState(() => cargandoFechas = false);
    } catch (e) {
      setState(() {
        errorFechas = "Error cargando calendario: $e";
        cargandoFechas = false;
      });
    }
  }

  Future<void> _pickHoraInicio() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: horaIni ?? const TimeOfDay(hour: 18, minute: 0),
    );
    if (picked != null) {
      setState(() {
        horaIni = picked;
        disponible = null;
        mensajeDisp = null;
      });
    }
  }

  Future<void> _pickHoraFin() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: horaFin ?? const TimeOfDay(hour: 20, minute: 0),
    );
    if (picked != null) {
      setState(() {
        horaFin = picked;
        disponible = null;
        mensajeDisp = null;
      });
    }
  }

  bool _horarioValido() {
    if (horaIni == null || horaFin == null) return false;
    final ini = horaIni!.hour * 60 + horaIni!.minute;
    final fin = horaFin!.hour * 60 + horaFin!.minute;
    return fin > ini;
  }

  void _alert(String titulo, String msg) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(titulo),
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

  Future<void> _consultarDisponibilidad() async {
    if (areaSel == null ||
        fechaSel == null ||
        horaIni == null ||
        horaFin == null) {
      _alert("Faltan datos", "Selecciona área, fecha, hora inicio y hora fin.");
      return;
    }
    if (!_horarioValido()) {
      _alert(
        "Horario inválido",
        "La hora fin debe ser mayor que la hora inicio.",
      );
      return;
    }

    setState(() {
      consultando = true;
      disponible = null;
      mensajeDisp = null;
    });

    try {
      final cveArea = (areaSel["cve_area"] as num).toInt();
      final fecha = _fmtFecha(fechaSel!);
      final ini = _fmtTime(horaIni!);
      final fin = _fmtTime(horaFin!);

      final res = await widget.dio.get(
        "/areas/$cveArea/disponibilidad",
        queryParameters: {"fecha": fecha, "inicio": ini, "fin": fin},
      );

      if (res.statusCode != 200) {
        setState(() {
          disponible = false;
          mensajeDisp =
              "Error disponibilidad. HTTP ${res.statusCode}\n${res.data}";
          consultando = false;
        });
        return;
      }

      final data = Map<String, dynamic>.from(res.data as Map);
      final disp = (data["disponible"] == true);

      setState(() {
        disponible = disp;
        mensajeDisp = disp
            ? "Disponible ✅"
            : "No disponible ❌ (elige otro horario)";
        consultando = false;
      });
    } catch (e) {
      setState(() {
        disponible = false;
        mensajeDisp = "Error consultando disponibilidad: $e";
        consultando = false;
      });
    }
  }

  Future<void> _crearReserva() async {
    if (disponible != true) {
      _alert(
        "No disponible",
        "Primero consulta disponibilidad y asegúrate que esté disponible.",
      );
      return;
    }

    final cveArea = (areaSel["cve_area"] as num).toInt();

    final payload = {
      "cve_area": cveArea,
      "id_persona_solicitante": widget.idPersona,
      "id_usuario_registro": widget.idUsuario,
      "fecha_reserva": _fmtFecha(fechaSel!),
      "hora_inicio": _fmtTime(horaIni!),
      "hora_fin": _fmtTime(horaFin!),
    };

    try {
      final res = await widget.dio.post("/reservas", data: payload);

      if (res.statusCode == 409) {
        _alert(
          "No disponible",
          "Alguien reservó antes ese horario. Elige otro.",
        );
        setState(() => disponible = false);
        return;
      }

      if (res.statusCode != 200) {
        _alert(
          "Error",
          "No se pudo crear la reserva.\nHTTP ${res.statusCode}\n${res.data}",
        );
        return;
      }

      await _cargarFechasOcupadas(cveArea: cveArea, month: _focusedDay);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text("Reserva creada"),
          content: const Text("Tu reserva quedó registrada como PENDIENTE."),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                widget.onReservaCreada();
              },
              child: const Text("Ver historial"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("OK"),
            ),
          ],
        ),
      );
    } catch (e) {
      _alert("Error", "No se pudo crear la reserva.\n$e");
    }
  }

  // --- UI helper (colores del calendario)
  Widget _dayMarker(DateTime day) {
    final d = _onlyDate(day);
    final isSelected = fechaSel != null && isSameDay(fechaSel!, d);
    final isOcc = _ocupadas.contains(d);

    final Color bg = isOcc ? AppColors.amarillo : AppColors.celesteClaro;
    final Color border = isSelected
        ? AppColors.celesteNegro
        : Colors.transparent;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      margin: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border, width: 2),
      ),
      alignment: Alignment.center,
      child: Text(
        '${day.day}',
        style: TextStyle(
          color: Colors.black,
          fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
        ),
      ),
    );
  }

  Widget _legendDot(Color c, String txt) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 6),
        Text(txt, style: const TextStyle(fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cargandoAreas) return const Center(child: CircularProgressIndicator());

    if (errorAreas != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(errorAreas!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _cargarAreas,
                child: const Text("Reintentar"),
              ),
            ],
          ),
        ),
      );
    }

    // ✅ FIX OVERFLOW: scroll + minHeight + intrinsicHeight
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: IntrinsicHeight(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ==========
                  // ÁREA
                  // ==========
                  DropdownButtonFormField<dynamic>(
                    value: areaSel,
                    items: areas
                        .map(
                          (a) => DropdownMenuItem(
                            value: a,
                            child: Text(a["nombre"].toString()),
                          ),
                        )
                        .toList(),
                    onChanged: (v) async {
                      setState(() {
                        areaSel = v;
                        fechaSel = null;
                        disponible = null;
                        mensajeDisp = null;
                        _ocupadas.clear();
                        errorFechas = null;
                      });

                      if (v != null) {
                        final cveArea = (v["cve_area"] as num).toInt();
                        await _cargarFechasOcupadas(
                          cveArea: cveArea,
                          month: _focusedDay,
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: "Área común",
                      border: OutlineInputBorder(),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // ==========
                  // CALENDAR
                  // ==========
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: const [
                        BoxShadow(color: Colors.black12, blurRadius: 4),
                      ],
                    ),
                    padding: const EdgeInsets.all(10),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_month,
                              color: AppColors.celesteNegro,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              "Calendario",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const Spacer(),
                            _legendDot(AppColors.amarillo, "Ocupada"),
                            const SizedBox(width: 10),
                            _legendDot(AppColors.celesteClaro, "Disponible"),
                          ],
                        ),
                        const SizedBox(height: 8),

                        if (areaSel == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: Text(
                              "Selecciona un área para ver el calendario.",
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else if (cargandoFechas)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: CircularProgressIndicator(),
                          )
                        else if (errorFechas != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Column(
                              children: [
                                Text(errorFechas!, textAlign: TextAlign.center),
                                const SizedBox(height: 10),
                                ElevatedButton(
                                  onPressed: () async {
                                    final cveArea = (areaSel["cve_area"] as num)
                                        .toInt();
                                    await _cargarFechasOcupadas(
                                      cveArea: cveArea,
                                      month: _focusedDay,
                                    );
                                  },
                                  child: const Text("Reintentar"),
                                ),
                              ],
                            ),
                          )
                        else
                          SizedBox(
                            height: 360,
                            child: TableCalendar(
                              firstDay: DateTime.now(),
                              lastDay: DateTime(
                                DateTime.now().year + 2,
                                12,
                                31,
                              ),
                              focusedDay: _focusedDay,
                              calendarFormat: CalendarFormat.month,
                              startingDayOfWeek: StartingDayOfWeek.monday,
                              availableGestures:
                                  AvailableGestures.horizontalSwipe,
                              selectedDayPredicate: (day) =>
                                  fechaSel != null && isSameDay(fechaSel!, day),
                              onDaySelected: (selectedDay, focusedDay) {
                                setState(() {
                                  fechaSel = _onlyDate(selectedDay);
                                  _focusedDay = focusedDay;
                                  disponible = null;
                                  mensajeDisp = null;
                                });
                              },
                              onPageChanged: (focusedDay) async {
                                _focusedDay = focusedDay;
                                if (areaSel != null) {
                                  final cveArea = (areaSel["cve_area"] as num)
                                      .toInt();
                                  await _cargarFechasOcupadas(
                                    cveArea: cveArea,
                                    month: focusedDay,
                                  );
                                }
                                if (mounted) setState(() {});
                              },
                              headerStyle: const HeaderStyle(
                                formatButtonVisible: false,
                                titleCentered: true,
                              ),
                              calendarStyle: const CalendarStyle(
                                outsideDaysVisible: false,
                                isTodayHighlighted: true,
                              ),
                              calendarBuilders: CalendarBuilders(
                                defaultBuilder: (context, day, _) =>
                                    _dayMarker(day),
                                todayBuilder: (context, day, _) =>
                                    _dayMarker(day),
                                selectedBuilder: (context, day, _) =>
                                    _dayMarker(day),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 12),

                  // FECHA seleccionada
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.black12),
                    ),
                    child: Text(
                      fechaSel == null
                          ? "Fecha: (selecciona en el calendario)"
                          : "Fecha: ${_fmtFecha(fechaSel!)}",
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // HORAS
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickHoraInicio,
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            horaIni == null
                                ? "Hora inicio"
                                : _fmtTime(horaIni!),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickHoraFin,
                          icon: const Icon(Icons.schedule),
                          label: Text(
                            horaFin == null ? "Hora fin" : _fmtTime(horaFin!),
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // CONSULTAR
                  ElevatedButton(
                    onPressed: consultando ? null : _consultarDisponibilidad,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.celesteNegro,
                    ),
                    child: consultando
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text(
                            "Consultar disponibilidad",
                            style: TextStyle(color: Colors.white),
                          ),
                  ),

                  const SizedBox(height: 10),

                  if (mensajeDisp != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (disponible == true)
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: (disponible == true)
                              ? Colors.green
                              : Colors.red,
                        ),
                      ),
                      child: Text(
                        mensajeDisp!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: (disponible == true)
                              ? Colors.green[800]
                              : Colors.red[800],
                        ),
                      ),
                    ),

                  const Spacer(),

                  // CONFIRMAR
                  ElevatedButton(
                    onPressed: (disponible == true) ? _crearReserva : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.amarillo,
                    ),
                    child: const Text(
                      "Confirmar reserva",
                      style: TextStyle(color: Colors.black),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    "Si no está disponible, elige otra fecha u horario.",
                    style: TextStyle(fontSize: 12, color: Colors.grey),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// =======================
// TAB: HISTORIAL GLOBAL DE RESERVAS
// =======================
class _HistorialReservasTab extends StatefulWidget {
  final Dio dio;

  const _HistorialReservasTab({required this.dio});

  @override
  State<_HistorialReservasTab> createState() => _HistorialReservasTabState();
}

class _HistorialReservasTabState extends State<_HistorialReservasTab> {
  bool cargando = true;
  String? error;
  List<dynamic> reservas = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      cargando = true;
      error = null;
    });

    try {
      // 🔸 Endpoint sugerido: GET /reservas/historial
      final res = await widget.dio.get("/reservas/historial");

      if (res.statusCode != 200) {
        setState(() {
          error =
              "Error al cargar historial de reservas. HTTP ${res.statusCode}\n${res.data}";
          cargando = false;
        });
        return;
      }

      setState(() {
        reservas = (res.data as List);
        cargando = false;
      });
    } catch (e) {
      setState(() {
        error = "Error al cargar historial: $e";
        cargando = false;
      });
    }
  }

  Color _estadoColor(String e) {
    final x = e.toLowerCase();
    if (x == "confirmada") return Colors.green;
    if (x == "pendiente") return Colors.orange;
    if (x == "cancelada" || x == "rechazada") return Colors.red;
    return Colors.blueGrey;
  }

  @override
  Widget build(BuildContext context) {
    if (cargando) return const Center(child: CircularProgressIndicator());

    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _cargar,
                child: const Text("Reintentar"),
              ),
            ],
          ),
        ),
      );
    }

    if (reservas.isEmpty) {
      return const Center(
        child: Text("No hay reservas registradas aún."),
      );
    }

    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reservas.length,
        itemBuilder: (_, i) {
          final r = reservas[i] as Map;

          final area = r["area_nombre"]?.toString() ?? "Área desconocida";
          final fecha = r["fecha_reserva"]?.toString() ?? "-";
          final ini =
              (r["hora_inicio"]?.toString() ?? "--:--").substring(0, 5);
          final fin = (r["hora_fin"]?.toString() ?? "--:--").substring(0, 5);
          final estado = r["estado"]?.toString() ?? "desconocido";
          final nombrePersona =
              r["nombre_persona"]?.toString() ?? "Persona desconocida";

          final c = _estadoColor(estado);

          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              boxShadow: const [
                BoxShadow(color: Colors.black12, blurRadius: 4),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Título: Área
                Text(
                  area,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                // Persona que reservó
                Row(
                  children: [
                    const Icon(Icons.person, size: 16),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        "Reservó: $nombrePersona",
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Fecha y horario
                Text("Fecha: $fecha"),
                Text("Horario: $ini - $fin"),
                const SizedBox(height: 10),
                // Estado
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: c.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: c),
                  ),
                  child: Text(
                    estado.toUpperCase(),
                    style: TextStyle(color: c, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
