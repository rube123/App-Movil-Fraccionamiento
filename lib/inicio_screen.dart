import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fraccionamiento/avisos_historial_screen.dart';
import 'package:fraccionamiento/avisos_screen.dart';
import 'package:fraccionamiento/colors.dart';
import 'package:fraccionamiento/residentes_screen.dart';
import 'package:fraccionamiento/area_comun_screen.dart';
import 'package:fraccionamiento/pagos_screen.dart';
import 'package:fraccionamiento/session.dart';
import 'package:fraccionamiento/controllers/auth_controller.dart';
import 'package:fraccionamiento/ui/profile_screen.dart';
import 'package:fraccionamiento/mesa_directiva_screen.dart';
import 'package:fraccionamiento/services/tutorial_service.dart';

class InicioScreen extends StatefulWidget {
  final List<String> roles;
  final int idPersona;
  final int idUsuario;
  final String tipoUsuario;

  const InicioScreen({
    super.key,
    required this.roles,
    required this.idPersona,
    required this.idUsuario,
    required this.tipoUsuario,
  });

  @override
  State<InicioScreen> createState() => _InicioScreenState();
}

class _InicioScreenState extends State<InicioScreen> {
  static const String baseUrl = "https://apifraccionamiento.onrender.com";

  // Keys para el tutorial
  final GlobalKey keyReservas = GlobalKey();
  final GlobalKey keyAvisos = GlobalKey();
  final GlobalKey keyPagos = GlobalKey();
  final GlobalKey keyPerfil = GlobalKey();

  int _currentIndex = 0;
  int unread = 0;

  late final Dio dio;
  late final PageController _pageController;
  Timer? _timer; // para unread
  Timer? _idleTimer; // para inactividad

  bool get isAdmin => widget.roles.contains('admin');
  bool get isMesa => widget.roles.contains('mesa_directiva');
  bool get isResidente => widget.roles.contains('residente');

  // Estado para el panel (residente/admin/mesa)
  String? nombreResidente;
  List<dynamic> reservasRecientes = [];
  List<dynamic> pagosRecientes = [];
  bool cargandoHomeResidente = false;
  String? errorHomeResidente;

  // Avisos por mes
  Map<int, int> avisosPorMes = {}; // mes -> total
  int mesSeleccionado = DateTime.now().month;

  @override
  void initState() {
    super.initState();

    dio = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 10),
      ),
    );

    _pageController = PageController(initialPage: 0);

    cargarUnread();
    _timer = Timer.periodic(const Duration(seconds: 20), (_) => cargarUnread());

    // Cargar dashboard
    _cargarDatosHome();

    // Inactividad
    _resetIdleTimer();

    // Tutorial (solo 1ª vez por persona)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _mostrarTutorialSiNecesario();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _idleTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ==================== INACTIVIDAD ====================

  void _resetIdleTimer() {
    _idleTimer?.cancel();
    _idleTimer = Timer(
      Duration(minutes: Session.inactivityMinutes),
      _onInactivityTimeout,
    );
  }

  Future<void> _onInactivityTimeout() async {
    await AuthController.to.logout();
    await Session.clear();

    if (!mounted) return;

    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  void _onUserInteraction() {
    // Cada interacción reinicia contador y actualiza last_activity
    Session.touch();
    _resetIdleTimer();
  }

  // ==================== TUTORIAL ====================

  Future<void> _mostrarTutorialSiNecesario() async {
    final sp = await SharedPreferences.getInstance();
    final prefKey = 'tutorial_home_mostrado_${widget.idPersona}';

    final yaMostrado = sp.getBool(prefKey) ?? false;
    if (yaMostrado) return;

    final tutorialService = TutorialService();

    final targets = tutorialService.createTargets(
      botonReservas: keyReservas,
      botonPagos: keyPagos,
      botonAvisos: (isAdmin || isMesa) ? keyAvisos : null,
      botonPerfil: keyPerfil,
      mostrarReservas: true,
      mostrarPagos: true,
      mostrarPerfil: true,
      mostrarAvisos: isAdmin || isMesa,
    );

    if (targets.isEmpty) return;

    await tutorialService.start(
      context: context,
      targets: targets,
    );

    await sp.setBool(prefKey, true);
  }

  // ==================== DATA INICIO ====================

  Future<void> cargarUnread() async {
    try {
      final res = await dio.get("/avisos/unread/${widget.idPersona}");
      if (!mounted) return;
      setState(() {
        unread = (res.data is Map) ? (res.data["unread"] ?? 0) : 0;
      });
    } catch (e) {
      print("❌ Error cargando unread: $e");
    }
  }

  Future<void> _cargarDatosHome() async {
    try {
      setState(() {
        cargandoHomeResidente = true;
        errorHomeResidente = null;
      });

      String endpoint;
      if (isAdmin) {
        endpoint = "/dashboard/admin";
      } else if (isMesa) {
        endpoint = "/dashboard/mesa/${widget.idPersona}";
      } else {
        endpoint = "/inicio/residente/${widget.idPersona}";
      }

      final res = await dio.get(endpoint);
      final data = res.data as Map<String, dynamic>;

      final avisosList = (data["avisos_por_mes"] ?? []) as List<dynamic>;

      setState(() {
        nombreResidente = data["nombre"] as String?;
        reservasRecientes = (data["reservas"] ?? []) as List<dynamic>;
        pagosRecientes = (data["pagos"] ?? []) as List<dynamic>;
        avisosPorMes = {
          for (final item in avisosList)
            (item["mes"] as int): (item["total"] as int),
        };
        cargandoHomeResidente = false;
      });
    } catch (e) {
      setState(() {
        errorHomeResidente = "Error al cargar datos: $e";
        cargandoHomeResidente = false;
      });
    }
  }

  Future<void> _cerrarSesion() async {
    await AuthController.to.logout();
    await Session.clear();

    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  Future<void> _irAAvisos() async {
    _onUserInteraction();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AvisosScreen(
          roles: widget.roles,
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
        ),
      ),
    );
    cargarUnread();
  }

  // ==================== NAVEGACIÓN ====================

  void _onItemTapped(int index) {
    _onUserInteraction();
    setState(() => _currentIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  List<BottomNavigationBarItem> _buildItems() {
    if (isAdmin) {
      // Admin
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Residentes',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.group),
          label: 'Mesa Dir.',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.payments, key: keyPagos),
          label: 'Pagos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_available, key: keyReservas),
          label: 'Áreas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications, key: keyAvisos),
          label: 'Avisos',
        ),
      ];
    } else if (isMesa) {
      // Mesa directiva
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.people),
          label: 'Residentes',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.payments, key: keyPagos),
          label: 'Pagos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_available, key: keyReservas),
          label: 'Áreas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.notifications, key: keyAvisos),
          label: 'Avisos',
        ),
      ];
    } else {
      // Residente
      return [
        const BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.payments, key: keyPagos),
          label: 'Pagos',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.event_available, key: keyReservas),
          label: 'Áreas',
        ),
      ];
    }
  }

  Drawer? _buildDrawer(BuildContext context) {
    if (isAdmin) return null;

    final statusBarHeight = MediaQuery.of(context).padding.top;

    return Drawer(
      child: Padding(
        padding: EdgeInsets.only(top: statusBarHeight),
        child: Column(
          children: [
            const ListTile(
              title: Text(
                "Menú",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text("Reservar Áreas Comunes"),
              onTap: () async {
                Navigator.pop(context);
                _onUserInteraction();
                if (isResidente) {
                  _onItemTapped(2);
                } else if (isMesa) {
                  _onItemTapped(3);
                }
              },
            ),
            if (isResidente || isMesa)
              ListTile(
                leading: const Icon(Icons.payments),
                title: const Text("Pagos"),
                onTap: () {
                  Navigator.pop(context);
                  _onUserInteraction();
                  if (isResidente) {
                    _onItemTapped(1);
                  } else if (isMesa) {
                    _onItemTapped(2);
                  }
                },
              ),
            ListTile(
              leading: const Icon(Icons.notifications),
              title: const Text("Avisos"),
              onTap: () async {
                Navigator.pop(context);
                _onUserInteraction();
                if (isMesa) {
                  _onItemTapped(4);
                } else if (isResidente) {
                  await _irAAvisos();
                }
              },
            ),
            const Spacer(),
            ListTile(
              leading: const Icon(Icons.logout),
              title: const Text("Cerrar sesión"),
              onTap: _cerrarSesion,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildAppBarActions() {
    return [
      // Notificaciones con badge
      Stack(
        children: [
          IconButton(
            icon: const Icon(Icons.notifications, color: Colors.white),
            onPressed: () async {
              _onUserInteraction();
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      AvisosHistorialScreen(idPersona: widget.idPersona),
                ),
              );
              cargarUnread();
            },
          ),
          if (unread > 0)
            Positioned(
              right: 8,
              top: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  unread.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      ),

      // Avatar / perfil
      Padding(
        padding: const EdgeInsets.only(right: 12),
        child: Obx(() {
          final photo = AuthController.to.user.value.photoUrl;

          return GestureDetector(
            onTap: () {
              _onUserInteraction();
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ProfileScreen(
                    idPersona: widget.idPersona,
                    idUsuario: widget.idUsuario,
                  ),
                ),
              );
            },
            child: CircleAvatar(
              key: keyPerfil,
              radius: 18,
              backgroundImage: photo.isNotEmpty
                  ? NetworkImage(photo)
                  : const AssetImage("assets/avatar_default.png")
                      as ImageProvider,
            ),
          );
        }),
      ),
    ];
  }

  // ==================== APPBAR / PAGES ====================

  String _getAppBarTitle() {
    if (isResidente) {
      switch (_currentIndex) {
        case 0:
          return 'Inicio';
        case 1:
          return 'Gestión de pagos';
        case 2:
          return 'Reserva de áreas';
        default:
          return 'Inicio';
      }
    }

    if (isAdmin) {
      switch (_currentIndex) {
        case 0:
          return 'Inicio';
        case 1:
          return 'Residentes';
        case 2:
          return 'Mesa Directiva';
        case 3:
          return 'Pagos';
        case 4:
          return 'Áreas comunes';
        case 5:
          return 'Avisos';
        default:
          return 'Inicio';
      }
    }

    if (isMesa) {
      switch (_currentIndex) {
        case 0:
          return 'Inicio';
        case 1:
          return 'Residentes';
        case 2:
          return 'Pagos';
        case 3:
          return 'Áreas comunes';
        case 4:
          return 'Avisos';
        default:
          return 'Inicio';
      }
    }

    return 'Inicio';
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: AppColors.celesteNegro,
      title: Text(
        _getAppBarTitle(),
        style: const TextStyle(color: Colors.white),
      ),
      actions: _buildAppBarActions(),
      foregroundColor: Colors.white,
    );
  }

  List<Widget> _buildPages() {
    if (isAdmin) {
      return [
        Padding(padding: const EdgeInsets.all(20.0), child: _buildAdminHome()),
        const ResidentesScreen(),
        const MesaDirectivaScreen(),
        PagosScreen(
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
          roles: widget.roles,
        ),
        AreaComunScreen(
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
        ),
        AvisosScreen(
          roles: widget.roles,
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
        ),
      ];
    }

    if (isMesa) {
      return [
        Padding(padding: const EdgeInsets.all(20.0), child: _buildMesaHome()),
        const ResidentesScreen(),
        PagosScreen(
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
          roles: widget.roles,
        ),
        AreaComunScreen(
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
        ),
        AvisosScreen(
          roles: widget.roles,
          idPersona: widget.idPersona,
          idUsuario: widget.idUsuario,
        ),
      ];
    }

    // Residente
    return [
      Padding(
        padding: const EdgeInsets.all(20.0),
        child: _buildResidenteHome(),
      ),
      PagosScreen(
        idPersona: widget.idPersona,
        idUsuario: widget.idUsuario,
        embedded: true,
        roles: widget.roles,
      ),
      AreaComunScreen(
        idPersona: widget.idPersona,
        idUsuario: widget.idUsuario,
        embedded: true,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final pages = _buildPages();

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTapDown: (_) => _onUserInteraction(),
      onPanDown: (_) => _onUserInteraction(),
      child: Scaffold(
        backgroundColor: AppColors.celesteClaro,
        drawer: _buildDrawer(context),
        appBar:
            (isAdmin || isMesa) && _currentIndex != 0 ? null : _buildAppBar(),
        body: PageView(
          controller: _pageController,
          onPageChanged: (index) {
            _onUserInteraction();
            setState(() => _currentIndex = index);
          },
          children: pages,
        ),
        bottomNavigationBar: BottomNavigationBar(
          type: BottomNavigationBarType.fixed,
          backgroundColor: AppColors.celesteNegro,
          selectedItemColor: Colors.white,
          unselectedItemColor: Colors.white70,
          currentIndex: _currentIndex,
          onTap: _onItemTapped,
          items: _buildItems(),
        ),
      ),
    );
  }

  // ==================== HOMES ====================

  Widget _buildAdminHome() {
    if (cargandoHomeResidente) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorHomeResidente != null) {
      return Center(
        child: Text(
          errorHomeResidente!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final nombre =
        nombreResidente ??
        (AuthController.to.user.value.displayName?.isNotEmpty == true
            ? AuthController.to.user.value.displayName!
            : "Administrador");

    final reservasMostrar = reservasRecientes.length > 2
        ? reservasRecientes.sublist(0, 2)
        : reservasRecientes;
    final pagosMostrar =
        pagosRecientes.isNotEmpty ? [pagosRecientes.first] : <dynamic>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // tarjeta bienvenida
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido,',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Panel general de actividad del fraccionamiento',
                  style: TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reservas recientes (todos)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Reservas Recientes (todos)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _onItemTapped(4),
                child: const Text(
                  'Ver todo',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reservasMostrar.isEmpty)
            const Text(
              'No hay reservas recientes.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: reservasMostrar.map((r) {
                final areaNombre =
                    (r["area_nombre"] ?? r["nombre_area"] ?? "Área común")
                        .toString();
                final fecha = (r["fecha_reserva"] ?? "").toString();
                final horaInicio = (r["hora_inicio"] ?? "").toString();
                final horaFin = (r["hora_fin"] ?? "").toString();
                final detalle = "$fecha  $horaInicio - $horaFin";

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _cardReserva(
                    icon: Icons.event_available,
                    iconBgColor: Colors.blueAccent.withOpacity(0.12),
                    iconColor: Colors.blueAccent,
                    titulo: areaNombre,
                    subtitulo: detalle,
                    onTap: () => _onItemTapped(4),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Pagos recientes (todos)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Pagos Recientes (todos)',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              GestureDetector(
                onTap: () => _onItemTapped(3),
                child: const Text(
                  'Ver todo',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pagosMostrar.isEmpty)
            const Text(
              'No hay pagos recientes.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: pagosMostrar.map((p) {
                final concepto =
                    (p["concepto"] ?? p["descripcion"] ?? "Pago").toString();
                final fechaPago =
                    (p["fecha_pago"] ?? p["pagado_el"] ?? "").toString();
                final monto =
                    (p["monto"] ?? p["total"] ?? "").toString(); // 1500.00

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _cardPago(
                    titulo: concepto,
                    subtitulo:
                        fechaPago.isNotEmpty ? "Pagado el $fechaPago" : "",
                    monto: monto.isNotEmpty ? "\$$monto" : "",
                    onTap: () => _onItemTapped(3),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          _buildGraficaAvisosAdmin(),
        ],
      ),
    );
  }

  Widget _buildGraficaAvisosAdmin() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Avisos enviados por mes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              DropdownButton<int>(
                value: mesSeleccionado,
                underline: const SizedBox.shrink(),
                items: List.generate(
                  12,
                  (i) => DropdownMenuItem(
                    value: i + 1,
                    child: Text(_mesNombreCorto(i + 1)),
                  ),
                ),
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    mesSeleccionado = value;
                  });
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 160,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final maxValor = avisosPorMes.isEmpty
                    ? 1.0
                    : avisosPorMes.values.reduce(max).toDouble();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: List.generate(12, (i) {
                    final mes = i + 1;
                    final valor = (avisosPorMes[mes] ?? 0).toDouble();
                    final heightFactor =
                        maxValor == 0 ? 0.0 : (valor / maxValor);

                    return Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Expanded(
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: constraints.maxWidth / 14,
                                height: constraints.maxHeight *
                                    heightFactor.clamp(0.0, 1.0),
                                decoration: BoxDecoration(
                                  color: mes == mesSeleccionado
                                      ? Colors.blueAccent
                                      : Colors.blueAccent.withOpacity(0.25),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _mesNombreCorto(mes),
                            style: const TextStyle(fontSize: 10),
                          ),
                        ],
                      ),
                    );
                  }),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mes seleccionado: ${_mesNombreLargo(mesSeleccionado)}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '${avisosPorMes[mesSeleccionado] ?? 0} avisos',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMesaHome() {
    if (cargandoHomeResidente) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorHomeResidente != null) {
      return Center(
        child: Text(
          errorHomeResidente!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final nombre =
        nombreResidente ??
        (AuthController.to.user.value.displayName?.isNotEmpty == true
            ? AuthController.to.user.value.displayName!
            : "Miembro de mesa directiva");

    final avisosMesActual = avisosPorMes[mesSeleccionado] ?? 0;

    final pagosMantenimiento = pagosRecientes
        .where((p) => (p["id_tipo_cuota"] ?? 0) == 1)
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // tarjeta avisos mes
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Avisos realizados este mes',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  '$avisosMesActual avisos',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueAccent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _mesNombreLargo(mesSeleccionado),
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          Text(
            'Hola, $nombre',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            'Desde aquí puedes revisar rápidamente los pagos de mantenimiento '
            'y las reservas de áreas realizadas en el fraccionamiento.',
            style: TextStyle(fontSize: 12, color: Colors.black54),
          ),
          const SizedBox(height: 20),

          // PAGOS MANTENIMIENTO
          const Text(
            'Pagos de mantenimiento',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (pagosMantenimiento.isEmpty)
            const Text(
              'No hay pagos de mantenimiento registrados.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: pagosMantenimiento.map((p) {
                final concepto =
                    (p["concepto"] ?? p["descripcion"] ?? "Pago").toString();
                final fecha = _shortFecha(
                  p["fecha_pago"] ??
                      p["pagado_el"] ??
                      p["fecha_transaccion"],
                );
                final monto =
                    (p["monto"] ?? p["total"] ?? "").toString(); // 1500.00
                final estado = (p["estado"] ?? '').toString();

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => _onItemTapped(2),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.purple.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.receipt_long,
                              color: Colors.purple,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  concepto,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fecha.isNotEmpty
                                      ? 'Fecha: $fecha'
                                      : 'Sin fecha registrada',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                monto.isNotEmpty ? '\$$monto' : '—',
                                style: const TextStyle(
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: _colorEstadoPago(estado)
                                      .withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  estado.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: _colorEstadoPago(estado),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // RESERVAS
          const Text(
            'Reservas de áreas',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (reservasRecientes.isEmpty)
            const Text(
              'No hay reservas de áreas registradas.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: reservasRecientes.map((r) {
                final areaNombre =
                    (r["area_nombre"] ?? r["nombre_area"] ?? "Área común")
                        .toString();
                final fecha = _shortFecha(r["fecha_reserva"]);
                final horaInicio = (r["hora_inicio"] ?? '').toString();
                final horaFin = (r["hora_fin"] ?? '').toString();

                final detalle = [
                  if (fecha.isNotEmpty) fecha,
                  if (horaInicio.isNotEmpty && horaFin.isNotEmpty)
                    '$horaInicio - $horaFin',
                ].join(' · ');

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: InkWell(
                    onTap: () => _onItemTapped(3),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: Colors.blueAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.event_available,
                              color: Colors.blueAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  areaNombre,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  detalle,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.chevron_right,
                            color: Colors.black45,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildResidenteHome() {
    if (cargandoHomeResidente) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorHomeResidente != null) {
      return Center(
        child: Text(
          errorHomeResidente!,
          style: const TextStyle(color: Colors.red),
        ),
      );
    }

    final nombre =
        nombreResidente ??
        (AuthController.to.user.value.displayName?.isNotEmpty == true
            ? AuthController.to.user.value.displayName!
            : "Residente");

    final reservasMostrar = reservasRecientes.length > 2
        ? reservasRecientes.sublist(0, 2)
        : reservasRecientes;
    final pagosMostrar =
        pagosRecientes.isNotEmpty ? [pagosRecientes.first] : <dynamic>[];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // bienvenida
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Bienvenido,',
                  style: TextStyle(fontSize: 14, color: Colors.black54),
                ),
                const SizedBox(height: 4),
                Text(
                  nombre,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Reservas
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Reservas Recientes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'Ver todo',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (reservasMostrar.isEmpty)
            const Text(
              'No tienes reservas recientes.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: reservasMostrar.map((r) {
                final areaNombre =
                    (r["area_nombre"] ?? r["nombre_area"] ?? "Área común")
                        .toString();
                final fecha = (r["fecha_reserva"] ?? "").toString();
                final horaInicio = (r["hora_inicio"] ?? "").toString();
                final horaFin = (r["hora_fin"] ?? "").toString();
                final detalle = "$fecha  $horaInicio - $horaFin";

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _cardReserva(
                    icon: Icons.event_available,
                    iconBgColor: Colors.blueAccent.withOpacity(0.12),
                    iconColor: Colors.blueAccent,
                    titulo: areaNombre,
                    subtitulo: detalle,
                    onTap: () => _onItemTapped(2),
                  ),
                );
              }).toList(),
            ),

          const SizedBox(height: 24),

          // Pagos
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Pagos Recientes',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                'Ver todo',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.blue,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (pagosMostrar.isEmpty)
            const Text(
              'No tienes pagos recientes.',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            )
          else
            Column(
              children: pagosMostrar.map((p) {
                final concepto =
                    (p["concepto"] ?? p["descripcion"] ?? "Pago").toString();
                final fechaPago =
                    (p["fecha_pago"] ?? p["pagado_el"] ?? "").toString();
                final monto =
                    (p["monto"] ?? p["total"] ?? "").toString(); // 1500.00

                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: _cardPago(
                    titulo: concepto,
                    subtitulo:
                        fechaPago.isNotEmpty ? "Pagado el $fechaPago" : "",
                    monto: monto.isNotEmpty ? "\$$monto" : "",
                    onTap: () => _onItemTapped(1),
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  // ==================== HELPERS ====================

  String _shortFecha(dynamic raw) {
    final s = raw?.toString() ?? '';
    if (s.isEmpty) return '';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  Color _colorEstadoPago(String estado) {
    switch (estado.toLowerCase()) {
      case 'pagado':
        return Colors.green;
      case 'pendiente':
        return Colors.orange;
      case 'cancelado':
      case 'fallido':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Widget _cardReserva({
    required IconData icon,
    required Color iconBgColor,
    required Color iconColor,
    required String titulo,
    required String subtitulo,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconBgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.black45),
          ],
        ),
      ),
    );
  }

  Widget _cardPago({
    required String titulo,
    required String subtitulo,
    required String monto,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.purple.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long,
                color: Colors.purple,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    titulo,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitulo,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ],
              ),
            ),
            Text(
              monto,
              style: const TextStyle(
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _boton(
    BuildContext context,
    IconData icono,
    String texto, {
    VoidCallback? onTap,
    Key? key,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          boxShadow: const [BoxShadow(blurRadius: 4, color: Colors.black12)],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icono, size: 40, color: AppColors.celesteVivo),
            const SizedBox(height: 10),
            Text(texto, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  String _mesNombreCorto(int mes) {
    const nombres = [
      'Ene',
      'Feb',
      'Mar',
      'Abr',
      'May',
      'Jun',
      'Jul',
      'Ago',
      'Sep',
      'Oct',
      'Nov',
      'Dic',
    ];
    return nombres[(mes - 1).clamp(0, 11)];
  }

  String _mesNombreLargo(int mes) {
    const nombres = [
      'Enero',
      'Febrero',
      'Marzo',
      'Abril',
      'Mayo',
      'Junio',
      'Julio',
      'Agosto',
      'Septiembre',
      'Octubre',
      'Noviembre',
      'Diciembre',
    ];
    return nombres[(mes - 1).clamp(0, 11)];
  }
}
